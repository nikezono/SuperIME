#
#  Ejje.rb
#  SuperIME
#
#  Created by 中園 翔 on 12/08/21.
#  Copyright 2012年 Keio Univ. All rights reserved.
#

#spaceALCから和英・英和翻訳の結果を持ってくる。
#EnglishJapanese and JapaneseEnglish.(ejje)

require 'net/http'
require 'nkf'
require 'uri'
 
require 'rubygems'
require 'moji'
class Ejje
    
    def Ejje::search(w,inputpat,limit=10)
        res = []
        res << [w[0],inputpat]
        w = NKF.nkf('-w',w[0])
        
        #weblioをスクレイピングする
        Net::HTTP.start('ejje.weblio.jp', 80) {|http|
            response = http.get("/content/#{w}")
            s = response.body.to_s
            s = NKF.nkf('-w',s)
            s = s.scan(/crosslink>(.+?)<\/a>/)
            
            #渡された文字列が全角なら和英、半角なら英和の結果を受け取るようにする
            if Moji.type?(w, Moji::ZEN) == true then
              s.each {|text|
                if Moji.type?(text[0], Moji::ZEN) == false then
                  res << [text[0],inputpat]
                end
              }
            elsif Moji.type?(w, Moji::HAN) == true then
              s.each {|text|
                if Moji.type?(text[0], Moji::HAN) == false then
                  res << [text[0],inputpat]
                end
              }
            end
        }
        return res
    end
end