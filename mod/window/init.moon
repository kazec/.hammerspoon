---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import once from require 'fn'
import merge from require 'fn.table'
{ sigcheck:T } = require 'typecheck'
import mainScreen, allScreens from require 'hs.screen'
{ :focusedWindow } = require 'hs.window'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

self =
  -- space: require 'window.space'
  screen: require 'window.screen'
  zoom: require 'window.zoom'
  cycle: require 'window.cycle'
  layout: require 'window.layout'

focused = (framer) ->
  window = focusedWindow!
  return if not window

  mframe = mainScreen!\_visibleframe!
  mframe.y = allScreens![1]\_frame!.h - mframe.h - mframe.y
  frame, size = window\topLeft!, window\size!
  frame.w, frame.h = size.w, size.h

  topleft, size = framer mframe, frame
  window\setTopLeft topleft if topleft
  window\setSize size if size

init = (setup) -> setup @

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'function', once(init)
  focused: T 'function', focused
}
