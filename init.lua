-- Setup package environment

local lua_version = _VERSION:match("%d+%.%d+")
local rocks_dir = hs.configdir .. '/lib/rocks'
local rocks_lib_dir = rocks_dir .. '/lib/lua/' .. lua_version
local rocks_share_dir = rocks_dir .. '/share/lua/' .. lua_version
local rocks_libs = { 'moonscript', 'inspect', 'vararg' }

if hs.fs.attributes(rocks_lib_dir, 'mode') ~= 'directory' then
   hs.notify.show('Lua rocks', 'Installing rocks for ' .. _VERSION, 'Please wait', '')
   local handle = io.popen(string.format("%s/lib/rocks/install.sh --lua_ver %s --tree %s --libs %s",
                            hs.configdir, lua_version, rocks_dir, table.concat(rocks_libs, ",")))
   print(handle:read('*a'))
   if not handle:close() then
      hs.notify.show('Lua rocks', 'Rocks installation failed', 'Click to see why', '')
      return
   end
   hs.notify.show('Lua rocks', 'Finished installing ' .. tostring(#rocks_libs) ' rocks', '')
end

local local_path = './lib/?/init.lua;./lib/?.lua;./mod/?/init.lua;./mod/?.lua;./util/?/init.lua;./util/?.lua;./ext/?/init.lua;'
local local_cpath = hs.configdir .. '/lib/?.so;' .. hs.configdir .. '/lib/?/init.so;' .. hs.configdir .. '/ext/?.so;'
local rocks_path = rocks_share_dir .. '/?.lua;' ..rocks_share_dir .. '/?/init.lua;'
local rocks_cpath = rocks_lib_dir .. '/?.so;'
package.path = local_path .. rocks_path .. package.path
package.cpath = local_cpath .. rocks_cpath .. package.cpath

_G.require = _G.rawrequire
package.loaded['hs'] = _G.hs -- So that require 'hs' no longer fails.
require('moonscript')

-- Setup moonscript enviroment

local moonscript = require('moonscript.base')
local loadstring = moonscript.loadstring

load = function(chunk, ...)
   if chunk:find('^%a+% *=') then
      chunk = 'export ' .. chunk
   end
   return loadstring(chunk, ...)
end

dofile = moonscript.dofile
loadfile = moonscript.loadfile

local trim = require('moonscript.util').trim
local rewrite_traceback = require('moonscript.errors').rewrite_traceback

local _traceback = debug.traceback
debug.traceback = function(message, level)
   original = _traceback('', (level or 1) + 1)
   rewritten = rewrite_traceback(trim(original), message or '')

   if rewritten then
      return trim(rewritten)
   elseif message then
      return message .. '\n' .. trim(original)
   else
      return trim(original)
   end
end

-- Load moonscript script

dofile('init.moon')
