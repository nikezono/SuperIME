#!/usr/bin/ruby -Ku
# -*- coding: utf-8 -*-
# nlpwww.nict.go.jp/wn-ja/
# 日本語Wordnetのdatabaseから検索した単語のHypやSynを持ってくる。
# 実装すると思われるファンクション
# F1 syns - Synonym 同義語
# F2 Hyps - Hyposym 上位語？
# F3 Also - Also 関連語 HatenaKeyword.rbに詳しい
# F4 Google 日本語入力 - 現在はピリオドだがこっちに移管したい
# F6 英語変換
# F7 カタカナ変換

require 'rubygems'
require 'sqlite3'

class Wordnet
  Word = Struct.new("Word",:wordid,:lang,:lemma,:pron,:pos)
  Sense = Struct.new("Sense",:synset,:wordid,:lang,:rank,:lexid,:freq,:src)
  Synset = Struct.new("Synset",:synset,:pos,:name,:src)
  SynLink = Struct.new("SynLink",:synset1,:synset2,:link,:src)
    
  attr_accessor :conn

  def initialize(dbfile)
    @conn = SQLite3::Database.new(dbfile)
  end

  def get_words(lemma)
    @conn.execute("select * from word where lemma=?",lemma).map{|row|Word.new(*row)}
  end

  def get_senses(word)
    @conn.execute("select * from sense where wordid=?",(word.wordid)).map{|row|Sense.new(*row)}
  end

  def get_sense(synset,lang="jpn")
    row = @conn.get_first_row("select * from sense where synset=? and lang=?",synset,lang)
    row ? Sense.new(*row) : nil
  end

  def get_synset(synset)
    row = @conn.get_first_row("select * from synset where synset=?",synset)
    row ? Synset.new(*row) : nil
  end

  def get_syn_links(sense,link)
    @conn.execute("select * from synlink where synset1=? and link=?",sense.synset,link).map{|row|Synlink.new(*row)}
  end

  def get_sys_links_recursive(senses,link,lang="jpn",depth=0)
    senses.each do |sense|
      syn_links = get_syn_links(sense,link)
      puts "#{' ' *depth}#{get_word(sense.wordid).lemma} #{get_synset(sense.synset).name}" unless syn_links.empty?
      _senses = syn_links.map{|syn_link|get_sense(syn_link.synset2.lang)}.compact
      get_sys_links_recursive(_senses,link,lang,depth+1)
    end
  end

  def main(word,link,lang='jpn')
    if words = get_words(word)
      sense = get_senses(words.first)
      get_sys_links_recursive(sense,link,lang)
    else
      STDERR.puts"(nothing found)"
    end
  end

  def close_db
    @conn.close
  end
  
end

if __FILE__ == $0
  if ARGV.length >= 2
    dbfile = "../Resources/wnjpn.db"
    #dbfile = "/Users/nakazono/wnjpn.db"#debug
    wn = Wordnet.new(dbfile)
    wn.main(*ARGV)
    wn.close_db
  end
end
