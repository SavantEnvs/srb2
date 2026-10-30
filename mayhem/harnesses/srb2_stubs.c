/* Environment for linking SRB2's picture code (r_picformats.c, r_patch.c) without the engine:
 * the zone allocator becomes plain malloc/free so ASan sees every block, and the console
 * and error hooks are inert. I_Error is fatal in the engine too, so it aborts. */
#include <stdarg.h>
#include <stdlib.h>

#include "doomdef.h"
#include "z_zone.h"

void *Z_Malloc2(size_t size, INT32 tag, void *user, INT32 alignbits, const char *file, INT32 line)
{
	(void)tag; (void)user; (void)alignbits; (void)file; (void)line;
	return malloc(size ? size : 1);
}

void *Z_Calloc2(size_t size, INT32 tag, void *user, INT32 alignbits, const char *file, INT32 line)
{
	(void)tag; (void)user; (void)alignbits; (void)file; (void)line;
	return calloc(1, size ? size : 1);
}

void *Z_Realloc2(void *ptr, size_t size, INT32 tag, void *user, INT32 alignbits, const char *file, INT32 line)
{
	(void)tag; (void)user; (void)alignbits; (void)file; (void)line;
	return realloc(ptr, size ? size : 1);
}

void Z_Free2(void *ptr, const char *file, INT32 line)
{
	(void)file; (void)line;
	free(ptr);
}

void Z_IterateTags(INT32 lowtag, INT32 hightag, boolean (*iterfunc)(void *))
{
	(void)lowtag; (void)hightag; (void)iterfunc;
}

void I_Error(const char *error, ...)
{
	(void)error;
	abort();
}

void CONS_Alert(alerttype_t level, const char *fmt, ...)
{
	(void)level; (void)fmt;
}

void CONS_Debug(INT32 debugflags, const char *fmt, ...)
{
	(void)debugflags; (void)fmt;
}

/* Palette hooks for the RGBA conversion paths; a fixed gray ramp keeps them well defined. */
#include "r_data.h"

static RGBA_t master_palette[256];
RGBA_t *pMasterPalette = master_palette;

UINT8 NearestPaletteColor(UINT8 r, UINT8 g, UINT8 b, RGBA_t *palette)
{
	(void)palette;
	return (UINT8)(((unsigned)r + g + b) / 3);
}
