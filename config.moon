-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

hs, fn, sh, sys, R, C, daemon, ds4irc = require('vararg').map(require, 'hs', 'fn', 'shell', 'system', 'assets', 'colors', 'daemon', 'ds4irc')

{ execute:exec } = os
import execute from sh
import partial from fn
import load from daemon
import bind from require 'hs.hotkey'
import window, mouse from hs
import doAfter, usleep from require 'hs.timer'
import windowBehaviors from require 'hs.drawing'
import defaultOutputDevice from require 'hs.audiodevice'
import launchOrFocusByBundleID from require 'hs.application'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

log = load 'log'

local *

console = load 'console',
  titleVisible: false
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
      { id: "Shown History", image: R('history.png'), tooltip: 'Show Logging History', fn: () -> log.print! }
      { id: "Open History", image: R('log.png'), tooltip: 'Open Log File', fn: log.openhistory }
      { id: "Top", image: R('ontop.png'), tooltip: 'Always On Top', fn: () -> console.alwaysOnTop(not console.alwaysOnTop!) }
      { id: "List Daemons", image: R('list.png'), tooltip: 'List Running Services', fn: () -> print(daemon.status! .. '\n') }
      { id: "NSToolbarSpaceItem", default: false }
    }
    setup:
      canCustomize: true
      displayMode: 'icon'
      sizeMode: 'regular'
  autocompletion: { ['hs']: hs, ['sh']: sh, ['fn']: fn, ['fn.table']: fn.table }

-- autoproxy = load 'autoproxy',
--   config: R['autoproxy-config.moon']
--   minify: true
--   server:
--     interface: 'localhost'
--     port: 8000

window = load 'window', () =>
  -- f13, mapped to tab
  -- switch focused window between screens
  bind '', 'f13', partial(@screen.focused, true)

  -- f19, mapped to x
  -- center focused window
  bind '', 'f19', partial(@focused, @layout.center)

  -- f14, mapped to esc
  -- animation disabled zoom
  bind '⌥', 'f14', partial(@zoom, 0.75)
  -- snap and resize focused window to prefined grids
  bind '⇧', 'f14', partial(@focused, partial(@layout.snap, {
    0.10, 0.10, 0.80, 0.80     -- center 80%
    0.15, 0.15, 0.70, 0.70     -- center 70%
    0.20, 0.20, 0.60, 0.60     -- center 60%
    0.25, 0.25, 0.50, 0.50     -- center 50%
    0.30, 0.30, 0.40, 0.40 })) -- center 40%

  -- maximize focused window
  bind '⇧', 'f15', partial(@focused, @layout.maximize)

  -- cycle ordered windows
  bind '⌥', 'f19', partial(@cycle, 3)
  
  -- bind '', 'f16', partial(@focused, partial(@layout.normalized, 0.0, 0.0, 0.5, 1.0))
  -- bind '', 'f17', partial(@focused, partial(@layout.normalized, 0.5, 0.0, 0.5, 1.0))
  -- switch focused window between spaces
  -- bind '⌥', 'f16', partial(@space.focused, false)
  -- bind '⌥', 'f17', partial(@space.focused, true)
  -- bind '⌥+⇧', 'f1', partial(@space.focused, 1)
  -- bind '⌥+⇧', 'f2', partial(@space.focused, 2)
  -- bind '⌥+⇧', 'f3', partial(@space.focused, 3)
  -- bind '⌥+⇧', 'f4', partial(@space.focused, 4)
  -- bind '⌥+⇧', 'f5', partial(@space.focused, 5)
  -- bind '⌥+⇧', 'f6', partial(@space.focused, 6)
  -- bind '⌥+⇧', 'f7', partial(@space.focused, 7)
  -- bind '⌥+⇧', 'f8', partial(@space.focused, 8)

  bind '', 'f16', partial(@focused, partial(@layout.snap, {
    0.00, 0.00, 0.70, 1.00     -- left 70%
    0.00, 0.00, 0.60, 1.00     -- left 60%
    0.00, 0.00, 0.50, 1.00     -- left 50
    0.00, 0.00, 0.40, 1.00     -- left 40%
    0.00, 0.00, 0.30, 1.00 })) -- left 30%
  bind '', 'f17', partial(@focused, partial(@layout.snap, {
    0.30, 0.00, 0.70, 1.00     -- right 70%
    0.40, 0.00, 0.60, 1.00     -- right 60%
    0.50, 0.00, 0.50, 1.00     -- right 50%
    0.60, 0.00, 0.40, 1.00     -- right 40%
    0.70, 0.00, 0.30, 1.00 })) -- right 30%
  bind '', 'f18', partial(@focused, partial(@layout.snap, {
    0.00, 0.00, 1.00, 0.70     -- top 70%
    0.00, 0.00, 1.00, 0.60     -- top 60%
    0.00, 0.00, 1.00, 0.50     -- top 50%
    0.00, 0.00, 1.00, 0.40     -- top 40%
    0.00, 0.00, 1.00, 0.30 })) -- top 30%
  bind '', 'f20', partial(@focused, partial(@layout.snap, {
    0.00, 0.30, 1.00, 0.70     -- bottom 70%
    0.00, 0.40, 1.00, 0.60     -- bottom 60%
    0.00, 0.50, 1.00, 0.50     -- bottom 50%
    0.00, 0.60, 1.00, 0.40     -- bottom 40%
    0.00, 0.70, 1.00, 0.30 })) -- bottom 30%
  -- move/extend window
  bind '⇧+⌃+⌥', 'w'    , partial(@focused, partial(@layout.move  , 01, 00))
  bind '⇧+⌃+⌥', 'd'    , partial(@focused, partial(@layout.move  , 00, -1))
  bind '⇧+⌃+⌥', 's'    , partial(@focused, partial(@layout.move  , -1, 00))
  bind '⇧+⌃+⌥', 'a'    , partial(@focused, partial(@layout.move  , 00, 01))
  -- bind '⇧+⌃+⌥', 'up'   , partial(@focused, partial(@layout.extend, 01, 00))
  -- bind '⇧+⌃+⌥', 'right', partial(@focused, partial(@layout.extend, 00, -1))
  -- bind '⇧+⌃+⌥', 'down' , partial(@focused, partial(@layout.extend, -1, 00))
  -- bind '⇧+⌃+⌥', 'left' , partial(@focused, partial(@layout.extend, 00, 01))

urlevent = load 'urlevent',
  -- router: {
  --   {
  --     dest: 'com.microsoft.edgemac'
  --     host: { 'youtube.com', 'douyu.com', 'panda.tv', 'huomao.com', 'v2ex.com', 'weibo.com', 'bilibili.com' }
  --   },
  --   {
  --     -- Replace 'http(s)://' with 'macappstores://' to open in Mac App Store directly.
  --     match: (host, params, url) ->
  --       return host == 'itunes.apple.com' and params['mt'] == '12'
  --     dest: (host, params, url) ->
  --       url = url\gsub 'https?://(.+)', 'macappstores://%1'
  --       return execute 'open', url
  --   },
  --   {
  --     dest: 'com.apple.Safari'
  --   }
  -- },
  callbacks:
    'reload': hs.reload,
    'toggle_app': (_, args) -> window.toggle args['id']

pressSystemKey = (code) ->
  hs.eventtap.event.newSystemKeyEvent(code, true)\post!
  hs.eventtap.event.newSystemKeyEvent(code, false)\post!

hotcorners = load 'hotcorners',
  debug: false
  supportMultiDisplays: true
  screenDidChangeDelay: 5
  'bottom-edge':
    'double-click': {
      { modifiers: '⌘', fn: sys.darkmode.toggle }
      { modifiers: '⌥', fn: sys.finder.toggleHidden }
    }
  'bottom-left':
    'mouse-hover': {
      { modifiers: 'fn', fn: () -> doAfter 1, sys.sleep }
      { modifiers: '⌃', fn: sys.display.sleep }
      { modifiers: '⌃+⌥', fn: sys.display.lock }
      { modifiers: 0, delay: 5, fn: sys.screensaver }
    }
    'left-click': {
      { modifiers: 0, fn: partial console.toggle, false }
    }
    'double-click': {
      -- { modifiers: '⌘', fn: partial ds4irc.start, '192.168.1.202', 4950 }
      { modifiers: 0, fn: hs.reload }
    }
    'right-click': {
      { modifiers: 'fn', fn: sys.logout }
      { modifiers: '⌃', fn: sys.shutdown }
      { modifiers: '⌃+⌥', fn: sys.restart }
    }
  'bottom-right':
    'mouse-hover': {
      { modifiers: '⌘', fn: partial pressSystemKey, 'PLAY' }
      { modifiers: '⌘', interval: 5, fn: partial pressSystemKey, 'NEXT' }
    }
    'left-click': {
      { modifiers: 0, fn: partial pressSystemKey, 'NEXT' }
      { modifiers: '⌥', fn: partial pressSystemKey, 'SOUND_DOWN' }
      { modifiers: '⌥+⇧', fn: partial pressSystemKey, 'SOUND_UP' }
    }
    'right-click': {
      { modifiers: 0, fn: partial pressSystemKey, 'PREVIOUS' }
    }
    'scroll-wheel': {
      {
        modifiers: 0, fn: (_, _, deltaY) ->
          audioDevice = defaultOutputDevice!
          if audioDevice and deltaY != 0
            volume = audioDevice\outputVolume!
            audioDevice\setOutputVolume(volume + (deltaY < 0 and 1 or -1))
      }
    }
  'bottom-right':
    'mouse-hover': {
      { modifiers: 'fn', fn: () -> doAfter 1, sys.sleep }
      { modifiers: '⌃', fn: sys.display.lock }
      { modifiers: '⌃+⌥', fn: sys.display.sleep }
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
  

menubars = load 'menubars', { 'caffeinate', 'volume', 'hammerspoon' }, {
  main:
    flatten: true
    items: { 'volume', 'hammerspoon' }
  -- autoproxy:
  --   icons:
  --     on:     R 'autoproxy-unknown.png', { w: 22, h: 20 }
  --     off:    R 'autoproxy-off.png',     { w: 22, h: 20 }
  --     auto:   R 'autoproxy-on.png',      { w: 22, h: 20 }
  --     direct: R 'autoproxy-direct.png',  { w: 22, h: 20 }
  --     proxy:  R 'autoproxy-proxy.png',   { w: 22, h: 20 }
  --   shortcuts: {
  --     { modifiers: { '⌥' }, toggle: true }
  --     { modifiers: { '⌃', '⇧' }, profile: 'proxy' }
  --     { modifiers: { '⌃' }, profile: 'auto' }
  --     { modifiers: { '⇧' }, profile: 'direct' }
  --   }
  caffeinate:
    toggle: 45
    notifyOnCompletion: true
    durations: {
      -1,
      "One 🍅": 25,
      "One Big 🍅": 50,
      "One Mega 🍅": 90
    }
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

notesTimer = nil

watchers: load 'watchers', { 'config', 'app', 'usb' },
  config: { '/Spoons' , '/assets/', '/ext/', '/%.DS_Store', '/%.git' }
  app:
    'com.apple.Notes':
      activated: () ->
        notesTimer\stop! if notesTimer
        notesTimer = nil
        -- open ProNotes if Notes is activated
        id = 'com.dexterleng.ProNotes' 
        hs.application.open id unless hs.application.get id
      deactivated: (app) ->
        -- close ProNotes if Notes is deactivated after 60 seconds
        notesTimer = doAfter 60, () ->
          if not app or not app\isFrontmost!
            pronotes = hs.application.get 'com.dexterleng.ProNotes'
            pronotes\kill! if pronotes
  -- wifi:
  usb:
    'Poker':
      connected: partial exec, [[
        /usr/local/bin/karabiner_cli --select-profile 'Poker'
      ]]
      disconnected: partial exec, [[
        /usr/local/bin/karabiner_cli --select-profile 'AIK'
      ]]
    'Poker II':
      connected: partial exec, [[
        /usr/local/bin/karabiner_cli --select-profile 'Poker'
      ]]
      disconnected: partial exec, [[
        /usr/local/bin/karabiner_cli --select-profile 'AIK'
      ]]
    -- 'Wireless Controller':
    --   connected: () -> -- some delay is needed
    --     usleep(100000)
    --     ds4irc.start '192.168.1.202', 4950
    --   disconnected: ds4irc.stop

return fn.table.merge { :fn, :sh, :sys, :R, :C, :daemon, :ds4irc }, daemon.modules!
