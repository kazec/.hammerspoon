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
