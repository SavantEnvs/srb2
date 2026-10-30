/* Known-answer probes for the code the fuzz targets exercise, built with the project's NORMAL
 * flags. mayhem/test.sh compares every line printed here against fixed expected values.
 *   selftest png <file>             decode to RGBA with the bundled libpng, print geometry + pixel hash
 *   selftest lua <chunk>            run a chunk in blua, print its result
 *   selftest luaerr <chunk>         print the load error blua reports for a bad chunk
 *   selftest patch <file> <flags>   Doom patch -> flat conversion
 *   selftest luadump <chunk> <out>  write the compiled bytecode of a chunk (seed generation)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "png.h"
#include "lua.h"
#include "lauxlib.h"

int selftest_patch(const char *path, int flags);

static int cmd_png(const char *path)
{
	png_image img;
	unsigned char *pix;
	size_t i, n;
	unsigned long hash = 2166136261UL;

	memset(&img, 0, sizeof img);
	img.version = PNG_IMAGE_VERSION;
	if (!png_image_begin_read_from_file(&img, path))
	{
		printf("decode error: %s\n", img.message);
		return 1;
	}
	img.format = PNG_FORMAT_RGBA;
	n = PNG_IMAGE_SIZE(img);
	pix = malloc(n);
	if (!pix || !png_image_finish_read(&img, NULL, pix, 0, NULL))
	{
		printf("decode error: %s\n", img.message);
		return 1;
	}
	for (i = 0; i < n; i++)
		hash = (hash ^ pix[i]) * 16777619UL & 0xffffffffUL;
	printf("%ux%u\n", (unsigned)img.width, (unsigned)img.height);
	printf("first %02x%02x%02x%02x\n", pix[0], pix[1], pix[2], pix[3]);
	printf("last %02x%02x%02x%02x\n", pix[n - 4], pix[n - 3], pix[n - 2], pix[n - 1]);
	printf("fnv %08lx\n", hash);
	free(pix);
	return 0;
}

static int cmd_lua(const char *chunk, int showerr)
{
	lua_State *L = luaL_newstate();

	if (luaL_loadbuffer(L, chunk, strlen(chunk), "=probe"))
	{
		if (showerr)
			printf("%s\n", lua_tostring(L, -1));
		return showerr ? 0 : 1;
	}
	if (lua_pcall(L, 0, 1, 0))
	{
		printf("runtime error: %s\n", lua_tostring(L, -1));
		return 1;
	}
	if (lua_isnumber(L, -1))
		printf("%ld\n", (long)lua_tonumber(L, -1));
	else
		printf("%s\n", lua_tostring(L, -1));
	lua_close(L);
	return 0;
}

static int writer(lua_State *L, const void *p, size_t sz, void *ud)
{
	(void)L;
	return fwrite(p, 1, sz, (FILE *)ud) != sz;
}

static int cmd_luadump(const char *chunk, const char *out)
{
	lua_State *L = luaL_newstate();
	FILE *f = fopen(out, "wb");

	if (!f || luaL_loadbuffer(L, chunk, strlen(chunk), "=seed"))
		return 1;
	lua_dump(L, writer, f);
	fclose(f);
	return 0;
}

int main(int argc, char **argv)
{
	if (argc >= 3 && !strcmp(argv[1], "png"))
		return cmd_png(argv[2]);
	if (argc >= 3 && !strcmp(argv[1], "lua"))
		return cmd_lua(argv[2], 0);
	if (argc >= 3 && !strcmp(argv[1], "luaerr"))
		return cmd_lua(argv[2], 1);
	if (argc >= 4 && !strcmp(argv[1], "patch"))
		return selftest_patch(argv[2], atoi(argv[3]));
	if (argc >= 4 && !strcmp(argv[1], "luadump"))
		return cmd_luadump(argv[2], argv[3]);
	fprintf(stderr, "usage: selftest png|lua|luaerr|patch|luadump ...\n");
	return 2;
}
