---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import execute from os
menubars = require 'menubars'
autoproxy = require 'autoproxy'
import partial from require 'fn'
{ sigcheck:T } = require 'typecheck'
import doAfter from require 'hs.timer'
import capitalize from require 'fn.string'
import applescript from require 'hs.osascript'
{ setContents:setPasteboard } = require 'hs.pasteboard'
import openNetworkProxies from require('system').preferences
import all, keys, imap, sort, insert, ieach from require 'fn.table'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

MODIFIERS_MAP = { '⌘': 'cmd', '⌃': 'ctrl', '⌥': 'alt', '⇧': 'shift', 'cmd': 'cmd', 'ctrl': 'ctrl', 'alt': 'alt', 'shift': 'shift' }

menuItem = nil

makemenu = (shortcuts, shownpp, modifiers) ->
  if shortcuts
    for _, s in ipairs shortcuts
      if all s.modifiers, partial(rawget, modifiers)
        if s.toggle then autoproxy.toggle!
        else autoproxy.on s.profile
        break

  p, url, enabled = autoproxy.status!
  profiles = autoproxy.profiles!
  pnames = keys profiles
  sort pnames

  local status, substatus, toggleTitle, toggleFn
  if enabled
    toggleTitle = 'Turn Auto Proxy Off'
    toggleFn = autoproxy.off
    if p
      status = "Auto Proxy: #{capitalize p}" if p
    else
      status = 'Auto Proxy: On'
      substatus = "URL: #{url}"
  else
    toggleTitle = 'Turn Auto Proxy On'
    status = 'Auto Proxy: Off'
    toggleFn = autoproxy.on

  menu = {
    { title: status, disabled: true }
    { title: toggleTitle, fn: () -> toggleFn! }
    { title: '-' }
    {
      title: 'Profiles...', menu: imap pnames, () =>
        url = profiles[@].url
        return {
          title: capitalize @
          checked: @ == p
          fn: partial autoproxy.on, @
          menu: {
            { title: "URL: #{url}", disabled: true }
            { title: 'Copy', fn: () -> setPasteboard url }
          }
        }
    }
  }

  if substatus
    insert menu, 2, { title: substatus, disabled: true }
    insert menu, 3, title: '-'

  if shownpp
    menu[#menu + 1] = { title: '-' }
    menu[#menu + 1] = {
      title: 'Open Network Proxy Preferences...'
      fn: openNetworkProxies
    }

  return menu

init = (options) ->
  with options
    icons = .icons or {}
    icons['on'] = menubars._defaultIcon unless icons['on']
    icons['off'] = menubars._defaultIcon unless icons['off']
    shortcuts = .shortcuts
    ieach shortcuts, () =>
      @modifiers = imap(@modifiers, partial(rawget, MODIFIERS_MAP))

    menuItem = menubars.new icons['off'], .title, partial(makemenu, shortcuts, .showNetworkProxyPreferences != false)
    autoproxy.callback (new) ->
      newIcon = if not new then icons['off']
      elseif icon = icons[new] then icon
      else icons['on']
      menuItem\setIcon newIcon

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  init: T 'table', init
}
