// Contract S1-05 app-shell flow tests — harness/contracts/
// S1-05.md §10 (SA-S5-8: this file lives under
// test/features/app_shell/, not integration_test/, so it runs
// in the local unit gate like every other test).
// Written and hash-locked BEFORE the wiring exists
// (stacked-PR process). The Generator must not edit, skip, or
// loosen these tests.
//
// The database is a real file through two opens, per the
// S1-02 pattern (SA-DB-5) — INT-CS-03 reopens the same file
// to prove restart persistence. Drags follow the S1-04 §8
// geometry and read board state through the painter, exactly
// like the WID-JP tests; the tray order comes from the app
// (unseeded in tests), so helpers read it from the painter
// instead of assuming a seed.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/app.dart';
import 'package:game_puzzle/data/app_database.dart';
import 'package:game_puzzle/data/progress_dao.dart';
import 'package:game_puzzle/features/completion/completion_screen.dart';
import 'package:game_puzzle/features/jigsaw_play/jigsaw_board_painter.dart';
import 'package:game_puzzle/features/mode_select/mode_select_screen.dart';
import 'package:game_puzzle/features/jigsaw_play/jigsaw_play_screen.dart';
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
/// the completion screen still appears (SA-S5-5).
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

/// One manifest record for the real S1-05 puzzle, with the
/// full key set the S1-01 loader validates.
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
    'text': {'en': 'A sample picture.'},
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

double _boardSide(WidgetTester tester) =>
    tester.view.physicalSize.width / tester.view.devicePixelRatio - 32;

double _cell(WidgetTester tester) => _boardSide(tester) / 3;

Offset _cellCenter(WidgetTester tester, int row, int col) {
  final cell = _cell(tester);
  return Offset(16 + cell * (col + 0.5), 56 + cell * (row + 0.5));
}

double _trayScroll = 0;

double _trayCenterY(WidgetTester tester) => 56 + _boardSide(tester) + 8 + 56;

Offset _slotCenter(WidgetTester tester, int slot) {
  final cell = _cell(tester);
  return Offset(16 + cell * (slot + 0.5) - _trayScroll, _trayCenterY(tester));
}

double _scrollForSlot(WidgetTester tester, int slot) {
  final contentCenter = 16 + _cell(tester) * (slot + 0.5);
  final maxScroll = _cell(tester) * 9 - _boardSide(tester);
  final desired = contentCenter - (16 + _boardSide(tester) / 2);
  return desired.clamp(0.0, maxScroll);
}

Future<void> _scrollTrayTo(WidgetTester tester, int slot) async {
  final target = _scrollForSlot(tester, slot);
  final delta = target - _trayScroll;
  if (delta == 0) return;
  final gesture = await tester.startGesture(
    Offset(16 + _boardSide(tester) / 2, _trayCenterY(tester)),
  );
  await gesture.moveBy(Offset(-delta, 0));
  await tester.pump();
  await gesture.up();
  await tester.pump();
  _trayScroll = target;
}

JigsawBoardPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('jigsaw-board-painter')),
  );
  return paint.painter! as JigsawBoardPainter;
}

Future<void> _dragFromTray(WidgetTester tester, int slot, Offset to) async {
  await _scrollTrayTo(tester, slot);
  final gesture = await tester.startGesture(_slotCenter(tester, slot));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

/// Places one piece on its home cell, reading the tray slot
/// and the home cell from the live painter state.
Future<void> _placeHome(WidgetTester tester, int pieceId) async {
  final painter = _painter(tester);
  final home = painter.board.homeOf(pieceId);
  await _dragFromTray(
    tester,
    painter.trayOrder.indexOf(pieceId),
    _cellCenter(tester, home.row, home.col),
  );
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
  _trayScroll = 0;
  await tester.pumpWidget(MyApp(dao: dao, assetLoader: _fakeLoader()));
  await _pumpReal(tester);
}

/// Opens the Animals puzzle from the theme screen and solves
/// all nine pieces. Since S2-01 (SA-WP-1) the theme tap lands
/// on the mode select screen first — one extra mechanical
/// tap on 'Jigsaw' (contract S2-01 §14); the rest of the
/// flow is unchanged.
Future<void> _solveAnimalsPuzzle(WidgetTester tester) async {
  await tester.tap(find.text('Animals'));
  await _pumpReal(tester);
  expect(find.byType(ModeSelectScreen), findsOneWidget);
  await tester.tap(find.text('Jigsaw'));
  await _pumpReal(tester);
  expect(find.byType(JigsawPlayScreen), findsOneWidget);
  for (var piece = 0; piece < 9; piece++) {
    await _placeHome(tester, piece);
  }
  expect(_painter(tester).board.isComplete, isTrue);
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
    dir = await Directory.systemTemp.createTemp('completion_flow_test');
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
    'INT-CS-01 completing in the shell calls markSolved with the right args and shows the completion screen',
    (tester) async {
      _useEmulatorSurface(tester);
      final dao = _RecordingDao(openDb());
      await _pumpApp(tester, dao);

      await _solveAnimalsPuzzle(tester);

      expect(find.byType(CompletionScreen), findsOneWidget);
      expect(find.text('Weaning the Calves'), findsWidgets);
      expect(dao.calls, hasLength(1));
      final call = dao.calls.single;
      expect(call.imageId, 'a1p1');
      expect(call.mode, ProgressModes.jigsaw);
      expect(call.timeSeconds, isNotNull);
      expect(call.timeSeconds, greaterThanOrEqualTo(0));

      // The write really landed in the file database.
      expect(await dao.isSolved('a1p1', ProgressModes.jigsaw), isTrue);
      final db = dao.attachedDatabase;
      final rows = await db.select(db.progress).get();
      expect(rows, hasLength(1));
      expect(rows.single.bestTime, call.timeSeconds);
    },
  );

  testWidgets(
    'INT-CS-02 a failing markSolved still shows the completion screen',
    (tester) async {
      _useEmulatorSurface(tester);
      final dao = _ThrowingDao(openDb());
      await _pumpApp(tester, dao);

      await _solveAnimalsPuzzle(tester);

      expect(find.byType(CompletionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('INT-CS-03 after a restart the Animals card shows 1 solved', (
    tester,
  ) async {
    _useEmulatorSurface(tester);
    final db1 = openDb();
    await _pumpApp(tester, ProgressDao(db1));
    await _solveAnimalsPuzzle(tester);
    expect(find.byType(CompletionScreen), findsOneWidget);

    // Restart: unmount, close, reopen the same file with a
    // fresh database + DAO, and pump a fresh app.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await db1.close();
    opened.remove(db1);
    final dao2 = ProgressDao(openDb());
    await _pumpApp(tester, dao2);

    expect(find.text('1 solved'), findsOneWidget);
    expect(find.bySemanticsLabel('Animals theme, 1 solved'), findsOneWidget);
  });
}
