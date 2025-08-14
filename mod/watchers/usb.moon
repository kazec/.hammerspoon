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
  _callbacks: nil

bind = (productName, eventName, callback) ->
  callbackFound = @_callbacks[productName]
  if not callbackFound
    callbackFound = {}
    @_callbacks[productName] = callbackFound
  callbackFound[eventName] = callback

watcherCallback = (event) ->
  with event
    log.infof 'USB Device: %q(%d) - %q(%d) %s', .productName, .productID, .vendorName, .vendorID, .eventType\upper! if log.infof

    if callbackFound = @_callbacks[.productName]
      eventName = .eventType == 'added' and 'connected' or 'disconnected'
      callback = callbackFound[eventName]
      callback event if callback

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
  bind: T 'string, ?function, ?function', bind
  :start, :stop
}
