---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

log = require('log').get 'menubars'
import partial, once from require 'fn'
{ new:MenuBarItem } = require 'hs.menubar'
import imageFromName from require 'hs.image'
import ipairs, setmetatable, require from _G
{ sigcheck:T, :isfunction, :isnumber } = require 'typecheck'
import ieach, ieachr, indexof, merge, any, join from require 'fn.table'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

self =
  _items: nil
  _mainItem: nil
  _submods: nil
  _submnames: nil
  _defaultIcon: imageFromName('statusicon')\setSize({ w: 17, h: 17})

newMenuItem = T '?hs.image|string, ?string, ?table|function, ?function', (icon, title, menu, fn) ->
  item = {
    :title, image: icon, :menu, :fn
    setIcon: (icon) => @icon = icon
    setTitle: (title) => @title = title
  }
  @_items = {} unless @_items
  @_items[#@_items + 1] = item
  return item

newBarItem = T '?hs.image|string, ?string, ?table|function, ?function', (icon, title, menu, fn) ->
  with MenuBarItem!
    \setIcon icon if icon
    \setTitle title if title
    \setMenu menu if menu
    \setClickCallback fn if fn

makeMenu = (items, flatten, mods) ->
  main = {}
  for i, item in ipairs items
    menu = item.menu
    menu = menu mods if isfunction menu
    if flatten == true or
      (isfunction(flatten) and flatten(menu)) or
      (isnumber(flatten) and flatten >= #menu)
        join main, menu
    else
      main[#main + 1] =
        title: item.title
        icon: item.icon
        :menu
    main[#main + 1] = title: '-' unless i == #items
  return main

init = (submods, options) ->
  with options
    mainItems = nil
    if main = .main
      @_mainItem =
        title: main.title
        icon: main.icon or @_defaultIcon
        flatten: main.flatten != false
      mainItems = main.items
      main.items = nil
    -- load submodules.
    @_submods = submods
    for _, modname in ipairs submods
      @new = mainItems and indexof(mainItems, modname) and newMenuItem or newBarItem
      mod = require "menubars.#{modname}"
      log.errorf 'Unable to load submodule: %s', modname unless mod
      mod.init options[modname]
      @[modname] = mod
    @new = nil

  return unless @_items
  -- create menubar item optionally.
  @_mainItem = with MenuBarItem!
    \setIcon @_mainItem.icon
    \setTitle @_mainItem.title if @_mainItem.title
    \setMenu partial makeMenu, @_items, @_mainItem.flatten

start = () -> ieach @_submods, (n) -> @[n].start! if @[n].start
stop = () -> ieachr @_submods, (n) -> @[n].stop! if @[n].stop

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  init: T 'table, table', once(init)
  :start, :stop
}
