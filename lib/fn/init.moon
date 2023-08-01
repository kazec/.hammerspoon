---------------------------------------------------------------------------
-- Environment ------------------------------------------------------------
---------------------------------------------------------------------------

import upper from string
table = require 'fn.table'
import concat, pack from table
import map from require 'vararg'
string = require 'fn.string'
{ sigcheck:T } = require 'typecheck'
{ inspect:_inspect } = require 'inspect'
import partial, partialr from require 'fn.internal'

---------------------------------------------------------------------------
-- Implementation ---------------------------------------------------------
---------------------------------------------------------------------------

inspect = (...) -> print map(_inspect, ...)

fif = (cond, t, f) -> if cond then t else f

pipe = (l, r) -> (...) -> r l ...

pipen = (...) ->
  f = pack(...)

  switch f.n
    when 0 then nil
    when 1 then f[1]
    when 2 then pipe(f[1], f[2])
    when 3
      f1, f2, f3 = f[1], f[2], f[3]
      (...) -> f3 f2 f1 ...
    when 4
      f1, f2, f3, f4 = f[1], f[2], f[3], f[4]
      (...) -> f4 f3 f2 f1 ...
    when 5
      f1, f2, f3, f4, f5 = f[1], f[2], f[3], f[4], f[5]
      (...) -> f5 f4 f3 f2 f1 ...
    else
      f1, f2, f3, f4, f5, f6 = f[1], f[2], f[3], f[4], f[5], f[6]
      r = (...) -> f6 f5 f4 f3 f2 f1 ...
      if f.n == 6 then r else pipen(r, select(7, ...))

once = (fn) ->
  return (...) ->
    error 'once: function can only be executed once.' unless fn
    f = fn
    fn = nil
    return f(...)

---------------------------------------------------------------------------
-- Interface --------------------------------------------------------------
---------------------------------------------------------------------------

{
  :table, :string, :inspect, :fif
  partial:  T 'function', partial
  partialr: T 'function', partialr
  pipe:     T 'function, function', pipe
  pipen:    T 'function...', pipe
  once:     T 'function', once
}
