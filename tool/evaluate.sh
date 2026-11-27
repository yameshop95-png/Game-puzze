#!/usr/bin/env bash
# Evaluator gate runner. Deterministic gates first, in a fixed order.
# The LLM UX grading step is only reached when every deterministic gate passes.
# Usage: tool/evaluate.sh [--dry-run] [SPRINT]
# NOTE: CI does not run this script. The E-step pre-checks below run only
# when the Evaluator runs evaluate.sh by hand (Opus review of PR #9).
set -u
DRY=0
if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi
SPRINT="${1:-all}"

gate() {
  local name="$1"; shift
  if [ $DRY -eq 1 ]; then
    echo "[dry-run] gate: $name -> $*"
    return 0
  fi
  echo "== gate: $name"
  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    exit 1
  fi
}

echo "Evaluating sprint: $SPRINT"

# Phase E pre-checks (T5, Opus review of PR #8): for E-steps the contract's
# tests must exist under test/engine, carry every test ID named in the
# contract, and contain no skipped tests; the step's engine package must
# exist. Lock membership and hashes are enforced by the tests-lock gate.
precheck_e() {
  local contract="harness/contracts/${SPRINT}.md"
  if [ ! -f "$contract" ]; then
    echo "FAIL: $contract not found"
    return 1
  fi
  local subdir=""
  case "$SPRINT" in
    E1) subdir="jigsaw" ;;
    *)
      echo "FAIL: no engine package mapping for step $SPRINT (add it to precheck_e before running this step)"
      return 1 ;;
  esac
  if [ ! -d "lib/engine/$subdir" ]; then
    echo "FAIL: lib/engine/$subdir does not exist"
    return 1
  fi
  if [ ! -d test/engine ]; then
    echo "FAIL: test/engine does not exist"
    return 1
  fi
  # Skipped tests, in any spelling: skip: <anything but false>, @Skip(...),
  # markTestSkipped(...).
  local skip_hits
  skip_hits=$( { grep -rnE "skip:" test/engine | grep -vE "skip:[[:space:]]*false([^A-Za-z0-9_]|$)" || true
                 grep -rnE "@Skip\(|markTestSkipped\(" test/engine || true; } )
  if [ -n "$skip_hits" ]; then
    echo "FAIL: skipped tests found under test/engine:"
    echo "$skip_hits"
    return 1
  fi
  # Every contract test ID must appear as an actual test declaration in a
  # *_test.dart file: comments are stripped first, the declaration must
  # start the line, and the ID must end at a non-digit boundary (so a
  # commented-out test, a string literal, or ENG-J-150 never counts for
  # ENG-J-15).
  local mirror f rel
  mirror=$(mktemp -d)
  while IFS= read -r f; do
    rel=${f#test/engine/}
    mkdir -p "$mirror/$(dirname "$rel")"
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
      }' "$f" > "$mirror/$rel"
  done <<EOFM
$(find test/engine -name '*_test.dart' -type f)
EOFM
  local ids id
  ids=$(grep -oE "[A-Z]+-[A-Z]-[0-9]+" "$contract" | sort -u)
  for id in $ids; do
    if ! grep -rqE "^[[:space:]]*(test|testWidgets)\([[:space:]]*['\"]${id}([^0-9]|$)" --include='*_test.dart' "$mirror"; then
      echo "FAIL: contract test ID $id has no test() declaration in a *_test.dart under test/engine"
      rm -rf "$mirror"
      return 1
    fi
  done
  rm -rf "$mirror"
  echo "E-step pre-checks OK for $SPRINT"
}
case "$SPRINT" in
  E*) gate "E-step pre-checks" precheck_e ;;
esac
if [ -f content/manifest.json ]; then
  gate "content validator" python3 content_pipeline/validate_manifest.py content/manifest.json
else
  echo "[skip] content validator: content/manifest.json not present yet"
fi
gate "engine purity" bash tool/check_engine_pure.sh
gate "tests lock" bash tool/verify_tests_lock.sh
gate "flutter analyze" flutter analyze
gate "unit tests + coverage" flutter test --coverage
gate "engine coverage >= 80%" dart tool/check_coverage.dart
if [ -d integration_test ]; then
  gate "integration tests" flutter test integration_test
else
  echo "[skip] integration tests: integration_test/ not present yet"
fi
echo "All deterministic gates passed. LLM UX grading (rubric: harness/ux_rubric.md, pass >= 8/10) may now run."
