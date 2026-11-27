import 'dart:io';

// Gate: line coverage of lib/engine/ must be >= 80% (reads coverage/lcov.info).
// Exits non-zero when the coverage file is missing (expected before Phase E).
Future<void> main() async {
  const threshold = 80.0;
  final file = File('coverage/lcov.info');
  if (!await file.exists()) {
    stderr.writeln('FAIL: coverage/lcov.info not found. Run: flutter test --coverage');
    exit(1);
  }
  var found = 0;
  var hit = 0;
  var inEngine = false;
  for (final line in await file.readAsLines()) {
    if (line.startsWith('SF:')) {
      inEngine = line.substring(3).contains('lib/engine/');
    } else if (inEngine && line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (inEngine && line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    }
  }
  if (found == 0) {
    stderr.writeln('FAIL: no lib/engine lines in coverage report.');
    exit(1);
  }
  final pct = hit * 100 / found;
  stdout.writeln('lib/engine coverage: ${pct.toStringAsFixed(1)}% ($hit/$found lines)');
  if (pct < threshold) {
    stderr.writeln('FAIL: below ${threshold.toStringAsFixed(0)}% threshold.');
    exit(1);
  }
  stdout.writeln('check_coverage: OK');
}
