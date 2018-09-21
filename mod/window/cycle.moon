---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import time from os
{ sigcheck:T } = require 'typecheck'
import _orderedwinids from require 'hs.window'
import runningApplications from require 'hs.application'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

_index = nil
_ordered = {}
_lastcycle = 0

orderWindows = () ->
  windows, result, orderedWindowIDs = {}, {}, _orderedwinids!
  for _, app in ipairs runningApplications!
    if app\kind! > 0 and not app\isHidden!
      for _, window in ipairs app\allWindows!
        if not window\isMinimized! and window\role! != 'AXScrollArea'
          if id = window\id!
            windows[id] = window

  for _, id in ipairs orderedWindowIDs
    result[#result + 1] = windows[id]

  return result

cycle = (expiration) ->
  now = time!

  if now - _lastcycle >= (expiration or 3)
    _ordered = orderWindows!
    _index = 1

  _lastcycle = now
  window = _ordered[_index]
  return unless window

  _index = _index >= #_ordered and 1 or _index + 1

  window\becomeMain!
  window\application!\_bringtofront!

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

T 'number', cycle
