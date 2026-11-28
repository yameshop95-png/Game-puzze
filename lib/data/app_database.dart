import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'progress_dao.dart';

part 'app_database.g.dart';

/// One solved puzzle in one play mode (contract S1-02, SA-DB-1).
///
/// The physical table name is `progress` and the physical
/// columns are `image_id`, `mode`, `solved_at`, `best_time`,
/// exactly as MUSE_STEPS §S1-02 spells them.
class Progress extends Table {
  TextColumn get imageId => text().named('image_id')();
  TextColumn get mode => text()();

  /// Stored by drift as epoch seconds (SA-DB-1 note in
  /// contract §3): sub-second precision is dropped and the
  /// value read back may be local time, so callers compare
  /// moments, not wall-clock fields.
  DateTimeColumn get solvedAt => dateTime().named('solved_at')();

  /// Best solve time in whole seconds; null when the solve
  /// was not timed (SA-DB-1).
  IntColumn get bestTime => integer().named('best_time').nullable()();

  @override
  Set<Column> get primaryKey => {imageId, mode};
}

/// Free-form key-value settings (contract S1-02, SA-DB-3).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Progress, Settings], daos: [ProgressDao])
class AppDatabase extends _$AppDatabase {
  /// Opens the database on an executor supplied by the
  /// caller — tests pass a NativeDatabase on a real file
  /// through this constructor (SA-DB-5).
  AppDatabase(super.e);

  /// Production opening through drift_flutter (SA-DB-5):
  /// `driftDatabase(name: 'game_puzzle')` resolves to the
  /// file `game_puzzle.sqlite` in the app documents
  /// directory.
  AppDatabase.production() : super(driftDatabase(name: 'game_puzzle'));

  @override
  int get schemaVersion => 1;
}
