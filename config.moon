-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

hs, fn, sh, sys, R, C, daemon, ds4irc = require('vararg').map(require, 'hs', 'fn', 'shell', 'system', 'assets', 'colors', 'daemon', 'ds4irc')

{ execute:exec } = os
import execute from sh
import partial from fn
import load from daemon
import bind from require 'hs.hotkey'
import window, itunes, mouse from hs
import doAfter, usleep from require 'hs.timer'
import windowBehaviors from require 'hs.drawing'
import launchOrFocusByBundleID from require 'hs.application'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

log = load 'log'

local *

console = load 'console',
  titleVisible: false
  toggleHotKey: { '⌃+⇧', 'z' }
  behavior: windowBehaviors.canJoinAllSpaces
  themes:
    'Solarized Light':
      darkmode: false
      font: { name: 'SF Mono Light', size: '14' }
      colors:
        print: C['Solarized']['Cyan']
        command: C['Solarized']['Base01']
        result: C['Solarized']['Red']
        inputBackground: C['Solarized']['Base3']
        outputBackground: C['Solarized']['Base3']
        windowBackground: C['Solarized']['Base3']
    'Solarized Dark':
      darkmode: true
      font: { name: 'SF Mono Light', size: '14' }
      colors:
        print: C['Solarized']['Green']
        command: C['Solarized']['Cyan']
        result: C['Solarized']['Red']
        inputBackground: C['Solarized']['Base03']
        outputBackground: C['Solarized']['Base03']
        windowBackground: C['Solarized']['Base03']
    'One Light':
      darkmode: false
      font: { name: 'SF Mono Light', size: '14' }
      colors:
        print: C['One Light']['FG']
        command: C['One Light']['Hue 5']
        result: C['One Light']['Hue 1']
        inputBackground: C['One Light']['BG']
        outputBackground: C['One Light']['BG']
        windowBackground: C['One Light']['BG']
    'One Dark':
      darkmode: true
      font: { name: 'SF Mono Light', size: '14' }
      colors:
        print: C['One Dark']['Hue 6-2']
        command: C['One Dark']['Hue 5']
        result: C['One Dark']['Hue 1']
        inputBackground: C['One Dark']['BG']
        outputBackground: C['One Dark']['BG']
        windowBackground: C['One Dark']['BG']
  toolbar:
    name: 'Console Toolbar'
    items: {
      { id: "NSToolbarFlexibleSpaceItem" }
      { id: "Reload", image: R('reload.png'), tooltip: 'Reload Hammerspoon', fn: hs.reload }
      { id: "History", image: R('history.png'), tooltip: 'Show Logging History', fn: () -> log.print! }
      { id: "Top", image: R('ontop.png'), tooltip: 'Always On Top', fn: () -> console.alwaysOnTop(not console.alwaysOnTop!) }
      { id: "List Daemons", image: R('list.png'), tooltip: 'List Running Services', fn: () -> print(daemon.status! .. '\n') }
      { id: "NSToolbarSpaceItem", default: false }
    }
    setup:
      canCustomize: true
      displayMode: 'icon'
      sizeMode: 'regular'
  autocompletion: { ['hs']: hs, ['sh']: sh, ['fn']: fn, ['fn.table']: fn.table }

autoproxy = load 'autoproxy',
  config: R['autoproxy-config.moon']
  minify: true
  server:
    interface: 'localhost'
    port: 8000

urlevent = load 'urlevent',
  router: {
    {
      dest: 'com.google.Chrome'
      host: { 'youtube.com', 'douyu.com', 'panda.tv', 'huomao.com', 'v2ex.com', 'weibo.com' }
    },
    {
      -- Replace 'http(s)://' with 'macappstores://' to open in Mac App Store directly.
      match: (host, params, url) ->
        return host == 'itunes.apple.com' and params['mt'] == '12'
      dest: (host, params, url) ->
        url = url\gsub 'https?://(.+)', 'macappstores://%1'
        return execute 'open', url
    },
    {
      dest: 'com.apple.Safari'
    }
  },
  callbacks:
    'reload': hs.reload

window = load 'window', () =>
  -- cycle ordered windows
  bind '', 'f19', partial(@cycle, 3)
  -- animation disabled zoom
  bind '', 'f18', partial(@zoom, 0.75)
  -- center, maximize, left/right half
  bind '', 'f20', partial(@focused, @layout.center)
  bind '⇧', 'f15', partial(@focused, @layout.maximize)
  bind '', 'f16', partial(@focused, partial(@layout.normalized, 0.0, 0.0, 0.5, 1.0))
  bind '', 'f17', partial(@focused, partial(@layout.normalized, 0.5, 0.0, 0.5, 1.0))
  -- switch focused window between screens
  bind '', 'f13', partial(@screen.focused, true)
  -- switch focused window between spaces
  bind '⌥', 'f16', partial(@space.focused, false)
  bind '⌥', 'f17', partial(@space.focused, true)
  bind '⌥+⇧', 'f1', partial(@space.focused, 1)
  bind '⌥+⇧', 'f2', partial(@space.focused, 2)
  bind '⌥+⇧', 'f3', partial(@space.focused, 3)
  bind '⌥+⇧', 'f4', partial(@space.focused, 4)
  bind '⌥+⇧', 'f5', partial(@space.focused, 5)
  bind '⌥+⇧', 'f6', partial(@space.focused, 6)
  bind '⌥+⇧', 'f7', partial(@space.focused, 7)
  bind '⌥+⇧', 'f8', partial(@space.focused, 8)
  -- snap and resize focused window to prefined grids
  bind '⇧', 'f14', partial(@focused, partial(@layout.snap, {
    0.10, 0.10, 0.80, 0.80     -- center 80%
    0.15, 0.15, 0.70, 0.70     -- center 70%
    0.20, 0.20, 0.60, 0.60     -- center 60%
    0.25, 0.25, 0.50, 0.50     -- center 50%
    0.30, 0.30, 0.40, 0.40 })) -- center 40%
  bind '⇧', 'f1', partial(@focused, partial(@layout.snap, {
    0.00, 0.00, 0.70, 1.00     -- left 70%
    0.00, 0.00, 0.60, 1.00     -- left 60%
    0.00, 0.00, 0.50, 1.00     -- left 50%
    0.00, 0.00, 0.40, 1.00     -- left 40%
    0.00, 0.00, 0.30, 1.00 })) -- left 30%
  bind '⇧', 'f2', partial(@focused, partial(@layout.snap, {
    0.30, 0.00, 0.70, 1.00     -- right 70%
    0.40, 0.00, 0.60, 1.00     -- right 60%
    0.50, 0.00, 0.50, 1.00     -- right 50%
    0.60, 0.00, 0.40, 1.00     -- right 40%
    0.70, 0.00, 0.30, 1.00 })) -- right 30%
  bind '⇧', 'f3', partial(@focused, partial(@layout.snap, {
    0.00, 0.00, 0.50, 0.50     -- top left 25%
    0.50, 0.00, 0.50, 0.50     -- top right 25%
    0.50, 0.50, 0.50, 0.50     -- bottom right 25%
    0.00, 0.50, 0.50, 0.50 })) -- bottom left 25%
  bind '⇧', 'f4', partial(@focused, partial(@layout.snap, {
    0.00, 0.50, 0.50, 0.50     -- bottom left 25%
    0.50, 0.50, 0.50, 0.50     -- bottom right 25%
    0.50, 0.00, 0.50, 0.50     -- top right 25%
    0.00, 0.00, 0.50, 0.50 })) -- top left 25%
  -- move/extend window
  bind '⇧+⌃+⌥', 'w'    , partial(@focused, partial(@layout.move  , 01, 00))
  bind '⇧+⌃+⌥', 'd'    , partial(@focused, partial(@layout.move  , 00, -1))
  bind '⇧+⌃+⌥', 's'    , partial(@focused, partial(@layout.move  , -1, 00))
  bind '⇧+⌃+⌥', 'a'    , partial(@focused, partial(@layout.move  , 00, 01))
  bind '⇧+⌃+⌥', 'up'   , partial(@focused, partial(@layout.extend, 01, 00))
  bind '⇧+⌃+⌥', 'right', partial(@focused, partial(@layout.extend, 00, -1))
  bind '⇧+⌃+⌥', 'down' , partial(@focused, partial(@layout.extend, -1, 00))
  bind '⇧+⌃+⌥', 'left' , partial(@focused, partial(@layout.extend, 00, 01))

hotcorners = load 'hotcorners',
  debug: false
  supportMultiDisplays: true
  screenDidChangeDelay: 5
  'top-edge':
    'double-click': {
      { modifiers: '⌘', fn: sys.darkmode.toggle }
      { modifiers: '⌥', fn: sys.finder.toggleHidden }
    }
  'bottom-left':
    'mouse-hover': {
      { modifiers: 'fn', fn: sys.sleep }
      { modifiers: '⌃', fn: sys.display.sleep }
      { modifiers: '⌃+⌥', fn: sys.display.lock }
      { modifiers: 0, delay: 5, fn: sys.screensaver }
    }
    'left-click': {
      { modifiers: 0, fn: partial console.toggle, false }
    }
    'double-click': {
      { modifiers: '⌘', fn: partial ds4irc.start, '192.168.1.202', 4950 }
      { modifiers: 0, fn: hs.reload }
    }
    'right-click': {
      { modifiers: 'fn', fn: sys.logout }
      { modifiers: '⌃', fn: sys.shutdown }
      { modifiers: '⌃+⌥', fn: sys.restart }
    }
  'bottom-right':
    'mouse-hover': {
      { modifiers: '⌘', fn: itunes.playpause }
      { modifiers: '⌘', interval: 5, fn: itunes.next }
    }
    'left-click': {
      { modifiers: 0, fn: itunes.next }
      { modifiers: '⌥', fn: itunes.volumeDown }
      { modifiers: '⌥+⇧', fn: itunes.volumeUp }
    }
    'right-click': {
      { modifiers: 0, fn: itunes.previous }
      { modifiers: '⌥', fn: sys.itunes.currentTrack }
    }
    'scroll-wheel': {
      {
        modifiers: 0, fn: (_, _, deltaY) ->
          itunes.setVolume(itunes.getVolume! + (deltaY < 0 and 1 or -1)) if deltaY != 0
      }
    }

menubars = load 'menubars', { 'autoproxy', 'caffeinate', 'volume', 'hammerspoon' }, {
  main:
    flatten: true
    items: { 'volume', 'hammerspoon' }
  autoproxy:
    icons:
      on:     R 'autoproxy-unknown.png', { w: 22, h: 20 }
      off:    R 'autoproxy-off.png',     { w: 22, h: 20 }
      auto:   R 'autoproxy-on.png',      { w: 22, h: 20 }
      direct: R 'autoproxy-direct.png',  { w: 22, h: 20 }
      proxy:  R 'autoproxy-proxy.png',   { w: 22, h: 20 }
    shortcuts: {
      { modifiers: { '⌥' }, toggle: true }
      { modifiers: { '⌃', '⇧' }, profile: 'proxy' }
      { modifiers: { '⌃' }, profile: 'auto' }
      { modifiers: { '⇧' }, profile: 'direct' }
    }
  caffeinate:
    toggle: 45
    notifyOnCompletion: true
    durations: { -1, 10, 30, 60, 120, 180, 240, 300 }
    icons:
      on:  R 'caffeinate-on.png',  { w: 22, h: 20 }
      off: R 'caffeinate-off.png', { w: 22, h: 20 }
  volume:
    icon: R '/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarRemovableDisk.icns', { w: 18, h: 16 }
    showVolumeDetails: true
  hammerspoon:
    configEditor: '/usr/local/bin/atom'
    consoleAlphaValues: { 0.25, 0.50, 0.75, 1.00 }
}

watchers: load 'watchers', { 'config', 'wifi', 'usb' },
  config: { '/Spoons' , '/assets/', '/ext/', '/%.DS_Store', '/%.git' }
  wifi:
    'Uncosmos':
      connected: partial exec, [[
        cd $HOME/.config/v2ray && ln -sf private.json config.json && \
        cd $HOME/Library/LaunchAgents && launchctl unload org.v2ray.plist && launchctl load org.v2ray.plist
      ]]
      disconnected: partial exec, [[
        cd $HOME/.config/v2ray && ln -sf public.json config.json && \
        cd $HOME/Library/LaunchAgents && launchctl unload org.v2ray.plist && launchctl load org.v2ray.plist
      ]]
  usb:
    'Poker':
      connected: partial exec, [[
        /usr/local/bin/karabiner_cli --select-profile 'Poker'
      ]]
      disconnected: partial exec, [[
        /usr/local/bin/karabiner_cli --select-profile 'AIK'
      ]]
    'Wireless Controller':
      connected: () -> -- some delay is needed
        usleep(100000)
        ds4irc.start '192.168.1.202', 4950
      disconnected: ds4irc.stop

return fn.table.merge { :fn, :sh, :sys, :R, :C, :daemon, :ds4irc }, daemon.modules!
