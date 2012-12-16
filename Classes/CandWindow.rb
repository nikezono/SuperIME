# -*- coding: utf-8 -*-
# CandWindow.rb
# SuperIME
#
# Created by Toshiyuki Masui on 2011/3/15.
# Copyright 2011 Pitecan Systems. All rights reserved.

class CandWindow < NSWindow
  def initWithContentRect(contentRect,styleMask:aStyle,backing:bufferingType,defer:d)
    # superにはキーワード引数が使えないらしく、以下のように書くことができない
    # super(contentRect,styleMask:NSBorderlessWindowMask,backing:NSBackingStoreBuffered,defer:false)
    if super(contentRect,NSBorderlessWindowMask,NSBackingStoreBuffered,false)
      setBackgroundColor(NSColor.clearColor)
      setLevel(NSStatusWindowLevel)
      setAlphaValue(1.0)
      setOpaque(false)
      setHasShadow(true)
      setCanHide(true)
      self
    end
  end

end
