---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import sort from table
import max, min from math
{ sigcheck:T } = require 'typecheck'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

move = (top, left, sframe, frame) ->
  x = if left >   1 then frame.x - left
  elseif left >   0 then sframe.x + sframe.w * (1 - left)
  elseif left ==  0 then frame.x
  elseif left >= -1 then sframe.x - sframe.w * left - frame.w
  else frame.x - left

  y = if top >   1 then frame.y - top
  elseif top >   0 then sframe.y + sframe.h * (1 - top)
  elseif top ==  0 then frame.y
  elseif top >= -1 then sframe.y - sframe.h * top - frame.h
  else frame.y - top

  return { :x, :y }

extend = (top, left, sframe, frame) ->
  x, w = if left > 1
    frame.x - left, frame.w + left
  elseif left > 0
    fx = sframe.x + sframe.w * (1 - left)
    fx, frame.w + frame.x - fx
  elseif left ==  0
    frame.x, frame.w
  elseif left >= -1
    fx = sframe.x - sframe.w * left - frame.w
    fx, frame.w + fx - frame.x
  else frame.x - left

  y, h = if left > 1
    frame.y - left, frame.h + left
  elseif left > 0
    fy = sframe.y + sframe.h * (1 - left)
    fy, frame.h + frame.y - fy
  elseif left ==  0
    frame.y, frame.h
  elseif left >= -1
    fy = sframe.y - sframe.h * left - frame.h
    fy, frame.h + fy - frame.y
  else frame.y - left

  return { :x, :y }, { :w, :h }

center = (sframe, frame) ->
  w, h = frame.w, frame.h
  x = sframe.x + sframe.w / 2 - w / 2
  y = sframe.y + sframe.h / 2 - h / 2
  return { :x, :y }

maximize = (sframe) -> sframe, sframe

normalized = (x, y, w, h, sframe) ->
  w = sframe.w * w
  h = sframe.h * h
  x = sframe.x + sframe.w * x
  y = sframe.y + sframe.h * y
  return { :x, :y }, { :w, :h }

snap = (grids, sframe, frame) ->
  results, glen = {}, #grids

  for i = 1, glen, 4
    gtopleft, gsize = normalized grids[i], grids[i + 1], grids[i + 2], grids[i + 3], sframe

    -- calculate intersection area
    fx, fy, gx, gy, fw, fh, gw, gh = frame.x, frame.y, gtopleft.x, gtopleft.y, frame.w, frame.h, gsize.w, gsize.h
    ix, iy = max(fx, gx), max(fy, gy)
    ix2, iy2 = min(fx + fw, gx + gw), min(fy + fh, gy + gh)
    iarea = (ix2 >= ix and iy2 >= iy) and (ix2 - ix) * (iy2 - iy) or 0

    -- calc ratios
    fratio = iarea / (fw * fh)
    gratio = iarea / (gw * gh)

    -- almost fit, use next grid frame
    if fratio >= 0.9 and gratio >= 0.9
      if i == glen - 3 -- last
        return results[1][2], results[1][3]
      return normalized grids[i + 4], grids[i + 5], grids[i + 6], grids[i + 7], sframe

    results[(i - 1) / 4 + 1] = { i, gtopleft, gsize, fratio, gratio }

  sort results, (r1, r2) ->
    fr1, fr2 = r1[4], r2[4]
    return fr1 > fr2 if fr1 != fr2
    sfr1, sfr2 = r1[5], r2[5]
    return sfr1 > sfr2 if sfr1 != sfr2
    return r1[1] < r2[1]

  return results[1][2], results[1][3]

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  move: T 'number, number, table, table', move
  extend: T 'number, number, table, table', extend
  center: T 'table, table', center
  maximize: T 'table', maximize
  normalized: T 'number, number, number, number, table, table' , normalized
  snap: T 'table, table, table', snap
}
