# -*- coding: utf-8 -*-
#
# GyaimController.rb
# Gyaim
#
# Created by Toshiyuki Masui on 2011/3/14.
# Copyright 2011 Pitecan Systems. All rights reserved.
#

framework 'InputMethodKit'

require 'WordSearch'
require 'Romakana'
require 'Crypt'
require 'Weblio'
require 'Reflexa'
require 'Ejje'
require 'GoogleSuggest'
require 'Yomi'


class GyaimController < IMKInputController
  attr_accessor :candwin
  attr_accessor :candview
  attr_accessor :textview

  @@ws = nil

  def initWithServer(server, delegate:d, client:c)
    # puts "initWithServer===============@@ws = #{@@ws}"
    # Log.log "initWithServer delegate=#{d}, client="#{c}"
    @client = c   # Lexierraではこれをnilにしてた。何故?

    # これが何故必要なのか不明
    @candwin = NSApp.delegate.candwin
    @textview = NSApp.delegate.textview

    # 辞書サーチ
    dictpath = NSBundle.mainBundle.pathForResource("dict", ofType:"txt")
    if @@ws.nil? then
      @@ws = WordSearch.new(dictpath)
    end

    resetState

    if super then
      self
    end
  end

  #
  # 入力システムがアクティブになると呼ばれる
  #
  def activateServer(sender)
    @@ws.start
    showWindow
  end

  #
  # 別の入力システムに切り換わったとき呼ばれる
  #
  def deactivateServer(sender)
    hideWindow
    fix
    @@ws.finish
  end

  def resetState
    @inputPat = ""
    @candidates = []
    @nthCand = 0
    @@ws.searchmode = 0
    @selectedstr = nil 
    @selectedCand = nil
      
    @func = false
    @weblio = false
    @reflexa = false
    @googleSuggest = false
    @googleJapanese = false
    @ejje = false
    @hira = false
    @kata = false
    @hirakata = false
  end

  def converting
    @inputPat.length > 0
  end

  #
  # キー入力などのイベントをすべて取得、必要なあらゆる処理を行なう
  # BS, Retなどが来ないこともあるのか?
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

      #puts "handleEvent: event = #{event}"
      #puts "handleEvent: sender = #{sender}"
      #puts "handleEvent: eventString=#{eventString}"
      #puts "handleEvent: keyCode=#{keyCode}"
      #puts "handleEvent: modifierFlags=#{modifierFlags}"
      
    # 選択されている文字列があれば覚えておく
    # 後で登録に利用するかも 
    range = @client.selectedRange
    astr = @client.attributedSubstringFromRange(range)
    if astr then
      s = astr.string
      @selectedstr = s if s != ""
    end

    return true if keyCode == kVirtual_JISKanaModeKey || keyCode == kVirtual_JISRomanModeKey
    return true if !eventString
    return true if eventString.length == 0

    handled = false

    # eventStringの文字コード取得
    # する方法がわからない
    s = sprintf("%s",eventString) # NSStringを普通のStringに??
    c = s.each_byte.to_a[0]
      #puts sprintf("c = 0x%x",c)

      
      #文字コードごとの処理
      #0x08:backspace
      #0x7f:del
      #0x1b:esc
      #上キーと左キーも同様に
      
    if c == 0x08 || c == 0x7f || keyCode == 123 || keyCode == 53 || keyCode == 126 then
      if converting then
        if @nthCand > 0 then
          @nthCand -= 1
          showCands
        elsif c == 0x08 || c == 0x7f then
          @inputPat.sub!(/.$/,'')
          searchAndShowCands
        end
        handled = true
      end
        
        #0x20:space
        #0x9:tab
        #再変換も実装。
        
    elsif c == 0x20 ||c == 0x9 then
      if converting then
        if @nthCand < @candidates.length-1 then
          @nthCand += 1
          showCands
        end
        handled = true
          
      elsif @selectedstr != "" then
        @inputPat = Yomi::search(@selectedstr)
        searchAndShowCands
        handled = true
        @selectedstr = nil
      end
        
        #0x0a:Enter
        #0x0d:リターン
        
    elsif c == 0x0a || c == 0x0d then
      if converting then
        if @@ws.searchmode > 0 then
          fix
        else
          if @nthCand == 0 && @hirakata != true then
            @@ws.searchmode = 1
            searchAndShowCands
          else
            fix
          end
        end
        handled = true
      end
        
        #function keys
        #122:F1 Weblioからスクレイピングして類語変換
        #120:F2 reflexaからスクレイピングして連想語変換
        #99:F3 Google サジェストからサジェスト変換
        #118:F4 Google 日本語入力から変換（連文節変換）
        #96:F5 Weblio 英和・和英辞書からスクレイピングして和英・英和変換
        #97:F6 mojiモジュールによるひらがな変換
        #98:F7 mojiモジュールによるカタカナ変換
        #100:F8 未定
        
    elsif  keyCode == 120 || keyCode == 122 || keyCode == 118 || keyCode == 96 || keyCode == 97 || keyCode == 98 then
      if converting || @selectedstr != "" then
          if keyCode == 122 then
            @weblio = true
          elsif keyCode == 120 then
            @reflexa = true
          elsif keyCode == 99 then
            @googleSuggest = true
          elsif keyCode == 118 then
            @googleJapanese = true
          elsif keyCode == 96 then 
            @ejje = true
          elsif keyCode == 97 then
            @hira = true
          elsif keyCode == 98 then
            @kata = true
          end
          @func = true
          
        functionKey
        searchAndShowCands if @func != true
        handled = true
      end
    
    #その他の文字    
    
    elsif c >= 0x21 && c <= 0x7e && (modifierFlags & NSControlKeyMask) == 0 then
    fix if @nthCand > 0 || @@ws.searchmode > 0
      @inputPat << eventString
      searchAndShowCands
      @@ws.searchmode = 0
      handled = true
    end
      
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
    
    
    #Function Keyが押されていた場合に動く
  def functionKey
      
      #puts @selectedstr
      
      #文字入力中に押された場合は通常の類語変換などのモジュールを動かす
      #文字列をドラッグして選択した状態で押された場合はその文字列についてモジュールを動かす
      
      if converting then
        @selectedCand = [@candidates[@nthCand],@inputPat]
      elsif @selectedstr != "" then
        @selectedCand = [@selectedstr,Yomi::search(@selectedstr).to_s]
        puts @selectedCand
        @inputPat = @selectedCand[1]
      end
          
    # 押されたFunction Keyによって各モジュールを呼び出す

    if @weblio == true then
      @weblio = false
      @candidates = Weblio::search(@selectedCand[0],@selectedCand[1])
      @candidates.unshift(@selectedCand[0])
      if @candidates.length < 8 then
        hiragana = @selectedCand[1].roma2hiragana
        @candidates.push(hiragana)
      end
      
    elsif @reflexa == true then
      @reflexa = false
      @candidates = Reflexa::search(@selectedCand[0],@selectedCand[1])
      @candidates.unshift(@selectedCand[0])
      if @candidates.length < 8 then
        hiragana = @selectedCand[1].roma2hiragana
        @candidates.push(hiragana)
      end

    elsif @ejje == true then
      @ejje = false
      @candidates = Ejje::search(@selectedCand[0],@selectedCand[1])

    elsif @hira == true then
      @hira = false
      hiragana = @selectedCand[1].roma2hiragana
      @candidates = []
      @candidates.unshift(hiragana)
      @hirakata = true
         
    elsif @kata == true then
      @kata = false
      katakana = @selectedCand[1].roma2katakana
      @candidates = []
      @candidates.unshift(katakana)
      @hirakata = true
        
    end

    @func = true
    @nthCand = 0
    showCands
      
  end


  # 単語を検索して候補の配列を作成するメソッド
  def searchAndShowCands      
      
    # WordSearch#search で検索して WordSearch#candidates で受け取る
    # @@ws.searchmode == 0 前方マッチ
    # @@ws.searchmode == 1 完全マッチ ひらがな/カタカナも候補に加える
        
    if @@ws.searchmode > 0
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
      @candidates.unshift(@selectedstr) if @selectedstr && @selectedstr != ''
      @candidates.unshift(@inputPat)
      if @candidates.length < 8 then
        hiragana = @inputPat.roma2hiragana
        @candidates.push(hiragana)
      end

    end
    @nthCand = 0
    showCands
  end
    
  
  def fix
      
      #print @selectedstr
    if @candidates.length > @nthCand then
      word = wordpart(@candidates[@nthCand])
      # 何故かinsertTextだとhandleEventが呼ばれてしまうようで
      # @client.insertText(word)
        #暗号化単語登録機能を一時的に落とした
      @client.insertText(word,replacementRange:NSMakeRange(NSNotFound, NSNotFound))
      if word == @selectedstr then
        if @inputPat =~ /^(.*)\?$/ then # 暗号化単語登録
            #@@ws.register(Crypt.encrypt(word,$1).to_s,'?')
        else
            #@@ws.register(word,@inputPat)
        end
        @selectedstr = nil
      else
        c = @candidates[@nthCand]
        if c.class == Array then
          if c[1] != 'ds' && c[1] != '?' then
              @@ws.study(c[0],c[1])
          end
        else
          # 読みが未登録 = ユーザ辞書に登録されていない
          if @inputPat != 'ds' && @inputPat != '?' then
              @@ws.study(word,@inputPat)
          end
        end
      end
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

    word = @cands[@nthCand]
      
    if word then
      kTSMHiliteRawText = 2
      attr = self.markForStyle(kTSMHiliteRawText,atRange:NSMakeRange(0,word.length))
      attrstr = NSAttributedString.alloc.initWithString(word,attributes:attr)
      @client.setMarkedText(attrstr,selectionRange:NSMakeRange(word.length,0),replacementRange:NSMakeRange(NSNotFound, NSNotFound))
    end
    
    #
    # 候補単語リストを表示
    #
    @textview.setString(@cands[@nthCand+1 .. @nthCand+1+10].join(' '))
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
    origin.x -= 15;
    origin.y -= 125;
    @candwin.setFrameOrigin(origin)
    NSApp.unhide(self)
  end

  def hideWindow
    NSApp.hide(self)
  end
end
