---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import setuservalue from debug
import partial from require 'fn'
{ new:Timer } = require 'hs.timer'
log = require('log').get 'hotcorners'
{ new:HotCorner } = require 'hotcorner'
import allScreens from require 'hs.screen'
import getObjectMetatable from require 'hs'
import ipairs, pairs, next, tostring from _G
{ new:ScreenWatcher } = require 'hs.screen.watcher'
{ sigcheck:T, :isfunction, :istable, :isstring } = require 'typecheck'
import unpack, first, indexof, ifilter, imap, keys, ieach, removek, join, merge from require 'fn.table'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

CORNER_WIDTH = 1.1 -- effectively same as setting to 1pt
CORNER_HEIGHT = 1.1
EDEGE_LENGTH = 100 -- to fit in Xcode's menubar
EDEGE_HEIGHT = 22 -- same as status bar's height

STANDARD_CORNER_POSITIONS =
  'top-left':     { x: 0, y: 0, w: CORNER_WIDTH, h: CORNER_HEIGHT }
  'top-right':    { x: -CORNER_WIDTH, y: 0, w: CORNER_WIDTH, h: CORNER_HEIGHT }
  'bottom-left':  { x: 0, y: -CORNER_HEIGHT, w: CORNER_WIDTH, h: CORNER_HEIGHT }
  'bottom-right': { x: -CORNER_WIDTH, y: -CORNER_HEIGHT, w: CORNER_WIDTH, h: CORNER_HEIGHT }
  'top-edge':     { cx: 0.5, y: 0, w: EDEGE_LENGTH, h: EDEGE_HEIGHT }
  'right-edge':   { x: -EDEGE_HEIGHT, cy: 0.5, w: EDEGE_HEIGHT, h: EDEGE_LENGTH }
  'bottom-edge':  { cx: 0.5, y: -EDEGE_HEIGHT, w: EDEGE_LENGTH, h: EDEGE_HEIGHT }
  'left-edge':    { x: 0, cy: 0.5, w: EDEGE_HEIGHT, h: EDEGE_LENGTH }

STANDARD_CORNERS = keys STANDARD_CORNER_POSITIONS

convertRelative = (value, max) ->
  if value > 1.0 then value
  elseif value >= 0 then value * max
  elseif value >= -1.0 then max + value * max
  else max + value

calcFrame = (position, screen) ->
  return position screen if isfunction position

  fullFrame = screen\fullFrame!
  with position
    localFrame =
      w: .w <= 1.0 and fullFrame.w * .w or .w
      h: .h <= 1.0 and fullFrame.h * .h or .h

    if .cx
      cx = convertRelative .cx, fullFrame.w
      localFrame.x = cx - localFrame.w / 2
    if .cy
      cy = convertRelative .cy, fullFrame.h
      localFrame.y = cy - localFrame.h / 2

    if .x
      localFrame.x = convertRelative .x, fullFrame.w
    if .y
      localFrame.y = convertRelative .y, fullFrame.h

    return screen\localToAbsolute localFrame

newWithActions = (frame, actions, setup) ->
  object = HotCorner frame

  if actions
    -- load raw actions
    mouseUp =  actions['mouse-up']
    object\mouseUpCallback mouseUp if mouseUp

    mouseDown = actions['mouse-down']
    object\mouseDownCallback mouseDown if mouseDown

    mouseEntered =  actions['mouse-entered']
    object\mouseEnteredCallback mouseEntered if mouseEntered

    mouseExited =  actions['mouse-exited']
    object\mouseExitedCallback mouseExited if mouseExited

    mouseClick = actions['mouse-click']
    object\mouseClickCallback mouseClick if mouseClick

    mouseHover = actions['mouse-hover']
    object\mouseHoverCallback mouseHover if mouseHover

    scrollWheel = actions['scroll-wheel']
    object\scrollWheelCallback scrollWheel if scrollWheel

    -- load shorthand bindings, which are stored in array part
    for _, action in ipairs actions
      object\bind unpack(action)

  setuservalue object, nil
  object\show!

  setup object if setup
  return object

newWithTemplate = (frame, template) ->
  object = HotCorner frame

  mouseUp = template\mouseUpCallback!
  mouseDown = template\mouseDownCallback!
  mouseEntered = template\mouseEnteredCallback!
  mouseExited = template\mouseExitedCallback!
  mouseClick = template\mouseClickCallback!
  mouseHover = template\mouseHoverCallback!
  scrollWheel = template\scrollWheelCallback!
  object\mouseUpCallback mouseUp if mouseUp
  object\mouseDownCallback mouseDown if mouseDown
  object\mouseEnteredCallback mouseEntered if mouseEntered
  object\mouseExitedCallback mouseExited if mouseExited
  object\mouseClickCallback mouseClick if mouseClick
  object\mouseHoverCallback mouseHover if mouseHover
  object\scrollWheelCallback scrollWheel if scrollWheel

  return object

reloadMultiple = (corner, screens) ->
  objects = corner.objects
  -- if corner has no objects before, create the first one
  if not objects
    objects = { newWithActions({}, corner.actions, corner.setup) }
    corner.objects = objects

  -- iterate through all screens
  for i, screen in ipairs screens
    -- calc the new frame
    newFrame = calcFrame corner.position, screen

    -- create if non-existent
    object = objects[i]
    if not object
      object = newWithTemplate newFrame, objects[1]
      objects[i] = object
      object\show!
    else -- reposition
      object\frame newFrame

  -- iterate through all unused objects
  for i = #screens + 1, #objects
    objects[i]\delete!
    objects[i] = nil

reload = (corner, screens) ->
  with corner
    -- corner with relative frame on one screen
    if .screen
      screenFound = first screens, () => @name! == .screen
      return unless screenFound

      -- calc the new frame
      newFrame = calcFrame .position, screenFound

      if not .object
        -- create if non-existent
        .object = newWithActions newFrame, .actions, .setup
      else
        -- repositioning
        .object\frame newFrame

    -- corner on multiple screens by their names
    elseif istable .screens
      screensFound = ifilter screens, () => indexof(.screens, @name!)
      reloadMultiple corner, screens if next screensFound

    -- corner on all screens
    elseif .screens
      -- reload on all screens
      reloadMultiple corner, screens

    -- corner with frame relative on the primary screen
    else
      newFrame = calcFrame .position, screens[1] -- primary screen is always the first one

      if not .object
        .object = newWithActions newFrame, .actions, .setup
      else
        .object\frame newFrame

    return

self =
  _debug: nil
  _corners: nil
  _screenwatcher: nil
  _screenDidChangeTimer: nil

loadAction = (event, action) ->
  modifiers = action.modifiers or false
  return switch event
    when 'left-click', 'right-click', 'double-click', 'scroll-wheel'
      { modifiers, event, action.fn or error("#{event} action's fn expect a function") }
    when 'mouse-hover'
      if action.interval
        { modifiers, event, { interval: action.interval, fn: action.fn or error("#{event} action's fn expect a function") } }
      elseif action.delay
        { modifiers, event, { delay: action.delay, fn: action.fn or error("#{event} action's fn expect a function") } }
      elseif action.sequences
        { modifiers, event, action.sequences }
      else
        { modifiers, event, action.fn or error("#{event} action's fn expect a function") }
    else error "Unrecognized event: #{event}"

loadActions = (actions) ->
  result = {}

  for event, action in pairs actions
    if isfunction action -- raw callback
      result[event] = action
    elseif action[1] -- action list
      join result, imap(action, partial(loadAction, event))
    else -- single action
      result[#result + 1] = loadAction event, action

  return result

loadCorners = (corners, defaultAllScreens) ->
  -- load custom corners
  for _, corner in ipairs corners
    corner.actions = loadActions corner.actions

  -- load standard corners
  for _, key in ipairs STANDARD_CORNERS
    if corner = corners[key]
      if not corner.actions
        corner = { actions: corner }

      corner.position = STANDARD_CORNER_POSITIONS[key]
      corner.actions = loadActions corner.actions
      corners[key] = nil
      corners[#corners + 1] = corner

  -- setup screen preferences
  for _, corner in ipairs corners
    if not corner.screen and corner.screens == nil -- not set explictly
      corner.screens = defaultAllScreens

  return corners

restart = () ->
  log.info 'Reloading all hotcorners...' if log.info

  screens = allScreens!
  for _, corner in ipairs @_corners
    reload corner, screens

  return unless @_debug

  color = istable(@_debug) and @_debug or { red: 1 }
  for _, corner in ipairs @_corners
    if corner.object
      corner.object\debugColor color
    elseif corner.objects
      for _, object in ipairs corner.objects
        object\debugColor color

init = (options) ->
  with options
    -- debug
    @_debug = .debug
    .debug = nil

    supportMultiDisplays = .supportMultiDisplays != false
    .supportMultiDisplays = nil
    -- setup watcher
    if supportMultiDisplays
      screenDidChangeDelay = .screenDidChangeDelay or 5
      .screenDidChangeDelay = nil
      @_screenDidChangeTimer = Timer 0, restart
      @_screenwatcher = ScreenWatcher () ->
        @_screenDidChangeTimer\setNextTrigger screenDidChangeDelay

    -- load corners
    @_corners = loadCorners options, supportMultiDisplays

    -- start
    restart!
    @_screenwatcher\start! if @_screenwatcher
    return

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'table', init
  :restart
}
