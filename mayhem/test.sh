#!/usr/bin/env bash
#
# mayhem/test.sh — runs the known-answer selftest (built by mayhem/build.sh with normal flags) and
# compares each probe against fixed expected output: libpng pixel decoding, blua compile+run and
# error reporting, and SRB2's Doom-patch conversion.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

SELFTEST="$SRC/out/selftest"
[ -x "$SELFTEST" ] || { echo "missing $SELFTEST: mayhem/build.sh did not produce it" >&2; emit_ctrf selftest 0 1; exit 1; }

PNGS="$SRC/mayhem/libpng_read_fuzzer/testsuite"
PATCHES="$SRC/mayhem/fuzz_doom_patch/testsuite"
passed=0 failed=0

# check <name> <expected> <command...>: the command's stdout must equal expected exactly.
check() {
  local name="$1" expected="$2" actual; shift 2
  actual="$("$@" 2>&1)"
  if [ "$actual" = "$expected" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL $name" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
  fi
}

nl=$'\n'

check png-basn0g08 "32x32${nl}first 000000ff${nl}last 222222ff${nl}fnv 632214b8" "$SELFTEST" png "$PNGS/basn0g08.png"
check png-basn2c08 "32x32${nl}first ffffffff${nl}last 000000ff${nl}fnv e4b33f25" "$SELFTEST" png "$PNGS/basn2c08.png"
check png-basn3p08 "32x32${nl}first 150000ff${nl}last ffffffff${nl}fnv 3488cddd" "$SELFTEST" png "$PNGS/basn3p08.png"
check png-basn6a08 "32x32${nl}first ff003500${nl}last 0063ffff${nl}fnv aaf15075" "$SELFTEST" png "$PNGS/basn6a08.png"
check png-basn4a08 "32x32${nl}first ffffff00${nl}last 000000ff${nl}fnv a8ff270d" "$SELFTEST" png "$PNGS/basn4a08.png"
check png-basn2c16 "32x32${nl}first ffff00ff${nl}last 0000ffff${nl}fnv 8840afbf" "$SELFTEST" png "$PNGS/basn2c16.png"
check png-ibasn6a16 "32x32${nl}first ffff0000${nl}last 0000ff00${nl}fnv 24546931" "$SELFTEST" png "$PNGS/ibasn6a16.png"

check lua-arith  "42" "$SELFTEST" lua "return 6*7"
check lua-loop   "110" "$SELFTEST" lua "local t={} for i=1,10 do t[i]=i*i end return t[10]+#t"
check lua-string "hello world" "$SELFTEST" lua "return 'hello' .. ' ' .. 'world'"
check lua-synerr1 "probe:1: unexpected symbol near '='" "$SELFTEST" luaerr "x = = 1"
check lua-synerr2 "probe:1: unexpected symbol near '<eof>'" "$SELFTEST" luaerr "return 1 +"

check patch-solid-0 "doompatch 4x4 flat: 00 10 20 30 01 11 21 31 02 12 22 32 03 13 23 33${nl}patch 4x4 offs=2,4 flat: 00 10 20 30 01 11 21 31 02 12 22 32 03 13 23 33" "$SELFTEST" patch "$PATCHES/solid_4x4.lmp" 0
check patch-solid-1 "doompatch 4x4 flat: 30 20 10 00 31 21 11 01 32 22 12 02 33 23 13 03${nl}patch 4x4 offs=2,4 flat: 30 20 10 00 31 21 11 01 32 22 12 02 33 23 13 03" "$SELFTEST" patch "$PATCHES/solid_4x4.lmp" 1
check patch-onepx   "doompatch 1x1 flat: 05${nl}patch 1x1 offs=0,0 flat: 05" "$SELFTEST" patch "$PATCHES/one_px.lmp" 0
check patch-gaps    "doompatch 6x8 flat: 01 ff ff 07 ff ff 02 ff ff 07 09 ff ff ff 0a 07 ff ff ff ff 0b 07 08 ff 03 ff 0c 07 08 ff 04 ff 0d 07 ff ff 05 ff 0e 07 ff ff ff ff 0f 07 ff ff${nl}patch 6x8 offs=0,0 flat: 01 ff ff 07 ff ff 02 ff ff 07 09 ff ff ff 0a 07 ff ff ff ff 0b 07 08 ff 03 ff 0c 07 08 ff 04 ff 0d 07 ff ff 05 ff 0e 07 ff ff ff ff 0f 07 ff ff" "$SELFTEST" patch "$PATCHES/gaps_6x8.lmp" 0

emit_ctrf "srb2-selftest" "$passed" "$failed"
