import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test bootstrap for the whole test/ tree (contract
/// S1-03, SA-UI-5): loads the Roboto family bundled in
/// the Flutter SDK before any test runs, so golden
/// files render with the real UI font and produce the
/// same pixels on the Linux CI runner and on a local
/// Linux machine. Without this, flutter_test falls
/// back to the Ahem test font and goldens carry no
/// visual signal.
///
/// Loading is best-effort: if the SDK font directory
/// cannot be found, tests still run (only golden
/// comparisons would render differently).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadRobotoFromSdk();
  await testMain();
}

Future<void> _loadRobotoFromSdk() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? _sdkRootFallback();
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!await dir.exists()) return;
  final loader = FontLoader('Roboto');
  var found = false;
  await for (final entity in dir.list()) {
    if (entity is File &&
        entity.path.split(Platform.pathSeparator).last.startsWith('Roboto-') &&
        entity.path.endsWith('.ttf')) {
      loader.addFont(
        entity.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
      found = true;
    }
  }
  if (found) await loader.load();
}

/// FLUTTER_ROOT is set by the flutter tool when it
/// runs tests; this fallback derives the SDK root
/// from the flutter_tester executable path (inside
/// bin/cache/artifacts/engine/ under the SDK root)
/// in case the variable is ever absent.
String? _sdkRootFallback() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    dir = dir.parent;
  }
  return Directory(
        '${dir.path}/bin/cache/artifacts/material_fonts',
      ).existsSync()
      ? dir.path
      : null;
}
