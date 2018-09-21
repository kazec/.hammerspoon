-- Setup Environment ------------------------------------------------------

package.path  ..= ';./lib/?/init.lua;./lib/?.lua;./mod/?/init.lua;./mod/?.lua;./util/?/init.lua;./util/?.lua;./ext/?/init.lua'
package.cpath ..= ';./lib/?.so;./lib/?/init.so;./ext/?.so'

_G.require = _G.rawrequire
package.loaded['hs'] = _G.hs -- So that require 'hs' no longer fails.
require 'moonscript'

-- Global Settings --------------------------------------------------------

-- dofile './debug.moon'

with require 'log'
  .level 'info'
  .tocli false
  .toconsole true
  .tohistory 'warn'
  .tofile os.getenv('HOME') .. '/.local/log/org.hammerspoon.log'

-- Load Modules -----------------------------------------------------------

modules = require 'config'
daemon = modules.daemon
daemon.start!

-- Make all modules available in _G.
require('fn.table').merge(_G, modules)

-- Hammserspoon -----------------------------------------------------------

with require 'hs'
  reload = .reload
  .reloading = false
  .reload = ->
    .reloading = true
    reload!

  .fs.rmdir .configdir .. '/Spoons'

  .shutdownCallback = ->
    .notify.withdrawAll!
    .settings.set('hs.reloaded', .reloading == true)
    pcall(daemon.stop)
  -- :/ no, I don't care about screen's gamma value
  getmetatable(.screen).__gc!

collectgarbage!
collectgarbage!
