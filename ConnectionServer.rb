#
#  ConnectionServer.rb
#  SuperIME
#
#  Created by 中園 翔 on 2012/12/11.
#  Copyright 2012年 __MyCompanyName__. All rights reserved.
#

require 'net/http'
require 'json'
require 'Romakana'

class ConnectionServer

    def getCandidates(cand,input,mode)

        candidates = []
        #分岐
        if mode == 0 then
            hiragana = input.roma2hiragana
            #ひらがなに変換出来ない場合エラーになるので呼ばない
            if hiragana != "" then
                Net::HTTP.start('localhost', 2342) {|http|
                    response = http.get("/?mode=0&text=#{hiragana}")
                    s = response.body.to_s
                    s = JSON.parse(s)
                    s.each {|text|
                        candidates << [text,@inputPat]
                    }
                }
            end
            candidates.unshift([hiragana,hiragana])
            candidates.unshift([input,input])
            return candidates
        
        elsif mode == 1 then
            return []
        end
    end
end

