#!/usr/bin/env bash
#
# mayhem/build.sh — builds SRB2's bundled libpng/zlib, its blua Lua interpreter and its picture
# code into three fuzz harnesses (+ standalone reproducers) and a normal-flags selftest.
# Everything is compiled from in-tree sources; nothing is fetched.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

PNG="$SRC/libs/libpng-src"
ZLIB="$SRC/libs/zlib"
BLUA="$SRC/src/blua"
BUILD="$SRC/build"
OUT="$SRC/out"

PNG_SRCS="png pngerror pngget pngmem pngpread pngread pngrio pngrtran pngrutil pngset pngtrans pngwio pngwrite pngwtran pngwutil"
ZLIB_SRCS="adler32 compress crc32 deflate infback inffast inflate inftrees trees uncompr zutil"
LUA_SRCS="lapi lbaselib ldo lfunc linit liolib llex lmem lobject lstate lstrlib ltablib lundump lzio lauxlib lcode ldebug ldump lgc lopcodes lparser lstring ltable ltm lvm loslib"
PICTURE_SRCS="r_picformats r_patch"

# compile_set <variant> <cflags> — variant "fuzz" is instrumented, "plain" uses the normal flags.
compile_set() {
  local variant="$1" cflags="$2" d="$BUILD/$1"
  mkdir -p "$d/png" "$d/zlib" "$d/blua" "$d/pic"
  cp "$PNG/scripts/pnglibconf.h.prebuilt" "$d/pnglibconf.h"
  {
    for f in $PNG_SRCS;     do echo "$PNG/$f.c|$d/png/$f.o|-I$d -I$PNG -I$ZLIB"; done
    for f in $ZLIB_SRCS;    do echo "$ZLIB/$f.c|$d/zlib/$f.o|-I$ZLIB"; done
    for f in $LUA_SRCS;     do echo "$BLUA/$f.c|$d/blua/$f.o|-I$BLUA"; done
    for f in $PICTURE_SRCS; do echo "$SRC/src/$f.c|$d/pic/$f.o|-I$SRC/src -I$BLUA"; done
    echo "$SRC/mayhem/harnesses/srb2_stubs.c|$d/pic/srb2_stubs.o|-I$SRC/src -I$BLUA"
  } | xargs -P "$MAYHEM_JOBS" -I{} bash -c '
      IFS="|" read -r src obj inc <<< "$1"
      $CC '"$cflags"' -w -ffunction-sections -fdata-sections $inc -c "$src" -o "$obj"' _ {}
  ar rcs "$d/libpng.a"  "$d"/png/*.o
  ar rcs "$d/libz.a"    "$d"/zlib/*.o
  ar rcs "$d/liblua.a"  "$d"/blua/*.o
  ar rcs "$d/libpic.a"  "$d"/pic/*.o
}

# 1) Selftest (normal flags): a clean build the oracle in test.sh runs.
mkdir -p "$OUT"
compile_set plain "-O2 $COVERAGE_FLAGS"
P="$BUILD/plain"
$CC -O2 $COVERAGE_FLAGS -w -I"$P" -I"$PNG" -I"$ZLIB" -I"$BLUA" -I"$SRC/src" \
    "$SRC/mayhem/selftest/selftest.c" "$SRC/mayhem/selftest/selftest_patch.c" \
    "$P/libpic.a" "$P/liblua.a" "$P/libpng.a" "$P/libz.a" \
    -Wl,--gc-sections -lm -o "$OUT/selftest"

# 2) Fuzz and standalone builds: project code and harnesses instrumented.
FLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS -O1"
compile_set fuzz "$FLAGS -fsanitize=fuzzer-no-link"
F="$BUILD/fuzz"
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$F/lsan_off.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$F/standalone_main.o"

# link_pair <name> <harness-obj> <libs...>.
link_pair() {
  local name="$1" harness="$2"; shift 2
  $CXX $FLAGS $LIB_FUZZING_ENGINE "$harness" "$F/lsan_off.o" "$@" -Wl,--gc-sections -lm -o "$SRC/$name"
  $CXX $FLAGS "$F/standalone_main.o" "$harness" "$F/lsan_off.o" "$@" -Wl,--gc-sections -lm -o "$SRC/$name-standalone"
}

# libpng_read_fuzzer: upstream's own OSS-Fuzz harness, unmodified.
$CXX $FLAGS -fsanitize=fuzzer-no-link -std=c++11 -w -I"$F" -I"$PNG" -I"$ZLIB" \
    -c "$PNG/contrib/oss-fuzz/libpng_read_fuzzer.cc" -o "$F/libpng_read_fuzzer.o"
link_pair libpng_read_fuzzer "$F/libpng_read_fuzzer.o" "$F/libpng.a" "$F/libz.a"

$CC $FLAGS -fsanitize=fuzzer-no-link -w -I"$BLUA" \
    -c "$SRC/mayhem/harnesses/fuzz_lua_load.c" -o "$F/fuzz_lua_load.o"
link_pair fuzz_lua_load "$F/fuzz_lua_load.o" "$F/liblua.a"

$CC $FLAGS -fsanitize=fuzzer-no-link -w -I"$SRC/src" -I"$BLUA" \
    -c "$SRC/mayhem/harnesses/fuzz_doom_patch.c" -o "$F/fuzz_doom_patch.o"
# r_picformats.c also holds the SPRTINFO parser, which refers to engine globals and functions the
# harness never calls (the sancov metadata keeps those sections alive through --gc-sections).
# Rather than link the whole engine, discover those leftover engine symbols with a throwaway link
# and give each a zero-filled placeholder object; nothing reachable from the harness uses them.
$CXX $FLAGS "$F/standalone_main.o" "$F/fuzz_doom_patch.o" "$F/lsan_off.o" "$F/libpic.a" \
    -Wl,--gc-sections -Wl,--warn-unresolved-symbols -lm \
    -o "$F/probe-link" 2> "$F/probe-link.log" || true
grep -o "undefined reference to \`[^']*'" "$F/probe-link.log" | sed "s/.*\`//; s/'$//" | sort -u |
  awk '{ printf "char %s[4096] __attribute__((aligned(16)));\n", $1 }' > "$F/engine_placeholders.c"
$CC $FLAGS -w -c "$F/engine_placeholders.c" -o "$F/engine_placeholders.o"
link_pair fuzz_doom_patch "$F/fuzz_doom_patch.o" "$F/libpic.a" "$F/engine_placeholders.o"
