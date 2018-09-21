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

bind = (productName, connected, disconnected) ->
  @_callbacks[productName] = { connected, disconnected }

watcherCallback = (event) ->
  with event
    log.infof 'USB Device: %q(%d) - %q(%d) %s', .productName, .productID, .vendorName, .vendorID, .eventType\upper! if log.infof

    if callbackFound = @_callbacks[.productName]
      callback = callbackFound[.eventType == 'added' and 1 or 2]
      callback event if callback

init = (options) ->
  @_callbacks = {}
  for productName, callbackPair in pairs options
    if isfunction callbackPair
      @.bind productName, callbackPair, nil
    else
      @.bind productName, callbackPair.connected, callbackPair.disconnected

  @_watcher = USBWatcher watcherCallback

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
