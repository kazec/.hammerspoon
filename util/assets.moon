---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import pcall from _G
import run from require 'shell'
import open, read, close from io
import configdir from require 'hs'
import byte, find, sub from string
{ sigcheck:T } = require 'typecheck'
import imageFromPath from require 'hs.image'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

ASSETS_DIR = "#{configdir}/assets"

path = (name) -> "#{ASSETS_DIR}/#{name}"

load = (p, arg) ->
  p = "#{ASSETS_DIR}/#{p}" unless byte(p) == 47 -- '^/'
  sub4 = sub p, -4
  sub5 = sub p, -5
  -- If the requested asset is an image.
  if sub4 == '.jpg' or sub4 == '.png' or sub4 == '.gif' or sub4 == '.ico' or
     sub4 == '.bmp' or sub5 == '.jpeg' or sub5 == '.icns'
    -- load asset as an hs.image object.
    success, result = pcall imageFromPath, p
    error "Failed to load image at path: #{p}" unless success
    result\size arg, true if arg
    return result
  elseif sub4 == '.lua' or sub5 == '.moon'
    -- If the requested asset is a lua/moon configuraion file.
    success, result = pcall dofile, p
    return success and result or nil
  else
    -- If the requested asset is a text file.
    output, success = run 'file', p
    if success and find output, 'text'
      handle = open p, 'r'
      content = read handle, '*a'
      close handle
      return content
    return p

setmetatable {
  assetsdir: ASSETS_DIR
  path: T 'string', path
  load: T 'string', load
}, {
  __index: T '?, string', (f) => path f
  __call:  T '?, string', (f, a) => load f, a
}
