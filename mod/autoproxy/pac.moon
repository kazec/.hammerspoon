---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import concat from table
import ipairs, tonumber from _G
import match, format, find from string

import run, escape from require 'shell'
import javascript from require 'hs.osascript'

{ sigcheck:T, :isstring, :checkers } = require 'typecheck'

log = require('log').get 'autoproxy'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

TEMPLATE = [[
function matchDomain(host, domain) {
  if (host != domain) {
    var hostLen = host.length, domainLen = domain.length;
    return host.charCodeAt(hostLen - domainLen - 1) === 46 && host.substring(hostLen - domainLen) === domain;
  }
  return true;
}

function FindProxyForURL(url, host) {
  if (isPlainHostName(host)) {
    return "DIRECT";
  }

%s
%s
}
]]

TESTER_WITH_NET = [[
  if (/^\d+\.\d+\.\d+\.\d+$/.test(host)) {
    var bytes = host.split(".");
    var ip = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | (bytes[3]);

%s
  }
%s
]]

RULE_FORMATTERS =
  'net': (rule) ->
    p1, p2, p3, p4, mask = match rule, '^(%d+)%.(%d+)%.(%d+)%.(%d+)/?(%d*)$'
    p1, p2, p3, p4 = tonumber(p1), tonumber(p2), tonumber(p3), tonumber(p4)
    mask = mask == '' and 32 or tonumber mask

    if not p1 or p1 > 0xff or p2 > 0xff or p3 > 0xff or p4 > 0xff or mask > 32 then
      log.error "Invalid 'net' rule: " .. rule
      return
    else
      -- JavaScript and Lua/C both use Two's Complement, while one uses 32 bits and the other uses 64 bits.
      mask = (0xffffffff >> (32 - mask)) << (32 - mask)
      pattern = ((p1 << 24) | (p2 << 16) | (p3 << 8) | p4) & mask
      mask = mask | 0xffffffff00000000 if mask & 2147483648 == 2147483648 -- 2^31
      pattern = pattern | 0xffffffff00000000 if pattern & 2147483648 == 2147483648
      return format '(ip & %s) === %s', mask, pattern
  'host': (rule) ->
    return format 'host === %q', rule if find rule, '^[-_%w]+[%.-_%w]*'
    log.error "Invalid 'host' rule: " .. rule
  'domain': (rule) ->
    return format 'matchDomain(host, %q)', rule if find rule, '^[-_%w]+[%.-_%w]*'
    log.error "Invalid 'domain' rule: " .. rule
  'host-keyword': (rule) ->
    return rule .. '.test(host)' if javascript rule
    log.error "Invalid 'url-keyword' rule: " .. rule
  'url-keyword': (rule) ->
    return rule .. '.test(url)' if javascript rule
    log.error "Invalid 'url-keyword' rule: " .. rule

conditions = (rsnames, rsdict) ->
  netr, textr = nil, nil
  for _, rsname in ipairs rsnames
    rsection = rsdict[rsname]
    if netlist = rsection['net']
      fmt = RULE_FORMATTERS['net']
      for _, rule in ipairs netlist
        netr = {} unless netr
        netr[#netr + 1] = fmt rule
    for _, rtype in ipairs { 'host', 'domain', 'host-keyword', 'url-keyword' }
      if rlist = rsection[rtype]
        fmt = RULE_FORMATTERS[rtype]
        for _, rule in ipairs rlist
          textr = {} unless textr
          textr[#textr + 1] = fmt rule
  netr = concat netr, ' || ' if netr
  textr = concat textr, ' || ' if textr
  return netr, textr

compile = (pnames, prsndict, pdict, rsdict) ->
  netr, textr, defaultr = '', '', nil
  for i, pname in ipairs pnames
    pvalue = pdict[pname]
    if i == #pnames
      defaultr = format '  return %q', pvalue
    else
      netconds, textconds = conditions prsndict[pname], rsdict
      netr ..= format '  if ( %s ) { return %q; }\n\n', netconds, pvalue if netconds
      textr ..= format '  if ( %s ) { return %q; }\n\n', textconds, pvalue if textconds

  unless netr == ''
    return format TEMPLATE, format(TESTER_WITH_NET, netr, textr), defaultr
  else
    return format TEMPLATE, textr, defaultr

minify = (pac) ->
  minified, success = run '/usr/local/bin/node /usr/local/bin/uglifyjs -m "toplevel,reserved=[\'FindProxyForURL\']" <<< ' .. escape pac
  return minified if success
  log.warnf 'Failed to minify pac, using the original one instead.\n' .. pac if log.warnf
  return pac

checkers.javascript = (v) -> isstring(v) and javascript(v)

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  compile: T 'table, table, table, table', compile
  minify: T 'javascript', minify
}
