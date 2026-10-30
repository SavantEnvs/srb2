/* Feeds an arbitrary Doom-format patch lump through SRB2's own picture code: the same
 * Picture_CheckIfDoomPatch validation the engine applies, then conversion of the raw lump and of
 * the internal patch_t built from it to flats (all four flip combinations). */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "doomdef.h"
#include "r_defs.h"
#include "r_patch.h"
#include "r_picformats.h"
#include "z_zone.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	softwarepatch_t *lump;
	patch_t *patch;
	INT16 width, height;
	int flags;

	if (size < 13)
		return -1;

	/* Picture_CheckIfDoomPatch reads columnofs[0..width) before it knows they fit in the lump;
	 * reject headers whose own column directory does not fit rather than hit that over-read. */
	width = (INT16)(data[0] | (data[1] << 8));
	height = (INT16)(data[2] | (data[3] << 8));
	if (width <= 0 || size < 8 + (size_t)width * 4)
		return -1;
	/* Keep the converted flats a sane size; this bounds memory, it is not a bug oracle. */
	if (height > 0 && (size_t)width * (size_t)height > ((size_t)1 << 22))
		return -1;

	lump = malloc(size);
	if (!lump)
		return -1;
	memcpy(lump, data, size);

	if (!Picture_CheckIfDoomPatch(lump, size))
	{
		free(lump);
		return -1;
	}

	for (flags = 0; flags < 4; flags++)
	{
		void *flat = Picture_Convert(PICFMT_DOOMPATCH, lump, PICFMT_FLAT, size, NULL, 0, 0, 0, 0, flags);
		Z_Free(flat);
	}

	patch = Patch_CreateFromDoomPatch(lump);
	for (flags = 0; flags < 4; flags++)
	{
		void *flat8 = Picture_Convert(PICFMT_PATCH, patch, PICFMT_FLAT, 0, NULL, 0, 0, 0, 0, flags);
		void *flat16 = Picture_Convert(PICFMT_PATCH, patch, PICFMT_FLAT16, 0, NULL, 0, 0, 0, 0, flags);
		Z_Free(flat8);
		Z_Free(flat16);
	}
	Patch_Free(patch);

	free(lump);
	return 0;
}
