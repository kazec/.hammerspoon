---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import ipairs from _G
log = require('log').get 'watchers'
{ sigcheck:T } = require 'typecheck'
import ieach, ieachr, merge from require 'fn.table'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

self =
  _submods: nil

init = (submods, options) ->
  for _, modname in ipairs submods
    log.infof 'Initializing watcher: %s', modname if log.infof
    mod = require "watchers.#{modname}"
    mod.init options[modname]
    @[modname] = mod
  @_submods = submods

start = () -> ieach @_submods, (n) -> @[n].start! if @[n].start
  
stop = () -> ieachr @_submods, (n) -> @[n].stop! if @[n].stop

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'table, table', init
  :start, :stop
}
