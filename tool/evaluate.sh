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
