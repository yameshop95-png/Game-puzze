// UNIT-DB-01..16 — contract harness/contracts/S1-02.md §9.
//
// Every test opens the database through NativeDatabase on a
// real temporary file (never in-memory, never
// AppDatabase.production()), per MUSE_STEPS §S1-02 and
// contract SA-DB-5. Persistence tests close the database and
// reopen the same file before asserting.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/data/app_database.dart';
import 'package:game_puzzle/data/progress_dao.dart';

void main() {
  // Whole-second timestamps: drift stores DateTime as epoch
  // seconds (contract S1-02 §3), and solved_at is compared by
  // millisecondsSinceEpoch.
  final t1 = DateTime.fromMillisecondsSinceEpoch(1764316800000);
  final t2 = DateTime.fromMillisecondsSinceEpoch(1764320400000);

  late Directory dir;
  late File dbFile;

  AppDatabase openDb() => AppDatabase(NativeDatabase(dbFile));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('app_database_test');
    dbFile = File('${dir.path}/game_puzzle.sqlite');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  Future<ProgressData> onlyProgressRow(AppDatabase db) async {
    final rows = await db.select(db.progress).get();
    expect(rows, hasLength(1));
    return rows.single;
  }

  test('UNIT-DB-01 markSolved first time writes the full row', () async {
    final db = openDb();
    addTearDown(db.close);
    await db.progressDao.markSolved(
      'animals_1_01',
      ProgressModes.jigsaw,
      solvedAt: t1,
      timeSeconds: 95,
    );
    final row = await onlyProgressRow(db);
    expect(row.imageId, 'animals_1_01');
    expect(row.mode, 'jigsaw');
    expect(row.solvedAt.millisecondsSinceEpoch, t1.millisecondsSinceEpoch);
    expect(row.bestTime, 95);
    expect(
      await db.progressDao.isSolved('animals_1_01', ProgressModes.jigsaw),
      isTrue,
    );
  });

  test('UNIT-DB-02 data survives closing and reopening the file', () async {
    var db = openDb();
    await db.progressDao.markSolved(
      'animals_1_01',
      ProgressModes.jigsaw,
      solvedAt: t1,
      timeSeconds: 95,
    );
    await db.progressDao.markSolved(
      'animals_1_02',
      ProgressModes.jigsaw,
      solvedAt: t1,
    );
    await db.progressDao.setSetting('khoa_a', 'gia_tri_1');
    await db.close();

    db = openDb();
    addTearDown(db.close);
    expect(await db.progressDao.solvedIds(ProgressModes.jigsaw), [
      'animals_1_01',
      'animals_1_02',
    ]);
    final rows = await db.select(db.progress).get();
    final byId = {for (final r in rows) r.imageId: r};
    expect(byId['animals_1_01']!.bestTime, 95);
    expect(byId['animals_1_02']!.bestTime, isNull);
    expect(await db.progressDao.getSetting('khoa_a'), 'gia_tri_1');
  });

  test(
    'UNIT-DB-03 re-solve faster lowers best_time, keeps first solved_at',
    () async {
      final db = openDb();
      addTearDown(db.close);
      await db.progressDao.markSolved(
        'animals_1_01',
        ProgressModes.jigsaw,
        solvedAt: t1,
        timeSeconds: 120,
      );
      await db.progressDao.markSolved(
        'animals_1_01',
        ProgressModes.jigsaw,
        solvedAt: t2,
        timeSeconds: 80,
      );
      final row = await onlyProgressRow(db);
      expect(row.bestTime, 80);
      expect(row.solvedAt.millisecondsSinceEpoch, t1.millisecondsSinceEpoch);
    },
  );

  test(
    'UNIT-DB-04 re-solve slower keeps best_time and first solved_at',
    () async {
      final db = openDb();
      addTearDown(db.close);
      await db.progressDao.markSolved(
        'animals_1_01',
        ProgressModes.jigsaw,
        solvedAt: t1,
        timeSeconds: 80,
      );
      await db.progressDao.markSolved(
        'animals_1_01',
        ProgressModes.jigsaw,
        solvedAt: t2,
        timeSeconds: 120,
      );
      final row = await onlyProgressRow(db);
      expect(row.bestTime, 80);
      expect(row.solvedAt.millisecondsSinceEpoch, t1.millisecondsSinceEpoch);
    },
  );

  test(
    'UNIT-DB-05 markSolved without timeSeconds leaves best_time null',
    () async {
      final db = openDb();
      addTearDown(db.close);
      await db.progressDao.markSolved(
        'animals_1_01',
        ProgressModes.jigsaw,
        solvedAt: t1,
      );
      final row = await onlyProgressRow(db);
      expect(row.bestTime, isNull);
      expect(
        await db.progressDao.isSolved('animals_1_01', ProgressModes.jigsaw),
        isTrue,
      );
    },
  );

  test(
    'UNIT-DB-06 re-solve without timeSeconds keeps the old best_time',
    () async {
      final db = openDb();
      addTearDown(db.close);
      await db.progressDao.markSolved(
        'animals_1_01',
        ProgressModes.jigsaw,
        solvedAt: t1,
        timeSeconds: 95,
      );
      await db.progressDao.markSolved(
        'animals_1_01',
        ProgressModes.jigsaw,
        solvedAt: t2,
      );
      final row = await onlyProgressRow(db);
      expect(row.bestTime, 95);
      expect(row.solvedAt.millisecondsSinceEpoch, t1.millisecondsSinceEpoch);
    },
  );

  test('UNIT-DB-07 re-solve with timeSeconds fills a null best_time', () async {
    final db = openDb();
    addTearDown(db.close);
    await db.progressDao.markSolved(
      'animals_1_01',
      ProgressModes.jigsaw,
      solvedAt: t1,
    );
    await db.progressDao.markSolved(
      'animals_1_01',
      ProgressModes.jigsaw,
      solvedAt: t2,
      timeSeconds: 70,
    );
    final row = await onlyProgressRow(db);
    expect(row.bestTime, 70);
    expect(row.solvedAt.millisecondsSinceEpoch, t1.millisecondsSinceEpoch);
  });

  test('UNIT-DB-08 the two modes of one image are independent rows', () async {
    final db = openDb();
    addTearDown(db.close);
    await db.progressDao.markSolved(
      'animals_1_01',
      ProgressModes.jigsaw,
      solvedAt: t1,
      timeSeconds: 95,
    );
    expect(
      await db.progressDao.isSolved('animals_1_01', ProgressModes.word),
      isFalse,
    );
    expect(await db.progressDao.solvedIds(ProgressModes.word), isEmpty);
    await db.progressDao.markSolved(
      'animals_1_01',
      ProgressModes.word,
      solvedAt: t1,
      timeSeconds: 50,
    );
    final rows = await db.select(db.progress).get();
    expect(rows, hasLength(2));
    final byMode = {for (final r in rows) r.mode: r};
    expect(byMode['jigsaw']!.bestTime, 95);
    expect(byMode['word']!.bestTime, 50);
  });

  test(
    'UNIT-DB-09 solvedIds returns only that mode, sorted ascending',
    () async {
      final db = openDb();
      addTearDown(db.close);
      await db.progressDao.markSolved(
        'animals_1_03',
        ProgressModes.jigsaw,
        solvedAt: t1,
      );
      await db.progressDao.markSolved(
        'animals_1_01',
        ProgressModes.jigsaw,
        solvedAt: t1,
      );
      await db.progressDao.markSolved(
        'animals_1_02',
        ProgressModes.jigsaw,
        solvedAt: t1,
      );
      await db.progressDao.markSolved(
        'animals_1_04',
        ProgressModes.word,
        solvedAt: t1,
      );
      expect(await db.progressDao.solvedIds(ProgressModes.jigsaw), [
        'animals_1_01',
        'animals_1_02',
        'animals_1_03',
      ]);
    },
  );

  test('UNIT-DB-10 solvedIds on a fresh database is empty', () async {
    final db = openDb();
    addTearDown(db.close);
    expect(await db.progressDao.solvedIds(ProgressModes.jigsaw), isEmpty);
    expect(await db.progressDao.solvedIds(ProgressModes.word), isEmpty);
  });

  test('UNIT-DB-11 isSolved is false for an unsolved image', () async {
    final db = openDb();
    addTearDown(db.close);
    expect(
      await db.progressDao.isSolved('animals_1_01', ProgressModes.jigsaw),
      isFalse,
    );
    await db.progressDao.markSolved(
      'animals_1_02',
      ProgressModes.jigsaw,
      solvedAt: t1,
    );
    expect(
      await db.progressDao.isSolved('animals_1_01', ProgressModes.jigsaw),
      isFalse,
    );
  });

  test('UNIT-DB-12 getSetting returns null for a missing key', () async {
    final db = openDb();
    addTearDown(db.close);
    expect(await db.progressDao.getSetting('chua_co'), isNull);
  });

  test(
    'UNIT-DB-13 a setting survives closing and reopening the file',
    () async {
      var db = openDb();
      await db.progressDao.setSetting('khoa_a', 'gia_tri_1');
      await db.close();

      db = openDb();
      addTearDown(db.close);
      expect(await db.progressDao.getSetting('khoa_a'), 'gia_tri_1');
    },
  );

  test(
    'UNIT-DB-14 setSetting overwrites one key, leaves others intact',
    () async {
      final db = openDb();
      addTearDown(db.close);
      await db.progressDao.setSetting('khoa_a', 'v1');
      await db.progressDao.setSetting('khoa_b', 'vb');
      await db.progressDao.setSetting('khoa_a', 'v2');
      expect(await db.progressDao.getSetting('khoa_a'), 'v2');
      expect(await db.progressDao.getSetting('khoa_b'), 'vb');
    },
  );

  test('UNIT-DB-15 schemaVersion is 1', () async {
    final db = openDb();
    addTearDown(db.close);
    expect(db.schemaVersion, 1);
  });

  test('UNIT-DB-16 the dumped v1 schema matches both tables', () {
    final file = File('drift_schemas/drift_schema_v1.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'drift_schemas/drift_schema_v1.json must be committed',
    );
    final decoded = jsonDecode(file.readAsStringSync()) as Map;
    final entities = decoded['entities'] as List;
    Map tableNamed(String name) => entities.cast<Map>().firstWhere(
      (e) => e['type'] == 'table' && e['data']['name'] == name,
    );
    final progress = tableNamed('progress');
    expect(progress['data']['explicit_pk'], ['image_id', 'mode']);
    final columns = (progress['data']['columns'] as List).cast<Map>();
    final bestTime = columns.firstWhere((c) => c['name'] == 'best_time');
    expect(bestTime['nullable'], isTrue);
    final settings = tableNamed('settings');
    expect(settings['data']['explicit_pk'], ['key']);
  });
}
