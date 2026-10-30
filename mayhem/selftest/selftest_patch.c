/* Known-answer probe for SRB2's Doom-patch -> flat conversion. Prints the converted flat as hex. */
#include <stdio.h>
#include <stdlib.h>

#include "doomdef.h"
#include "r_defs.h"
#include "r_patch.h"
#include "r_picformats.h"
#include "z_zone.h"

int selftest_patch(const char *path, int flags)
{
	FILE *f = fopen(path, "rb");
	size_t size = 0, cap = 4096, n, i;
	unsigned char *buf = malloc(cap), *flat;
	softwarepatch_t *lump;
	patch_t *patch;
	size_t outsize = 0;

	if (!f || !buf)
		return 1;
	while ((n = fread(buf + size, 1, cap - size, f)) > 0)
	{
		size += n;
		if (size == cap)
			buf = realloc(buf, cap *= 2);
	}
	fclose(f);

	lump = (softwarepatch_t *)buf;
	if (!Picture_CheckIfDoomPatch(lump, size))
	{
		printf("invalid\n");
		return 1;
	}

	flat = Picture_Convert(PICFMT_DOOMPATCH, lump, PICFMT_FLAT, size, &outsize, 0, 0, 0, 0, flags);
	printf("doompatch %dx%d flat:", lump->width, lump->height);
	for (i = 0; i < outsize; i++)
		printf(" %02x", flat[i]);
	printf("\n");
	Z_Free(flat);

	patch = Patch_CreateFromDoomPatch(lump);
	flat = Picture_Convert(PICFMT_PATCH, patch, PICFMT_FLAT, 0, &outsize, 0, 0, 0, 0, flags);
	printf("patch %dx%d offs=%d,%d flat:", patch->width, patch->height, patch->leftoffset, patch->topoffset);
	for (i = 0; i < outsize; i++)
		printf(" %02x", flat[i]);
	printf("\n");
	Z_Free(flat);
	Patch_Free(patch);
	free(buf);
	return 0;
}
