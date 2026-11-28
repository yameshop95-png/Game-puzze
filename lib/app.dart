import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'data/app_database.dart';
import 'data/progress_dao.dart';
import 'features/completion/completion_screen.dart';
import 'features/jigsaw_play/jigsaw_play_screen.dart';
import 'features/mode_select/mode_select_screen.dart';
import 'features/word_play/word_play_screen.dart';
import 'features/theme_select/theme_progress.dart';
import 'features/theme_select/theme_select_screen.dart';
import 'services/asset_loader.dart';

/// Deterministic tray seed for device flows (contract
/// S1-05 §3, SA-S5-2): set with
/// `--dart-define=GAME_SEED=<n>` (Maestro uses 42).
/// Production builds pass nothing, the seed stays null
/// and puzzles shuffle freely.
const String _seedEnv = String.fromEnvironment('GAME_SEED');
final int? _gameSeed = _seedEnv.isEmpty ? null : int.tryParse(_seedEnv);

Random? _seededRng() => _gameSeed == null ? null : Random(_gameSeed);

/// The app shell (contract S1-04 §5): a [MaterialApp]
/// whose home is the theme select screen, wired so
/// tapping a theme opens the mode select screen for
/// that theme's first level-1 puzzle (S2-01,
/// SA-WP-1) — or an empty screen when the theme has
/// no content yet. Wiring lives here, not in the
/// screens (contract S1-03 SA-UI-4).
///
/// S1-05 (SA-S5-5): the shell owns ONE [ProgressDao]
/// for the app's whole life — the theme provider reads
/// through it and the completion handler writes through
/// the same instance.
///
/// [themeProvider], [assetLoader] and [dao] are
/// test-only overrides; production builds the real
/// provider and DAO over the drift database exactly as
/// S1-02/S1-03 settled.
class MyApp extends StatefulWidget {
  final ThemeProgressProvider? themeProvider;
  final AssetLoader? assetLoader;
  final ProgressDao? dao;

  const MyApp({super.key, this.themeProvider, this.assetLoader, this.dao});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// The single shared DAO (SA-S5-5); injected in
  /// tests, production drift database otherwise.
  late final ProgressDao _dao =
      widget.dao ?? ProgressDao(AppDatabase.production());

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Puzzle',
      home: Builder(
        builder: (context) {
          final loader = widget.assetLoader ?? AssetLoader();
          final provider =
              widget.themeProvider ??
              AssetThemeProgressProvider(
                assetLoader: loader,
                progressDao: _dao,
              );
          return ThemeSelectScreen(
            provider: provider,
            onThemeSelected: (themeId) =>
                _openPuzzle(context, loader, _dao, themeId),
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
  ProgressDao dao,
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
  if (asset == null) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const JigsawEmptyScreen()));
    return;
  }
  // S2-01 (SA-WP-1): a theme tap now lands on the mode
  // select screen; the chosen mode pushes its play
  // screen on top of it.
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ModeSelectScreen(
        asset: asset,
        image: _thumbImage(asset),
        onJigsawSelected: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _playScreen(context, dao, asset, tolerance),
            ),
          );
        },
        onWordsSelected: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _wordScreen(context, dao, asset),
            ),
          );
        },
      ),
    ),
  );
}

/// The thumb provider the mode select header and the
/// word play header share (contract S2-01 §2): the
/// asset's thumb path under the same `content/` prefix
/// as the play image (S1-01 §4).
ImageProvider _thumbImage(PuzzleAsset asset) =>
    ResizeImage(AssetImage('content/${asset.thumbPath}'), width: 600);

/// Builds a play screen for [asset] with the shell's
/// completion wiring (used for the first open and for
/// Play again). The image key prefixes the asset's
/// content-relative play path (S1-01 §4: paths are
/// relative to the `content/` directory).
JigsawPlayScreen _playScreen(
  BuildContext context,
  ProgressDao dao,
  PuzzleAsset asset,
  double tolerance,
) {
  return JigsawPlayScreen(
    asset: asset,
    image: ResizeImage(AssetImage('content/${asset.playPath}'), width: 1080),
    rng: _seededRng(),
    snapToleranceRatio: tolerance,
    onCompleted: (elapsed) =>
        _onPuzzleCompleted(context, dao, asset, tolerance, elapsed),
  );
}

/// Completion wiring (contract S1-05 §6, SA-S5-5):
/// record the solve first, then show the completion
/// screen — even when the write fails (the failure is
/// only debug-logged, never a crash). Play again pops
/// the completion screen and pushes a fresh play screen
/// for the same asset.
Future<void> _onPuzzleCompleted(
  BuildContext context,
  ProgressDao dao,
  PuzzleAsset asset,
  double tolerance,
  Duration elapsed,
) async {
  try {
    await dao.markSolved(
      asset.id,
      ProgressModes.jigsaw,
      solvedAt: DateTime.now(),
      timeSeconds: elapsed.inSeconds,
    );
  } catch (e) {
    debugPrint('markSolved failed for ${asset.id}: $e');
  }
  if (!context.mounted) return;
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => CompletionScreen(
        puzzleName: asset.title.isNotEmpty ? asset.title : asset.theme,
        elapsed: elapsed,
        // S1-05: the just-written time is the best;
        // querying the real best is left to S1-06+.
        bestSeconds: elapsed.inSeconds,
        onPlayAgain: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => _playScreen(context, dao, asset, tolerance),
            ),
          );
        },
      ),
    ),
  );
}

/// Builds a word play screen for [asset] with the
/// shell's completion wiring (contract S2-01 §2/§8).
WordPlayScreen _wordScreen(
  BuildContext context,
  ProgressDao dao,
  PuzzleAsset asset,
) {
  return WordPlayScreen(
    asset: asset,
    image: _thumbImage(asset),
    rng: _seededRng(),
    onCompleted: (elapsed) => _onWordCompleted(context, dao, asset, elapsed),
  );
}

/// Word completion wiring (contract S2-01 §8,
/// SA-WP-7): the mirror of the jigsaw handler with
/// mode `word` — record the solve first, then show
/// the completion screen, even when the write fails.
/// Play again pushes a fresh word play screen for
/// the same asset. Best keeps the S1-05 precedent:
/// the just-written time, no real DB query.
Future<void> _onWordCompleted(
  BuildContext context,
  ProgressDao dao,
  PuzzleAsset asset,
  Duration elapsed,
) async {
  try {
    await dao.markSolved(
      asset.id,
      ProgressModes.word,
      solvedAt: DateTime.now(),
      timeSeconds: elapsed.inSeconds,
    );
  } catch (e) {
    debugPrint('markSolved failed for ${asset.id}: $e');
  }
  if (!context.mounted) return;
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => CompletionScreen(
        puzzleName: asset.title.isNotEmpty ? asset.title : asset.theme,
        elapsed: elapsed,
        bestSeconds: elapsed.inSeconds,
        onPlayAgain: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => _wordScreen(context, dao, asset),
            ),
          );
        },
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
