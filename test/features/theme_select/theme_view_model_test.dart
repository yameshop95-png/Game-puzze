import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/data/app_database.dart';
import 'package:game_puzzle/data/progress_dao.dart';
import 'package:game_puzzle/features/theme_select/theme_progress.dart';
import 'package:game_puzzle/services/asset_loader.dart';

/// One manifest record with the full key set the
/// S1-01 parser requires; only image_id/theme vary.
Map<String, dynamic> record(String id, String theme) {
  return {
    'image_id': id,
    'theme': theme,
    'level': 1,
    'title': 'Title $id',
    'creator': {'name': 'A Creator'},
    'creation_year': 1900,
    'source': {'institution': 'A Museum'},
    'rights': {'status': 'cc0'},
    'image': {'file': '$theme/$id.jpg'},
    'text': {'en': 'A sentence for $id.'},
    'reviewed_by': 'James',
    'reviewed_on': '2026-11-28',
  };
}

AssetLoader loaderFor(List<Map<String, dynamic>> records) {
  return AssetLoader(loadString: (_) async => jsonEncode(records));
}

void main() {
  late Directory tmpDir;
  late AppDatabase db;
  late ProgressDao dao;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('theme_vm_test');
    db = AppDatabase(NativeDatabase(File('${tmpDir.path}/test.sqlite')));
    dao = ProgressDao(db);
  });

  tearDown(() async {
    await db.close();
    await tmpDir.delete(recursive: true);
  });

  test(
    'WID-TS-11 computeThemeViewModel counts puzzles per theme and solved as the union of both modes',
    () async {
      final loader = loaderFor([
        record('animals_1_01', 'animals'),
        record('animals_1_02', 'animals'),
        record('animals_1_03', 'animals'),
        record('space_1_01', 'space'),
      ]);
      final solvedAt = DateTime.utc(2026, 1, 1);
      await dao.markSolved(
        'animals_1_01',
        ProgressModes.jigsaw,
        solvedAt: solvedAt,
      );
      await dao.markSolved(
        'animals_1_02',
        ProgressModes.word,
        solvedAt: solvedAt,
      );
      // Solved in the other theme must not leak in.
      await dao.markSolved(
        'space_1_01',
        ProgressModes.jigsaw,
        solvedAt: solvedAt,
      );

      final animals = await computeThemeViewModel(
        'animals',
        assetLoader: loader,
        progressDao: dao,
      );
      expect(animals.themeId, 'animals');
      expect(animals.displayName, 'Animals');
      expect(animals.puzzleCount, 3);
      expect(animals.solvedCount, 2);

      final space = await computeThemeViewModel(
        'space',
        assetLoader: loader,
        progressDao: dao,
      );
      expect(space.puzzleCount, 1);
      expect(space.solvedCount, 1);
    },
  );

  test('WID-TS-12 the 75 percent gate is strict at the boundary', () async {
    final loader = loaderFor([
      record('maps_1_01', 'maps'),
      record('maps_1_02', 'maps'),
      record('maps_1_03', 'maps'),
      record('maps_1_04', 'maps'),
    ]);
    final solvedAt = DateTime.utc(2026, 1, 1);
    for (final id in ['maps_1_01', 'maps_1_02', 'maps_1_03']) {
      await dao.markSolved(id, ProgressModes.jigsaw, solvedAt: solvedAt);
    }

    // 3 of 4 is exactly 75%: the gate needs strictly
    // more, so the next level stays locked.
    var maps = await computeThemeViewModel(
      'maps',
      assetLoader: loader,
      progressDao: dao,
    );
    expect(maps.solvedCount, 3);
    expect(maps.nextLevelLocked, isTrue);

    await dao.markSolved('maps_1_04', ProgressModes.jigsaw, solvedAt: solvedAt);
    maps = await computeThemeViewModel(
      'maps',
      assetLoader: loader,
      progressDao: dao,
    );
    expect(maps.solvedCount, 4);
    expect(maps.nextLevelLocked, isFalse);
  });

  test(
    'WID-TS-13 a theme with no puzzles yet is locked with zero counts',
    () async {
      final vmResult = await computeThemeViewModel(
        'animals',
        assetLoader: loaderFor(const []),
        progressDao: dao,
      );
      expect(vmResult.puzzleCount, 0);
      expect(vmResult.solvedCount, 0);
      expect(vmResult.nextLevelLocked, isTrue);
    },
  );

  test('WID-TS-14 an unknown theme id throws ArgumentError', () async {
    await expectLater(
      computeThemeViewModel(
        'ocean',
        assetLoader: loaderFor(const []),
        progressDao: dao,
      ),
      throwsArgumentError,
    );
  });

  test(
    'WID-TS-15 AssetThemeProgressProvider returns the whole catalog in SA-UI-2 order',
    () async {
      final loader = loaderFor([
        record('animals_1_01', 'animals'),
        record('animals_1_02', 'animals'),
        record('animals_1_03', 'animals'),
      ]);
      final provider = AssetThemeProgressProvider(
        assetLoader: loader,
        progressDao: dao,
      );

      final themes = await provider.loadThemes();
      expect(themes, hasLength(5));
      expect(themes.map((t) => t.themeId), [
        'animals',
        'landscapes',
        'space',
        'maps',
        'landmarks',
      ]);
      expect(themes.map((t) => t.displayName), [
        'Animals',
        'Landscapes',
        'Space',
        'Maps',
        'Landmarks',
      ]);
      expect(themes.first.puzzleCount, 3);
      expect(themes.first.solvedCount, 0);
    },
  );
}
