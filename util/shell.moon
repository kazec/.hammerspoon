---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import popen from io
import find, gsub from string
import tostring, ipairs from _G

{ execute:exec } = os
{ :istable, sigcheck:T } = require 'typecheck'
{ :pack, concat:tconcat, :imap } = require 'fn.table'

log = require('log').get 'shell'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

escape = (str) ->
  if find str, '[^a-zA-Z0-9,._+:@%/-]'
    "'#{gsub(str, "'", "'\\''")}'"
  else str

concat = (...) ->
  first = ...
  args = istable(first) and first or {...}
  return tconcat imap(args, escape), ' '

run = (...) ->
  args = {...}
  cmd = #args == 1 and args[1] or concat args
  log.tracef 'Running shell command:\n %s', cmd if log.tracef
  handle = popen cmd
  output = handle\read '*a'
  success, status, code = handle\close!
  log.tracef 'Result: %s, %s, %d', output, status, code if log.tracef
  return success and output or nil, status, code if success

execute = (...) ->
  args = {...}
  cmd = #args == 1 and args[1] or concat args
  log.tracef 'Executing shell command:\n %s', cmd if log.tracef
  return exec cmd

script_path = () -> debug.getinfo(2, "S").source\sub(2)\match("(.*/)")

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  escape:  T 'string', escape
  -- Escape and concatenate the arguments specified as in the shell environment.
  concat:  T 'string|table, string...', concat
  -- Run a list of commands/arguments using 'io.popen', the stdout will be returned as the first value, followed by other
  -- values returned by 'io.close'.
  run:     T 'string, string...', run
  -- Execute a list of commands/arguments using 'os.execute'.
  execute: T 'string, string...', execute
  -- Get current script file path
  script_path: script_path
}
