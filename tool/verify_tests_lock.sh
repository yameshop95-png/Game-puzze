#!/usr/bin/env bash
# Gate: every test file must match the sha256 recorded in harness/tests.lock,
# and every test file on disk must be present in the lock.
set -u
LOCK="harness/tests.lock"
if [ ! -f "$LOCK" ]; then
  echo "FAIL: $LOCK not found. Tests are locked from Phase E onward."
  exit 1
fi
status=0
while read -r hash path; do
  [ -z "${hash:-}" ] && continue
  case "$hash" in \#*) continue ;; esac
  if [ ! -f "$path" ]; then
    echo "MISSING: $path"
    status=1
    continue
  fi
  actual=$(sha256sum "$path" | awk '{print $1}')
  if [ "$actual" != "$hash" ]; then
    echo "CHANGED: $path"
    status=1
  fi
done < "$LOCK"
for f in $(find test integration_test .maestro test_driver -type f 2>/dev/null); do
  if ! grep -q " $f\$" "$LOCK"; then
    echo "UNLOCKED: $f"
    status=1
  fi
done
if [ $status -eq 0 ]; then
  echo "verify_tests_lock: OK"
fi
exit $status
