import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'data/app_database.dart';
import 'data/progress_dao.dart';
import 'features/jigsaw_play/jigsaw_play_screen.dart';
import 'features/theme_select/theme_progress.dart';
import 'features/theme_select/theme_select_screen.dart';
import 'services/asset_loader.dart';

/// The app shell (contract S1-04 §5): a [MaterialApp]
/// whose home is the theme select screen, wired so
/// tapping a theme opens that theme's first level-1
/// puzzle — or an empty screen when the theme has no
/// content yet. Wiring lives here, not in the screens
/// (contract S1-03 SA-UI-4).
///
/// [themeProvider] and [assetLoader] are test-only
/// overrides; production builds the real provider over
/// the drift database exactly as S1-02/S1-03 settled.
class MyApp extends StatelessWidget {
  final ThemeProgressProvider? themeProvider;
  final AssetLoader? assetLoader;

  const MyApp({super.key, this.themeProvider, this.assetLoader});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Puzzle',
      home: Builder(
        builder: (context) {
          final loader = assetLoader ?? AssetLoader();
          final provider =
              themeProvider ??
              AssetThemeProgressProvider(
                assetLoader: loader,
                progressDao: ProgressDao(AppDatabase.production()),
              );
          return ThemeSelectScreen(
            provider: provider,
            onThemeSelected: (themeId) => _openPuzzle(context, loader, themeId),
          );
        },
      ),
    );
  }
}

/// Opens the first (theme, level 1) asset, or the empty
/// screen when there is none. Contract §5 words this as
/// `AssetLoader.firstAsset(themeId, level: 1)`; the
/// S1-01 loader has no such helper, so the selection
/// happens here over `load()` (flagged in the contract
/// for Opus to confirm). A manifest that fails to load
/// is treated as "no content" — the empty screen, never
/// a crash.
Future<void> _openPuzzle(
  BuildContext context,
  AssetLoader loader,
  String themeId,
) async {
  PuzzleAsset? found;
  try {
    final assets = await loader.load();
    for (final asset in assets) {
      if (asset.theme == themeId && asset.level == 1) {
        found = asset;
        break;
      }
    }
  } catch (_) {
    found = null;
  }
  final tolerance = await _snapToleranceRatio();
  if (!context.mounted) return;
  final asset = found;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => asset == null
          ? const JigsawEmptyScreen()
          : JigsawPlayScreen(
              asset: asset,
              image: ResizeImage(AssetImage(asset.playPath), width: 1080),
              snapToleranceRatio: tolerance,
            ),
    ),
  );
}

/// The shell's snap tolerance comes from
/// `config/game_config.json` (contract §6); 0.2 is the
/// settled default when the key or the file is absent.
Future<double> _snapToleranceRatio() async {
  try {
    // cache: false — the cached future of a bundled
    // string can outlive the caller (in tests it never
    // completes in a later test's zone; the file is
    // tiny and read once per navigation).
    final raw = await rootBundle.loadString(
      'config/game_config.json',
      cache: false,
    );
    final decoded = jsonDecode(raw);
    if (decoded is Map && decoded['snapToleranceRatio'] is num) {
      return (decoded['snapToleranceRatio'] as num).toDouble();
    }
  } catch (_) {
    // Fall through to the default.
  }
  return 0.2;
}

/// Shown when a theme has no level-1 puzzle yet
/// (contract §5): a plain scaffold, never a crash. The
/// Semantics label is the exact wording the contract
/// pins; the visible text stays English.
class JigsawEmptyScreen extends StatelessWidget {
  const JigsawEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Semantics(
          container: true,
          label: 'Chưa có câu đố',
          child: const ExcludeSemantics(child: Text('No puzzles yet')),
        ),
      ),
    );
  }
}
