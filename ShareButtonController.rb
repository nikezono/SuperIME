#
#  ShareButtonController.rb
#  SuperIME
#
#  Created by 中園 翔 on 2012/12/11.
#  Copyright 2012年 __MyCompanyName__. All rights reserved.
#

class ShareButtonController < NSButton
    
    @str = nil
    
    #strに選択範囲の文字列を送る
    #このオブジェクトのクラス変数を他のコントローラからsetterで変更するというやり方で、
    #うまく行くかよくわからないので、
    #とりあえずグローバル変数を作った
    
    def setStr(resp)
        @str = resp
    end
    
    #ボタンが押されたとき呼ばれる
    def sharingService(sender)
    
        puts $selectedstr#debug
        picker = NSSharingServicePicker.alloc
        picker.initWithItems([$selectedstr])
        picker.delegate = self
        picker.showRelativeToRect(sender.bounds,
                                  ofView:sender,
                                  preferredEdge:NSMinXEdge)
    end
end
