---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import setmetatable from _G
import mergek, override, copy from require 'fn.table'

{ :checkers, sigcheck:T } = require('typecheck')

color = require('hs.drawing.color')

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

palettes = color.lists()
defaultPalette = palettes.x11

hex = (h) ->
  switch hex\len()
    when 4, 7 then { hex: h }
    when 9 then { hex: h\sub(1, 7), alpha: tonumber("0x#{h\sub(8, 9)}" / 255) }

name = (n) ->
  c = defaultPalette[n]
  return c if c

  for _, p in ipairs palettes
    c = p[n]
    return c if c

  return nil

ishex = (v) ->
  return false unless type(v) == 'string' and v\sub(1,1) == '#'
  len = v\len()
  return len == 4 or len == 7 or len == 9

checkers.hex = ishex

get = (v) -> if ishex(v) then hex(v) else name(v)

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

setmetatable({
  :palettes
  hex:    T 'hex', hex
  name:   T 'string', name
  get:    T 'string', get
  asHSB:  color.asHSB
  asRGB:  color.asRGB
}, {
  __call: T '?, string', (_, v) -> get(v)
  __index: palettes
})
