---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import pairs from _G
log = require('log').get 'watchers'
import merge, imapkv from require 'fn.table'
AppWatcher = require 'hs.application.watcher'
{ sigcheck:T, :isfunction, :istable } = require 'typecheck'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

EVENTS = {
  'activated', 'deactivated', 'launching', 'launched', 'terminated', 'hidden',
  'unhidden' 
}

EVENT_MAP = imapkv EVENTS, (event) -> AppWatcher[event], event

self =
  _watcher: nil
  _callbacks: nil

bind = (appID, eventName, callback) ->
  callbackFound = @_callbacks[appID]
  if not callbackFound
    callbackFound = {}
    @_callbacks[appID] = callbackFound
  callbackFound[eventName] = callback

watcherCallback = (appName, eventType, appObj) ->
  appID = appObj\bundleID!
  
  log.logf 'App Event: %s %s', appName, eventType if log.logf
  
  callbackFound = @_callbacks[appID]
  return unless callbackFound

  eventName = EVENT_MAP[eventType]
  return unless eventName

  callback = callbackFound[eventName]
  return unless callback
  
  log.infof 'App Event Callback: %s %s', appID, eventName if log.infof
  callback appObj

init = (func) ->
  @_callbacks = {}
  @_watcher = AppWatcher.new watcherCallback
  func self

start = () -> @_watcher\start!
stop = () -> @_watcher\stop!

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'function', init
  bind: T 'string, string, function', bind
  :start, :stop
}
