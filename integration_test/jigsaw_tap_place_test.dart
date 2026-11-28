// Contract S2-02 integration tests — harness/contracts/S2-02.md
// §12. These run ONLY on the CI android-it gate, never as a
// local gate: the local machine has no emulator. Geometry
// follows contract S1-04 §8 and is computed from the real
// surface size at runtime. The test image is generated
// deterministically in memory — no PNG fixture.
//
// "No drag" follows the settled definition (contract S2-02
// §10, SA-J2-9 reading (a)): no drag gesture is ever applied
// TO A PIECE — every piece/cell interaction below is a tap
// (tapAt). The tray strip is wider than the screen, so
// scrolling it keeps using the tray-bed drag, exactly like
// the older IT-J tests: tray scrolling and piece dragging
// are different gestures in the §6 design.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/engine/jigsaw/board.dart';
import 'package:game_puzzle/engine/jigsaw/tray_order.dart';
import 'package:game_puzzle/features/jigsaw_play/jigsaw_board_painter.dart';
import 'package:game_puzzle/features/jigsaw_play/jigsaw_play_screen.dart';
import 'package:game_puzzle/services/asset_loader.dart';
import 'package:integration_test/integration_test.dart';

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

double _boardSide(WidgetTester tester) =>
    tester.view.physicalSize.width / tester.view.devicePixelRatio - 32;

double _cell(WidgetTester tester) => _boardSide(tester) / 3;

Offset _cellCenter(WidgetTester tester, int row, int col) {
  final cell = _cell(tester);
  return Offset(16 + cell * (col + 0.5), 56 + cell * (row + 0.5));
}

Offset _slotCenter(WidgetTester tester, int slot) {
  final cell = _cell(tester);
  return Offset(16 + cell * (slot + 0.5) - _trayScroll, _trayCenterY(tester));
}

/// The tray strip holds 9 slots of one cell each
/// (contract S1-04 §8) — wider than the screen — so it
/// scrolls horizontally. Slot centres in the contract are
/// CONTENT coordinates; the visible centre subtracts the
/// current scroll offset, tracked here across the taps of
/// one test.
double _trayScroll = 0;

double _trayCenterY(WidgetTester tester) => 56 + _boardSide(tester) + 8 + 56;

double _scrollForSlot(WidgetTester tester, int slot) {
  final contentCenter = 16 + _cell(tester) * (slot + 0.5);
  final maxScroll = _cell(tester) * 9 - _boardSide(tester);
  final desired = contentCenter - (16 + _boardSide(tester) / 2);
  return desired.clamp(0.0, maxScroll);
}

/// Scrolls the tray strip (a horizontal tray-bed drag,
/// never a piece drag) until [slot] is centred.
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
  final image = await _testImage();
  await tester.pumpWidget(
    MaterialApp(
      home: JigsawPlayScreen(
        asset: _asset,
        image: image,
        rng: Random(42),
        onCompleted: onCompleted,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

JigsawBoardPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('jigsaw-board-painter')),
  );
  return paint.painter! as JigsawBoardPainter;
}

List<int> _seededOrder() =>
    TrayOrder.shuffled(pieceCount: 9, rng: Random(42)).order;

/// A pure tap: down + up at the same point, no movement —
/// the only gesture ever applied to a piece or a cell in
/// this file (contract S2-02 §10).
Future<void> _tapAt(WidgetTester tester, Offset pos) async {
  await tester.tapAt(pos);
  await tester.pump();
}

/// Selects a tray piece by tapping it: scroll its slot
/// into view (tray-bed drag), then tap its centre.
Future<void> _tapTraySlot(WidgetTester tester, int slot) async {
  await _scrollTrayTo(tester, slot);
  await _tapAt(tester, _slotCenter(tester, slot));
}

/// Places one piece home using taps only: tap the tray
/// piece to select it, tap its home cell to place it.
Future<void> _tapPlaceHome(
  WidgetTester tester,
  int piece,
  List<int> order,
) async {
  final home = _painter(tester).board.homeOf(piece);
  await _tapTraySlot(tester, order.indexOf(piece));
  expect(_painter(tester).selectedPieceId, piece);
  await _tapAt(tester, _cellCenter(tester, home.row, home.col));
  expect(_painter(tester).board.isHome(piece), isTrue);
  expect(_painter(tester).selectedPieceId, isNull);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Jigsaw tap-to-place integration S2-02', () {
    testWidgets('IT-J-07 solving the whole 3x3 by taps only completes it', (
      tester,
    ) async {
      var completions = 0;
      await _pumpPlay(tester, onCompleted: (_) => completions++);
      final order = _seededOrder();

      for (var piece = 0; piece < 9; piece++) {
        await _tapPlaceHome(tester, piece, order);
      }

      expect(_painter(tester).board.isComplete, isTrue);
      expect(completions, 1);
    });

    testWidgets(
      'IT-J-08 select, place wrong by tap, re-select and move home by tap',
      (tester) async {
        await _pumpPlay(tester);
        final order = _seededOrder();
        final piece = order.first;
        final board = _painter(tester).board;
        final home = board.homeOf(piece);
        final wrongRow = (home.row + 1) % 3;

        // Select by tap, then tap a wrong empty cell:
        // the piece lands there (the core fix-up path
        // of SA-J2-2 — a non-dragging user must be
        // able to correct a misplaced piece).
        await _tapTraySlot(tester, 0);
        expect(_painter(tester).selectedPieceId, piece);
        await _tapAt(tester, _cellCenter(tester, wrongRow, home.col));
        expect(board.positionOf(piece), CellPos(wrongRow, home.col));
        expect(board.isHome(piece), isFalse);
        expect(_painter(tester).selectedPieceId, isNull);

        // Tap the placed piece to select it again,
        // then tap its home cell: it moves home.
        await _tapAt(tester, _cellCenter(tester, wrongRow, home.col));
        expect(_painter(tester).selectedPieceId, piece);
        await _tapAt(tester, _cellCenter(tester, home.row, home.col));
        expect(board.isHome(piece), isTrue);
        expect(_painter(tester).selectedPieceId, isNull);
      },
    );
  });
}
