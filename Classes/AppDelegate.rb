# AppDelegate.rb
# SuperIME
#
# Created by Toshiyuki Masui on 2011/3/15.
# Copyright 2011 Pitecan Systems. All rights reserved.

require 'rubygems'
require 'leveldb'

class AppDelegate
  attr_accessor :candwin
  attr_accessor :candview
  attr_accessor :textview
  attr_accessor :inputcontroller
    
  def awakeFromNib()
    #LevelDBと接続する。
    $kanaDB = LevelDB::DB.new File.expand_path 'kanakanji.ldb', File.dirname(__FILE__)
  end
    
  
end