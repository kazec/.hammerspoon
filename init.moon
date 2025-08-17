-- Debug Settings --------------------------------------------------------

dofile './debug.moon'

with require 'log'
  .tocli false
  .toconsole true
  .tohistory 'info'
  .tofile "#{os.getenv('HOME')}/Library/Logs/org.hammerspoon.log"

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

  .fs.rmdir "#{.configdir}/Spoons"

  .shutdownCallback = ->
    .notify.withdrawAll!
    .settings.set('hs.reloaded', .reloading == true)
    pcall(daemon.stop)
  -- :/ no, I don't care about screen's gamma value
  getmetatable(.screen).__gc!

collectgarbage!
collectgarbage!
