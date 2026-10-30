/* Loads an arbitrary chunk (Lua 5.1 source or precompiled bytecode) through SRB2's bundled blua,
 * exactly as lua_script.c's LUA_LoadFile does for an addon's Lua lump. Load only: nothing runs. */
#include <stddef.h>
#include <stdint.h>

#include "lua.h"
#include "lauxlib.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	lua_State *L = luaL_newstate();
	int rc;

	if (!L)
		return -1;
	rc = luaL_loadbuffer(L, (const char *)data, size, "@fuzz.lua");
	lua_close(L);
	return rc ? -1 : 0;
}
