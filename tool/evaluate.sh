#!/usr/bin/env bash
# Evaluator gate runner. Deterministic gates first, in a fixed order.
# The LLM UX grading step is only reached when every deterministic gate passes.
# Usage: tool/evaluate.sh [--dry-run] [SPRINT]
# NOTE: CI does not run this script, but the E-step pre-checks live in
# tool/check_e_step.sh, which CI does run (Static gates job).
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

# Phase E pre-checks (T5, Opus review of PR #8) live in their own script,
# tool/check_e_step.sh, so CI runs them too (code-review of PR #9: a gate
# that only runs by hand is not a gate). evaluate.sh just calls it.
precheck_e() {
  bash tool/check_e_step.sh "$SPRINT"
}
precheck_s1() {
  bash tool/check_e_step.sh S1-01
  bash tool/check_e_step.sh S1-02
  bash tool/check_e_step.sh S1-03
}
case "$SPRINT" in
  E*) gate "E-step pre-checks" precheck_e ;;
  S1) gate "S-step pre-checks" precheck_s1 ;;
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
