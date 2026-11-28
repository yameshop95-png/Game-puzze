// Contract S1-01 tests (UNIT-AL-01..12) for AssetLoader.
// Written and hash-locked BEFORE the implementation (PR test/S1-01).
// The loader is exercised only through an injected fake loadString,
// except UNIT-AL-01 (reads the fixture file) and UNIT-AL-12
// (filesystem placement rule).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/services/asset_loader.dart';

const String _oneRecordJson = '''
{
  "image_id": "animals_1_01",
  "theme": "animals",
  "level": 1,
  "title": "Red Fox",
  "creator": {"name": "John James Audubon", "anonymous": false,
              "death_year": 1851},
  "creation_year": 1845,
  "source": {"institution": "Smithsonian Institution",
             "object_url": "https://www.si.edu/object/red-fox",
             "record_id": "si-fox-001", "license_text": "CC0",
             "license_evidence_url": "https://www.si.edu/openaccess",
             "retrieved_on": "2026-11-27"},
  "rights": {"status": "cc0", "contains_identifiable_person": false,
             "trademark_or_logo": false},
  "image": {"file": "animals/red-fox.jpg",
            "sha256": "3f5c9a1e7b2d4a6f8e0c1b3d5a7f9e2c4b6a8d0f1e3a5c7b9d2f4a6c8e0b1d3f",
            "short_side_px": 1200, "phash": "a1b2c3d4e5f60718"},
  "text": {"en": "A red fox sits in the grass."},
  "reviewed_by": "James",
  "reviewed_on": "2026-11-27"
}
''';

Map<String, dynamic> validRecord() =>
    jsonDecode(_oneRecordJson) as Map<String, dynamic>;

String manifestOf(List<Object?> records) => jsonEncode(records);

AssetLoader loaderReturning(String body) =>
    AssetLoader(loadString: (_) async => body);

void main() {
  group('AssetLoader (contract S1-01)', () {
    test('UNIT-AL-01 valid 3-record manifest keeps order and maps '
        'every field', () async {
      final body = File('test/fixtures/manifest_valid.json').readAsStringSync();
      final assets = await loaderReturning(body).load();
      expect(assets, hasLength(3));

      final fox = assets[0];
      expect(fox.id, 'animals_1_01');
      expect(fox.theme, 'animals');
      expect(fox.level, 1);
      expect(fox.title, 'Red Fox');
      expect(fox.textEn, 'A red fox sits in the grass.');
      expect(fox.playPath, 'packs/animals/1/animals_1_01/play.webp');
      expect(fox.thumbPath, 'packs/animals/1/animals_1_01/thumb.webp');
      expect(fox.creator, 'John James Audubon');
      expect(fox.institution, 'Smithsonian Institution');

      final lake = assets[1];
      expect(lake.id, 'landscapes_1_01');
      expect(lake.theme, 'landscapes');
      expect(lake.level, 1);
      expect(lake.title, 'Mountain Lake at Dawn');
      expect(lake.textEn, 'A calm lake reflects the mountains at dawn.');
      expect(lake.playPath, 'packs/landscapes/1/landscapes_1_01/play.webp');
      expect(lake.thumbPath, 'packs/landscapes/1/landscapes_1_01/thumb.webp');
      expect(lake.creator, 'Albert Bierstadt');
      expect(lake.institution, 'The Metropolitan Museum of Art');

      final orion = assets[2];
      expect(orion.id, 'space_1_01');
      expect(orion.theme, 'space');
      expect(orion.level, 1);
      expect(orion.title, 'Orion Constellation Engraving');
      expect(orion.textEn, 'Stars form the hunter Orion in the night sky.');
      expect(orion.playPath, 'packs/space/1/space_1_01/play.webp');
      expect(orion.thumbPath, 'packs/space/1/space_1_01/thumb.webp');
      expect(orion.creator, 'Johannes Hevelius');
      expect(orion.institution, 'Library of Congress');
    });

    test('UNIT-AL-02 injected loadString is used with the default '
        'manifest path', () async {
      String? seenPath;
      final loader = AssetLoader(
        loadString: (path) async {
          seenPath = path;
          return manifestOf([validRecord()]);
        },
      );
      final assets = await loader.load();
      expect(assets, hasLength(1));
      expect(seenPath, 'content/manifest.json');
      expect(seenPath, AssetLoader.manifestPath);
    });

    test('UNIT-AL-03 empty array yields an empty list', () async {
      final assets = await loaderReturning('[]').load();
      expect(assets, isEmpty);
    });

    test('UNIT-AL-04 missing required field throws FormatException', () async {
      final record = validRecord()..remove('title');
      expect(
        () => loaderReturning(manifestOf([record])).load(),
        throwsA(isA<FormatException>()),
      );
    });

    test('UNIT-AL-05 level as a string throws FormatException', () async {
      final record = validRecord();
      record['level'] = '1';
      expect(
        () => loaderReturning(manifestOf([record])).load(),
        throwsA(isA<FormatException>()),
      );
    });

    test('UNIT-AL-06 empty theme throws FormatException', () async {
      final record = validRecord();
      record['theme'] = '';
      expect(
        () => loaderReturning(manifestOf([record])).load(),
        throwsA(isA<FormatException>()),
      );
    });

    test('UNIT-AL-07 second record broken throws, no partial list', () async {
      final broken = validRecord();
      (broken['text'] as Map<String, dynamic>).remove('en');
      expect(
        () => loaderReturning(manifestOf([validRecord(), broken])).load(),
        throwsA(isA<FormatException>()),
      );
    });

    test('UNIT-AL-08 top-level object instead of array throws '
        'FormatException', () async {
      expect(
        () => loaderReturning(_oneRecordJson).load(),
        throwsA(isA<FormatException>()),
      );
    });

    test('UNIT-AL-09 malformed JSON throws FormatException', () async {
      expect(
        () => loaderReturning('this is not json').load(),
        throwsA(isA<FormatException>()),
      );
    });

    test('UNIT-AL-10 unknown extra field is ignored', () async {
      final record = validRecord();
      record['surprise_field'] = 'ignored';
      final assets = await loaderReturning(manifestOf([record])).load();
      expect(assets, hasLength(1));
      expect(assets.single.id, 'animals_1_01');
      expect(assets.single.title, 'Red Fox');
      expect(assets.single.textEn, 'A red fox sits in the grass.');
    });

    test('UNIT-AL-11 creator as a plain string throws '
        'FormatException', () async {
      final record = validRecord();
      record['creator'] = 'Audubon';
      expect(
        () => loaderReturning(manifestOf([record])).load(),
        throwsA(isA<FormatException>()),
      );
    });

    test('UNIT-AL-12 fake manifest lives only under test/fixtures', () {
      expect(File('test/fixtures/manifest_valid.json').existsSync(), isTrue);
      // S1-05 update (SA-S5-1): real content shipped — the
      // app manifest now lives at content/manifest.json and
      // holds the settled single a1p1 record (animals/1).
      // The S1-01 form of this test asserted the file did
      // not exist yet; that premise ended at S1-05.
      final real = File('content/manifest.json');
      expect(real.existsSync(), isTrue);
      final decoded = jsonDecode(real.readAsStringSync());
      expect(decoded, isA<List<dynamic>>());
      final records = decoded as List<dynamic>;
      expect(records, hasLength(1));
      final record = records.single as Map<String, dynamic>;
      expect(record['image_id'], 'a1p1');
      expect(record['theme'], 'animals');
      expect(record['level'], 1);
    });
  });
}
