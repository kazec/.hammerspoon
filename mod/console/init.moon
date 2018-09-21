---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

hs = require 'hs'
import tostring from _G
import find from string
colors = require 'colors'
{ :rect } = require 'hs.geometry'
log = require('log').get 'console'
import leftClick from require 'hs.eventtap'
import focusedWindow from require 'hs.window'
{ new:Toolbar } = require 'hs.webview.toolbar'
import partial, partialr, once from require 'fn'
import styledtext, console, settings, hotkey, application from hs
{ :istable, :ishex, :isfunction, sigcheck:T } = require 'typecheck'
import copy, sort, join, merge, reduce, eachk from require 'fn.table'
import getAbsolutePosition, setAbsolutePosition from require 'hs.mouse'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

self = merge {
  theme: nil
  completions: nil
}, console

printc = (color, v) ->
  color = if istable color then color
  elseif ishex color then colors.hex color
  else colors.name color

  console.print styledtext.new(tostring v, {
    :color,
    font: console.consoleFont()
  })

buildcompletions = (modpairs) ->
  result = {}
  for n, m in pairs modpairs
    for k, v in pairs m
      comp = result[k]
      newcomp = n .. '.' .. (isfunction(v) and k .. '()' or k)
      if comp
        comp[#comp + 1] = newcomp
        result[k] = comp
      else result[k] = { newcomp }
  return result

autocomplete = (kw, completions, handler) ->
  result = {}
  for k, t in pairs completions
    join result, t if k\find kw, nil, true

  default = handler kw
  switch #result
    when 1 then default
    when 1
      if #default == 0
        result[#result + 1] = 'dummy'
        result
      else
        default[#default + 1] = result[1]
        default
    else
      sort(result)
      join default, result

init = (options) ->
  with options
    -- Window behavior
    if .behavior
      @.behavior .behavior
    -- Toggle hot key
    if .toggleHotKey
      @_hotkey = hotkey.bind .toggleHotKey[1], .toggleHotKey[2], @toggle
    if not .titleVisible
      @.titleVisibility 'hidden'
    -- initialize theme.
    if .themes
      theme = require 'console.theme'
      current = .themes.current
      if current then .themes.current = nil
      elseif saved = settings.get 'console.theme'
        current = saved if .themes[saved]
      theme.init(.themes, current)
      @theme = theme
    -- initialize toolbar.
    if .toolbar
      toolbar = Toolbar .toolbar.name, .toolbar.items
      if globalCallback = .toolbar.callback
        toolbar\setCallback globalCallback
      if setup = .toolbar.setup
        eachk setup, (k, v) -> toolbar[k] toolbar, v
      @.toolbar toolbar
    -- build auto-completion handler.
    if .autocompletion
      completions = buildcompletions .autocompletion
      _completion = hs.completionsForInputString
      hs.completionsForInputString = partialr autocomplete, completions, _completion
      @_completions = completions
      log.debugf 'Auto-completion table built with %d entries.', reduce(completions, 0, (r, t) -> r + #t) if log.debug
  -- apply saved settings.
  alpha = settings.get 'console.alpha'
  @.alpha alpha if alpha != nil

  frame = settings.get 'console.frame'
  if frame and settings.get 'hs.reloaded'
    @.open!
    if window = @.hswindow!
      log.debug 'Restoring to previous window frame : ' .. tostring(frame) if log.debug
      window\setFrame rect frame._x, frame._y, frame._w, frame._h

stop = () ->
  settings.set 'console.alpha', @.alpha!
  settings.set 'console.theme', @.theme.get! if @.theme
  if window = @.hswindow! then settings.set 'console.frame', window\frame!

toggle = (focusTextField) ->
  win = @.window!

  if win
    win\close!
  else
    @.open!
    if focusTextField
      win = @.window!
      mousePosition = getAbsolutePosition!
      frame = win\frame!
      leftClick { x: frame._x + frame._w - 30, y: frame._y + frame._h - 30 }
      setAbsolutePosition mousePosition

  return

window = () -> application.get('org.hammerspoon.Hammerspoon')\findWindow('Hammerspoon Console')

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  printc: T 'color, any', printc
  init: T 'table', once(init)
  toggle: T '?boolean', toggle
  :stop, :window
  -- rename
  open: hs.openConsole
  hswindow: window
  alwaysOnTop: hs.consoleOnTop
  setContent: console.setConsole,
  getContent: console.getConsole
}
