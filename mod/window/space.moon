---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import time from os
{ new:Timer } = require 'hs.timer'
import map from require 'hs.keycodes'
import indexof from require 'fn.table'
import tostring, ipairs, error from _G
import event from require 'hs.eventtap'
import focusedWindow from require 'hs.window'
{ :isnumber, sigcheck:T } = require 'typecheck'
import activeSpace, mainScreenUUID from require 'spaces'
import screenUUIDisAnimating, details from require 'spaces.internal'
import setAbsolutePosition, getAbsolutePosition from require 'hs.mouse'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

LMOUSE_UP   = event._newMouseEvent event.types.leftMouseUp, { x: 0, y: 0 }, 'left'
LMOUSE_DOWN = event._newMouseEvent event.types.leftMouseDown, { x: 0, y: 0 }, 'left'
KEY_UP      = event.newKeyEvent { 'ctrl' }, '1', false
KEY_DOWN    = event.newKeyEvent { 'ctrl' }, '1', true

_destSpaceID = -1
_screenUUID = nil
_clickPosition = nil
_mousePosition = nil

local _timer
_timer = Timer 0, () ->
  if not screenUUIDisAnimating _screenUUID -- animation finished
    LMOUSE_UP\location(_clickPosition)\post!
    setAbsolutePosition _mousePosition
    _clickPosition = nil
    _mousePosition = nil
    error 'Failed to switch to destination space' unless activeSpace! == _destSpaceID
    return
  -- continue to check every 0.1 second
  _timer\setNextTrigger 0.1

findNextSpaceIdx = (spaces, srcID, next) ->
  slen = #spaces
  for i = 1, slen
    id = spaces[i].ManagedSpaceID
    if id == srcID
      sidx = next and (i == slen and 1 or i + 1) or  (i == 1 and slen or i - 1)
      return sidx

focused = (offset) ->
  return if _clickPosition

  -- get focused window
  window = focusedWindow!
  return unless window

  -- find current screen
  for _, screen in ipairs details!
    if current = screen['Current Space']
      currentID = current.ManagedSpaceID
      spaces = screen.Spaces

      nidx = isnumber(offset) and offset or findNextSpaceIdx(spaces, currentID, offset)
      nspace = spaces[nidx]
      return unless nspace

      keycode = map[tostring nidx]
      return unless keycode

      _destSpaceID = nspace.ManagedSpaceID
      _screenUUID = screen['Display Identifier']
      _screenUUID = mainScreenUUID! if _screenUUID == 'Main'
      _mousePosition = getAbsolutePosition!

      -- emit mouse events
      clickPosition = window\zoomButtonRect!
      clickPosition.x -= 3
      _clickPosition = clickPosition

      -- -- click to focus
      -- LMOUSE_DOWN\location(clickPosition)\post!
      -- LMOUSE_UP\location(clickPosition)\post!

      -- hold left mouse down
      LMOUSE_DOWN\location(clickPosition)\post! --

      -- emit key events.
      KEY_DOWN\setKeyCode(keycode)\post!
      KEY_UP\setKeyCode(keycode)\post!

      -- resume timer
      _timer\setNextTrigger 0.3
      return


  error 'Unable to get current space info, is the private API broken?'
  return

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  focused: T 'boolean|number', focused
}
