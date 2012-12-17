#
#  GyazoButtonController.rb
#  SuperIME
#
#  Created by 中園 翔 on 2012/12/17.
#  Copyright 2012年 __MyCompanyName__. All rights reserved.
#


class GyazoButtonController

    def pushedButton(sender)
        
        # get id
        user = IO.popen("whoami", "r+").gets.chomp
        program = ARGV[0].to_s
        idfile = "/Users/#{user}/Library/Gyazo/id"
        old_idfile = File.dirname(program) + "/gyazo.app/Contents/Resources/id"
        
        id = ''
        if File.exist?(idfile) then
            id = File.read(idfile).chomp
            elsif File.exist?(old_idfile) then
            id = File.read(old_idfile).chomp
        end
        
        # capture png file
        tmpfile = "/tmp/image_upload#{$$}.png"
        imagefile = ARGV[1]
        
        if imagefile && File.exist?(imagefile) then
            system "sips -s format png \"#{imagefile}\" --out \"#{tmpfile}\""
            else
            system "screencapture -i \"#{tmpfile}\""
            if File.exist?(tmpfile) then
                system "sips -d profile --deleteColorManagementProperties \"#{tmpfile}\""
            end
        end
        
        if !File.exist?(tmpfile) then
            exit
        end
        
        imagedata = File.read(tmpfile)
        File.delete(tmpfile)
        
        # upload
        boundary = '----BOUNDARYBOUNDARY----'
        
        host = 'gyazo.com'
        cgi = '/upload.cgi'
        ua   = 'Gyazo/1.0.1'
        
data = <<EOF
--#{boundary}\r
content-disposition: form-data; name="id"\r
\r
#{id}\r
--#{boundary}\r
content-disposition: form-data; name="imagedata"; filename="gyazo.com"\r
\r
#{imagedata}\r
--#{boundary}--\r
EOF
        
        header ={
            'Content-Length' => data.length.to_s,
            'Content-type' => "multipart/form-data; boundary=#{boundary}",
            'User-Agent' => ua
        }
        
        Net::HTTP.start(host,80){|http|
            res = http.post(cgi,data,header)
            #puts "cgi:#{cgi} data:#{data} header:#{header}"
            url = res.response.body
            IO.popen("pbcopy","r+"){|io|
                io.write url
                io.close
            }
            #system "open #{url}"
            ime = SuperIMEController.new
            ime.insert(url)
            
            # save id
            newid = res.response['X-Gyazo-Id']
            if newid and newid != "" then
                if !File.exist?(File.dirname(idfile)) then
                    Dir.mkdir(File.dirname(idfile))
                end
                if File.exist?(idfile) then
                    File.rename(idfile, idfile+Time.new.strftime("_%Y%m%d%H%M%S.bak"))
                end
                File.open(idfile,"w").print(newid)
                if File.exist?(old_idfile) then
                    File.delete(old_idfile)
                end
            end
        }
    end
end