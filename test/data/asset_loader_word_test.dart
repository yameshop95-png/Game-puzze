// Contract S2-01 tests (UNIT-AW-01..04) for the word-mode
// fields of AssetLoader: text.en_word -> PuzzleAsset.textEnWord
// and text.en_alt -> PuzzleAsset.textEnAlt (SA-WP-2/SA-WP-3).
// Written and hash-locked BEFORE the implementation exists
// (stacked-PR process). The Generator must not edit, skip, or
// loosen these tests.
//
// The loader is exercised only through an injected fake
// loadString, mirroring the UNIT-AL pattern of S1-01.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/services/asset_loader.dart';

/// One structurally valid manifest record (the full key set
/// the S1-01 loader validates), with a mutable text block so
/// each case can shape en_word / en_alt.
Map<String, dynamic> _record(Map<String, dynamic> text) => {
  'image_id': 'a1p1',
  'theme': 'animals',
  'level': 1,
  'title': 'Weaning the Calves',
  'creator': {'name': 'Rosa Bonheur', 'anonymous': false, 'death_year': 1899},
  'creation_year': 1879,
  'source': {
    'institution': 'the_met',
    'object_url': 'https://www.metmuseum.org/art/collection/search/435703',
    'record_id': '435703',
    'license_text': 'CC0 1.0 (The Met Open Access policy)',
    'license_evidence_url':
        'https://www.metmuseum.org/about-the-met/policies-and-documents/open-access',
    'retrieved_on': '2026-11-28',
  },
  'rights': {
    'status': 'cc0',
    'contains_identifiable_person': false,
    'trademark_or_logo': false,
  },
  'image': {
    'file': 'images/a1p1.jpg',
    'sha256':
        'f45fb06387a48b316df517924f0da26754a26565f7b172c0773cca89945e954a',
    'short_side_px': 3085,
    'phash': '4d1d169899908684',
  },
  'text': text,
  'reviewed_by': 'James',
  'reviewed_on': '2026-11-28',
};

AssetLoader _loaderWith(Map<String, dynamic> text) =>
    AssetLoader(loadString: (_) async => jsonEncode([_record(text)]));

void main() {
  group('AssetLoader word fields (contract S2-01)', () {
    test(
      'UNIT-AW-01 a record without en_word/en_alt loads with textEnWord null and textEnAlt empty',
      () async {
        final assets = await _loaderWith({'en': 'A sample picture.'}).load();
        expect(assets, hasLength(1));
        expect(assets.single.textEnWord, isNull);
        expect(assets.single.textEnAlt, isEmpty);
      },
    );

    test(
      'UNIT-AW-02 en_word and en_alt parse verbatim and textEnAlt is unmodifiable',
      () async {
        final assets = await _loaderWith({
          'en': 'A sample picture.',
          'en_word': 'Every calf has its own pose and mood.',
          'en_alt': ['Every calf has its own mood and pose.'],
        }).load();
        final asset = assets.single;
        expect(asset.textEnWord, 'Every calf has its own pose and mood.');
        expect(asset.textEnAlt, ['Every calf has its own mood and pose.']);
        expect(() => asset.textEnAlt.add('x'), throwsUnsupportedError);
      },
    );

    test(
      'UNIT-AW-03 an en_alt element that is empty or not a string throws FormatException',
      () async {
        await expectLater(
          _loaderWith({
            'en': 'A sample picture.',
            'en_alt': [''],
          }).load(),
          throwsFormatException,
        );
        await expectLater(
          _loaderWith({
            'en': 'A sample picture.',
            'en_alt': [42],
          }).load(),
          throwsFormatException,
        );
      },
    );

    test(
      'UNIT-AW-04 an en_word that is not a string or is empty throws FormatException',
      () async {
        await expectLater(
          _loaderWith({'en': 'A sample picture.', 'en_word': 42}).load(),
          throwsFormatException,
        );
        await expectLater(
          _loaderWith({'en': 'A sample picture.', 'en_word': ''}).load(),
          throwsFormatException,
        );
      },
    );
  });
}
