---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import format from string
import once from require 'fn'
settings = require 'hs.settings'
import run, execute from require 'shell'
{ urlParts:urlparts } = require 'hs.http'
{ new:newserver } = require 'hs.httpserver'
import dofile from require 'moonscript.base'
import javascript from require 'hs.osascript'
import compile, minify from require 'autoproxy.pac'
import map, mapk, keys, key, merge from require 'fn.table'
{ sigcheck:T, :isstring, :isboolean, :checkers } = require 'typecheck'

log = require('log').get 'autoproxy'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

self =
  _server: nil
  _callback: nil
  _profiles: nil
  _config:
    path: nil
    minify: false

activenetworkservice = () ->
  -- Shamelessly copied from https://apple.stackexchange.com/a/223446
  result = run([[
    services=$(networksetup -listnetworkserviceorder | grep 'Hardware Port')

    while read line; do
        sname=$(echo $line | awk -F  "(, )|(: )|[)]" '{print $2}')
        sdev=$(echo $line | awk -F  "(, )|(: )|[)]" '{print $4}')
        if [ -n "$sdev" ]; then
            ifout="$(ifconfig $sdev 2>/dev/null)"
            echo "$ifout" | grep 'status: active' > /dev/null 2>&1
            rc="$?"
            if [ "$rc" -eq 0 ]; then
                currentservice="$sname"
                currentdevice="$sdev"
                currentmac=$(echo "$ifout" | awk '/ether/{print $2}')
            fi
        fi
    done <<< "$(echo "$services")"

    if [ -n "$currentservice" ]; then
        echo $currentservice
        echo $currentdevice
        echo $currentmac
    else
        exit 1
    fi]])
  return result\match '(.+)\n(.+)\n(.+)' if result

networksetup = (cmd, value, service) ->
  service or= activenetworkservice()
  if not service
    log.warn 'No active network service now. Use the last active one instead.' if log.warn
    service = settings.get 'autoproxy.network-service' or 'Wi-Fi'
  else
    settings.set 'autoproxy.network-service', service

  return if value == nil
    run '/usr/sbin/networksetup', cmd, service
  elseif isboolean value
    execute '/usr/sbin/networksetup', cmd, service, value and 'on' or 'off'
  else
    execute '/usr/sbin/networksetup', cmd, service, value

makeurl = (server, path) ->
  return format 'http://%s:%d/%s', server\getInterface! or '0.0.0.0', server\getPort!, path

profiles = () -> mapk @_profiles, (n, _) -> url: makeurl(@_server, n)

status = (tostr) ->
  return (networksetup('-getautoproxyurl')) if tostr
  url, enabled = networksetup('-getautoproxyurl')\match 'URL: (%g+)\nEnabled: (%a+)'
  enabled = enabled == 'Yes'

  if url == '(null)'
    return nil, nil, enabled
  else
    if @_profiles
      p = key profiles!, () => @url == url
      return p, url, enabled if p
    return nil, url, enabled

on = (p) ->
  p or= (status!) or settings.get 'autoproxy.profile'
  log.errorf 'Please specify a profile to use, candidates are: \n%s', profiles! unless p
  log.info "Switing to profile: #{p}" if log.info

  networksetup '-setautoproxyurl', makeurl(@_server, p)
  networksetup '-setautoproxystate', false
  networksetup '-setautoproxystate', true

  @._callback(p) if @_callback
  settings.set 'autoproxy.profile', p

off = () ->
  log.info 'Turning off...' if log.info
  networksetup '-setautoproxystate', false
  @._callback(nil) if @_callback

toggle = () ->
  profile, _, enabled = status!
  if enabled then off!
  else
    profile or= settings.get 'autoproxy.profile'
    on profile

test = (url, host, p) ->
  url = "http://#{url}" unless url\find 'http://', nil, true
  host = host or urlparts(url).host
  log.errorf 'Unable to extract host from possibly malformed URL:\n%s', url unless host

  p or= (status!)
  log.errorf 'Please specify a profile name to test against, candidates are:\n%s', keys @_profiles unless p

  log.infof 'Testing with profile: %s\nURL: %s\nHOST: %s', p, url, host
  tester = "function isPlainHostName(a){return !a.includes(\".\");}#{@_profiles[p]}#{format 'FindProxyForURL(%q,%q);', url, host}"
  success, result, err = javascript tester
  log.error "An exception has occured: #{err}" unless success

  return result

load = (config, mini) ->
  prsndicts = config.profiles
  rsdict = config.rules
  pdict = config.proxies
  return map prsndicts, (prsndict) ->
    pac = compile prsndict.proxies, prsndict, pdict, rsdict
    return mini and minify(pac) or pac

callback = (c) -> @_callback = c

init = (options) ->
  with options
    @_config.minify = .minify or false
    servercfg = .server or {
      interface: 'localhost'
      port: 8000
    }

    if isstring .config
      @_config.path = .config -- load on start
    else
      @_profiles = load .config, @_config.minify
    @_server = newserver!\setInterface(servercfg.interface)\setPort(servercfg.port)

start = () ->
  if @_config.path
    @_profiles = load dofile(@_config.path), @_config.minify

  @_server\setCallback((method, path) ->
    if method == 'GET'
      if prof = path\match '^/(%a+)'
        if resp = @_profiles[prof]
          log.debugf 'Response: %s', prof if log.debugf
          return resp, 200, {}
    log.debugf 'Invalid HTTP request: %s, "%s"', method, path if log.debugf
    return 'Invalid Request', 400, {}
  )\start!

  if p = (status!) or settings.get 'autoproxy.profile'
    on p

stop = () ->
  off!
  @_server\stop!
  @_profiles = nil if @_config.path

restart = () ->
  stop!
  start!

checkers['autoproxy.profile'] = (v) -> isstring(v) and @_profiles and @_profiles[v]

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge self, {
  status: T '?boolean', status
  on: T '?autoproxy.profile', on
  test: T 'string, ?string, ?autoproxy.profile', test
  callback: T 'function', once(callback)
  init: T 'table', once(init)
  :profiles, :start, :restart, :off, :toggle
}
