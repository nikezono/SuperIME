##  Weblio.rb
##  nikezono.net
##  汎用スクレイパー
##  英語にした
##  いずれサーバサイド実装

require 'net/http'
require 'nkf'
require 'uri'
class Weblio

    def Weblio::search(w,inputpat,limit=10)
    res = []
    res << [w[0],inputpat]
    w = NKF.nkf('-w',w[0])
    Net::HTTP.start('ejje.weblio.jp', 80) {|http|
        response = http.get("/english-thesaurus/content/#{w}")
        s = response.body.to_s
        s = NKF.nkf('-w',s)
        s = s.scan(/wdntCL>(.+?)<\/p>/)
        puts "s:#{s}"
        s.each do |arr|
            puts "arr:#{arr}"
            text = arr[0].split(',')
            puts "text:#{text}"
            text.each do |t|
                puts "t:#{t}"
                res << [t.strip,inputpat]
            end
        end
    }
    return res.uniq
  end
end
        #web = Weblio.new
    #Weblio::search("学校",'gakkou')
	