// Contract S1-04 widget tests — harness/contracts/S1-04.md §12.
// Written and hash-locked BEFORE the play screen exists
// (stacked-PR process). The Generator must not edit, skip, or
// loosen these tests.
//
// Geometry follows contract §8: boardTop = 56 (AppBar),
// boardSide = screenWidth - 32, trayTop = boardTop + boardSide
// + 8, trayHeight = 112. The surface is set to the CI
// emulator's logical size (1080x2340 px at density 2.75).
// Pieces have no widgets of their own (§6: one painter), so
// tests read board state through the painter and drag by
// coordinates.
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/app.dart';
import 'package:game_puzzle/engine/jigsaw/board.dart';
import 'package:game_puzzle/engine/jigsaw/tray_order.dart';
import 'package:game_puzzle/features/jigsaw_play/jigsaw_board_painter.dart';
import 'package:game_puzzle/features/jigsaw_play/jigsaw_play_screen.dart';
import 'package:game_puzzle/features/mode_select/mode_select_screen.dart';
import 'package:game_puzzle/features/theme_select/theme_progress.dart';
import 'package:game_puzzle/services/asset_loader.dart';

const PuzzleAsset _asset = PuzzleAsset(
  id: 'animals_1_01',
  theme: 'animals',
  level: 1,
  title: 'Red Fox',
  textEn: 'A red fox sits in the grass.',
  playPath: 'packs/animals/1/animals_1_01/play.webp',
  thumbPath: 'packs/animals/1/animals_1_01/thumb.webp',
  creator: 'John James Audubon',
  institution: 'Smithsonian Institution',
);

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

/// The tray strip holds 9 slots of one cell each
/// (contract §8) — wider than the screen — so it
/// scrolls horizontally (MUSE_STEPS §6, contract §8
/// clarification). Slot centres in the contract are
/// CONTENT coordinates; the visible centre subtracts
/// the current scroll offset, tracked here across the
/// drags of one test and reset by _pumpPlay.
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

/// Scrolls the tray strip (a horizontal tray drag that
/// is not a long-press pickup) until [slot] is centred.
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

/// A deterministic 3x3 image (nine coloured cells), generated
/// in memory exactly like the integration tests do (contract
/// §2): no PNG fixture lives in the repo.
Future<MemoryImage> _testImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const colors = <Color>[
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.brown,
  ];
  for (var i = 0; i < 9; i++) {
    canvas.drawRect(
      Rect.fromLTWH((i % 3) * 100.0, (i ~/ 3) * 100.0, 100, 100),
      Paint()..color = colors[i],
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(300, 300);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return MemoryImage(data!.buffer.asUint8List());
}

Future<void> _pumpPlay(
  WidgetTester tester, {
  void Function(Duration)? onCompleted,
}) async {
  _trayScroll = 0;
  final image = await tester.runAsync(_testImage);
  await tester.pumpWidget(
    MaterialApp(
      home: JigsawPlayScreen(
        asset: _asset,
        image: image!,
        rng: Random(42),
        onCompleted: onCompleted,
      ),
    ),
  );
  // Let the screen's own image stream resolve from the cache.
  await tester.runAsync(() async {
    await precacheImage(image, tester.element(find.byType(JigsawPlayScreen)));
  });
  await tester.pump();
}

JigsawBoardPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('jigsaw-board-painter')),
  );
  return paint.painter! as JigsawBoardPainter;
}

List<int> _seededOrder() =>
    TrayOrder.shuffled(pieceCount: 9, rng: Random(42)).order;

/// Long-press drag out of the tray (contract §9): scroll
/// the slot into view, hold past the long-press timeout,
/// then move and release.
Future<void> _dragFromTray(WidgetTester tester, int slot, Offset to) async {
  await _scrollTrayTo(tester, slot);
  final gesture = await tester.startGesture(_slotCenter(tester, slot));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

/// Direct drag of a piece already on the board (contract §9).
Future<void> _dragOnBoard(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<void> _placeHome(
  WidgetTester tester,
  int pieceId,
  List<int> order,
) async {
  final board = _painter(tester).board;
  final home = board.homeOf(pieceId);
  await _dragFromTray(
    tester,
    order.indexOf(pieceId),
    _cellCenter(tester, home.row, home.col),
  );
}

void main() {
  group('JigsawPlayScreen S1-04', () {
    testWidgets('WID-JP-01 renders buttons, empty board, seeded tray order', (
      tester,
    ) async {
      _useEmulatorSurface(tester);
      await _pumpPlay(tester);

      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget);
      final painter = _painter(tester);
      expect(painter.board.totalPieces, 9);
      expect(painter.board.placedCount, 0);
      expect(painter.trayOrder.order, _seededOrder());
    });

    testWidgets('WID-JP-02 tray drag within tolerance snaps home', (
      tester,
    ) async {
      _useEmulatorSurface(tester);
      await _pumpPlay(tester);
      final order = _seededOrder();
      final piece = order.first;
      final home = _painter(tester).board.homeOf(piece);

      await _dragFromTray(tester, 0, _cellCenter(tester, home.row, home.col));

      expect(_painter(tester).board.isHome(piece), isTrue);
    });

    testWidgets('WID-JP-03 drop outside tolerance returns piece to tray', (
      tester,
    ) async {
      _useEmulatorSurface(tester);
      await _pumpPlay(tester);
      final order = _seededOrder();
      final piece = order.first;

      // The board's top-left corner is ~0.7 cell units from the
      // nearest cell centre — far outside the 0.2 tolerance.
      await _dragFromTray(tester, 0, const Offset(17, 57));

      final board = _painter(tester).board;
      expect(board.isPlaced(piece), isFalse);
      expect(board.placedCount, 0);
    });

    testWidgets('WID-JP-04 drop on wrong empty cell stays on that cell', (
      tester,
    ) async {
      _useEmulatorSurface(tester);
      await _pumpPlay(tester);
      final order = _seededOrder();
      final piece = order.first;
      final home = _painter(tester).board.homeOf(piece);
      final wrongRow = (home.row + 1) % 3;

      await _dragFromTray(tester, 0, _cellCenter(tester, wrongRow, home.col));

      final board = _painter(tester).board;
      expect(board.positionOf(piece), CellPos(wrongRow, home.col));
      expect(board.isHome(piece), isFalse);
    });

    testWidgets(
      'WID-JP-05 drop on occupied cell is rejected, board unchanged',
      (tester) async {
        _useEmulatorSurface(tester);
        await _pumpPlay(tester);
        final order = _seededOrder();
        final first = order[0];
        final second = order[1];
        await _placeHome(tester, first, order);
        final home = _painter(tester).board.homeOf(first);

        await _dragFromTray(tester, 1, _cellCenter(tester, home.row, home.col));

        final board = _painter(tester).board;
        expect(board.isHome(first), isTrue);
        expect(board.isPlaced(second), isFalse);
        expect(board.placedCount, 1);
      },
    );

    testWidgets('WID-JP-06 placed piece drags directly on the board', (
      tester,
    ) async {
      _useEmulatorSurface(tester);
      await _pumpPlay(tester);
      final order = _seededOrder();
      final piece = order.first;
      final home = _painter(tester).board.homeOf(piece);
      final wrongRow = (home.row + 1) % 3;
      await _dragFromTray(tester, 0, _cellCenter(tester, wrongRow, home.col));
      expect(_painter(tester).board.isHome(piece), isFalse);

      await _dragOnBoard(
        tester,
        _cellCenter(tester, wrongRow, home.col),
        _cellCenter(tester, home.row, home.col),
      );

      expect(_painter(tester).board.isHome(piece), isTrue);
    });

    testWidgets(
      'WID-JP-07 quick tray drag without long-press picks nothing up',
      (tester) async {
        _useEmulatorSurface(tester);
        await _pumpPlay(tester);
        final order = _seededOrder();
        final piece = order.first;
        final home = _painter(tester).board.homeOf(piece);

        final gesture = await tester.startGesture(_slotCenter(tester, 0));
        await gesture.moveTo(_cellCenter(tester, home.row, home.col));
        await gesture.up();
        await tester.pump();

        expect(_painter(tester).board.isPlaced(piece), isFalse);
      },
    );

    testWidgets(
      'WID-JP-08 preview overlay shows while pressed, hides on release',
      (tester) async {
        _useEmulatorSurface(tester);
        await _pumpPlay(tester);
        const key = ValueKey('jigsaw-preview-overlay');
        expect(find.byKey(key), findsNothing);

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Preview')),
        );
        await tester.pump();
        expect(find.byKey(key), findsOneWidget);
        expect(tester.widget<Opacity>(find.byKey(key)).opacity, 0.7);

        await gesture.up();
        await tester.pump();
        expect(find.byKey(key), findsNothing);
      },
    );

    testWidgets(
      'WID-JP-09 hint lights the first unplaced tray piece home cell for 1.2s',
      (tester) async {
        _useEmulatorSurface(tester);
        await _pumpPlay(tester);
        final order = _seededOrder();
        final expected = _painter(tester).board.homeOf(order.first);
        expect(_painter(tester).hintCell, isNull);

        await tester.tap(find.text('Hint'));
        await tester.pump();
        expect(_painter(tester).hintCell, expected);

        await tester.pump(const Duration(milliseconds: 1300));
        expect(_painter(tester).hintCell, isNull);
      },
    );

    testWidgets(
      'WID-JP-10 completion fires onCompleted exactly once and locks dragging',
      (tester) async {
        _useEmulatorSurface(tester);
        var completions = 0;
        Duration? lastElapsed;
        // S1-05 (contract S1-05 §5, SA-S5-4): onCompleted now
        // carries the measured Duration.
        await _pumpPlay(
          tester,
          onCompleted: (elapsed) {
            completions++;
            lastElapsed = elapsed;
          },
        );
        final order = _seededOrder();

        for (var piece = 0; piece < 9; piece++) {
          await _placeHome(tester, piece, order);
        }
        expect(_painter(tester).board.isComplete, isTrue);
        expect(completions, 1);
        expect(lastElapsed, isNotNull);
        expect(lastElapsed!.compareTo(Duration.zero) >= 0, isTrue);

        // Further dragging is locked (contract §4): piece 0 must
        // stay home and the callback must not fire again.
        final home = _painter(tester).board.homeOf(0);
        await _dragOnBoard(
          tester,
          _cellCenter(tester, home.row, home.col),
          _cellCenter(tester, (home.row + 1) % 3, home.col),
        );
        expect(_painter(tester).board.isHome(0), isTrue);
        expect(completions, 1);
      },
    );
  });

  group('App shell wiring S1-04', () {
    testWidgets(
      'WID-JP-11 tapping a theme with an asset pushes the play screen',
      (tester) async {
        _useEmulatorSurface(tester);
        await tester.pumpWidget(
          MyApp(
            themeProvider: _FakeThemeProvider(),
            assetLoader: AssetLoader(
              loadString: (_) async => _manifestJson('animals', 'animals_1_01'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Animals'));
        await tester.pumpAndSettle();

        // S2-01 (SA-WP-1) mechanical update, contract
        // S2-01 §14: the theme tap now lands on the mode
        // select screen first — one extra tap on
        // 'Jigsaw'; the final assertion is unchanged.
        expect(find.byType(ModeSelectScreen), findsOneWidget);
        await tester.tap(find.text('Jigsaw'));
        await tester.pumpAndSettle();

        expect(find.byType(JigsawPlayScreen), findsOneWidget);
      },
    );

    testWidgets(
      'WID-JP-12 tapping a theme without an asset pushes the empty screen',
      (tester) async {
        _useEmulatorSurface(tester);
        await tester.pumpWidget(
          MyApp(
            themeProvider: _FakeThemeProvider(),
            assetLoader: AssetLoader(
              loadString: (_) async => _manifestJson('space', 'space_1_01'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Animals'));
        await tester.pumpAndSettle();

        expect(find.byType(JigsawEmptyScreen), findsOneWidget);
        expect(find.bySemanticsLabel('Chưa có câu đố'), findsOneWidget);
      },
    );
  });
}

class _FakeThemeProvider implements ThemeProgressProvider {
  @override
  Future<List<ThemeViewModel>> loadThemes() async => [
    for (final info in themeCatalog)
      ThemeViewModel(
        themeId: info.id,
        displayName: info.displayName,
        puzzleCount: 1,
        solvedCount: 0,
        nextLevelLocked: false,
      ),
  ];
}

/// One manifest record with the full key set the S1-01
/// loader validates (contract S1-01 §5.3).
String _manifestJson(String theme, String id) => jsonEncode([
  {
    'image_id': id,
    'theme': theme,
    'level': 1,
    'title': 'Sample',
    'creator': {'name': 'A Creator'},
    'creation_year': 1900,
    'source': {'institution': 'An Institution'},
    'rights': {'status': 'cc0'},
    'image': {'file': '$theme/sample.jpg'},
    'text': {'en': 'A sample picture.'},
    'reviewed_by': 'James',
    'reviewed_on': '2026-11-28',
  },
]);
