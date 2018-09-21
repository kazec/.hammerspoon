---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import floor from math
import pairs, ipairs from _G
{ :isnumber, sigcheck:T } = require('typecheck')

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

isidx = (k) -> isnumber(k) and k >= 1 and floor(k) == k

ieach = (list, fn) -> for _, v in ipairs list do fn v

ieachi = (list, fn) -> for i, v in ipairs list do fn i, v

ieachr = (list, fn) -> for i = #list, 1, -1 do fn list[i]

each = (dict, fn) -> for _, v in pairs dict do fn v

eachk = (dict, fn) -> for k, v in pairs dict do fn k, v

imap = (list, fn) ->
  t = {}
  for i, v in ipairs list
    t[i] = fn v
  return t

map = (dict, fn) ->
  t = {}
  for k, v in pairs dict
    t[isidx(k) and #t + 1 or k] = fn v
  return t

imapi = (list, fn) ->
  t = {}
  for i, v in ipairs list
    t[i] = fn(i, v)
  return t

mapk = (dict, fn) ->
  t = {}
  for k, v in pairs dict
    t[isidx(k) and #t + 1 or k] = fn k, v
  return t

ifilter = (list, fn) ->
  t = {}
  for i, v in ipairs list
    t[i] = v if fn v
  return t

filter = (dict, fn) ->
  t = {}
  for k, v in pairs dict
    t[isidx(k) and #t + 1 or k] = v if fn v
  return t

ifilteri = (list, fn) ->
  t = {}
  for i, v in ipairs list
    t[i] = v if fn(i, v)
  return t

filterk = (dict, fn) ->
  t = {}
  for k, v in pairs dict
    t[isidx(k) and #t + 1 or k] = v if fn k, v
  return t

ireduce = (list, init, fn) ->
  len = #list
  return init if len == 0

  r = fn(init, list[1])
  for i = 2, len do r = fn r, list[i]
  return r

reduce = (dict, init, fn) ->
  r = init
  for k, v in pairs dict do r = fn r, v
  return r

reducek = (dict, init, fn) ->
  r = init
  for k, v in pairs dict do r = fn r, k, v
  return r

indexof = (list, e) ->
  for i, v in ipairs list do return i if v == e
  return nil

index = (list, fn) ->
  for i, v in ipairs list do return i if fn v
  return nil

keyof = (dict, e) ->
  for k, v in pairs dict do return k if v == e
  return nil

key = (dict, fn) ->
  for k, v in pairs dict do return k if fn v
  return nil

first = (list, fn) ->
  for i, v in ipairs list do return v if fn v
  return nil

last = (list, fn) ->
  for i = #list, 0, -1
    v = list[i]
    break if v == nil
    return v if fn v
  return nil

contains = (dict, e) ->
  for k, v in pairs dict do return true if v == e
  return false

find = (dict, fn) ->
  for k, v in pairs dict do return v if fn k, v
  return nil

all = (dict, fn) ->
  for k, v in pairs dict do return false if not fn v
  return true

any = (dict, fn) ->
  for k, v in pairs dict do return true if fn v
  return false

keys = (dict) ->
  t = {}
  for k, _ in pairs dict do t[#t + 1] = k
  return t

values = (dict) ->
  t = {}
  for _, v in pairs dict do t[#t + 1] = v
  return t

enpair = (dict) ->
  t = {}
  for _, v in ipairs dict do t[v[1]] = v[2]
  return t

depair = (dict) ->
  t = {}
  for _, v in ipairs dict do t[v[1]] = v[2]
  return t

unset = (dict, fn) ->
  for k, v in pairs dict
    dict[k] = nil if fn v
  return dict

unsetk = (dict, fn) ->
  for k, v in pairs dict
    dict[k] = nil if fn k, v
  return dict

removek = (dict, key) ->
  v = dict[key]
  dict[key] = nil
  return v

copy = (dict) -> { k, v for k, v in pairs dict }

copyk = (dict, keys) -> { k, dict[k] for _, k in ipairs keys }

join = (l1, l2) ->
  for i = 1, #l2 do l1[#l1 + 1] = l2[i]
  return l1

merge = (d1, d2) ->
  for k, v in pairs d2 do d1[k] = v
  return d1

mergek = (d1, d2, keys) ->
  for _, k in ipairs keys do d1[k] = d2[k]
  return d1

extend = (d1, d2) ->
  for k, v in pairs d2 do d1[k] = v if d1[k] == nil
  return d1

override = (d1, d2) ->
  for k, _ in pairs d1
    v = d2[k]
    d1[k] = v if v != nil
  return d1

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

merge {
  ieach:     T 'table, function', ieach
  ieachi:    T 'table, function', ieachi
  ieachr:    T 'table, function', ieachr
  each:      T 'table, function', each
  eachk:     T 'table, function', eachk
  imap:      T 'table, function', imap
  map:       T 'table, function', map
  imapi:     T 'table, function', imapi
  mapk:      T 'table, function', mapk
  ifilter:   T 'table, function', ifilter
  filter:    T 'table, function', filter
  ifilteri:  T 'table, function', ifilteri
  filterk:   T 'table, function', filterk
  ireduce:   T 'table, ?, function', ireduce
  reduce:    T 'table, ?, function', reduce
  reducek:   T 'table, ?, function', reducek
  indexof:   T 'table, any', indexof
  index:     T 'table, function', index
  keyof:     T 'table, any', keyof
  key:       T 'table, function', key
  first:     T 'table, function', first
  last:      T 'table, function', last
  contains:  T 'table, any', contains
  find:      T 'table, function', find
  all:       T 'table, function', all
  any:       T 'table, function', any
  keys:      T 'table', keys
  values:    T 'table', values
  enpair:    T 'table', enpair
  depair:    T 'table', depair
  unset:     T 'table, function', unset
  unsetk:    T 'table, function', unsetk
  removek:   T 'table, any', removek
  copy:      T 'table', copy
  copyk:     T 'table, table', copyk
  join:      T 'table, table', join
  merge:     T 'table, table', merge
  mergek:    T 'table, table', mergek
  extend:    T 'table, table', extend
  override:  T 'table, table', override
}, table
