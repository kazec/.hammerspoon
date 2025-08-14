_G._DEBUG = true

import inspect from require 'inspect'
{ pack:vpack, map:vmap } = require 'vararg'

-- Debugging functions ----------------------------------------------------

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

-- Function tracing ------------------------------------------------------

-- Create a file to log the trace (e.g., "function_trace.log")
trace_file = io.open "#{os.getenv('HOME')}/Library/Logs/org.hammerspoon.trace.log", "w"
indent_level = 0

-- Define the hook function
trace_hook = (event, line) ->
  info = debug.getinfo 2, "nS" -- Get info about the calling function (level 2)

  -- Filter out C functions or internal debug library calls if desired
  if info.what == "C" or info.short_src == '[string "debug"]'
    return

  if event == "call"
    indent_level += 1
    func_name = info.name or "anonymous"
    source_info = "#{info.short_src}:#{info.linedefined}"
    prefix = string.rep "  ", indent_level
    trace_file\write "#{prefix}CALL: #{func_name} (#{source_info})\n"
  elseif event == "return" or event == "tail return"
    func_name = info.name or "anonymous"
    source_info = "#{info.short_src}:#{info.linedefined}"
    prefix = string.rep "  ", indent_level
    trace_file\write "#{prefix}RETURN: #{func_name} (#{source_info})\n"
    indent_level -= 1

-- Set the hook for "call", "return", and "tail return" events
debug.sethook trace_hook, "crl"
