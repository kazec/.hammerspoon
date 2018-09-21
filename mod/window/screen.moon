---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import max, min from math
{ sigcheck:T } = require 'typecheck'
import allScreens, mainScreen from require 'hs.screen'
{ :focusedWindow, :_setTopLeft, :_setSize, :_topLeft, :_size } = require 'hs.window'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

focused = (next) ->
  window = focusedWindow!
  return unless window

  screens = allScreens!
  slen = #screens
  return if slen == 1

  ph = screens[1]\_frame!.h
  topleft, size = _topLeft(window), _size(window)
  fx, fy, fw, fh = topleft.x, topleft.y, size.w, size.h
  farea = fw * fh

  for i, screen in ipairs screens
    sframe = screen\_visibleframe!
    sx, sy, sw, sh = sframe.x, sframe.y, sframe.w, sframe.h
    sy = ph - sh - sy

    ix, iy = max(fx, sx), max(fy, sy)
    ix2, iy2 = min(fx + fw, sx + sw), min(fy + fh, sy + sh)

    if (ix2 >= ix and iy2 >= iy) and (ix2 - ix) * (iy2 - iy) / farea > 0.5
      nidx = next and (i == slen and 1 or i + 1) or (i == 1 and slen or i - 1)
      nframe = screens[nidx]\_visibleframe!

      nx, ny, nw, nh = nframe.x, nframe.y, nframe.w, nframe.h
      ny = ph - nh - ny

      x = (fx - sx) / sw * nw + nx
      y = (fy - sy) / sh * nh + ny
      w = (fw / sw) * nw
      h = (fh / sh) * nh

      _setTopLeft window, { :x, :y }
      _setSize window, { :w, :h }

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

focused: T 'boolean', focused
