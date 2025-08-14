---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import time from os
{ new:Timer } = require 'hs.timer'
import map from require 'hs.keycodes'
import indexof, contains from require 'fn.table'
import tostring, ipairs, error from _G
import event from require 'hs.eventtap'
import mainScreen from require 'hs.screen'
import focusedWindow from require 'hs.window'
{ :isstring, :isnumber, sigcheck:T } = require 'typecheck'
import allSpaces, focusedSpace, moveWindowToSpace from require 'hs.spaces'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

_findNextSpace = (spaces, current, next) ->
  slen = #spaces
  for i = 1, slen
    id = spaces[i]
    if id == current
      sidx = next and (i == slen and 1 or i + 1) or  (i == 1 and slen or i - 1)
      return sidx

focused = (offset) ->
  -- get focused window
  window = focusedWindow!
  return unless window

  -- find spaces on current screen
  focusedSpace = focusedSpace!
  return unless focusedSpace

  screen = mainScreen!
  spaces = allSpaces! if screen
  spaces = spaces[screen\getUUID!] if spaces

  return unless contains spaces, focusedSpace

  if isstring(offset)
    nextSpaceID = _findNextSpace(spaces, focusedSpace, true) if offset == 'next'
    nextSpaceID = _findNextSpace(spaces, focusedSpace, false) if offset == 'prev'
    return error 'invalid offset' unless nextSpaceID
  elseif isnumber(offset)
    nextSpaceID = offset
  else
    return error "invalid offset type: #{type offset}"

  ok, err = moveWindowToSpace window, nextSpaceID
  error err if not ok

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  focused: T 'string|number', focused
}
