---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

{ sigcheck:T } = require 'typecheck'
import mainScreen from require 'hs.screen'
import focusedWindow from require 'hs.window'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

_zoomed = {}
_zcount = 0

fequals = (f1, f2) -> f1._x == f2._x and f1._y == f2._y and f1._w == f2._w and f1._h == f2._h

fscale = (f, s) ->
  w, h = f._w, f._h
  f._w = s * w
  f._h = s * h
  f._x += (1 - s) * w / 2
  f._y += (1 - s) * h / 2

zoom = (scale) ->
  window = focusedWindow!
  return if not window

  frame, sframe = window\frame!, mainScreen!\frame!
  windowArea = frame._w * frame._h
  screenArea = sframe._w * sframe._h

  -- too small or too large, eg: hotcorner, desktop
  return if windowArea < 150000 or windowArea > screenArea

  id = window\id!
  zoomed = _zoomed[id]

  if zoomed
    unzoomedFrame = zoomed[1]
    zoomedFrame = zoomed[2]

    if fequals frame, zoomedFrame -- not changed since last zoom
      window\_setTopLeft unzoomedFrame
      window\_setSize unzoomedFrame
      _zoomed[id] = { frame, window\frame! }
    else
      _zoomed[id] = { frame, window\frame! }

  elseif fequals frame, sframe -- fullscreen
    fscale frame, scale or 0.7
    window\_setTopLeft frame
    window\_setSize frame
  else
    window\_setTopLeft sframe
    window\_setSize sframe

    if _zcount > 1000
      _zoomed =
        [id]: { frame, window\frame! }
      _zcount = 1
    else
      _zoomed[id] = { frame, window\frame! }
      _zcount += 1

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

T 'number', zoom
