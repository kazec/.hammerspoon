---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import execute from os
import format from string

import partial from require 'fn'
{ sigcheck:T } = require 'typecheck'
import doAfter from require 'hs.timer'
import run, escape from require 'shell'
{ get:Application } = require 'hs.application'
import systemSleep from require 'hs.caffeinate'
import setmetatable, tostring, tonumber from _G
import applescript, javascript from require 'hs.osascript'


app = require 'hs.application'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

SH_OPEN_SSE = 'open -a ScreenSaverEngine'
SH_DSPL_SLEEP = 'pmset displaysleepnow'
SH_KILL_DOCK = 'killall Dock'
SH_KILL_FINDER = 'killall Finder'
SH_RESET_DOCK = 'defaults delete com.apple.dock && killall Dock'
AS_LOCK = 'tell application "System Events" to key code 12 using {control down, command down}'
AS_SLEEP = 'tell application "System Events" to sleep'
AS_LOGOUT = 'tell application "System Events" to log out'
AS_RESTART = 'tell application "System Events" to restart'
AS_SHUTDWN = 'tell application "System Events" to shut down'
AS_TOGGLE_DM = 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode'
JS_NC_TOGGLE = 'Application("System Events").processes["SystemUIServer"].menuBars[0].menuBarItems["Notification Center"].click()'
JS_NC_TODAY = 'Application("System Events").processes["NotificationCenter"].windows[0].radioGroups[0].radioButtons["Today"].click()'
JS_NC_NCS = 'Application("System Events").processes["NotificationCenter"].windows[0].radioGroups[0].radioButtons["Notifications"].click()'
AS_ITUNES_CT = [[tell application "iTunes"
  activate
  reveal current track
end tell]]

defaults = (domain, key, type, newvalue) ->
  if newvalue != nil
    return run format('defaults write %s %s -%s %s', domain, key, type, tostring newvalue)
  else
    output, success = run format('defaults read %s %s', domain, key)
    return switch type
      when 'bool' then output == '1\n' or output == 'true\n'
      when 'int', 'float' then tonumber output
      else success and output or nil

plistpath = (label, dir = '~/Library/LaunchAgents') -> dir .. '/' .. label .. '.plist'

darkmode = (flag) ->
  if flag != nil
    print 'Application("System Events").appearancePreferences.darkMode = ' .. tostring(flag)
    javascript 'Application("System Events").appearancePreferences.darkMode = ' .. tostring(flag)
  else
    _, result = javascript 'Application("System Events").appearancePreferences.darkMode()'
    result

wallpaper = (path) ->
  return execute 'sqlite3 ' .. '~/Library/Application\\ Support/Dock/desktoppicture.db "update data set value = \'' .. escape(path) .. '\'" && killall Dock'

safari = (attr) ->
  attr = attr == 'title' and 'name' or attr or 'URL'
  _, output = applescript 'tell application "Safari" to get ' .. attr .. ' of current tab of front window'
  return output

chrome = (attr) ->
  attr = 'document.' .. attr
  _, output = applescript 'tell application "Google Chrome" to set source to execute front window\'s active tab javascript "' .. attr .. '"'
  return output

reindexmails = () ->
  size = () ->
    size, success = execute 'ls -lnah ~/Library/Mail/V4/MailData | grep -E "Envelope Index$" | awk \'{print $5}\''
    return success and size or 'NaN'

  mail = app.get 'com.apple.mail'
  activated = not not mail
  mail\kill! if activated

  before = size!
  execute '/usr/bin/sqlite3 ~/Library/Mail/V5/MailData/Envelope\\ Index "vacuum"'
  after = size!

  app.launchOrFocusByBundleID 'com.apple.mail' if activated
  return before, after

nodisturb = (flag) ->
  if flag != nil
    'true' == run '/usr/libexec/PlistBuddy -c "Print doNotDisturb" $(find ~/Library/Preferences/ByHost -name com.apple.notificationcenterui.*.plist)'
  else
    applescript [[
      tell application "System Events" to tell process "SystemUIServer"
        key down option
        click menu bar item 1 of menu bar 1
        key up option
      end tell
    ]]

opennpp = () ->
  execute 'open /System/Library/PreferencePanes/Network.prefPane'
  doAfter 0.2, () ->
    applescript [[
      tell application "System Events" to tell process "System Preferences" to tell window "Network"
        click button "Advanced…"
        click radio button "Proxies" of tab group 1 of sheet 1
      end tell
    ]]

finderToggleHidden = () ->
  finder = Application 'com.apple.finder'
  showAll = defaults('com.apple.finder', 'AppleShowAllFiles', 'bool')
  defaults('com.apple.finder', 'AppleShowAllFiles', 'bool', not showAll)
  if finder
    finder\kill!
    execute '(sleep 0.5; open -a Finder; open -a Finder) &'

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  defaults: T 'string, string, ?string, ?string|boolean', defaults

  sleep:       partial applescript, AS_SLEEP
  logout:      partial applescript, AS_LOGOUT
  restart:     partial applescript, AS_RESTART
  shutdown:    partial applescript, AS_SHUTDWN
  screensaver: partial execute, SH_OPEN_SSE

  display:
    sleep:     partial execute, SH_DSPL_SLEEP
    lock:      partial applescript, AS_LOCK

  darkmode:
    toggle:    partial applescript, AS_TOGGLE_DM
    darkmode:  T '?boolean', darkmode

  wallpaper: T 'string', wallpaper

  preferences:
    openNetworkProxies: opennpp

  launchctl:
    plist:  T 'string, ?string', plistpath
    load:   T 'string', partial run, 'launchctl', 'load'
    unload: T 'string', partial run, 'launchctl', 'unload'
    start:  T 'string', partial run, 'launchctl', 'start'
    stop:   T 'string', partial run, 'launchctl', 'stop'

  safari:
    url:    partial safari, 'URL'
    title:  partial safari, 'name'
    text:   partial safari, 'text'
    source: partial safari, 'source'

  chrome:
    url:    partial chrome, 'URL'
    title:  partial chrome, 'title'
    text:   partial chrome, 'documentElement.outerText'
    source: partial chrome, 'documentElement.outerHTML'
    attribute: T 'string', chrome

  dock:
    kill: partial execute, SH_KILL_DOCK
    reset: partial execute, SH_RESET_DOCK
    showHidden: T '?boolean', partial defaults, 'com.apple.dock', 'showhidden', 'bool'

  finder:
    kill: partial execute, SH_KILL_FINDER
    showHidden: T '?boolean', partial defaults, 'com.apple.dock', 'AppleShowAllFiles', 'bool'
    showPathBar: T '?boolean', partial defaults, 'com.apple.dock', 'ShowPathbar', 'bool'
    showStatusBar: T '?boolean', partial defaults, 'com.apple.dock', 'ShowStatusbar', 'bool'
    toggleHidden: finderToggleHidden

  mails:
    reindex: reindexmails

  notificationcenter:
    toggle: partial javascript, JS_NC_TOGGLE
    today:  partial javascript, JS_NC_TODAY
    notifications:  partial javascript, JS_NC_NCS
    doNotDisturb: T '?boolean', nodisturb

  itunes:
    currentTrack: partial applescript, AS_ITUNES_CT
}
