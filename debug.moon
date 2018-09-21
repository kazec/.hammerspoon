_G._DEBUG = true

import inspect from require 'inspect'
{ pack:vpack, map:vmap } = require 'vararg'

_G.I = (...) ->
  print vmap(inspect, ...)
  ...

p = require('moon').p
_G.P = (...) ->
  for i, v in vpack ...
    p v
  ...

_G.G = () =>
  _G.GI = @
  @

_G.L = require

_G.U = (modname) ->
  package.loaded[modname] = nil

_G.RL = (modname) ->
  package.loaded[modname] = nil
  require modname
