---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import pairs from _G
log = require('log').get 'watchers'
import merge from require 'fn.table'
{ new:WifiWatcher } = require 'hs.wifi.watcher'
{ sigcheck:T, :isfunction } = require 'typecheck'
import currentNetwork, interfaceDetails from require 'hs.wifi'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

self =
  _watcher: nil
  _callbacks: nil
  _lastSSID: nil

bind = (ssid, eventName, callback) ->
  callbackFound = @_callbacks[ssid]
  if not callbackFound
    callbackFound = {}
    @_callbacks[ssid] = callbackFound
  callbackFound[eventName] = callback

watcherCallback = () ->
  currentSSID = currentNetwork!
  return if currentSSID == @_lastSSID

  log.infof 'Wi-Fi Changed: %q -> %q', @_lastSSID, currentSSID if log.infof

  callbackFound = @_callbacks[@_lastSSID]
  if callbackFound
    eventName = 'disconnected'
    callback = callbackFound[eventName]
    callback @_lastSSID, currentSSID if callback

  callbackFound = @_callbacks[currentSSID]
  if callbackFound
    eventName = 'connected'
    callback = callbackFound[eventName]
    callback @_lastSSID, currentSSID if callback

  @_lastSSID = currentSSID

init = (func) ->
  @_callbacks = {}
  @_lastSSID = currentNetwork!
  @_watcher = WifiWatcher watcherCallback
  func self

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
