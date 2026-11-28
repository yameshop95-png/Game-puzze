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
# S-step pre-checks (S1-01, contract SA-6): the S steps live outside
# lib/engine + test/engine, so they get their own branch here instead
# of the engine mapping below. Checks, mirroring the E-step ones:
#   - the step's test file and lib file exist;
#   - no skipped tests in the step's test directory;
#   - every UNIT-AL ID in the contract is declared as test('<ID>...'
#     in the step's test file.
if [ "$STEP" = "S1-01" ]; then
  s_test="test/data/asset_loader_test.dart"
  s_lib="lib/services/asset_loader.dart"
  if [ ! -f "$s_test" ]; then
    echo "FAIL: $s_test does not exist"
    exit 1
  fi
  if [ ! -f "$s_lib" ]; then
    echo "FAIL: $s_lib does not exist"
    exit 1
  fi
  skip_hits=$( { grep -rnE "skip[[:space:]]*:" test/data | grep -vE "skip[[:space:]]*:[[:space:]]*false([^A-Za-z0-9_]|$)" || true
                 grep -rnE "@Skip\(|markTestSkipped\(" test/data || true; } )
  if [ -n "$skip_hits" ]; then
    echo "FAIL: skipped tests found under test/data:"
    echo "$skip_hits"
    exit 1
  fi
  s_ids=$(grep -oE "UNIT-AL-[0-9]+" "$contract" | sort -u)
  if [ -z "$s_ids" ]; then
    echo "FAIL: no UNIT-AL test IDs found in $contract"
    exit 1
  fi
  for id in $s_ids; do
    if ! grep -qE "^[[:space:]]*(test|testWidgets)\([[:space:]]*['\"]${id}([^0-9]|$)" "$s_test"; then
      echo "FAIL: contract test ID $id has no test() declaration in $s_test"
      exit 1
    fi
  done
  echo "check_e_step: OK for $STEP"
  exit 0
fi
# S1-02 branch (contract SA-DB-6): same shape as S1-01, for the
# drift data layer. Checks:
#   - the step's test file and both lib files exist;
#   - no skipped tests in the step's test directory;
#   - every UNIT-DB ID in the contract is declared as test('<ID>...'
#     in the step's test file.
if [ "$STEP" = "S1-02" ]; then
  s_test="test/data/app_database_test.dart"
  s_libs="lib/data/app_database.dart lib/data/progress_dao.dart"
  if [ ! -f "$s_test" ]; then
    echo "FAIL: $s_test does not exist"
    exit 1
  fi
  for s_lib in $s_libs; do
    if [ ! -f "$s_lib" ]; then
      echo "FAIL: $s_lib does not exist"
      exit 1
    fi
  done
  skip_hits=$( { grep -rnE "skip[[:space:]]*:" test/data | grep -vE "skip[[:space:]]*:[[:space:]]*false([^A-Za-z0-9_]|$)" || true
                 grep -rnE "@Skip\(|markTestSkipped\(" test/data || true; } )
  if [ -n "$skip_hits" ]; then
    echo "FAIL: skipped tests found under test/data:"
    echo "$skip_hits"
    exit 1
  fi
  s_ids=$(grep -oE "UNIT-DB-[0-9]+" "$contract" | sort -u)
  if [ -z "$s_ids" ]; then
    echo "FAIL: no UNIT-DB test IDs found in $contract"
    exit 1
  fi
  # dart format wraps long test names: a line ending in test( is
  # joined onto the next line before matching, mirroring the
  # E-step mirror logic below.
  s_joined=$(mktemp)
  awk '
    {
      if (hold != "") { $0 = hold $0; hold = "" }
      if ($0 ~ /(^|[^A-Za-z0-9_])(test|testWidgets)\([[:space:]]*$/) { hold = $0; next }
      print
    }
    END { if (hold != "") print hold }' "$s_test" > "$s_joined"
  for id in $s_ids; do
    if ! grep -qE "^[[:space:]]*(test|testWidgets)\([[:space:]]*['\"]${id}([^0-9]|$)" "$s_joined"; then
      echo "FAIL: contract test ID $id has no test() declaration in $s_test"
      rm -f "$s_joined"
      exit 1
    fi
  done
  rm -f "$s_joined"
  echo "check_e_step: OK for $STEP"
  exit 0
fi
# S1-03 branch (contract SA-UI-6): same shape as S1-01/S1-02, for
# the theme-select feature. Checks:
#   - lib/features/theme_select/ exists;
#   - the step's widget test file exists;
#   - the golden PNG and the test bootstrap exist (SA-UI-5);
#   - no skipped tests under test/features;
#   - every WID-TS ID in the contract is declared as test('<ID>...'
#     or testWidgets('<ID>...' in a *_test.dart under
#     test/features/theme_select/ (unit + widget files together).
if [ "$STEP" = "S1-03" ]; then
  s_dir="test/features/theme_select"
  s_test="$s_dir/theme_select_test.dart"
  if [ ! -d lib/features/theme_select ]; then
    echo "FAIL: lib/features/theme_select/ does not exist"
    exit 1
  fi
  if [ ! -f "$s_test" ]; then
    echo "FAIL: $s_test does not exist"
    exit 1
  fi
  if [ ! -f test/goldens/theme_select.png ]; then
    echo "FAIL: test/goldens/theme_select.png does not exist"
    exit 1
  fi
  if [ ! -f test/flutter_test_config.dart ]; then
    echo "FAIL: test/flutter_test_config.dart does not exist"
    exit 1
  fi
  skip_hits=$( { grep -rnE "skip[[:space:]]*:" test/features | grep -vE "skip[[:space:]]*:[[:space:]]*false([^A-Za-z0-9_]|$)" || true
                 grep -rnE "@Skip\(|markTestSkipped\(" test/features || true; } )
  if [ -n "$skip_hits" ]; then
    echo "FAIL: skipped tests found under test/features:"
    echo "$skip_hits"
    exit 1
  fi
  s_ids=$(grep -oE "WID-TS-[0-9]+" "$contract" | sort -u)
  if [ -z "$s_ids" ]; then
    echo "FAIL: no WID-TS test IDs found in $contract"
    exit 1
  fi
  # Join lines ending in test( / testWidgets( onto the next line
  # (dart format wraps long names), mirroring the S1-02 block.
  s_joined=$(mktemp)
  for f in "$s_dir"/*_test.dart; do
    awk '
      {
        if (hold != "") { $0 = hold $0; hold = "" }
        if ($0 ~ /(^|[^A-Za-z0-9_])(test|testWidgets)\([[:space:]]*$/) { hold = $0; next }
        print
      }
      END { if (hold != "") print hold }' "$f" >> "$s_joined"
  done
  for id in $s_ids; do
    if ! grep -qE "^[[:space:]]*(test|testWidgets)\([[:space:]]*['\"]${id}([^0-9]|$)" "$s_joined"; then
      echo "FAIL: contract test ID $id has no test() declaration under $s_dir"
      rm -f "$s_joined"
      exit 1
    fi
  done
  rm -f "$s_joined"
  echo "check_e_step: OK for $STEP"
  exit 0
fi
# S1-04 branch (contract S1-04 §11): same shape as
# S1-01..03, for the jigsaw play feature. Three test
# ID families live in three different places:
#   - WID-JP widget IDs in test/features/jigsaw_play/;
#   - IT-J integration IDs in integration_test/
#     (checked as declarations only — running them is
#     the CI android-it gate, contract S1-04 §11);
#   - the step's new ENG-J ID in
#     test/engine/jigsaw/board_test.dart.
# Checks:
#   - lib/features/jigsaw_play/ and lib/app.dart exist;
#   - both integration files and the widget test file
#     exist;
#   - no skipped tests under test/features or
#     integration_test;
#   - every WID-JP / IT-J / ENG-J ID in the contract
#     is declared as test('<ID>...' or
#     testWidgets('<ID>...' in its family's files.
if [ "$STEP" = "S1-04" ]; then
  w_dir="test/features/jigsaw_play"
  w_test="$w_dir/jigsaw_play_test.dart"
  i_dir="integration_test"
  i_files="$i_dir/jigsaw_snap_test.dart $i_dir/completion_event_test.dart"
  e_test="test/engine/jigsaw/board_test.dart"
  if [ ! -d lib/features/jigsaw_play ]; then
    echo "FAIL: lib/features/jigsaw_play/ does not exist"
    exit 1
  fi
  if [ ! -f lib/app.dart ]; then
    echo "FAIL: lib/app.dart does not exist"
    exit 1
  fi
  if [ ! -f "$w_test" ]; then
    echo "FAIL: $w_test does not exist"
    exit 1
  fi
  for i_file in $i_files; do
    if [ ! -f "$i_file" ]; then
      echo "FAIL: $i_file does not exist"
      exit 1
    fi
  done
  skip_hits=$( { grep -rnE "skip[[:space:]]*:" test/features "$i_dir" | grep -vE "skip[[:space:]]*:[[:space:]]*false([^A-Za-z0-9_]|$)" || true
                 grep -rnE "@Skip\(|markTestSkipped\(" test/features "$i_dir" || true; } )
  if [ -n "$skip_hits" ]; then
    echo "FAIL: skipped tests found under test/features or $i_dir:"
    echo "$skip_hits"
    exit 1
  fi
  # check_family greps the contract for one ID prefix
  # and requires every such ID to be declared in the
  # family's files, joining lines that end in test( /
  # testWidgets( onto the next line first (dart format
  # wraps long names), mirroring S1-02/S1-03.
  check_family() {
    local prefix="$1" label="$2"; shift 2
    local ids joined id
    ids=$(grep -oE "${prefix}-[0-9]+" "$contract" | sort -u)
    if [ -z "$ids" ]; then
      echo "FAIL: no $prefix test IDs found in $contract"
      exit 1
    fi
    joined=$(mktemp)
    for f in "$@"; do
      awk '
        {
          if (hold != "") { $0 = hold $0; hold = "" }
          if ($0 ~ /(^|[^A-Za-z0-9_])(test|testWidgets)\([[:space:]]*$/) { hold = $0; next }
          print
        }
        END { if (hold != "") print hold }' "$f" >> "$joined"
    done
    for id in $ids; do
      if ! grep -qE "^[[:space:]]*(test|testWidgets)\([[:space:]]*['\"]${id}([^0-9]|$)" "$joined"; then
        echo "FAIL: contract test ID $id has no test() declaration in $label"
        rm -f "$joined"
        exit 1
      fi
    done
    rm -f "$joined"
  }
  check_family "WID-JP" "$w_dir" "$w_dir"/*_test.dart
  check_family "IT-J" "$i_dir" "$i_dir"/*_test.dart
  check_family "ENG-J" "$e_test" "$e_test"
  echo "check_e_step: OK for $STEP"
  exit 0
fi
# S1-05 branch (contract S1-05 §9, SA-S5-8): same shape
# as S1-01..04, for the completion feature. Checks:
#   - test/features/completion/ exists;
#   - the completion widget test, the app-shell flow
#     test, the completion screen lib file and the
#     Maestro flow all exist;
#   - no skipped tests under test/features/completion
#     or test/features/app_shell;
#   - every WID-CP ID in the contract is declared in
#     the completion test file and every INT-CS ID in
#     the app-shell flow test file.
if [ "$STEP" = "S1-05" ]; then
  c_dir="test/features/completion"
  c_test="$c_dir/completion_screen_test.dart"
  a_dir="test/features/app_shell"
  a_test="$a_dir/completion_flow_test.dart"
  if [ ! -d "$c_dir" ]; then
    echo "FAIL: $c_dir/ does not exist"
    exit 1
  fi
  if [ ! -f "$c_test" ]; then
    echo "FAIL: $c_test does not exist"
    exit 1
  fi
  if [ ! -f "$a_test" ]; then
    echo "FAIL: $a_test does not exist"
    exit 1
  fi
  if [ ! -f lib/features/completion/completion_screen.dart ]; then
    echo "FAIL: lib/features/completion/completion_screen.dart does not exist"
    exit 1
  fi
  if [ ! -f .maestro/persistence_restart.yaml ]; then
    echo "FAIL: .maestro/persistence_restart.yaml does not exist"
    exit 1
  fi
  skip_hits=$( { grep -rnE "skip[[:space:]]*:" "$c_dir" "$a_dir" | grep -vE "skip[[:space:]]*:[[:space:]]*false([^A-Za-z0-9_]|$)" || true
                 grep -rnE "@Skip\(|markTestSkipped\(" "$c_dir" "$a_dir" || true; } )
  if [ -n "$skip_hits" ]; then
    echo "FAIL: skipped tests found under $c_dir or $a_dir:"
    echo "$skip_hits"
    exit 1
  fi
  # check_ids greps the contract for one ID prefix and
  # requires every such ID to be declared in the given
  # file, joining lines that end in test( / testWidgets(
  # onto the next line first (dart format wraps long
  # names), mirroring the S1-04 block.
  check_ids() {
    local prefix="$1" file="$2"
    local ids joined id
    ids=$(grep -oE "${prefix}-[0-9]+" "$contract" | sort -u)
    if [ -z "$ids" ]; then
      echo "FAIL: no $prefix test IDs found in $contract"
      exit 1
    fi
    joined=$(mktemp)
    awk '
      {
        if (hold != "") { $0 = hold $0; hold = "" }
        if ($0 ~ /(^|[^A-Za-z0-9_])(test|testWidgets)\([[:space:]]*$/) { hold = $0; next }
        print
      }
      END { if (hold != "") print hold }' "$file" > "$joined"
    for id in $ids; do
      if ! grep -qE "^[[:space:]]*(test|testWidgets)\([[:space:]]*['\"]${id}([^0-9]|$)" "$joined"; then
        echo "FAIL: contract test ID $id has no test() declaration in $file"
        rm -f "$joined"
        exit 1
      fi
    done
    rm -f "$joined"
  }
  check_ids "WID-CP" "$c_test"
  check_ids "INT-CS" "$a_test"
  echo "check_e_step: OK for $STEP"
  exit 0
fi
# S1-06 branch (contract S1-06 §7, SA-S6-6): same
# shape as S1-01..05, for performance + text
# scaling. Checks:
#   - the perf test, the perf driver and the
#     text-scale test all exist;
#   - no skipped tests in the text-scale directory
#     or the perf test;
#   - every PERF ID in the contract is declared in
#     integration_test/perf_test.dart and every
#     WID-FS ID in the text-scale test (declarations
#     only for PERF — running it is the CI
#     android-it gate, contract S1-04 Đ11).
if [ "$STEP" = "S1-06" ]; then
  p_test="integration_test/perf_test.dart"
  p_driver="test_driver/perf_driver.dart"
  f_dir="test/features/text_scale"
  f_test="$f_dir/text_scale_test.dart"
  if [ ! -f "$p_test" ]; then
    echo "FAIL: $p_test does not exist"
    exit 1
  fi
  if [ ! -f "$p_driver" ]; then
    echo "FAIL: $p_driver does not exist"
    exit 1
  fi
  if [ ! -f "$f_test" ]; then
    echo "FAIL: $f_test does not exist"
    exit 1
  fi
  skip_hits=$( { grep -rnE "skip[[:space:]]*:" "$f_dir" "$p_test" | grep -vE "skip[[:space:]]*:[[:space:]]*false([^A-Za-z0-9_]|$)" || true
                 grep -rnE "@Skip\(|markTestSkipped\(" "$f_dir" "$p_test" || true; } )
  if [ -n "$skip_hits" ]; then
    echo "FAIL: skipped tests found under $f_dir or in $p_test:"
    echo "$skip_hits"
    exit 1
  fi
  # check_ids mirrors the S1-05 block: grep the
  # contract for one ID prefix and require every
  # such ID to be declared in the given file,
  # joining lines that end in test( / testWidgets(
  # onto the next line first (dart format wraps
  # long names).
  check_ids() {
    local prefix="$1" file="$2"
    local ids joined id
    ids=$(grep -oE "${prefix}-[0-9]+" "$contract" | sort -u)
    if [ -z "$ids" ]; then
      echo "FAIL: no $prefix test IDs found in $contract"
      exit 1
    fi
    joined=$(mktemp)
    awk '
      {
        if (hold != "") { $0 = hold $0; hold = "" }
        if ($0 ~ /(^|[^A-Za-z0-9_])(test|testWidgets)\([[:space:]]*$/) { hold = $0; next }
        print
      }
      END { if (hold != "") print hold }' "$file" > "$joined"
    for id in $ids; do
      if ! grep -qE "^[[:space:]]*(test|testWidgets)\([[:space:]]*['\"]${id}([^0-9]|$)" "$joined"; then
        echo "FAIL: contract test ID $id has no test() declaration in $file"
        rm -f "$joined"
        exit 1
      fi
    done
    rm -f "$joined"
  }
  check_ids "PERF" "$p_test"
  check_ids "WID-FS" "$f_test"
  echo "check_e_step: OK for $STEP"
  exit 0
fi
subdir=""
case "$STEP" in
  E1) subdir="jigsaw" ;;
  E2) subdir="jigsaw" ;;
  E3) subdir="jigsaw" ;;
  E4) subdir="word" ;;
  E5) subdir="progress" ;;
  E6) subdir="content_mode" ;;
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
