---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import format from string
import time, execute from os
import floor, ceil from math
menubars = require 'menubars'
log = require('log').get 'menubars'
{ sigcheck:T } = require 'typecheck'
{ show:notify } = require 'hs.notify'
import partial, once from require 'fn'
import sound, settings from require 'hs'
import isidx, sort, imap, depair, merge from require 'fn.table'
{ new:Timer, :doAfter } = require 'hs.timer'
import preventIdleDisplaySleep, allowIdleDisplaySleep from require 'hs.caffeinate'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

self =
  _timer: nil
  _menuItem: nil
  _onIcon: nil
  _offIcon: nil
  _activation: nil

minutesToStr = (minutes) ->
  return 'Indefinitely' if minutes < 0

  hours = floor minutes / 60
  minutes = minutes - hours * 60
  return if minutes == 0 then format('%.d hour', hours) .. (hours == 1 and '' or 's')
  elseif hours == 0 then format('%.d minute', minutes) .. (minutes == 1 and '' or 's')
  else format('%.d hour', hours) .. (hours == 1 and '' or 's') ..
    format(' %.d minute', minutes) .. (minutes == 1 and '' or 's')

on = (minutes, hint) ->
  minutes or= -1
  hint or= minutesToStr(minutes)
  log.info 'Starting caffeination: ' .. hint if log.info
  preventIdleDisplaySleep!
  @_menuItem\setIcon @_onIcon

  seconds = minutes * 60
  if minutes < 0 then @_timer\stop!
  else @_timer\setNextTrigger(seconds)

  @_activation =
    since: time!
    hint: hint
    duration: seconds

off = () ->
  log.info 'Stopping caffeination' if log.info
  allowIdleDisplaySleep!
  @_timer\stop!
  @_activation = nil
  @_menuItem\setIcon @_offIcon

toggle = (minutes) -> @_activation and off! or on(minutes)

status = (tostr) ->
  return tostr and 'Caffeination: Off' or false if not @_activation
  return tostr and 'Caffeination: On' or true if @_activation.duration < 0
  seconds = @_activation.since + @_activation.duration - time!
  return seconds unless tostr
  return 'Caffeination: Less than one minute' if seconds < 60
  minutes = ceil seconds / 60
  return 'Caffeination: ' .. minutesToStr(minutes) .. ' remaining'

makeMenu = (minutes, durations, esaver, modifiers) ->
  -- toggle the status if option key is down
  toggle minutes if modifiers['alt'] == true

  -- make the menu table
  menu = {{ title: status(true), disabled: true }}
  menu[#menu + 1] = {
    title: 'Turn Caffeination Off'
    fn: off
  } if @_activation
  menu[#menu + 1] = title: '-'
  menu[#menu + 1] =
    title: 'Caffeinate...'
    menu: imap durations, (t) -> {
      title: t[1]
      checked: do
        if not @_activation then false
        elseif @_activation.duration < 0 and t[2] < 0 then true
        else @_activation.duration == t[2] * 60
      fn: partial on, t[2], t[1]
    }
    fn: partial on, -1

  if esaver
    menu[#menu + 1] = title: '-'
    menu[#menu + 1] =
      title:  'Open Energy Saver Preferences...'
      fn: () -> execute 'open /System/Library/PreferencePanes/EnergySaver.prefPane'
  return menu

init = (options) ->
  with options
    @_onIcon = .icons.on or menubars._defaultIcon
    @_offIcon = .icons.off or menubars._defaultIcon
    durations = .durations or { -1, 30, 60, 120, 240, 300 }
    durations = depair { isidx(k) and minutesToStr(v) or k, v for k, v in pairs durations }
    sort durations, (d1, d2) -> d1[2] < d2[2]
    title = .title

    -- Get previous activation info.
    menu = partial makeMenu, .toggle or -1, durations, .showEnergySaverPreferences != false
    timerCallback = not .notifyOnCompletion and off or () ->
      notify 'Caffeination Ended', '', 'Duration: ' .. minutesToStr(@_activation.duration / 60)
      sound.getByName('Glass')\play!
      off!
    if activation = settings.get 'menubars.caffeinate.activation'
      if activation.duration < 0
        log.debugf 'Restoring previous caffeination session: %s' .. minutesToStr(activation.duration / 60) if log.debugf
        preventIdleDisplaySleep!
        @_menuItem = menubars.new @_onIcon, title, menu
        @_timer = Timer 0, timerCallback
        @_activation = activation
        return
      else
        remaining = activation.since + activation.duration - time!
        if remaining > 0
          log.debugf 'Restoring previous caffeination session: %s' .. minutesToStr(activation.duration / 60) if log.debugf
          preventIdleDisplaySleep!
          @_menuItem = menubars.new @_onIcon, title, menu
          @_timer = Timer(remaining, timerCallback)\start!
          @_activation = activation
          return

    @_menuItem = menubars.new @_offIcon, title, menu
    @_timer = Timer 0, timerCallback
    return

stop = () ->
  allowIdleDisplaySleep!
  log.debugf 'Saving caffeination info: %s', @_activation if log.debugf
  settings.set 'menubars.caffeinate.activation', @_activation

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'table', once(init)
  on: T '?number', on
  off: T '?number', off
  toggle: T '?number', toggle
  status: T '?boolean', status
  :stop
}
