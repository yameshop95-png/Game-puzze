#!/usr/bin/env bash
# E-step pre-checks, extracted from evaluate.sh so CI can run them too
# (code-review of PR #9: a gate that only runs by hand is not a gate).
# Usage: tool/check_e_step.sh <STEP>   e.g. tool/check_e_step.sh E1
# Checks, for the step's contract:
#   - the contract file exists;
#   - the step's engine package exists (mapping below; an unmapped step
#     FAILs loudly instead of being skipped);
#   - test/engine exists and contains no skipped tests;
#   - every test ID in the contract is declared as test('<ID>...' or
#     testWidgets('<ID>...' in a *_test.dart file (comments stripped,
#     test( joined with the next line when split, digit boundary after
#     the ID).
set -u
cd "$(dirname "$0")/.."
STEP="${1:-}"
if [ -z "$STEP" ]; then
  echo "FAIL: usage: tool/check_e_step.sh <STEP>"
  exit 1
fi
contract="harness/contracts/${STEP}.md"
if [ ! -f "$contract" ]; then
  echo "FAIL: $contract not found"
  exit 1
fi
subdir=""
case "$STEP" in
  E1) subdir="jigsaw" ;;
  E2) subdir="jigsaw" ;;
  E3) subdir="jigsaw" ;;
  E4) subdir="word" ;;
  *)
    echo "FAIL: no engine package mapping for step $STEP (add it to check_e_step.sh before running this step)"
    exit 1 ;;
esac
if [ ! -d "lib/engine/$subdir" ]; then
  echo "FAIL: lib/engine/$subdir does not exist"
  exit 1
fi
if [ ! -d test/engine ]; then
  echo "FAIL: test/engine does not exist"
  exit 1
fi
# Skipped tests, in any spelling: skip <spaces>: <anything but false>,
# @Skip(...), markTestSkipped(...).
skip_hits=$( { grep -rnE "skip[[:space:]]*:" test/engine | grep -vE "skip[[:space:]]*:[[:space:]]*false([^A-Za-z0-9_]|$)" || true
               grep -rnE "@Skip\(|markTestSkipped\(" test/engine || true; } )
if [ -n "$skip_hits" ]; then
  echo "FAIL: skipped tests found under test/engine:"
  echo "$skip_hits"
  exit 1
fi
# Mirror the test files with comments stripped and triple-quoted
# string contents blanked (single-line strings kept — the test ID
# lives inside one), then join a line that ends with test( or
# testWidgets( onto the next line so a wrapped declaration still counts.
mirror=$(mktemp -d)
trap 'rm -rf "$mirror"' EXIT
while IFS= read -r f; do
  rel=${f#test/engine/}
  mkdir -p "$mirror/$(dirname "$rel")"
  awk -v blank_triple=1 -f tool/strip_comments.awk "$f" | awk '
    {
      if (hold != "") { $0 = hold $0; hold = "" }
      if ($0 ~ /(^|[^A-Za-z0-9_])(test|testWidgets)\([[:space:]]*$/) { hold = $0; next }
      print
    }
    END { if (hold != "") print hold }' > "$mirror/$rel"
done <<EOFM
$(find test/engine -name '*_test.dart' -type f)
EOFM
ids=$(grep -oE "[A-Z]+-[A-Z]-[0-9]+" "$contract" | sort -u)
for id in $ids; do
  if ! grep -rqE "^[[:space:]]*(test|testWidgets)\([[:space:]]*['\"]${id}([^0-9]|$)" --include='*_test.dart' "$mirror"; then
    echo "FAIL: contract test ID $id has no test() declaration in a *_test.dart under test/engine"
    exit 1
  fi
done
echo "check_e_step: OK for $STEP"
