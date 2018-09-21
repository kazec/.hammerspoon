#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>

#pragma mark - Marcos

#define MATCH_CHECKERS  1
#define MATCH_METAFIELD "__name"
#define MODULE_LUAOPEN_FN luaopen_typecheck

#define isis(str, i) ((str)[i] == 'i' && (str)[(i) + 1] == 's')
#define isany(str, i) ((str)[i] == 'a' && (str)[(i) + 1] == 'n' && (str)[(i) + 2] == 'y')
#define isnil(str, i) ((str)[i] == 'n' && str[(i) + 1] == 'i' && (str)[(i) + 2] == 'l')
#define is3dots(str, i) ((str)[i] == '.' && (str)[(i) + 1] == '.' && (str)[(i) + 2] == '.')
#define isspacedarr(str, i) ((str)[i] == ' ' && str[(i) + 1] == '-' && (str)[(i) + 2] == '>' && (str)[(i) + 3] == ' ')
#define makesubstr(src, sz) ({ char *dest = malloc((sz + 1) * sizeof(char)); \
                               memcpy(dest, src, sz); \
                               dest[sz] = '\0'; \
                               dest;})

#pragma mark - Internal Functions & Variables

static int moduleRef;

// [-0, +0, v]
static int argerrordn(lua_State *L, lua_Debug *ar, int arg, const char *name, const char *expected, size_t esize,
                     const char *got) {
    char *exp = makesubstr(expected, esize);
    lua_getinfo(L, "nSl", ar);
    lua_pushfstring(L, "%s:%d: bad argument #%d '%s' to '%s' (expected %s, got %s)",
                    ar->short_src, ar->currentline, arg, name, ar->name, exp, got);
    free(exp);
    return lua_error(L);
}

// [-0, +0, v]
static int argerror(lua_State *L, int arg, const char *expected, size_t esize, const char *got) {
    lua_Debug ar;
    lua_getstack(L, 0, &ar);

    char *exp = makesubstr(expected, esize);
    lua_getinfo(L, "n", &ar); lua_getstack(L, 1, &ar); lua_getinfo(L, "Sl", &ar);
    lua_pushfstring(L, "%s:%d: bad argument #%d to '%s' (expected %s, got %s)",
                    ar.short_src, ar.currentline, arg, ar.name, exp, got);

    free(exp);
    return lua_error(L);
}

// [-0, +0, v]
static int resulterror(lua_State *L, int arg, const char *expected, size_t esize, const char *got) {
    lua_Debug ar;
    lua_getstack(L, 0, &ar);

    char *exp = makesubstr(expected, esize);
    lua_getinfo(L, "n", &ar); lua_getstack(L, 1, &ar); lua_getinfo(L, "Sl", &ar);
    lua_pushfstring(L, "bad result #%d from '%s' (expected %s, got %s)",
                    ar.short_src, ar.currentline, arg, ar.name, exp, got);

    free(exp);
    return lua_error(L);
}

// [-0, +0, v]
static int declerror(lua_State *L, int arg, const char *decl) {
    lua_Debug ar;
    lua_getstack(L, 0, &ar);
    lua_getinfo(L, "nSl", &ar);
    lua_pushfstring(L, "%s:%d: bad argument #%d to '%s' (invalid pattern(s) declaration: '%s')",
                    ar.short_src, ar.currentline, arg, ar.name, decl);
    return lua_error(L);
}

// [-0, +0, v]
static int sigerror(lua_State *L, int arg, const char *sig) {
    lua_Debug ar;
    lua_getstack(L, 0, &ar);
    lua_getinfo(L, "nSl", &ar);
    lua_pushfstring(L, "%s:%d: bad argument #%d to '%s' (invalid function signature: '%s')",
                    ar.short_src, ar.currentline, arg, ar.name, sig);
    return lua_error(L);
}

// [-0, +0, v]
static int optmatch(lua_State *L, int obj, const char *pattern, size_t psize) {
    // Match for standalone '?'
    if (pattern[0] != '?') return 0;

    if (psize == 1 // pattern = '?'
        || (lua_isnoneornil(L, obj)) // pattern == '?sometype|...', obj == nil or doesn't exist
        || (psize == 4 && isany(pattern, 1))) { // pattern == '?any'
        return 1;
    } else return -1;
}

static int strmatch(const char *actual, const size_t asize, const char *pattern, size_t psize) {
    const char *expected = pattern, *pend = pattern + psize;

    while (1) {
        const char *eend = memchr(expected, '|', (size_t)(pend - expected));
        size_t esize = (size_t)(eend ? eend - expected : pend - expected);

        if (esize != asize) {
            if (esize == 3 && isany(expected, 0)) return 1; // expected == "any", actual != "nil" (tsize != asize)
        } else if (!memcmp(actual, expected, asize) // expected == actual
                   || (esize == 3 && isany(expected, 0) && !isnil(actual, 0))) { // expected == "any", actual != "nil"
            return 1;
        }

        if (eend) expected = eend + 1; // Next expected type.
        else return 0; // Last loop.
    }
}

#ifdef MATCH_CHECKERS
// [-0, +0, -]
static int checkersmatch(lua_State *L, int obj, const char *pattern, size_t psize) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, moduleRef); // typecheck
    lua_getfield(L, -1, "checkers");              // checkers, typecheck

    const char *expected = pattern, *pend = pattern + psize;

    while (1) {
        const char *eend = memchr(expected, '|', (size_t)(pend - expected));
        size_t esize = (size_t)(eend ? eend - expected : pend - expected);

        lua_pushlstring(L, expected, esize);    // expected, checkers, typecheck
        lua_gettable(L, -2);                // checkers.expected, checkers, typecheck
        if (lua_isfunction(L, -1)) {        // checkers.expected, checkers, typecheck
            int idx = obj > 0 ? obj : obj - 3;
            lua_pushvalue(L, idx);          // obj, checkers.expected, checkers, typecheck

            if (lua_pcall(L, 1, 1, 0) == LUA_OK
                && lua_toboolean(L, -1)) {  // result|msg, checkers, typecheck
                lua_pop(L, 3);              // -
                return 1;
            } /* else {                     // result|msg, checkers, typecheck } */
        } /* else {                         // checkers.expected, checkers, typecheck } */

        if (eend) { // Next checkers.expected.
            lua_pop(L, 1);                  // checkers, typecheck
            expected = eend + 1;
        } else { // Last loop.
            lua_pop(L, 3);                  // -
            return 0;
        }
    }
}
#endif

// [-0,+1|0, -]
static const char *typematch(lua_State *L, int i, const char *pattern, size_t psize) {
    // Check optional prefix '?'
    int result = optmatch(L, i, pattern, psize);
    if (result == 1) return NULL; // '?' detected, obj is nil.
    else if (result == -1) { // '?' detected, but obj is not nil.
        pattern++; psize--; // skip '?'
    }

    // Check lua primitive types.
    const char *actual = luaL_typename(L, i);
    size_t asize = strlen(actual);
    if (strmatch(actual, asize, pattern, psize)) return NULL;

    #ifdef MATCH_METAFIELD // Match metafield.
    if(lua_getmetatable(L, i)) {                                    // metatable
        if (lua_getfield(L, -1, MATCH_METAFIELD) == LUA_TSTRING) {  // __field, metatable
            size_t fsize;
            const char *field = lua_tolstring(L, -1, &fsize);       // __field, metatable
            if (strmatch(field, fsize, pattern, psize)) {
                lua_pop(L, 2);                                      // -
                return NULL;
            }

            #if !MATCH_CHECKERS
            lua_remove(L, -2);                                      // field
            return name;
            #endif
        }                                                           // field, metatable
        lua_pop(L, 2);                                              // -
    }                                                               // -
    #endif

    #if MATCH_CHECKERS // Match custom checkers.
    if (checkersmatch(L, i, pattern, psize)) return NULL;
    #endif

    // All matches failed, return `actual` as the mismatched type.
    // The stack doesn't need to be balanced since a mismatch always means the end of the function call.
    // lua_pushlstring(L, actual, asize);                       // actual
    return actual;
}

static int typecheck(lua_State *L, const int darg, int varg, const int vargmax,
                     int(*error)(lua_State *, int, const char *, size_t, const char *)) {
    // Get patterns declaration.
    size_t dsize;
    const char *decl = luaL_checklstring(L, darg, &dsize);

    if (dsize == 0) return 0;

    const char *pattern = decl, *dend = decl + dsize;

    // Loop to check each type pattern.
    while (1) {
        size_t psize;
        const char *pend = strchr(pattern, ','), *mismatch;

        if (!pend) { // Last pattern, check for '...'.
            psize = (size_t)(dend - pattern);

            if (psize > 3 && is3dots(dend, -3)) { // '...' found, check all remaining values with the last pattern.
                for (/* i already initialized */; varg <= vargmax; varg++) {
                    mismatch = typematch(L, varg, pattern, psize - 3);
                    if (mismatch) return error(L, varg, pattern, psize, mismatch);
                }
                return 0; // Check passed.
            }
        } else {
            psize = (size_t)(pend - pattern);
        }

        // Number of values provided is not enough.
        if (varg > vargmax) {
          // Only perform optional match.
          if (!optmatch(L, varg, pattern, psize)) return error(L, varg, pattern, psize, lua_typename(L, LUA_TNONE));
        } else {
          // Perform normal match.
          mismatch = typematch(L, varg, pattern, psize);
          if (mismatch) return error(L, varg, pattern, psize, mismatch);
        }

        // Last loop, all patterns successfully matched.
        if (!pend) return 0;

        // Next pattern & value.
        pattern = pend + 2;
        if (pattern >= dend) return declerror(L, 1, decl);
        varg++;
    }
    // Unreachable.
}

static int argscheck(lua_State *L, lua_Debug *ar, int arg) {
    // Get patterns declaration.
    size_t dsize;
    const char *decl = luaL_checklstring(L, arg, &dsize);

    if (dsize == 0) return 0;

    // Loop to check each type pattern.
    int n = 1;
    const char *pat = decl, *dend = decl + dsize;

    while (1) {
        size_t psize;
        const char *pend = strchr(pat, ','), *argname, *mismatch;

        if (!pend) { // Last pattern, check for '...'.
            psize = (size_t)(dend - pat);

            if (psize > 3 && is3dots(dend, -3)) { // '...' found, match all remaining values with the last pattern.
                for (/* n already initialized */; n <= ar->nparams; n++) {
                    argname = lua_getlocal(L, ar, n);
                    mismatch = typematch(L, -1, pat, psize - 3); // Match without '...'.
                    if (mismatch) return argerrordn(L, ar, n, argname, pat, psize, mismatch);
                }
                return 0; // Check passed.
            }
        } else {
            psize =(size_t)(pend - pat);
        }

        // Parameters is fewer than patterns.
        if (n > ar->nparams) return argerrordn(L, ar, n, "(undefined)", pat, psize, lua_typename(L, LUA_TNONE));

        // Perform match.
        argname = lua_getlocal(L, ar, n);
        mismatch = typematch(L, -1, pat, psize);
        if (mismatch) return argerrordn(L, ar, n, argname, pat, psize, mismatch);

        // Last loop, all patterns successfully matched.
        if(!pend) return 0;

        // Next pattern & vararg
        pat = pend + 2;
        if (pat >= dend) return declerror(L, arg, decl);
        n++;
    }
}

static int vargcheck(lua_State *L, lua_Debug *ar, int arg) {
    // Get patterns declaration.
    size_t dsize;
    const char *decl = luaL_checklstring(L, arg, &dsize);

    if (dsize == 0) return 0;

    // Loop to check each type pattern.
    int n = -1;
    const char *pattern = decl, *dend = decl + dsize;

    while (1) {
        size_t psize;
        const char *pend = strchr(pattern, ','), *mismatch;

        if (!pend) { // Last pattern, check for '...'.
            psize = (size_t)(dend - pattern);

            if (psize > 3 && is3dots(dend, -3)) { // '...' found, match all remaining values with the last pattern.
                for (/* i already initialized */; lua_getlocal(L, ar, n); n--) {
                    mismatch = typematch(L, -1, pattern, psize - 3);
                    if (mismatch) return argerrordn(L, ar, ar->nparams - n, "(vararg)", pattern, psize, mismatch);
                }
                return 0; // Check passed.
            }
        } else {
            psize = (size_t)(pend - pattern);
        }

        // Number of values provided is not enough.
        if (!lua_getlocal(L, ar, n))
            return argerrordn(L, ar, ar->nparams - n, "(undefined)", pattern, psize, lua_typename(L, LUA_TNONE));

        // Perform match.
        mismatch = typematch(L, -1, pattern, psize);
        if (mismatch) return argerrordn(L, ar, ar->nparams - n, "(vararg)", pattern, psize, mismatch);

        // Last loop, all patterns successfully matched.
        if (!pend) return 0;

        // Next pattern & vararg.
        pattern = pend + 2;
        if (pattern >= dend) return declerror(L, arg, decl);
        n--;
    }
}

static int parsesig(lua_State *L, int arg) {
    // Get sigature declaration.
    size_t ssize;
    const char *sig = luaL_checklstring(L, arg, &ssize);
    if (ssize == 0) return sigerror(L, arg, sig);;

    // Parse arguments type patterns declaration.
    size_t adsize;
    const char *adecl, *arr2;
    if (sig[0] == '(') { // Check for left parenthesis.
        adecl = sig + 1;
        const char *adend = strchr(adecl, ')');
        if (!adend) return sigerror(L, arg, sig);

        adsize = (size_t)(adend - adecl);
        arr2 = strchr(adecl, '>');
    } else {
        adecl = sig;
        arr2 = strchr(adecl, '>');
        adsize = arr2 ? (size_t)(arr2 - 2 - sig) : ssize;
    }

    lua_pushlstring(L, adecl, adsize);
    if (!arr2) return 1;

    const char *send = sig + ssize;

    // Check if the '>' found is at index 2 of a ' -> ' substring.
    if ((arr2 - sig < 3)
        || (send - arr2 < 3)
        || !isspacedarr(arr2, -2)) return sigerror(L, arg, sig);

    // Parse arguments type patterns declaration.
    size_t rdsize;
    const char *rdecl = arr2 + 2;

    if (rdecl[0] == '(') { // Check for left parenthesis.
        rdecl++;
        if (send[-1] != ')') return sigerror(L, arg, sig);
        rdsize = (size_t)(send - 1 - rdecl);
    } else {
        rdsize = (size_t)(send - rdecl);
    }

    lua_pushlstring(L, rdecl, rdsize);
    return 2;
}

static int sigchecked_closure(lua_State *L) {
    int top = lua_gettop(L);

    // Check argument values type.
    lua_pushvalue(L, lua_upvalueindex(2));  // args decl, args...
    typecheck(L, -1, 1, top, argerror);     // args decl, args...
    lua_pop(L, 1);                          // args...

    // Call wrapped func.
    lua_pushvalue(L, lua_upvalueindex(1));  // wrapped func, args...
    lua_insert(L, 1);                       // args..., wrapped func
    lua_call(L, top, LUA_MULTRET);          // results...

    top = lua_gettop(L);

    // No need to check return values.
    if (lua_isnone(L, lua_upvalueindex(3))) {
        return lua_gettop(L);
    }

    // Check result values type.
    lua_pushvalue(L, lua_upvalueindex(3));  // results decl, result...
    typecheck(L, -1, 1, top, resulterror);  // results decl, result...
    lua_pop(L, 1);                          // results...

    // Return results.
    return lua_gettop(L);
}

#pragma mark - Lua Module Functions

static int typecheck_typecheck(lua_State *L) {
    return typecheck(L, 1, 2, lua_gettop(L), argerror);
}

static int typecheck_typematch(lua_State *L) {
    // Get the pattern string.
    size_t dsize;
    const char *decl = luaL_checklstring(L, 1, &dsize);

    if (dsize == 0) {
        lua_pushboolean(L, 1);
        return 1;
    }

    int i = 2;
    const int top = lua_gettop(L);
    const char *pattern = decl, *dend = decl + dsize;

    // Push failure in advance.
    lua_pushboolean(L, 0);

    // Loop to check each expected type.
    while (1) {
        const char *pend = strchr(pattern, ','), *mismatch;
        size_t psize;

        if (!pend) { // Last pattern, check for '...'.
            psize = (size_t)(dend - pattern);

            if (psize > 3 && is3dots(dend, -3)) { // '...' found, check all remaining values with the last pattern.
                for (/* i already initialized */; i <= top; i++) {
                    mismatch = typematch(L, i, pattern, psize - 3);
                    if (mismatch) return 1;
                }
                lua_pushboolean(L, 1); // Push success.
                return 1; // Check passed.
            }
        } else {
            psize = (size_t)(pend - pattern);
        }

        // Number of values provided is not enough.
        if (i > top) return 1;

        // Perform match.
        mismatch = typematch(L, i, pattern, (size_t)(pend - pattern));
        if (mismatch) return 1;

        // Last loop, all patterns successfully matched.
        if (!pend) {
            lua_pushboolean(L, 1); // Push success.
            return 1; // Check passed.
        }

        // Next pattern & value.
        pattern = pend + 2;
        if (pattern >= dend) return declerror(L, 1, decl);
        i++;
    }
    // Unreachable.
}

static int typecheck_sigcheck(lua_State *L) {
    if (!lua_isfunction(L, 2)) return argerror(L, 2, "function", 8, luaL_typename(L, 2));
    lua_pushcclosure(L, sigchecked_closure, 1 + parsesig(L, 1));
    return 1;
}

static int typecheck_sigcheckoff(__unused lua_State *L) {
  return 1;
}

static int typecheck_argscheck(lua_State *L) {
    lua_Debug ar;
    if(!lua_getstack(L, 1, &ar)) {
        return luaL_error(L, "unable to get stack information, 'vargcheck' must be called in a Lua function.");
    }
    lua_getinfo(L, "u", &ar);

    if (lua_gettop(L) == 1) {
        return argscheck(L, &ar, 1);
    } else if (ar.isvararg) {
        argscheck(L, &ar, 1);
        return vargcheck(L, &ar, 2);
    } else {
        return luaL_error(L, "'argscheck' with vararg pattern specified must be called inside a vararg function.");
    }
}

static int typecheck_vargcheck(lua_State *L) {
    lua_Debug ar;
    if(!lua_getstack(L, 1, &ar)) {
        return luaL_error(L, "unable to get stack information, 'vargcheck' must be called in a Lua function.");
    }
    lua_getinfo(L, "u", &ar);

    if (ar.isvararg) {
        return vargcheck(L, &ar, 1);
    } else {
        return luaL_error(L, "'vargcheck' must be called inside a vararg function.");
    }
}

static int prim_is_closure(lua_State *L) {
  int type = lua_type(L, 1);
  int expected = (int)lua_tointeger(L, lua_upvalueindex(1));
  lua_pushboolean(L, type == expected);
  return 1;
}

#ifdef MATCH_METAFIELD
static int metafield_is_closure(lua_State *L) {
  if (lua_getmetatable(L, 1) && lua_getfield(L, -1, MATCH_METAFIELD) == LUA_TSTRING) {
    const char *type = lua_tostring(L, -1);
    const char *expected = lua_tostring(L, lua_upvalueindex(1));
    lua_pushboolean(L, !strcmp(type, expected));
  } else {
    lua_pushboolean(L, 0);
  }

  return 1;
}
#endif

static int typecheck_meta__index(lua_State *L) {
  size_t ksize;
  const char *key = luaL_checklstring(L, 2, &ksize);
  if (ksize <= 2 || !isis(key, 0)) return 0;

  // Search for cached.
  lua_rawgeti(L, LUA_REGISTRYINDEX, moduleRef); // typecheck, key
  lua_pushstring(L, key); // key, typecheck
  lua_rawget(L, -2); // match or nil, typecheck, key
  if (lua_isfunction(L, -1)) {
    return 1;
  }

  // Skip leading 'is'
  key += 2;

  // Match for primitive types.
  if (!strcmp(key, "number")) {
    lua_pushinteger(L, LUA_TNUMBER); lua_pushcclosure(L, prim_is_closure, 1);
  } else if (!strcmp(key, "string")) {
    lua_pushinteger(L, LUA_TSTRING); lua_pushcclosure(L, prim_is_closure, 1);
  } else if (!strcmp(key, "boolean")) {
    lua_pushinteger(L, LUA_TBOOLEAN); lua_pushcclosure(L, prim_is_closure, 1);
  } else if (!strcmp(key, "table")) {
    lua_pushinteger(L, LUA_TTABLE); lua_pushcclosure(L, prim_is_closure, 1);
  } else if (!strcmp(key, "function")) {
    lua_pushinteger(L, LUA_TFUNCTION); lua_pushcclosure(L, prim_is_closure, 1);
  } else if (!strcmp(key, "thread")) {
    lua_pushinteger(L, LUA_TTHREAD); lua_pushcclosure(L, prim_is_closure, 1);
  } else if (!strcmp(key, "userdata")) {
    lua_pushinteger(L, LUA_TUSERDATA); lua_pushcclosure(L, prim_is_closure, 1);
  } else {
    #if !MATCH_CHECKERS && !defined(MATCH_METAFIELD)
    return 0;
    #endif

    // Match for checkers.
    #if MATCH_CHECKERS
    lua_getfield(L, -2, "checkers");              // checkers, nil, typecheck, key
    lua_pushstring(L, key);                       // key+2, checkers, nil, typecheck, key
    int t = lua_gettable(L, -2);
    if (t == LUA_TFUNCTION) {                     // checkers[key+2], checkers, nil, typecheck, key
      goto success;
    }

    #if !defined(MATCH_METAFIELD)
    return 0;
    #endif
    #endif

    // Match for metafield.
    #ifdef MATCH_METAFIELD
    lua_pushstring(L, key);
    lua_pushcclosure(L, metafield_is_closure, 1);
    #endif
  }

success: // matched func, ..., key
  lua_copy(L, 1, -2); // matched func, key, ...
  lua_copy(L, -1, -3); // matched func, key, matched func
  lua_rawgeti(L, LUA_REGISTRYINDEX, moduleRef); // typecheck, ...
  lua_copy(L, -1, 1); lua_pop(L, 1); // matched func, key, matched func, ... typecheck
  lua_rawset(L, 1); // matched func, ... typecheck
  return 1;
}

int MODULE_LUAOPEN_FN(lua_State *L) {
    lua_createtable(L, 0, 1); // typecheck
    lua_pushcfunction(L, typecheck_typecheck); lua_setfield(L, -2, "typecheck"); // typecheck
    lua_pushcfunction(L, typecheck_typematch); lua_setfield(L, -2, "typematch"); // typecheck
    lua_pushcfunction(L, typecheck_argscheck); lua_setfield(L, -2, "argscheck"); // typecheck
    lua_pushcfunction(L, typecheck_vargcheck); lua_setfield(L, -2, "vargcheck"); // typecheck
    if (lua_getglobal(L, "_DEBUG") != LUA_TNIL && lua_toboolean(L, -1)) { // _DEBUG on, typecheck
      lua_pushcfunction(L, typecheck_sigcheck);  lua_setfield(L, -3, "sigcheck"); // typecheck
    } else { // _DEBUG off, typecheck.
      lua_pushcfunction(L, typecheck_sigcheckoff);  lua_setfield(L, -3, "sigcheck"); // typecheck
    }
    lua_pop(L, 1); // typecheck
    #if MATCH_CHECKERS
    lua_newtable(L); // checkers, typecheck
    lua_setfield(L, -2, "checkers"); // typecheck
    #endif
    lua_pushvalue(L, -1); // typecheck, typecheck
    moduleRef = luaL_ref(L, LUA_REGISTRYINDEX); // typecheck
    lua_createtable(L, 0, 1); // metatable, typecheck
    lua_pushcfunction(L, typecheck_meta__index); lua_setfield(L, -2, "__index"); // metatable, typecheck
    lua_setmetatable(L, -2); // typecheck

    return 1;
}
