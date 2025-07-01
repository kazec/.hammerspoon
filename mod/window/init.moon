---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import once from require 'fn'
log = require('log').get 'window'
import merge from require 'fn.table'
{ sigcheck:T } = require 'typecheck'
{ open:openApp } = require 'hs.application'
import mainScreen, allScreens from require 'hs.screen'
{ get:getWindow, :focusedWindow } = require 'hs.window'

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

  screen_frame = mainScreen!\_visibleframe!
  screen_frame.y = allScreens![1]\_frame!.h - screen_frame.h - screen_frame.y
  frame, size = window\topLeft!, window\size!
  frame.w, frame.h = size.w, size.h

  topleft, size = framer screen_frame, frame
  window\setTopLeft topleft if topleft
  window\setSize size if size

_last_focused_window_id = nil
toggle = (bundleID) ->
  window = focusedWindow!
  if window and window\application!\bundleID! == bundleID
    -- Bring previously focused window back to focus
    last_window = getWindow _last_focused_window_id if _last_focused_window_id
    last_window\focus! if last_window
    log.infof 'bringing window back to focus: %s[%d]', last_window\title!, _last_focused_window_id if last_window and log.infof
    _last_focused_window_id = nil
  else
    -- Focus the window by activating the app
    _last_focused_window_id = window\id! if window or nil
    openApp bundleID

init = (setup) -> setup @

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'function', once(init)
  focused: T 'function', focused
  toggle: T 'string', toggle
}
