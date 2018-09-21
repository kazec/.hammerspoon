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

bind = (ssid, connected, disconnected) ->
  @_callbacks[ssid] = { connected, disconnected }

watcherCallback = () ->
  currentSSID = currentNetwork!
  return if currentSSID == @_lastSSID

  log.infof 'Wi-Fi Changed: %q -> %q', @_lastSSID, currentSSID if log.infof

  callbackFound = @_callbacks[@_lastSSID]
  if callbackFound
    disconnected = callbackFound[2]
    disconnected @_lastSSID, currentSSID if disconnected

  callbackFound = @_callbacks[currentSSID]
  if callbackFound
    connected = callbackFound[1]
    connected @_lastSSID, currentSSID if connected

  @_lastSSID = currentSSID

init = (options) ->
  @_callbacks = {}
  for ssid, callbackPair in pairs options
    if isfunction callbackPair
      @.bind ssid, callbackPair, nil
    else
      @.bind ssid, callbackPair.connected, callbackPair.disconnected

  @_lastSSID = currentNetwork!
  @_watcher = WifiWatcher watcherCallback

start = () -> @_watcher\start!
stop = () -> @_watcher\stop!

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'table', init
  bind: T 'string, function, ?function', bind
  :start, :stop
}
