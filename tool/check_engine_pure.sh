#!/usr/bin/env bash
# Gate: lib/engine must stay pure Dart.
# Rules (tightened for Phase E, per the Opus review of PR #7 on issue #2):
#  - Imports/exports: only dart:core, dart:math, dart:collection,
#    dart:convert, relative paths, and package:game_puzzle/engine/**.
#    This bans package:flutter*, dart:ui, dart:io, flutter_test, and any
#    import reaching outside lib/engine.
#  - Banned APIs: DateTime.now() and Random() with no seed.
#    Inject clock and rng instead (harness/MUSE_STEPS.md, Phase E risks).
set -u
if [ ! -d lib/engine ]; then
  echo "check_engine_pure: lib/engine does not exist yet - nothing to check."
  exit 0
fi
fail=0

imports=$(grep -rhnE "^[[:space:]]*(import|export)[[:space:]]+['\"]" lib/engine || true)
if [ -n "$imports" ]; then
  while IFS= read -r line; do
    uri=$(printf '%s' "$line" | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/")
    case "$uri" in
      dart:core|dart:math|dart:collection|dart:convert) ;;
      package:game_puzzle/engine/*) ;;
      ./*|../*) ;;
      *) echo "FAIL: import not allowed in lib/engine: $line"; fail=1 ;;
    esac
  done <<EOF
$imports
EOF
fi

hits=$(grep -rnE "DateTime\.now\(|Random\([[:space:]]*\)" lib/engine || true)
if [ -n "$hits" ]; then
  echo "FAIL: banned APIs in lib/engine (DateTime.now / unseeded Random):"
  echo "$hits"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "check_engine_pure: OK (import allowlist respected, no DateTime.now()/Random() in lib/engine)"
