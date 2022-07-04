---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import ieach, map, sort, keys from require 'fn.table'
import partial, once from require 'fn'

{ :isstring, :checkers, sigcheck:T } = require 'typecheck'
{ get:getcolor } = require 'colors'

console = require 'hs.console'
log = require('log').get 'console'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

DEFAULT_THEME =
  darkmode: false
  font: { name: 'Menlo-Regular', size: 12.0 }
  colors:
    print: { alpha: 1.0, blue: 0.432, green: 0.0, red: 0.6 }
    command: { alpha: 1.0, blue: 0.0, green: 0.0, red: 0.0 }
    result: { alpha: 1.0, blue: 0.7, green: 0.532, red: 0.0 }
    inputBackground: { alpha: 1.0, blue: 1.0, green: 1.0, red: 1.0 }
    outputBackground: { alpha: 1.0, blue: 1.0, green: 1.0, red: 1.0 }
    windowBackground: { list: 'System', name: 'windowBackgroundColor' }

themes = nil
current = nil

apply = (t) ->
  with console
    .consoleFont t.font if t.font
    .darkMode t.darkmode unless t.darkmode == nil
    .consolePrintColor t.colors.print
    .consoleCommandColor t.colors.command
    .inputBackgroundColor t.colors.inputBackground
    .outputBackgroundColor t.colors.outputBackground
    .windowBackgroundColor t.colors.windowBackground

set = (new) ->
  if new != current
    log.info 'Switching to new console theme : ' .. new if log.info
    apply themes[new]
    current = new

get = () -> current

init = (thms, current = 'Default') ->
  ieach thms, (t) -> t.colors = map(t.colors, getcolor)
  themes = thms
  themes['Default'] = DEFAULT_THEME unless thms['Default']
  set current

checkers['console.theme'] = (v) -> isstring(v) and themes[v]

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  apply: T 'table', apply
  set: T '?console.theme', set
  init: T 'table, ?string', once(init)
  all: () -> keys themes
  :get
}
