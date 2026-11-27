#!/usr/bin/env bash
# Gate: lib/engine must stay pure Dart — no Flutter imports allowed.
set -u
if [ ! -d lib/engine ]; then
  echo "check_engine_pure: lib/engine does not exist yet - nothing to check."
  exit 0
fi
hits=$(grep -rn "package:flutter" lib/engine || true)
if [ -n "$hits" ]; then
  echo "FAIL: Flutter imports found in lib/engine:"
  echo "$hits"
  exit 1
fi
echo "check_engine_pure: OK (no package:flutter imports in lib/engine)"
