---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import pairs from _G
log = require('log').get 'watchers'
import merge from require 'fn.table'
{ new:USBWatcher } = require 'hs.usb.watcher'
{ sigcheck:T, :isfunction } = require 'typecheck'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

self =
  _watcher: nil
  _callbacks: {}

bind = (deviceName, eventName, callback) ->
  if isfunction deviceName
    @_callbacks[#@_callbacks + 1] = deviceName
    return

  @_callbacks[#@_callbacks + 1] = (info) ->
    if deviceName and deviceName ~= info.productName
      return
    if eventName and eventName ~= info.eventType
      return
    
    callback info

watcherCallback = (event) ->
  with event
    log.infof 'USB Device: %q(%d) - %q(%d) %s', .productName, .productID, .vendorName, .vendorID, .eventType\upper! if log.infof

  for callback in *@_callbacks
    callback event

init = (func) ->
  @_callbacks = {}
  @_watcher = USBWatcher watcherCallback
  func self

start = () -> @_watcher\start!
stop = () -> @_watcher\stop!

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'function', init
  bind: T '?string|function, ?string, ?function', bind
  :start, :stop
}
