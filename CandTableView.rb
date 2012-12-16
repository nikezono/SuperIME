#
#  CandTableView.rb
#  SuperIME
#
#  Created by 中園 翔 on 2012/12/11.
#  Copyright 2012年 __MyCompanyName__. All rights reserved.
#

class CandTableView
    
    def init
        @candidates = []
    end
        
    def setCandidates(req)
        @candidates = req
    end
    
    def getCandidates
        return @candidates
    end
    
    def reload
        self.reloadData
    end
    
    def numberOfRowsInTableView(aTableView)
        return 0 if @candidates.nil?
        return @candidates.size
    end
    
    def tableView(aTableView,
                  objectValueForTableColumn: aTableColumn,
                  row: rowIndex)
        puts rowIndex
        puts aTableColumn.identifier
        
        return nil if aTableColumn.identifier == 'Image'
        return "aaa"
        
        for num in rowIndex
            case aTableColumn.identifier
                when 'Candidate' # 1列目のデータ
                    str = @candidates[num][1]
                when 'Description'  # 2列目のデータ
                    str = @candidates[num][2]
            end
        end
         
        return str
    end

end

