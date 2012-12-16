#
#  Yomi.rb
#  SuperIME
#
#  Created by 中園 翔 on 12/08/26.
#  Copyright 2012年 Keio Univ. All rights reserved.
#
#　Yahoo!ルビ振りAPIを用いて、漢字混じりの文章をローマ字に直すモジュール
#　既に確定された選択文字列の再変換のときに使う

require 'rexml/document'
require 'net/http'

class Yomi
  @appid = "GV5fsDCxg66pvH_q.L1mOA7bOE5bVgzrKccbcRshKs8owBVRAyuuBAmfb0Xqeoo-"

  def Yomi::search(inputString)
      res = ""
      
      Net::HTTP.start('jlp.yahooapis.jp', 80) {|http|
          response = http.get("/FuriganaService/V1/furigana?appid=#{@appid}&sentence=#{inputString}")
          s = response.body.to_s
          doc = REXML::Document.new(s)
          doc.elements.each('/ResultSet/Result/WordList/Word/Roman') do |element|
            res << element.text
          end
      }
      return res
  end

end