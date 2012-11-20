#
#  GoogleSuggest.rb
#  Gyaim
#
#  Created by 中園 翔 on 12/08/22.
#  Copyright 2012年 Keio Univ. All rights reserved.
#
#google　サジェストから候補をもらってくる


require 'net/http'
require 'nkf'
require 'uri'
class GoogleSuggest
    
    def GoogleSuggest::search(w,inputpat,limit=10)
        res = []
        res << [w[0],inputpat]
        w = NKF.nkf('-w',w[0])
        Net::HTTP.start('www.google.jp', 80) {|http|
            response = http.get("/complete/search?output=toolbar&hl=ja&q=#{q}")
            s = response.body.to_s
            s = NKF.nkf('-w',s)
            while s.sub!(/data="([^"]*)"\/>/,'') do
                word = $1.split[0]
                res << word
            end
        }
        return res
    end
end