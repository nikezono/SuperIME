# -*- coding: utf-8 -*-
#
# SuperIMEController.rb
# SuperIME
# 
# Created by Sho Nakazono on 2012/12/10.
# Copyright 2012 nikezono.net. All rights reserved.
#
# IMKServerのコントローラクラス
# 入力のハンドルを行う
# 同時に、TableViewとTabViewのdataSourceでもあるので、
# それらのプロトコルも実装している
#

framework 'InputMethodKit'
framework 'Foundation'

require 'Romakana'
require 'Weblio'
require 'Ejje'
require 'Yomi'
require 'CandTableView'
require 'ImageItem'
require 'GyazoButtonController'


class SuperIMEController < IMKInputController
    
    attr_accessor :candwin, :tableview, :modeSelector, :imageBrowserView, :tabview, :candview
    
    @@cs = nil
    @@candidates = nil
    @@circle = NSImage.alloc.initByReferencingFile(NSBundle.mainBundle.pathForResource("circle",ofType:"png"))
    @@gyazoIcon = NSImage.alloc.initByReferencingFile(NSBundle.mainBundle.pathForResource("bigicon",ofType:"png"))
    @@selectedMode = 0
    
    def awakeFromNib
        @cache = []
        @imageBrowserView.animates = true
        @imageBrowserView.dataSource = self
        @imageBrowserView.delegate = self
    end
    
    def initWithServer(server, delegate:d, client:c)
        # Log.log "initWithServer delegate=#{d}, client="#{c}"
        @client = c   # Lexierraではこれをnilにしてた。何故?
        @@client = @client
        
        
        # アウトレットの初期化
        @candwin = NSApp.delegate.candwin
        @candview = NSApp.delegate.candview
        @tableview = NSApp.delegate.tableview
        @selector = NSApp.delegate.modeSelector
        @imageBrowserView = NSApp.delegate.imageBrowserView
        @tabview = NSApp.delegate.tabview
        
        #サーバと接続
        if @@cs.nil? then
            @@cs = ConnectionServer.new
        end
        
        @cachedPat = Array.new # REPEATキーの為にキャッシュ
        @show = false
        
        resetState
        
        if super then
            self
        end
    end
    
    #入力が確定されるごとにリセットされる
    def resetState
        @inputPat = "" # 入力された単語
        @@candidates = []
        $selectedstr = nil
        @@nthCand = 0
        @@selectedMode = 0
        @selector.selectSegmentWithTag(@@selectedMode)
        @tabview.selectFirstTabViewItem(self)
        
        @copy = nil
        
        hideWindow
        
    end
    
    def converting
        @inputPat.length > 0
    end
    
    #
    # キー入力などのイベントをすべて取得、必要なあらゆる処理を行なう
    # バインディングをしなければキーイベントのままアプリケーションごとに処理される
    # つまり、NSTextFieldにカーソルを当てている場合、CommandをスルーしてあるのでCommand+Aなどの機能はそのまま使える
    #
    def handleEvent(event, client:sender)
        
        # かなキーボードのコード
        kVirtual_JISRomanModeKey = 102
        kVirtual_JISKanaModeKey  = 104
        kVirtual_Arrow_Left      = 0x7B
        kVirtual_Arrow_Right     = 0x7C
        kVirtual_Arrow_Down      = 0x7D
        kVirtual_Arrow_Up        = 0x7E
        
        @client = sender
        # puts "handleEvent: event.type = #{event.type}"
        return false if event.type != NSKeyDown
        
        eventString = event.characters
        keyCode = event.keyCode
        modifierFlags = event.modifierFlags
        
        #puts "handleEvent: event = #{event}, sender = #{sender}, eventString=#{eventString}, keyCode=#{keyCode}, handleEvent: modifierFlags=#{modifierFlags}"#debug
        
        # 選択されている文字列があれば覚えておく
        # イベントをハンドルした'時点'で選択されている文字列しか受け取れないので、
        # 仮に選択範囲がある状態でAなどのキーを叩くと、既に選択範囲は無いわけだが、selectedstrには中身が入っている。
        # つまりマウスクリックイベントが取れない。（本当は取れる？）
        # なので、マウスで選択した範囲をハンドルするためには、CTRL+Lなどのキーを押さないといけない。（検討)
        @range = @client.selectedRange
        astr = @client.attributedSubstringFromRange(@range)
        if astr then
            s = astr.string
            $selectedstr = s if s != ""
        end 
        
        
        return true if keyCode == kVirtual_JISRomanModeKey || keyCode == kVirtual_JISKanaModeKey 
        return true if !eventString
        return true if eventString.length == 0
        
        handled = false
        
        # eventStringの文字コード取得
        s = sprintf("%s",eventString) # NSStringを普通のStringに??
        c = s.each_byte.to_a[0]
        
        #文字コードごとの処理
        #0x08:backspace
        #0x7f:del
            
        if c == 0x08 || c == 0x7f then
            if converting then#変換中で
                if @@nthCand > 0 then#最初の候補文字列でないとき
                    @@nthCand -= 1#変換候補を一つ戻す
                    #ビューを選択された文字列までスクロールする
                    @tableview.scrollRowToVisible(@@nthCand)
                    @imageBrowserView.scrollIndexToVisible(@@nthCand) if @@selectedMode == 3
                    #@imageBrowserView.setSelectionIndexes(@@nthCand,false) if @@selectedMode == 3
                    showCands
                else
                    @inputPat.sub!(/.$/,'')#最初の候補であれば、inputから一文字削る
                    
                    if @@selectedMode != 0 then#かな漢字変換に戻る
                        @@selectedMode = 0
                        @selector.selectSegmentWithTag(0)
                        @tabview.selectFirstTabViewItem(self)
                    end
                    searchAndShowCands if @inputPat != ""
                    showCands if @inputPat == ""
                    hideWindow if @inputPat == ""
                end
                handled = true#変換中でないときはハンドルされない→NSTextFieldのBSイベントが来る
            end
            
        #0x1b:esc 全削除
        elsif c ==  0x1b then
            
            #変換中であれば学習した辞書の内容も消す
            if converting then
                $kanaDB.delete @inputPat.roma2hiragana
                @inputPat = ""#全入力を削除する
                if @@selectedMode != 0 then#かな漢字変換に戻る
                    @@selectedMode = 0
                    @selector.selectSegmentWithTag(0)
                    @tabview.selectFirstTabViewItem(self)
                end
                searchAndShowCands
                handled = true
            else
                @cachedPat.clear
                @count = 0
                resetState
            end
            hideWindow
            
        #0x9:tab
        #変換モード切り替え
        #シフトと同時押しで変換モード戻る
        elsif c == 0x9 then
            if converting then #いきなり類語、といったことは出来ない
                @@selectedMode += 1 if modifierFlags != 131072
                @@selectedMode -= 1 if modifierFlags == 131072
                @@selectedMode = 0 if @@selectedMode == 4
                
                @selector.selectSegmentWithTag(@@selectedMode)
                @tableview.scrollRowToVisible(@@nthCand-1)
                
                searchAndShowCands if converting

                @tabview.selectFirstTabViewItem(self) if @@selectedMode == 0
                
                if @@selectedMode == 3 then 
                    @imageBrowserView.reloadData
                    @tabview.selectLastTabViewItem(self) 
                    @@nthCand = 0 
                    @imageBrowserView.scrollIndexToVisible(@@nthCand)
                    #@imageBrowserView.setSelectionIndexes(0,'yes') if @@selectedMode == 3
                end
                showWindow
                handled = true
            end

        #0x20:space
        #候補送り
        #再変換も実装。
            
        elsif c == 0x20 then
            
            if converting then#変換中
                if @@nthCand < @@candidates.length-1 then
                    @@nthCand += 1
                    showCands
                    
                    showWindow
                    
                    #ビューを選択された文字列までスクロールする
                    @tableview.scrollRowToVisible(@@nthCand+8)
                    
                    #ビューを選択された画像までスクロールする
                    if @@selectedMode == 3 then
                        @imageBrowserView.scrollIndexToVisible(@@nthCand)
                        #@imageBrowserView.setSelectionIndexes(@@nthCand,false)
                    end
                end
                
                handled = true
                
            elsif $selectedstr != nil then#変換中でない、かつ選択範囲にテキストが存在する
                @inputPat = Yomi::search($selectedstr)#読み仮名APIを用いて文字列の再変換を始める
                searchAndShowCands
                $selectedstr = nil
                showWindow
                handled = true
                
            else #変換中でなく、かつ、再変換でもないs
                insert ""
                @cachedPat.unshift eventString
            end
                
        #0x0a:Enter
        #0x0d:リターン
        
        elsif c == 0x0a || c == 0x0d then            
            if converting then
                
                #学習機能
                unless @copy.nil? then
                    cands = $kanaDB[@inputPat.roma2hiragana]
                    cands.insert(1," \"#{@copy}\",")
                    $kanaDB.put(@inputPat.roma2hiragana,cands)
                end
                
                fix
                handled = true
            else#非変換中
                @client.insertText(eventString,replacementRange:NSMakeRange(NSNotFound, NSNotFound))
                @cachedPat.unshift eventString
                handled = true
            end

            
        # keyCode 122: F1
        # Dynamic MacroによるREPEATキー。
        # これまでの入力をキャッシュし繰り返しパターンを判別し入力するというもの
        # 4/3 とりあえず「直前の入力動作を全部繰り返す」は実装した
        # 4/4 アルゴリズムを考えられないのでダーティに作った
            
        elsif keyCode == 122 then
            unless converting then
                #puts "#{@cachedPat[1]} & #{@cachedPat[0]}"
                #単純に繰り返しなら同じもの入れる
                if @cachedPat[1] == @cachedPat[0] then
                    @client.insertText(@cachedPat[0],replacementRange:NSMakeRange(NSNotFound, NSNotFound))
                
                #複数の入力(てか２つ)の繰り返しなら同じもの入れる
                elsif @cachedPat[1] + @cachedPat[0] == @cachedPat[3] + @cachedPat[2] then
                    @client.insertText(@cachedPat[1] + @cachedPat[0],replacementRange:NSMakeRange(NSNotFound, NSNotFound))
                end
                handled = true
            end

            
        # keyCode 123: F2
        # 1文字置換
        elsif keyCode == 120 then
            unless converting then
                range = NSMakeRange(@range.location-2,2)
                str = @client.attributedSubstringFromRange(range)
                str = str.string
                @client.insertText(str.reverse,replacementRange:range)
            end
            handled = true
            
            
        #いわゆる英数キーと記号
        elsif c >= 0x21 && c <= 0x7e && (modifierFlags  == 0 || modifierFlags == 131072) then
            fix if @@nthCand > 0#タブなどで変換送り中に他の文字列の入力を始めた場合、そこまでを確定する
            
            #変換中ではなく選択文字列が存在する場合、学習機能をスタートする
            unless converting && $selectedstr.nil? then
                @copy = $selectedstr
            end
            @inputPat << eventString
            searchAndShowCands
            handled = true
        end
        
        @@candidates = @@candidates
        @tableview.reloadData
        
        showWindow if @show
        return handled
    end
    
    def wordpart(e) # 候補が[単語, 読み]のような配列で返ってくるとき単語部分だけ取得
        e.class == String ? e : e[0]
    end
    
    def delete(a,s)
        a.find_all { |e|
            wordpart(e) != s
        }
    end
    
    
    # 単語を検索して候補の配列を作成するメソッド
    def searchAndShowCands
        @@selectedMode = @selector.selectedSegment
        @@candidates = @@cs.getCandidates(@@candidates[@@nthCand],@inputPat,@@selectedMode)
        @@nthCand = 0
        showCands
    end
    
    
    #入力の確定
    def fix
        if @@candidates.length > @@nthCand then
            word = wordpart(@@candidates[@@nthCand])
            
            if @@candidates[@@nthCand][1] == "Gyazo" then
                gyazo = GyazoController.new
                gyazo.Gyazo
            else
                @client.insertText(word,replacementRange:NSMakeRange(NSNotFound, NSNotFound))
            end
            
            @cachedPat.unshift word
            
        end
        resetState
    end
    
    def showCands
        #
        # 選択中の単語をキャレット位置にアンダーライン表示
        #
        @cands = @@candidates.collect { |e|
            wordpart(e)
        }
        
        word = @cands[@@nthCand]
        
        if word then
            kTSMHiliteRawText = 2	
            attr = self.markForStyle(kTSMHiliteRawText,atRange:NSMakeRange(0,word.length))
            attrstr = NSAttributedString.alloc.initWithString(word,attributes:attr)
            @client.setMarkedText(attrstr,selectionRange:NSMakeRange(word.length,0),replacementRange:NSMakeRange(NSNotFound, NSNotFound))
        end
        
        #
        # 候補単語リストを表示
        #
        #@textview.setString(@cands[@@nthCand+1 .. @@nthCand+1+10].join(' '))
    end
    
    
    # タブビュー系プロトコル
    # データソースにこのクラスを定義してあるので、handleEventごとに随時呼び出される
    # タブビューの項目数を決定する
    def numberOfRowsInTableView(aTableView)
        
        return 0 if  @@candidates.nil?
        return @@candidates.size
    end
    
    #テーブルにデータを入力する
    def tableView(aTableView,
                  objectValueForTableColumn: aTableColumn,
                  row: rowIndex)
        
        return @@circle if aTableColumn.identifier == 'Image' && rowIndex == @@nthCand
        return nil if aTableColumn.identifier == 'Image'
        return @@candidates[rowIndex][0] if aTableColumn.identifier == 'Candidate'
        
    end
    
    #イメージビュープロトコル
    def numberOfItemsInImageBrowser(browser)
        return 0 if @@candidates == nil
        return @@candidates.length
        
    end
    
    def imageBrowser(browser, itemAtIndex:index)
        url = @@candidates[index][0]
        if @@candidates[index][1] == "Gyazo" then
            imageItem = ImageItem.new('http://gyazo.com/public/img/top/bigicon.png')
        else
            imageItem = ImageItem.new(url)
        end
        @cache[index] = imageItem
        return imageItem
    end

    
    #
    # キャレットの位置に候補ウィンドウを出す
    #
    def showWindow
        # MacRubyでポインタを使うための苦しいやり方
        # 説明: http://d.hatena.ne.jp/Watson/20100823/1282543331
        #
        @show = true
        @candview.setFrameSize(NSMakeSize(300,17*(@@candidates.length+3))) if @@candidates.length != 0 && @@candidates.length <= 10
        @candview.setFrameSize(NSMakeSize(300,17))if @@candidates.length == 0
        @candview.setFrameSize(NSMakeSize(300,175))if @@candidates.length >= 10
        
        lineRectP = Pointer.new('{CGRect={CGPoint=dd}{CGSize=dd}}')
        @client.attributesForCharacterIndex(0,lineHeightRectangle:lineRectP)
        lineRect = lineRectP[0]
        origin = lineRect.origin
        origin.x -= 0
        origin.y -= 50 + (@@candidates.length * 17) if @@candidates.length <= 6
        origin.y -= 150 + ((@@candidates.length-6) *17) if @@candidates.length <= 10 && @@candidates.length > 6
        origin.y -= 169  if @@candidates.length > 10
        @candwin.setFrameOrigin(origin)
        NSApp.unhide(self)
    end
    
    def hideWindow
        @show = false
        NSApp.hide(self)
    end
    
    #外部クラスから文字列を入力するためのメソッド
    
    def insert(word)
        @@client.insertText(word,replacementRange:NSMakeRange(NSNotFound, NSNotFound))
    end
    
    # 入力システムがアクティブになると呼ばれる
    def activateServer(sender)
        #showWindow
    end
    
    # 別の入力システムに切り換わったとき呼ばれる
    def deactivateServer(sender)
        hideWindow
        fix#現在の入力を確定する
    end
    
end