// Contract S2-01 app-shell flow tests — harness/contracts/
// S2-01.md §12 (SA-WP-8: this file lives under
// test/features/app_shell/, not integration_test/, so it runs
// in the local unit gate like every other test).
// Written and hash-locked BEFORE the wiring exists
// (stacked-PR process). The Generator must not edit, skip, or
// loosen these tests.
//
// Mirrors the INT-CS pattern of S1-05: a fake manifest through
// the real AssetLoader, a real file database through two
// opens (INT-WP-03 reopens the same file to prove restart
// persistence). The manifest record is the real a1p1 WITH
// text.en_word added (SA-WP-2); the app is unseeded in tests,
// so the solve helper taps pool chips by their token-index
// keys, never by visual position.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/app.dart';
import 'package:game_puzzle/data/app_database.dart';
import 'package:game_puzzle/data/progress_dao.dart';
import 'package:game_puzzle/features/completion/completion_screen.dart';
import 'package:game_puzzle/features/mode_select/mode_select_screen.dart';
import 'package:game_puzzle/features/word_play/word_play_screen.dart';
import 'package:game_puzzle/services/asset_loader.dart';

/// A [ProgressDao] that records every markSolved call and
/// then performs it for real.
class _RecordingDao extends ProgressDao {
  _RecordingDao(super.db);

  final List<({String imageId, String mode, int? timeSeconds})> calls = [];

  @override
  Future<void> markSolved(
    String imageId,
    String mode, {
    required DateTime solvedAt,
    int? timeSeconds,
  }) {
    calls.add((imageId: imageId, mode: mode, timeSeconds: timeSeconds));
    return super.markSolved(
      imageId,
      mode,
      solvedAt: solvedAt,
      timeSeconds: timeSeconds,
    );
  }
}

/// A [ProgressDao] whose markSolved always fails, to prove
/// the completion screen still appears (SA-WP-7, mirroring
/// INT-CS-02).
class _ThrowingDao extends ProgressDao {
  _ThrowingDao(super.db);

  @override
  Future<void> markSolved(
    String imageId,
    String mode, {
    required DateTime solvedAt,
    int? timeSeconds,
  }) async {
    throw StateError('database unavailable');
  }
}

/// The a1p1 en_word sentence of SA-WP-2: 11 tokens.
const String _enWord = 'Every calf in the picture has its own pose and mood.';

/// One manifest record for the real puzzle, with the full
/// key set the S1-01 loader validates and text.en_word
/// added per SA-WP-2.
String _manifestA1p1() => jsonEncode([
  {
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
    'text': {'en': 'A sample picture.', 'en_word': _enWord},
    'reviewed_by': 'James',
    'reviewed_on': '2026-11-28',
  },
]);

AssetLoader _fakeLoader() =>
    AssetLoader(loadString: (_) async => _manifestA1p1());

void _useEmulatorSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// drift answers from a background isolate; give the real
/// event loop a turn so pending DB work lands, then settle.
Future<void> _pumpReal(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(WidgetTester tester, ProgressDao dao) async {
  await tester.pumpWidget(MyApp(dao: dao, assetLoader: _fakeLoader()));
  await _pumpReal(tester);
}

/// Opens the Animals puzzle in word mode: theme card ->
/// mode select -> Words (SA-WP-1).
Future<void> _openWordMode(WidgetTester tester) async {
  await tester.tap(find.text('Animals'));
  await _pumpReal(tester);
  expect(find.byType(ModeSelectScreen), findsOneWidget);
  await tester.tap(find.text('Words'));
  await _pumpReal(tester);
  expect(find.byType(WordPlayScreen), findsOneWidget);
}

/// Solves the word puzzle by tapping the pool chips in
/// token-index order (the keys are index-based, SA-WP-6,
/// so the unseeded scramble does not matter). Each chip is
/// scrolled into view first: the screen is one scrolling
/// column (SA-WP-6).
Future<void> _solveWordPuzzle(WidgetTester tester) async {
  final count = _enWord.split(' ').length;
  for (var i = 0; i < count; i++) {
    final chip = find.byKey(ValueKey('pool_$i'));
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await tester.pump();
  }
  await _pumpReal(tester);
}

void main() {
  late Directory dir;
  late File dbFile;
  final opened = <AppDatabase>[];

  AppDatabase openDb() {
    final db = AppDatabase(NativeDatabase(dbFile));
    opened.add(db);
    return db;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('word_completion_flow_test');
    dbFile = File('${dir.path}/game_puzzle.sqlite');
  });

  tearDown(() async {
    for (final db in opened) {
      await db.close();
    }
    opened.clear();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  testWidgets(
    'INT-WP-01 completing word mode in the shell calls markSolved with mode word and shows the completion screen',
    (tester) async {
      _useEmulatorSurface(tester);
      final dao = _RecordingDao(openDb());
      await _pumpApp(tester, dao);

      await _openWordMode(tester);
      await _solveWordPuzzle(tester);

      expect(find.byType(CompletionScreen), findsOneWidget);
      expect(find.text('Weaning the Calves'), findsWidgets);
      expect(dao.calls, hasLength(1));
      final call = dao.calls.single;
      expect(call.imageId, 'a1p1');
      expect(call.mode, ProgressModes.word);
      expect(call.timeSeconds, isNotNull);
      expect(call.timeSeconds, greaterThanOrEqualTo(0));

      // The write really landed in the file database,
      // under the word mode only.
      expect(await dao.isSolved('a1p1', ProgressModes.word), isTrue);
      expect(await dao.isSolved('a1p1', ProgressModes.jigsaw), isFalse);
    },
  );

  testWidgets(
    'INT-WP-02 a failing markSolved still shows the completion screen',
    (tester) async {
      _useEmulatorSurface(tester);
      final dao = _ThrowingDao(openDb());
      await _pumpApp(tester, dao);

      await _openWordMode(tester);
      await _solveWordPuzzle(tester);

      expect(find.byType(CompletionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('INT-WP-03 after a restart the word solve still counts', (
    tester,
  ) async {
    _useEmulatorSurface(tester);
    final db1 = openDb();
    await _pumpApp(tester, ProgressDao(db1));
    await _openWordMode(tester);
    await _solveWordPuzzle(tester);
    expect(find.byType(CompletionScreen), findsOneWidget);

    // Restart: unmount, close, reopen the same file with a
    // fresh database + DAO, and pump a fresh app.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await db1.close();
    opened.remove(db1);
    final dao2 = ProgressDao(openDb());
    await _pumpApp(tester, dao2);

    expect(await dao2.isSolved('a1p1', ProgressModes.word), isTrue);
    expect(find.text('1 solved'), findsOneWidget);
  });
}
