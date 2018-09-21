---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import next from _G
import find, sub from string
import partial from require 'fn'
log = require('log').get 'watchers'
import doAfter from require 'hs.timer'
import ifilter, index from require 'fn.table'
{ new:PathWatcher } = require 'hs.pathwatcher'
import configdir, reload, openConsole from require 'hs'
{ sigcheck:T, :isstring, :istable } = require 'typecheck'
{ new:Notification, :activationTypes } = require 'hs.notify'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

NOTIFICATION_ATTRS =
  title: 'Configuration Modified'
  informativeText: 'Hammerspoon configuration file(s) has been modified. Click to reload.'
  hasActionButton: true
  actionButtonTitle: 'Reload'
  otherButtonTitle: 'Dismiss'

pathwatcher = nil
prevNotification = nil

notificationCallback = () =>
  @activationType! == activationTypes.actionButtonClicked and reload! or openConsole!

watcherCallback = (filter, paths) ->
  paths = ifilter paths, filter
  return if #paths == 0

  log.infof 'Config Files Modified:\n%s', paths if log.infof
  return if prevNotification

  prevNotification = Notification(notificationCallback, NOTIFICATION_ATTRS)\send!
  doAfter 6, () -> prevNotification\withdraw!

init = (filters) ->
  filter = if filters
    (p) -> not index(filters, () => find p, @)
  else
    (p) -> sub(p, -5) == '.moon'
  pathwatcher = PathWatcher configdir, partial(watcherCallback, filter)

start = () -> pathwatcher\start!

stop = () -> pathwatcher\stop!

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  init: T 'table', init
  :start, :stop
}
