---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

urlevent = require 'hs.urlevent'
import any from require 'fn.table'
log = require('log').get 'urlevent'
import processInfo from require 'hs'
import openURLWithBundle from urlevent
import partialr, once from require 'fn'
{ sigcheck:T, :istable, :isstring, :isfunction } = require 'typecheck'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

route = (_, host, params, url, rules) ->
  for i, r in ipairs rules
    if (host and r.host and any r.host, (p) -> host\find p) or
       (url and r.url and any r.url, (p) -> url\find p) or
       (r.match and r.match host, params, url) or
       (i == #rules)
       log.debugf 'Routing HTTP URL: %q, dest: %s', url, tostring(r.dest) if log.debugf
       if isstring r.dest
         return openURLWithBundle url, r.dest
       elseif isfunction r.dest
         return r.dest host, params, url
       else
         log.warnf 'Invalid rule destination: %s', tostring(r.dest)
  log.warnf 'Unable to route HTTP URL: %q', url if log.warnf

init = (router) ->
  if urlevent.getDefaultHandler('http')\lower! != processInfo.bundleID\lower!
    log.warn 'Hammerspoon is not configured for http(s):// URLs.\nType "hs.urlevent.setDefaultHandler(\'http\', hs.processInfo.bundleID)" and confirm the prompt.'
  urlevent.httpCallback = isfunction(router) and router or partialr(route, router)

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  init: T 'table|function', once(init)
}
