import '../../data/progress_dao.dart';
import '../../engine/progress/gate.dart';
import '../../services/asset_loader.dart';

/// One theme in the fixed catalog (contract S1-03,
/// SA-UI-2).
class ThemeInfo {
  final String id;
  final String displayName;

  const ThemeInfo(this.id, this.displayName);
}

/// The fixed theme catalog, in display order
/// (SA-UI-2: ids and order come from the manifest
/// schema enum; display names are pinned here). The
/// manifest is never used to derive this list — it
/// only supplies per-theme puzzle counts.
const List<ThemeInfo> themeCatalog = [
  ThemeInfo('animals', 'Animals'),
  ThemeInfo('landscapes', 'Landscapes'),
  ThemeInfo('space', 'Space'),
  ThemeInfo('maps', 'Maps'),
  ThemeInfo('landmarks', 'Landmarks'),
];

/// Display data for one theme card, fully computed
/// by [computeThemeViewModel].
class ThemeViewModel {
  final String themeId;
  final String displayName;

  /// How many puzzles of this theme currently exist
  /// in the manifest.
  final int puzzleCount;

  /// How many of those puzzles are solved, in any
  /// play mode.
  final int solvedCount;

  /// Whether the gate to the theme's next level is
  /// still closed (contract §2).
  final bool nextLevelLocked;

  const ThemeViewModel({
    required this.themeId,
    required this.displayName,
    required this.puzzleCount,
    required this.solvedCount,
    required this.nextLevelLocked,
  });
}

/// Data source for the theme select screen
/// (SA-UI-3): the widget depends only on this
/// interface, never on the DAO or loader directly.
abstract class ThemeProgressProvider {
  Future<List<ThemeViewModel>> loadThemes();
}

/// The E5 gate, as a value so unit tests can
/// substitute a fake (SA-UI-3 names the gate as an
/// input of [computeThemeViewModel]).
typedef GateCheck =
    bool Function(int solvedOwned, int totalOwned, double threshold);

/// Computes the view model for one catalog theme.
///
/// - `puzzleCount` counts manifest records with this
///   theme (SA-UI-2: the manifest only counts).
/// - `solvedCount` counts this theme's puzzles that
///   are solved in either play mode — the E5 gate
///   counts a solve in any mode, and aggregation is
///   the call layer's job (contract E5, decision 5).
/// - Until the S3 store exists, everything in the
///   manifest counts as owned, so
///   `totalOwned = puzzleCount` (SA-UI-3).
/// - [threshold] is passed in, never read from a
///   file here; 0.75 mirrors `harness/thresholds.yaml`
///   (the single source) via `config/game_config.json`.
///
/// Throws [ArgumentError] when [themeId] is not in
/// the catalog — the catalog is the only source of
/// display names, so an unknown id is a programming
/// error, not data to render.
Future<ThemeViewModel> computeThemeViewModel(
  String themeId, {
  required AssetLoader assetLoader,
  required ProgressDao progressDao,
  GateCheck gate = isUnlocked,
  double threshold = 0.75,
}) async {
  ThemeInfo? info;
  for (final entry in themeCatalog) {
    if (entry.id == themeId) {
      info = entry;
      break;
    }
  }
  if (info == null) {
    throw ArgumentError.value(themeId, 'themeId', 'not in the theme catalog');
  }

  final assets = await assetLoader.load();
  final ownedIds = <String>{
    for (final asset in assets)
      if (asset.theme == themeId) asset.id,
  };
  final solvedIds = <String>{
    ...await progressDao.solvedIds(ProgressModes.jigsaw),
    ...await progressDao.solvedIds(ProgressModes.word),
  };
  final solvedCount = ownedIds.intersection(solvedIds).length;
  final totalOwned = ownedIds.length;

  return ThemeViewModel(
    themeId: themeId,
    displayName: info.displayName,
    puzzleCount: totalOwned,
    solvedCount: solvedCount,
    nextLevelLocked: !gate(solvedCount, totalOwned, threshold),
  );
}

/// The production [ThemeProgressProvider]: computes
/// every catalog theme, in catalog order.
class AssetThemeProgressProvider implements ThemeProgressProvider {
  final AssetLoader assetLoader;
  final ProgressDao progressDao;
  final GateCheck gate;
  final double threshold;

  const AssetThemeProgressProvider({
    required this.assetLoader,
    required this.progressDao,
    this.gate = isUnlocked,
    this.threshold = 0.75,
  });

  @override
  Future<List<ThemeViewModel>> loadThemes() async {
    return [
      for (final info in themeCatalog)
        await computeThemeViewModel(
          info.id,
          assetLoader: assetLoader,
          progressDao: progressDao,
          gate: gate,
          threshold: threshold,
        ),
    ];
  }
}
