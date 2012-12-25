##  Weblio.rb
##  nikezono.net
##  汎用スクレイパー
##  いずれサーバサイド実装

require 'net/http'
require 'nkf'
require 'uri'
class Weblio

    def Weblio::search(w,inputpat,limit=10)
    res = []
    res << [w[0],inputpat]
    w = NKF.nkf('-w',w[0])
    Net::HTTP.start('thesaurus.weblio.jp', 80) {|http|
        response = http.get("/content/#{w}")
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
        #web = Weblio.new
    #Weblio::search("学校",'gakkou')