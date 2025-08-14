---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import pairs from _G
import partial from require 'fn'
log = require('log').get 'watchers'
import merge from require 'fn.table'
import doAfter from require 'hs.timer'
import focusedSpace from require 'hs.spaces'
{ new:SpacesWatcher} = require 'hs.spaces.watcher'
{ sigcheck:T, :isfunction, :istable } = require 'typecheck'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

self =
  _timer: nil
  _watcher: nil
  _callbacks: nil

bind = (space_num, callback) ->
  @_callbacks[space_num] = callback

timerCallback = () ->
  -- Call all registered callbacks with the new space number
  space_number = focusedSpace!
  callback = @_callbacks[space_number]
  log.infof 'Space Changed: %s', space_number if log.infof
  if callback
    callback space_number

watcherCallback = (space_number) ->
  @_timer\stop! if @_timer
  @_timer = doAfter 0.5, timerCallback

init = (func) ->
  @_callbacks = {}
  @_watcher = SpacesWatcher watcherCallback
  func self

  timerCallback

start = () -> @_watcher\start!
stop = () -> @_watcher\stop!

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'function', init
  bind: T 'string, function', bind
  :start, :stop
}
