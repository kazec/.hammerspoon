---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import date from os
import open, close from io
import once from require 'fn'
{ map:vmap } = require 'vararg'
import inspect from require 'inspect'
import format, upper, find from string
import ieach, each, imap, merge from require 'fn.table'
import error, getmetatable, tostring, pairs, rawget from _G
{ :isstring, :istable, :isnumber, :checkers, sigcheck:T } = require 'typecheck'
styledtext, ipc, console = vmap require, 'hs.styledtext', 'hs.ipc', 'hs.console'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

LEVEL_KEYS = { 'trace', 'debug', 'info', 'warn', 'error' }
LEVELS = { 'trace': 1, 'debug': 2, 'info': 3, 'warn': 4, 'error': 5 }
LEVELS_WF = merge { "#{k}f", v for k, v in pairs LEVELS }, LEVELS
MIN_LEVEL, MAX_LEVEL, ERROR_LEVEL = LEVELS['trace'], LEVELS['error'], LEVELS['error']

CONSOLE_COLORS = imap({ '#6a7c81', '#359774', '#009cc7', '#db7c00', '#ff2424', '#d10000' }, (h) -> { hex: h })
CLI_COLORS = { '\27[38;5;15m', '\27[38;5;35m', '\27[38;5;33m', '\27[38;5;3m', '\27[38;5;1m', '\27[38;5;9m' }

LOG_FMT = '\n%s - [%s] <%s> : %s'
LOG_FMTF = '\n%s - [%s] <%s> : '
DATE_FMT = '%Y-%m-%d %H:%M:%S'
INSPECT_OPTIONS =
  depth: 2

HIST_SIZE_LIMIT = 1000
HIST_FILE_SIZE = 2 * 1024 * 1024

checkers['log.level'] = (v) -> LEVELS[v] != nil

_lvl = _DEBUG and LEVELS['trace'] or LEVELS['info']
_tohistlvl = nil
_tocli = false
_toconsole = true

loggers = {}
history = {}
histfile = nil
histfpath = nil

openhistory = () -> hs.open histfpath if histfpath

log2console = (lvl, msg) ->
  console.printStyledtext(styledtext.new(msg, {
    color: CONSOLE_COLORS[lvl],
    font:  console.consoleFont!
  }))

-- Print log message to remote ipc client if present.
-- From https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/ipc/init.lua#L363
log2cli = (lvl, msg) ->
  msg = "\n#{CLI_COLORS[lvl]}#{msg}"
  for k,v in pairs ipc.__registeredCLIInstances do
    v.print msg if v._cli.console and v.print and not v._cli.quietMode

log2both = (lvl, msg) ->
  log2cli(lvl, msg)
  log2console(lvl, msg)

log2history = (id, level, msg) ->
  histsize = #history
  if histsize >= HIST_SIZE_LIMIT then history = {}
  else history[histsize + 1] = { lvl:level, :id, :msg }
  return unless histfile

  hsize = histfile\seek 'end'
  return histfile\write msg if hsize < HIST_FILE_SIZE
  histfile\close!
  histfile = open histfpath, 'w+'

tostr = (v) ->
  return if isstring(v) or isnumber(v) then v
  elseif istable v
    mt = getmetatable v
    if mt and mt.__tostring then tostring v
    else inspect v, INSPECT_OPTIONS
  else tostring v

logger_update = () =>
  log2prompt = if _tocli and _toconsole then log2both
  elseif _tocli then log2cli
  elseif _toconsole then log2console
  id = @_id

  for lvl, key in ipairs LEVEL_KEYS
    ukey = upper key
    toprompt = log2prompt and (lvl >= @_lvl or lvl >= _lvl)
    tohist = if _tohist = rawget(@, '_tohistlvl') then lvl >= _tohist else lvl >= _tohistlvl
    if toprompt and tohist
      @[key] = (msg) ->
        msg = format LOG_FMT, date(DATE_FMT), ukey, id, msg
        log2prompt lvl, msg
        log2history id, lvl, msg
        error! if lvl >= ERROR_LEVEL
      @["#{key}f"] = (fmt, ...) ->
        msg = format "#{LOG_FMTF}#{fmt}", date(DATE_FMT), ukey, id, vmap(tostr, ...)
        log2prompt lvl, msg
        log2history id, lvl, msg
        error! if lvl >= ERROR_LEVEL
    elseif tohist
      @[key] = (msg) ->
        msg = format LOG_FMT, date(DATE_FMT), ukey, id, msg
        log2history id, lvl, msg
        error! if lvl >= ERROR_LEVEL
      @["#{key}f"] = (fmt, ...) ->
        msg = format "#{LOG_FMTF}#{fmt}", date(DATE_FMT), ukey, id, vmap(tostr, ...)
        log2history id, lvl, msg
        error! if lvl >= ERROR_LEVEL
    elseif toprompt
      @[key] = (msg) ->
        msg = format LOG_FMT, date(DATE_FMT), ukey, id, msg
        log2prompt lvl, msg
        error! if lvl >= ERROR_LEVEL
      @["#{key}f"] = (fmt, ...) ->
        msg = format "#{LOG_FMTF}#{fmt}", date(DATE_FMT), ukey, id, vmap(tostr, ...)
        log2prompt lvl, msg
        error! if lvl >= ERROR_LEVEL
    else
      @[key] = nil
      @["#{key}f"] = nil

logger_level = (key) =>
  return @_lvl <= MAX_LEVEL and @_lvl or _lvl unless key
  @_lvl = LEVELS[key]
  @update!

logger_tohistory = (v) =>
  if v == nil
    return LEVELS[_tohistlvl] unless @_tohistlvl
    return @_tohistlvl > MAX_LEVEL and false or LEVELS[@_tohistlvl]
  @_tohistlvl = isstring v and LEVELS[v] or (v and MIN_LEVEL or MAX_LEVEL + 1)
  @update!

new = (id, level, tohist) ->
  logger = { _id: id, _lvl: LEVELS[level or 'warn'] }
  if tohist != nil
    logger._tohistlvl = isstring tohist and LEVELS[tohist] or (tohist and MIN_LEVEL or MAX_LEVEL + 1)

  if not loggers[id] then loggers[id] = logger
  else error format('Logger with id <%s> is already created.', id)

  setmetatable(merge(logger, {
    update: logger_update
    level: T '?, ?log.level', logger_level
    tohistory: T '?, ?boolean|log.level', logger_tohistory
    openhistory: openhistory
  }), {
    __index: T '?, string', (key) =>
      lvl = LEVELS_WF[key]
      return nil unless lvl
      return error! if lvl >= ERROR_LEVEL
  })\update!
  return logger

get = (id, lvl, tohist) ->
  logger = loggers[id]
  if logger
    logger._lvl = LEVELS[lvl] if lvl
    logger._tohistlvl = isstring tohist and LEVELS[tohist] or (tohist and MIN_LEVEL or MAX_LEVEL + 1) if tohist
    logger\update! if lvl or tohist != nil
    return logger
  return new(id, lvl, tohist)

level = (key) ->
  return LEVEL_KEYS[_lvl] unless key
  _lvl = LEVELS[key]

toconsole = (flag) ->
  return _toconsole unless flag
  _toconsole = flag
  each(loggers, logger_update)

tocli = (flag) ->
  return _tocli unless flag
  _tocli = flag
  each(loggers, logger_update)
  if flag and not ipc.cliStatus!
    error('Logging to CLI enabled, but Hammerspoon CLI is not installed properly.')

tohistory = (v) ->
  return _tohistlvl > MAX_LEVEL and false or LEVEL_KEYS[_tohistlvl] if v == nil
  _tohistlvl = isstring(v) and LEVELS[v] or (v and MIN_LEVEL or MAX_LEVEL + 1)

print = (level, id) ->
  return ieach(history, (e) ->
    { :lvl, :msg } = e
    log2console(lvl, msg) if _toconsole
    log2cli(lvl, msg) if _tocli
  ) unless level or id

  if level and id -- print by level and id
    lvl = LEVELS[level]
    error format('Invalid level name %s, valid names are:\n%s', level, LEVEL_KEYS) unless lvl

    ieach(history, (e) ->
      { id:eid, lvl:elvl, :msg } = e
      if elvl >= lvl and find(eid, id, 1, true) == 1 -- id prefix matches
        log2console lvl, msg if _toconsole
        log2cli lvl, msg if _tocli
    )
  else
    lvl = LEVELS[level]
    if lvl -- print by level
      ieach(history, (e) ->
        { lvl:elvl, :msg } = e
        if elvl >= lvl
          log2console lvl, msg if _toconsole
          log2cli lvl, msg if _tocli
      )
    else
      id = id and id or level -- print by id
      ieach(history, (e) ->
        if find(e.id, id, 1, true) == 1 -- id prefix matches
          { :lvl, :msg } = e
          log2console lvl, msg if _toconsole
          log2cli lvl, msg if _tocli
      )

tofile = (path) ->
  histfile = open path, 'a'
  error "Unable to open logging history file at path: #{path}" unless histfile
  histfpath = path

start = () ->
  TO_HS_LEVEL = {
    error: 'error'
    warning: 'warning'
    info: 'info'
    debug: 'debug'
    trace: 'verbose'
  }

  hs_lvl = TO_HS_LEVEL[level!]  
  hs.logger.setGlobalLogLevel hs_lvl

stop = () ->
  if histfile
    histfile\write '\n\nSEE YOU COWBOY, SOMEDAY SOMEWHERE!\n'
    histfile\flush!
    histfile\close!
    histfile = nil

  hs.logger.setGlobalLogLevel 'nothing'

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  new:       T 'string, ?log.level, ?boolean|log.level', new
  get:       T 'string, ?log.level, ?boolean|log.level', get
  level:     T '?log.level', level
  toconsole: T '?boolean', toconsole
  tocli:     T '?boolean', tocli
  tofile:    T 'string', once(tofile)
  tohistory: T '?boolean|log.level', tohistory
  print:     T '?string, ?string', print
  :start, :stop, :openhistory
}
