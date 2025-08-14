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

bind = (appID, callback) ->
  @_callbacks[appID] = callback

watcherCallback = (appName, eventType, appObj) ->
  appID = appObj\bundleID!
  
  log.logf 'App Event: %s %s', appName, eventType if log.logf
  
  callbackFound = @_callbacks[appID]
  return unless callbackFound
  
  eventName = EVENT_MAP[eventType]
  return unless eventName

  log.infof 'App Event Callback: %s %s', appID, eventName if log.infof

  if isfunction callbackFound
    callbackFound appObj, eventName
  else if istable callbackFound
    callback = callbackFound[eventName]
    callback appObj if callback
  else
    log.errorf 'Invalid callback type: %s', type callbackFound

init = (options) ->
  @_callbacks = {}

  for appID, callback in pairs options
    @.bind appID, callback
  
  @_watcher = AppWatcher.new watcherCallback

start = () -> @_watcher\start!
stop = () -> @_watcher\stop!

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'table', init
  bind: T 'string, table|function', bind
  :start, :stop
}
