#include <lua.h>
#include <lauxlib.h>

#pragma mark - Marcos

#define MODULE_LUAOPEN_FN luaopen_fn_internal

static int partial_closure(lua_State *L) {
    const int npargs = (int)lua_tointeger(L, lua_upvalueindex(1));
    const int nargs = lua_gettop(L);

    lua_settop(L, nargs + npargs + 1); // nil..., args...
    lua_rotate(L, 1, npargs + 1);      // args..., nil...

    // Fill nils with func and partial args.
    for (int i = 2; i <= npargs + 2; i++) {
        lua_copy(L, lua_upvalueindex(i), i - 1);
    }

    lua_call(L, npargs + nargs, LUA_MULTRET);
    return lua_gettop(L);
}

static int partialr_closure(lua_State *L) {
    const int npargs = (int)lua_tointeger(L, lua_upvalueindex(1));
    const int nargs = lua_gettop(L);

    lua_settop(L, nargs + npargs + 1); // nil..., args...
    lua_rotate(L, 1, 1);               // nil..., args..., nil

    // Fill nils with func and partial args.
    lua_copy(L, lua_upvalueindex(2), 1);
    for (int i = 3; i <= npargs + 2; i++) {
        lua_copy(L, lua_upvalueindex(i), nargs + i - 1);
    }

    lua_call(L, npargs + nargs, LUA_MULTRET);
    return lua_gettop(L);
}

static int partial(lua_State *L, int left) {
    int nargs = lua_gettop(L) - 1;
    if (nargs >= 254) luaL_error(L, "too many arguments");
    else if(nargs <= 0) return 1;

    lua_pushinteger(L, nargs);                                                 // nargs, args..., func
    lua_insert(L, 1);                                                          // args..., func, nargs
    lua_pushcclosure(L, left ? partial_closure : partialr_closure, nargs + 2); // partial closure
    return 1;
}

static int fn_partial(lua_State *L) {
    return partial(L, 1);
}

static int fn_partialr(lua_State *L) {
    return partial(L, 0);
}

int MODULE_LUAOPEN_FN(lua_State *L) {
    lua_newtable(L);
    lua_pushcfunction(L, fn_partial); lua_setfield(L, -2, "partial");
    lua_pushcfunction(L, fn_partialr); lua_setfield(L, -2, "partialr");
    return 1;
}
