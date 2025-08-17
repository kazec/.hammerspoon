---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import time from os
{ map:keycodes } = require 'hs.keycodes'
log = require('log').get('window', 'debug')
import doAfter, doWhile from require 'hs.timer'
import indexof, contains from require 'fn.table'
import tostring, ipairs, error from _G
import event from require 'hs.eventtap'
import mainScreen from require 'hs.screen'
import focusedWindow from require 'hs.window'
import absolutePosition from require 'hs.mouse'
{ :isboolean, :isnumber, sigcheck:T } = require 'typecheck'
import allSpaces, focusedSpace from require 'hs.spaces'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

LMOUSE_UP   = event._newMouseEvent event.types.leftMouseUp, { x: 0, y: 0 }, 'left'
LMOUSE_DOWN = event._newMouseEvent event.types.leftMouseDown, { x: 0, y: 0 }, 'left'
KEY_UP      = event.newKeyEvent { 'ctrl' }, '1', false
KEY_DOWN    = event.newKeyEvent { 'ctrl' }, '1', true

_window = nil
_windowFrame = nil
_destSpaceID = -1
_destSpaceOffset = -1
_clickPosition = nil
_mousePosition = nil

_checkAnimationRunning = () ->
  if not _window
    log.error 'No window to move'
    return false

  windowFrame = _window\frame!
  if _windowFrame and windowFrame\equals _windowFrame -- animation finished
    log.debugf 'Window animation finished: %s', windowFrame if log.debugf
    LMOUSE_UP\location(_clickPosition)\post!
    absolutePosition _mousePosition
    _clickPosition = nil
    _mousePosition = nil
    return false
    
  -- continue to check every 0.1 second
  log.debugf 'Window still animating: %s -> %s', _windowFrame, windowFrame if log.debugf
  _windowFrame = windowFrame
  return true

_findNextSpace = (spaces, current, next) ->
  log.debugf 'Finding next space: %s, %s, %s', spaces, current, next if log.debugf
  slen = #spaces
  for i = 1, slen
    id = spaces[i]
    if id == current
      sidx = next and (i == slen and 1 or i + 1) or  (i == 1 and slen or i - 1)
      return sidx, spaces[sidx]
  log.error 'no next space'

_moveWindowToSpace = (window, spaceOffset, spaceID) ->
  keycode = keycodes[tostring spaceOffset]
  return log.errorf 'invalid space offset: %s, id: %s', spaceOffset, spaceID unless keycode

  _destSpaceID = spaceID
  _destSpaceOffset = spaceOffset
  _mousePosition = absolutePosition!

  -- emit mouse events
  _clickPosition = window\zoomButtonRect!
  _clickPosition.x += 13
  _clickPosition.y += 5

  -- -- click to focus
  LMOUSE_DOWN\location(_clickPosition)\post!
  LMOUSE_UP\location(_clickPosition)\post!

  -- hold left mouse down
  LMOUSE_DOWN\location(_clickPosition)\post! --

  doAfter 0.1, () ->
    -- emit key events.
    KEY_DOWN\setKeyCode(keycode)\post!
    KEY_UP\setKeyCode(keycode)\post!


  -- resume timer
  _window = window
  doAfter 0.3, () ->
    if _checkAnimationRunning!
      doWhile _checkAnimationRunning, () -> return, 0.1

  log.infof 'moving window %s to space: %s', window\title!, spaceOffset if log.infof

focused = (spaceOffset) ->
  -- get focused window
  window = focusedWindow!
  return unless window

  -- find spaces on current screen
  current = focusedSpace!
  return unless current

  screen = mainScreen!
  spaces = allSpaces! if screen
  spaces = spaces[screen\getUUID!] if spaces

  nextSpaceOffset = spaceOffset
  if isboolean(spaceOffset)
    nextSpaceOffset, nextSpaceID = _findNextSpace(spaces, current, spaceOffset)
  
  _moveWindowToSpace window, nextSpaceOffset, nextSpaceID

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  focused: T 'boolean|number', focused
}
