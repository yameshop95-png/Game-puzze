#!/usr/bin/env bash
# Evaluator gate runner. Deterministic gates first, in a fixed order.
# The LLM UX grading step is only reached when every deterministic gate passes.
# Usage: tool/evaluate.sh [--dry-run] [SPRINT]
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
  esac
  if [ -n "$subdir" ] && [ ! -d "lib/engine/$subdir" ]; then
    echo "FAIL: lib/engine/$subdir does not exist"
    return 1
  fi
  if [ ! -d test/engine ]; then
    echo "FAIL: test/engine does not exist"
    return 1
  fi
  if grep -rnE "skip:[[:space:]]*(true|'|\")" test/engine >/dev/null 2>&1; then
    echo "FAIL: skipped tests found under test/engine:"
    grep -rnE "skip:" test/engine
    return 1
  fi
  local ids id
  ids=$(grep -oE "[A-Z]+-[A-Z]-[0-9]+" "$contract" | sort -u)
  for id in $ids; do
    if ! grep -rq "$id" test/engine; then
      echo "FAIL: contract test ID $id not found under test/engine"
      return 1
    fi
  done
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
