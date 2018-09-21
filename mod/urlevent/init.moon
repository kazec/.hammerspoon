---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import pairs from _G
import once from require 'fn'
urlevent = require 'hs.urlevent'
{ sigcheck:T } = require 'typecheck'
import copy, merge from require 'fn.table'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

self = copy urlevent

init = (options) ->
  with options
    @_callbacks = .callbacks
    if .router
      @router = require('urlevent.router')
      @router.init .router

start = () ->
  for e, c in pairs @_callbacks
    @.bind e, c
  @_callbacks = nil

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'table', once(init)
  :start
}
