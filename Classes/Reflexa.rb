#
#  Reflexa.rb
#  Gyaim
#
#  Created by 中園 翔 on 12/07/01.
#  Copyright 2012年 Keio Univ. All rights reserved.
#

require 'net/http'
require 'nkf'
require 'uri'
class Reflexa
    
    def Reflexa::search(w,inputpat,limit=10)
        res = []
        #res << [w[0],inputpat]
        w = URI.encode(w[0])
        Net::HTTP.start('labs.preferred.jp', 80) {|http|
            response = http.get("/reflexa/api.php?q=#{w}&format=xml")
            s = response.body.to_s
            #p s
            s = NKF.nkf('-w',s)
            s = s.scan(/word>(.+?)<\/word>/)
            #p s
            s.each {|text|
                res << [text[0],inputpat]
            }
        }
        return res
    end
end


