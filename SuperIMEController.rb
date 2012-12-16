# -*- coding: utf-8 -*-
#
# SuperIMEController.rb
# SuperIME
# 
# Created by Sho Nakazono on 2012/12/10.
# Copyright 2012 nikezono.net. All rights reserved.
#

framework 'InputMethodKit'
framework 'Foundation'

require 'WordSearch'
require 'Romakana'
require 'Weblio'
require 'Reflexa'
require 'Ejje'
require 'Yomi'
require 'CandTableView'


class SuperIMEController < IMKInputController
    
    attr_accessor :candwin
    attr_accessor :tableview
    attr_accessor :modeSelector
    
    @@ws = nil
    @@table = nil
    @@candTable = nil
    @@circle = NSImage.alloc.initByReferencingFile(NSBundle.mainBundle.pathForResource("circle",ofType:"png"))
    @@selectedMode = 0
    
    def initWithServer(server, delegate:d, client:c)
        # puts "initWithServer===============@@ws = #{@@ws}"
        # Log.log "initWithServer delegate=#{d}, client="#{c}"
        @client = c   # Lexierraではこれをnilにしてた。何故?
        @@client = @client
        #puts @client.class
        
        
        # アウトレットの初期化
        @candwin = NSApp.delegate.candwin
        @tableview = NSApp.delegate.tableview
        @selector = NSApp.delegate.modeSelector
        
        # 辞書サーチ
        dictpath = NSBundle.mainBundle.pathForResource("dict", ofType:"txt")
        if @@ws.nil? then
            @@ws = WordSearch.new(dictpath)
        end
        
        if @@table.nil? then
            @@table = CandTableView.new
        end
        
        resetState
        
        if super then
            self
        end
    end
    
    #入力が確定されるごとにリセットされる
    def resetState
        @inputPat = ""
        $selectedstr = nil
        @candidates = []
        @@nthCand = 0
        @@ws.searchmode = 0
        @@selectedMode = 0
        @selector.selectSegmentWithTag(@@selectedMode)
    end
    
    def converting
        @inputPat.length > 0
    end
    
    #
    # キー入力などのイベントをすべて取得、必要なあらゆる処理を行なう
    # バインディングをしなければキーイベントのままアプリケーションごとに処理される
    # つまり、NSTextFieldにカーソルを当てている場合、CommandをスルーしてあるのでCommand+Aなどの機能は据え置きとなる
    #
    def handleEvent(event, client:sender)
        
        #debug
        
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
        range = @client.selectedRange
        astr = @client.attributedSubstringFromRange(range)
        if astr then
            s = astr.string
            $selectedstr = s if s != ""
        end
        
        
        return true if keyCode == kVirtual_JISKanaModeKey || keyCode == kVirtual_JISRomanModeKey
        return true if !eventString
        return true if eventString.length == 0
        
        handled = false
        
        # eventStringの文字コード取得
        s = sprintf("%s",eventString) # NSStringを普通のStringに??
        c = s.each_byte.to_a[0]
        #puts sprintf("c = 0x%x",c)
        
        #文字コードごとの処理
        #0x08:backspace
        #0x7f:del
            
        if c == 0x08 || c == 0x7f then
            if converting then#変換中で
                if @@nthCand > 0 then#最初の候補文字列でないとき
                    @@nthCand -= 1#変換候補を一つ戻す
                    #ビューを選択された文字列までスクロールする
                    @tableview.scrollRowToVisible(@@nthCand)
                    showCands
                else
                    @inputPat.sub!(/.$/,'')#最初の候補であれば、inputから一文字削る
                    
                    if @@selectedMode != 0 then#かな漢字変換に戻る
                        @@selectedMode = 0
                        @selector.selectSegmentWithTag(0)
                    end
                    searchAndShowCands
                end
                handled = true#変換中でないときはハンドルされない→NSTextFieldのBSイベントが来る
            end
            
            
        #0x1b:esc 全削除
        elsif c ==  0x1b then
            if converting then
                @inputPat = ""#全入力を削除する
                searchAndShowCands
                handled = true
            end
            
        #0x9:tab
        #変換モード切り替え	
        elsif c == 0x9 then
            if converting then #いきなり類語、といったことは出来ない
                @@selectedMode += 1
                @@selectedMode = 0 if @@selectedMode == 6
                @selector.selectSegmentWithTag(@@selectedMode)
                @tableview.scrollRowToVisible(@@nthCand-1)
                searchAndShowCands if converting
                handled = true
            end

        #0x20:space
        #候補
        #再変換も実装。
            
        elsif c == 0x20 then
            
            if converting then#変換中
                if @@nthCand < @candidates.length-1 then
                    @@nthCand += 1
                    showCands
                        
                    #ビューを選択された文字列までスクロールする
                    @tableview.scrollRowToVisible(@@nthCand+8)
                end
                handled = true
                
            elsif $selectedstr != nil then#変換中でない、かつ選択範囲にテキストが存在する
                @inputPat = Yomi::search($selectedstr)#読み仮名APIを用いて文字列の再変換を始める
                searchAndShowCands
                handled = true
                $selectedstr = nil
            end#変換中でなく、選択範囲が存在しない場合、NSTextFieldのspaceが呼ばれる
            
        #0x0a:Enter
        #0x0d:リターン
        #入力と変換の確定
            
        elsif c == 0x0a || c == 0x0d then
            if converting then
                fix
            
                handled = true
            end
            
        #その他の文字
        #いわゆる英数キーと記号
        elsif c >= 0x21 && c <= 0x7e && (modifierFlags  == 0 || modifierFlags == 131072) then
            fix if @@nthCand > 0 || @@ws.searchmode > 0#タブなどで変換送り中に他の文字列の入力を始めた場合、そこまでを確定する
            #puts modifierFlags#debug
            @inputPat << eventString
            searchAndShowCands
            @@ws.searchmode = 0
            handled = true
        end
        
        
        @@candTable = @candidates
        @tableview.reloadData
        
        showWindow
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
        
        #とりあえず、モードごとの条件分岐を行なっているが、
        #最終的には、サーバへのレスポンスを行い、そのクエリとして@selector.selectedSegmentを渡す。
        #返り値は一意に [image_url,単語,読み仮名]とする
        
        #まずは選択されているモードを調べる
        @@selectedMode = @selector.selectedSegment
        
        if @@selectedMode == 1 #類語
            @candidates = Weblio::search(@candidates[@@nthCand],@inputPat)
            @@nthCand = 0
            showCands
            
            elsif @@selectedMode == 2 #連想語
            @candidates = Reflexa::search(@candidates[@@nthCand],@inputPat)
                @@nthCand = 0
                showCands
            elsif @@selectedMode == 3 #英和和英
            @candidates = Ejje::search(@candidates[@@nthCand],@inputPat)
                @@nthCand = 0
                showCands
            
            #以下
        
        # WordSearch#search で検索して WordSearch#candidates で受け取る
        # @@ws.searchmode == 0 前方マッチ
        # @@ws.searchmode == 1 完全マッチ ひらがな/カタカナも候補に加える
        
        elsif @@ws.searchmode > 0
            @@ws.search(@inputPat)
            @candidates = @@ws.candidates
            #print @candidates
            katakana = @inputPat.roma2katakana
            if katakana != "" then
                @candidates = delete(@candidates,katakana)
                @candidates.unshift(katakana)
            end
            hiragana = @inputPat.roma2hiragana
            if hiragana != "" then
                @candidates = delete(@candidates,hiragana)
                @candidates.unshift(hiragana)
            end
            @candidates.unshift(@inputPat)
            else
            @@ws.search(@inputPat)
            @candidates = @@ws.candidates
            @candidates.unshift($selectedstr) if $selectedstr && $selectedstr != nil
            @candidates.unshift(@inputPat)
            if @candidates.length < 8 then
                hiragana = @inputPat.roma2hiragana
                @candidates.push(hiragana)
            end
            
        end
        @@nthCand = 0
        showCands
    end
    
    
    #入力の確定
    def fix
        if @candidates.length > @@nthCand then
            word = wordpart(@candidates[@@nthCand])

            @client.insertText(word,replacementRange:NSMakeRange(NSNotFound, NSNotFound))
        end
        resetState
    end
    
    def showCands
        #
        # 選択中の単語をキャレット位置にアンダーライン表示
        #
        @cands = @candidates.collect { |e|
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
        
        return 0 if  @@candTable.nil?
        return @@candTable.size
    end
    
    #テーブルにデータを入力する
    def tableView(aTableView,
                  objectValueForTableColumn: aTableColumn,
                  row: rowIndex)
        
        return @@circle if aTableColumn.identifier == 'Image' && rowIndex == @@nthCand
        return nil if aTableColumn.identifier == 'Image'
        return @@candTable[rowIndex][0] if aTableColumn.identifier == 'Candidate'
        return @@candTable[rowIndex][0] if aTableColumn.identifier == 'Description'
        
    end
    
    #
    # キャレットの位置に候補ウィンドウを出す
    #
    def showWindow
        # MacRubyでポインタを使うための苦しいやり方
        # 説明: http://d.hatena.ne.jp/Watson/20100823/1282543331
        #
        lineRectP = Pointer.new('{CGRect={CGPoint=dd}{CGSize=dd}}')
        @client.attributesForCharacterIndex(0,lineHeightRectangle:lineRectP)
        lineRect = lineRectP[0]
        origin = lineRect.origin
        origin.x -= 0;
        origin.y -= 200;
        @candwin.setFrameOrigin(origin)
        NSApp.unhide(self)
    end
    
    def hideWindow
        NSApp.hide(self)
    end
    
    #外部クラスから文字列を
    
    def insert(word)
        @@client.insertText(word,replacementRange:NSMakeRange(NSNotFound, NSNotFound))
    end
    
    # 入力システムがアクティブになると呼ばれる
    def activateServer(sender)
        @@ws.start
        showWindow
    end
    
    # 別の入力システムに切り換わったとき呼ばれる
    def deactivateServer(sender)
        hideWindow
        fix#現在の入力を確定する
        @@ws.finish
    end
    
end