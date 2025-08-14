---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

hs = require 'hs'
import exit from os
import format from string
console = require 'console'
menubars = require 'menubars'
import partial from require 'fn'
import execute from require 'shell'
log = require('log').get 'menubars'
{ sigcheck:T } = require 'typecheck'
import imap, indexof, insert, sort from require 'fn.table'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

toggle = (fn) -> () -> fn not fn!

relaunch = () ->
  log.info 'Relaunching Hammerspoon...'
  execute "(while ps -p #{hs.processInfo.processID} > /dev/null; do sleep 1; done; open -a \"#{hs.processInfo.bundlePath}\") &"
  exit true, true

editcfg = (editor, indir) ->
  execute editor, indir and hs.configdir or "#{hs.configdir}/init.moon"

MENU = {
  {
    title: 'Config...', menu: {
      { title: 'Reload', fn: hs.reload }
      { title: 'Edit', fn: nil }
      { title: 'Edit in Directory', fn: nil }
    }
    fn: nil
  }
  {
    title: 'Console...', menu: {
      { title: 'Toggle', fn: console.toggle }
      { title: '-' }
      { title: 'Alpha', menu: nil }
      { title: 'Theme', menu: nil }
      { title: '-' }
      { title: 'Dark Mode', checked: nil, fn: toggle console.darkMode }
      { title: 'Always on Top', checked: nil, fn: toggle console.alwaysOnTop }
      { title: '-' }
      { title: 'Open Log File', fn: log.openhistory }
    }
    fn: console.open
  }
  {
    title: 'Preferences...', menu: {
      { title: 'Open', fn: hs.openPreferences }
      { title: '-' }
      { title: 'Dark Mode', checked: nil, fn: toggle hs.preferencesDarkMode }
      { title: 'Show Dock Icon', checked: nil, fn: toggle hs.dockIcon }
      { title: 'Show Menu Icon', checked: nil, fn: toggle hs.menuIcon }
    }
    fn: hs.openPreferences
  }
  { title: '-' }
  {
    title: 'About & Updates...', menu: {
      { title: 'About Hammserspoon', fn: hs.openAbout }
      { title: 'Check for Updates...', disabled: nil, fn: () -> hs.checkForUpdates! }
      { title: "-" },
      { title: 'Automatically Check for Updates', checked: nil, fn: toggle hs.automaticallyCheckForUpdates }
    }
  }
  { title: '-' }
  { title: 'Quit Hammerspoon', fn: partial exit, true, true }
  {
    title: 'Relaunch Hammerspoon', fn: relaunch
  }
}

FLAT_MENU = {
  { title: 'Reload Config', fn: hs.reload }
  { title: 'Edit Config', fn: nil }
  { title: "-" }
  { title: 'Toggle Console', fn: console.toggle }
  { title: 'Console Alpha', menu: nil }
  { title: 'Console Theme', menu: nil }
  { title: 'Console Dark Mode', checked: nil, fn: toggle console.darkMode },
  { title: 'Console Always on Top', checked: nil, fn: toggle console.alwaysOnTop }
  { title: "-" }
  {
    title: 'Preferences...', fn: hs.openPreferences, menu: {
      { title: 'Open', fn: hs.openPreferences }
      { title: '-' }
      { title: 'Show Dock Icon', checked: nil, fn: toggle hs.dockIcon }
      { title: 'Show Menu Icon', checked: nil ,fn: toggle hs.menuIcon }
    }
  }
  { title: "-" },
  { title: 'About Hammerspoon', fn: hs.openAbout }
  { title: 'Check for Updates...', disabled: nil, fn: () -> hs.checkForUpdates! }
  { title: 'Automatically Check for Updates', checked: nil, fn: toggle hs.automaticallyCheckForUpdates }
  { title: "-" }
  { title: 'Quit Hammerspoon', fn: partial exit, true, true }
  { title: 'Relaunch Hammerspoon', fn: relaunch }
}

menuitem = nil

makeAlphaMenu = (values) ->
  current = console.alpha!
  menu = if indexof values, current
    { { title: format('Current Value: %.d%%', current * 100), disabled: true },
      { title: '-' } }
  else {}

  for _, v in ipairs values
    menu[#menu + 1] =
      value: v
      title: format '%.d%%', v * 100
      checked: v == current
      fn: () -> console.alpha  v

  return menu

makeThemeMenu = () ->
  current = console.theme.get!
  themes = console.theme.all!

  sort themes, (l, r) ->
    return true if l == 'Default'
    return false if l == 'Default'
    return l < r

  return imap themes, () => {
    title: @
    checked: @ == current
    fn: partial console.theme.set, @
  }

updateMenu = (menu) ->
  m = menu[2].menu
  m[3].menu = makeAlphaMenu!
  m[4].menu = makeThemeMenu!
  m[6].checked = console.darkMode!
  m[7].checked = console.alwaysOnTop!
  m = menu[3].menu
  m[3].checked = hs.preferencesDarkMode!
  m[4].checked = hs.dockIcon!
  m[4].title = m[4].checked and 'Dock Icon' or 'Show Dock Icon'
  m[5].checked = hs.menuIcon!
  m[5].title = m[5].checked and 'Menu Icon' or 'Show Menu Icon'
  m = menu[5].menu
  m[2].disabled = not hs.canCheckForUpdates!
  m[4].checked = hs.automaticallyCheckForUpdates!

updateFlatMenu = (menu) ->
  menu[5].menu = makeAlphaMenu!
  menu[6].menu = makeThemeMenu!
  menu[7].checked = console.darkMode!
  menu[8].checked = console.alwaysOnTop!
  m = menu[10].menu
  m[3].checked = hs.dockIcon!
  m[4].checked = hs.menuIcon!
  menu[12].disabled = not hs.canCheckForUpdates!
  menu[13].checked = hs.automaticallyCheckForUpdates!

makemenu = (mod) ->
  return if mod['alt'] == true
    updateFlatMenu FLAT_MENU
    FLAT_MENU
  else
    updateMenu MENU
    MENU

init = (options) ->
  with options
    icon = .icon or menubars._defaultIcon
    editor = .configEditor or 'open'
    alphaValues = .consoleAlphaValues or { 0.3, 0.5, 0.75, 1.00 }

    edit = partial editcfg, editor, false
    editdir = partial editcfg, editor, true
    editm = (mod) -> editcfg(editor, mod['alt'] == true)
    MENU[1].fn = editm
    MENU[1].menu[2].fn = edit
    MENU[1].menu[3].fn = editdir
    FLAT_MENU[2].fn = editm
    makeAlphaMenu = partial makeAlphaMenu, alphaValues
    menuitem = menubars.new icon, .title, makemenu
    return

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  init: T 'table', init
}
