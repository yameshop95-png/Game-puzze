import 'package:drift/drift.dart';

import 'app_database.dart';

part 'progress_dao.g.dart';

/// Play-mode values stored in the progress table
/// (contract S1-02, SA-DB-2): plain string constants in
/// the DAO file, no enum — the E5 gate counts per mode at
/// the call layer, the database only stores.
abstract final class ProgressModes {
  static const String jigsaw = 'jigsaw';
  static const String word = 'word';
}

/// Data access for the progress and settings tables
/// (contract S1-02 §5). The only DAO in S1-02; settings
/// access lives here too (contract §5.2).
@DriftAccessor(tables: [Progress, Settings])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  /// Marks one image as solved in one mode (upsert,
  /// SA-DB-4): a new row is inserted; an existing row
  /// keeps its first `solved_at` and its `best_time`
  /// becomes the min of old and new, where a null on
  /// either side yields the non-null side (contract
  /// §5.1).
  Future<void> markSolved(
    String imageId,
    String mode, {
    required DateTime solvedAt,
    int? timeSeconds,
  }) {
    return into(progress).insert(
      ProgressCompanion.insert(
        imageId: imageId,
        mode: mode,
        solvedAt: solvedAt,
        bestTime: Value(timeSeconds),
      ),
      onConflict: DoUpdate(
        (_) => ProgressCompanion.custom(
          bestTime: CustomExpression<int>(
            timeSeconds == null
                ? 'best_time'
                : 'CASE WHEN best_time IS NULL OR $timeSeconds < best_time '
                    'THEN $timeSeconds ELSE best_time END',
          ),
        ),
        target: [progress.imageId, progress.mode],
      ),
    );
  }

  /// Whether this image has been solved in this mode.
  Future<bool> isSolved(String imageId, String mode) async {
    final row = await (select(progress)
          ..where((t) => t.imageId.equals(imageId) & t.mode.equals(mode)))
        .getSingleOrNull();
    return row != null;
  }

  /// Every image id solved in [mode], sorted ascending by
  /// image id (contract §5.2) so callers — and the E5
  /// gate counting at the call layer — get a deterministic
  /// list.
  Future<List<String>> solvedIds(String mode) {
    return (select(progress)
          ..where((t) => t.mode.equals(mode))
          ..orderBy([(t) => OrderingTerm.asc(t.imageId)]))
        .map((r) => r.imageId)
        .get();
  }

  /// Reads one settings key; null when the key is absent
  /// (SA-DB-3).
  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Writes one settings key, overwriting any existing
  /// value (SA-DB-3).
  Future<void> setSetting(String key, String value) {
    return into(settings).insert(
      SettingsCompanion.insert(key: key, value: value),
      mode: InsertMode.insertOrReplace,
    );
  }
}
