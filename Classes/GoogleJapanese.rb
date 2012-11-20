#
#  GoogleJapanese.rb
#  Gyaim
#
#  Created by 中園 翔 on 12/08/22.
#  Copyright 2012年 Keio Univ. All rights reserved.
#

#google 日本語入力を使って変換する（連文節変換)

require 'net/http'
require 'nkf'
require 'uri'
class GoogleJapanese
    
    def GoogleJapanese::search(w,inputpat,limit=10)
        res = []
        res << [w[0],inputpat]
        w = NKF.nkf('-w',w[0])
        Net::HTTP.start('www.google.com', 80) {|http|
            response = http.get("/transliterate?langpair=ja-Hira|ja&text=#{w}")
            s = response.body.to_s
            s = NKF.nkf('-w',s)
            s = s.scan(/crosslink>(.+?)<\/a>/)
            s.each {|text|
                res << [text[0],inputpat]
            }
        }
        return res
    end
end


