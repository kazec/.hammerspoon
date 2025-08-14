---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import date from os
import format from string
log = require('log').get 'daemon'
{ sigcheck:T, :isfunction, :istable } = require 'typecheck'
import concat, ieach, ieachr, imap, merge, first from require 'fn.table'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

modinfos = {}

load = (modname, ...) ->
  mod = require modname
  log.error 'Module "%s" must return a table.', modname unless istable mod

  mod.init ... if isfunction mod.init

  modinfos[#modinfos + 1] =
    mod: mod,
    name: modname,
    status: 'loaded',
    timestamp: date '%Y-%m-%d %H:%M:%S'
  return mod

start = (modname) ->
  trystart = (info) ->
    if isfunction info.mod.start
      log.infof 'Starting module: %s', info.name if log.info
      info.mod.start!
      info.status = if isfunction info.mod.stop then 'active running' else 'started'
      info.timestamp = date '%Y-%m-%d %H:%M:%S'

  if modname
    info = first(modinfos, (info) -> info.name == modname)
    log.errorf 'Unable to find module "%s".', modname if info == nil
    trystart info
  else
    ieach modinfos, trystart

stop = (modname) ->
  trystop = (info) ->
    if isfunction info.mod.stop
      log.infof 'Stopping module: %s', info.name if log.info
      info.mod.stop!
      info.status = 'stopped'
      info.timestamp = date '%Y-%m-%d %H:%M:%S'

  if modname
    info = first(modinfos, (info) -> info.name == modname)
    log.error 'Unable to find module "%s".', modname if info == nil
    trystop info
  else
    ieachr modinfos, trystop

restart = (modname) ->
  info = first(modinfos, (info) -> info.name == modname)
  log.error 'Unable to find module "%s".', modname if info == nil

  if isfunction info.mod.restart
    log.infof 'Restarting module: %s', info.name if log.info
    prevstatus = info.status
    info.status = 'restarting'
    info.mod.restart!
    info.status = prevstatus
  elseif isfunction info.mod.stop and isfunction info.mod.start
    log.infof 'Stopping module: %s', info.name if log.info
    info.mod.stop!
    info.status = 'stopped'
    log.infof 'Starting module: %s', info.name if log.info
    info.mod.start!
    info.status = 'active running'
    info.timestamp = date '%Y-%m-%d %H:%M:%S'

status = (modname, tostr = true) ->
  local fmtinfo
  if tostr
    fmtinfo = (info) -> format 'Module <%s> is %s since %s', info.name, info.status, info.timestamp
  else
    fmtinfo = (info) -> { name: info.name, status: info.status, timestamp: info.timestamp }

  if modname
    info = first(modinfos, (info) -> info.name == modname)
    log.error 'Unable to find module "%s".', modname unless info != nil
    return fmtinfo info
  elseif tostr
    return format('%d module(s) loaded/running now:\n', #modinfos) ..
      concat(imap(modinfos, fmtinfo), '\n')
  else return imap modinfos, fmtinfo

modules = () -> { info.name, info.mod for _, info in ipairs modinfos }

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
   -- Load a module using 'require' and call its 'init' optionally, the module will be retained.
   load:    T 'string, ?...', load
   -- Start the specific module or all modules in order optionally.
   start:   T '?string', start
   -- Stop the specific module or all modules in reversed order optionally.
   stop:    T '?string', stop
   -- Restart the specific module.
   restart: T 'string', restart
   -- Get status of specific module or all modules.
   status:  T '?string, ?boolean', status
   -- Get all loaded modules
   :modules
}
