#
#  ConnectionServer.rb
#  SuperIME
#
#  Created by 中園 翔 on 2012/12/11.
#  Copyright 2012年 nikezono.net. All rights reserved.
#
#  与えられた文字列とモードごとに、サーバと接続し結果を取得する
#  mode
#  0:かな漢字変換
#  1:類語変換
#  2:英語変換
#  3:tiqav
#
#  実装目標
#  1.サーバ&クライアントサイド両方でキャッシュする(redis&levelDB)
#  2.httpではなくWebSocketクライアントとして実装する
#  3.単語の配列を[読み]のみの配列にする?
#  trie使うとか?

require 'net/http'
require 'json'
require 'Romakana'
require 'Weblio'
require 'date'

class ConnectionServer

    def getCandidates(cand,input,mode)

    
        candidates = []
        hiragana = input.roma2hiragana

        #分岐
        if mode == 0 then
            
          #ひらがなに変換出来ない場合エラーになるので呼ばない
          if hiragana != "" then
            #LevelDBに問い合わせて、存在する場合はそれ使う
            if $kanaDB.includes? hiragana then
                s = $kanaDB.get(hiragana)
                #puts "get leveldb: #{s}"
                
            else
                Net::HTTP.start('localhost', 2342) {|http|
                    response = http.get("/?mode=0&hira=#{hiragana}")
                    s = response.body.to_s
                    #puts "insert db :#{$kanaDB.put(hiragana,s)}"
                    $kanaDB.put(hiragana,s)
                }
            end
            s = JSON.parse(s)
            s.each {|text|
              candidates.push [text,input]
            }
          end

        
              #記号
              #ここをもう少しロジカルに書きたい
              #サーバサイドで実装するべき
              if input == "," || input == "." || input ==  "/" || input == "~" || input == "!" || input == "batu" || input == "maru" || input == "sankaku" || input == "[" || input == "]" || input == "time" then

                candidates.unshift(["、",input]) if input == ","
                candidates.unshift(["。",input]) if input == "."
                candidates.unshift(["・",input]) if input == "/"
                candidates.unshift(["〜",input]) if input == "~"
                candidates.unshift(["！",input]) if input == "!"
                candidates.unshift(["☓",input]) if input == "batu"
                candidates.unshift(["○",input]) if input == "maru"
                candidates.unshift(["△",input]) if input == "sankaku"
                candidates.unshift(["「",input]) if input == "["
                candidates.unshift(["」",input]) if input == "]"
                if input == "time" then
                    date = Time.now
                    wdays = ["日", "月", "火", "水", "木", "金", "土"]
                    candidates.unshift(["#{wdays[date.wday]}曜日"])
                    candidates.unshift(["#{date.hour}時#{date.min}分"])
                    candidates.unshift(["#{date.month}月#{date.day}日"])
                    candidates.unshift(["#{date.month}月#{date.day}日#{date.hour}時#{date.min}分"])
                    candidates.unshift(["#{date}"])
                end
              end
              candidates.unshift([input,input]) #英語追加
              
            return candidates
            
        #類語
        elsif mode == 1 then
            candidates = Weblio::search(cand,input)
            return candidates
            
        #英語
        elsif mode == 2 then
            candidates = Ejje::search(cand,input)
            return candidates
        
        #画像
        #google Custom SearchのAPIはクエリ制限が厳しすぎる。
        #bingのAPIはBasic認証をかけられてしまう。
        #yahooは2013年3月から有料化する。
            
        elsif mode == 3 then
            #LevelDBに問い合わせて、存在する場合はそれ使う
            if $superDB.includes? hiragana then
                s = $superDB.get(hiragana)
                #puts "get leveldb: #{s}"
                
            else

                Net::HTTP.start('localhost', 2342) {|http|
                    response = http.get("/?mode=3&hira=#{hiragana}")
                    s = response.body.to_s
                    $superDB.put(hiragana,s)
                }
            end
                s = JSON.parse(s)
                s.each {|text|
                    candidates.push [text,input]
                }
            
            candidates.unshift ["スクリーンショットの撮影","Gyazo"]
            return candidates
        end
    end
end

