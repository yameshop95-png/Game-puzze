#!/usr/bin/env bash
# Gate: lib/engine must stay pure Dart.
# Rules (tightened for Phase E; round 3 per the Opus review of PR #9):
#  - Imports/exports/parts: EVERY quoted URI of each directive is checked
#    (conditional imports included; directives are joined across lines up
#    to ";"). Allowed: dart:core, dart:math, dart:collection,
#    dart:convert; package:game_puzzle/engine/** with no ".." segment;
#    relative URIs (./x, ../x, or bare "piece.dart") that resolve to a
#    target INSIDE lib/engine.
#  - Banned APIs, matched as whole tokens with or without "()" so
#    tear-offs count too: DateTime.now, DateTime.timestamp, Random.secure,
#    Random.new, Stopwatch, and the unseeded Random()/Random(null)
#    Comments are stripped before scanning, so a comment merely naming a
#    banned API does not fail the gate. Seeded Random(seed) and names that
#    merely contain a banned word (SeededRandom) are allowed.
#    Inject clock and rng instead (harness/MUSE_STEPS.md, Phase E risks).
#  Known simplification: comment stripping cuts at the first "//" and
#  handles /* */ blocks without nesting; string literals containing
#  "//" or "/*" would be misread. Engine code has no such literals.
set -u
if [ ! -d lib/engine ]; then
  echo "check_engine_pure: lib/engine does not exist yet - nothing to check."
  exit 0
fi
fail=0
engine_root=$(realpath -m lib/engine)

# ---- Import / export / part URIs -------------------------------------------
# Directives may span several lines, so each directive is first joined up
# to its terminating ";" (line number of its first line is kept).
while IFS= read -r dart_file; do
  directives=$(awk '
    {
      if (collecting) {
        buf = buf " " $0
        if ($0 ~ /;/) { printf "%d\t%s\n", start, buf; collecting = 0 }
        next
      }
      if ($0 ~ /^[[:space:]]*(import|export|part)([[:space:]]|$)/) {
        start = NR; buf = $0
        if ($0 ~ /;/) { printf "%d\t%s\n", start, buf }
        else { collecting = 1 }
      }
    }' "$dart_file")
  [ -z "$directives" ] && continue
  while IFS=$'\t' read -r lineno line; do
    uris=$(printf '%s' "$line" | grep -oE "'[^']+'|\"[^\"]+\"" | tr -d "'\"" || true)
    [ -z "$uris" ] && continue
    while IFS= read -r uri; do
      [ -z "$uri" ] && continue
      case "$uri" in
        dart:core|dart:math|dart:collection|dart:convert) ;;
        dart:*)
          echo "FAIL: dart import not allowlisted: $dart_file:$lineno -> $uri"; fail=1 ;;
        package:game_puzzle/engine/*)
          case "/$uri/" in
            */../*) echo "FAIL: package URI with '..' segment: $dart_file:$lineno -> $uri"; fail=1 ;;
          esac ;;
        package:*)
          echo "FAIL: package import not allowlisted: $dart_file:$lineno -> $uri"; fail=1 ;;
        *:*)
          echo "FAIL: import URI scheme not allowlisted: $dart_file:$lineno -> $uri"; fail=1 ;;
        *)
          # No scheme: a relative URI (./x, ../x, or bare piece.dart).
          resolved=$(realpath -m "$(dirname "$dart_file")/$uri")
          case "$resolved" in
            "$engine_root"/*) ;;
            *) echo "FAIL: relative import escapes lib/engine: $dart_file:$lineno -> $uri"; fail=1 ;;
          esac ;;
      esac
    done <<EOFU
$uris
EOFU
  done <<EOFD
$directives
EOFD
done <<EOFF
$(find lib/engine -name '*.dart' -type f)
EOFF

# ---- Banned APIs (comments stripped, line numbers preserved) --------------
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
while IFS= read -r dart_file; do
  rel=${dart_file#lib/engine/}
  mkdir -p "$tmp/$(dirname "$rel")"
  awk '
    BEGIN { inblock = 0 }
    {
      line = $0; out = ""
      while (length(line) > 0) {
        if (inblock) {
          end = index(line, "*/")
          if (end == 0) { line = "" }
          else { line = substr(line, end + 2); inblock = 0 }
        } else {
          start = index(line, "/*")
          slash = index(line, "//")
          if (slash > 0 && (start == 0 || slash < start)) {
            out = out substr(line, 1, slash - 1); line = ""
          } else if (start > 0) {
            out = out substr(line, 1, start - 1)
            line = substr(line, start + 2); inblock = 1
          } else {
            out = out line; line = ""
          }
        }
      }
      print out
    }' "$dart_file" > "$tmp/$rel"
done <<EOFF
$(find lib/engine -name '*.dart' -type f)
EOFF

banned='(^|[^A-Za-z0-9_])(DateTime\.now|DateTime\.timestamp|Random\.secure|Random\.new|Stopwatch)([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])Random[[:space:]]*\([[:space:]]*(null)?[[:space:]]*\)'
hits=$(grep -rnE "$banned" "$tmp" || true)
if [ -n "$hits" ]; then
  echo "FAIL: banned APIs in lib/engine (DateTime.now/timestamp, Random.secure, Random.new, unseeded Random, Stopwatch):"
  printf '%s\n' "$hits" | sed "s|$tmp/|lib/engine/|"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "check_engine_pure: OK (all import URIs allowlisted + contained, no banned APIs in lib/engine)"
