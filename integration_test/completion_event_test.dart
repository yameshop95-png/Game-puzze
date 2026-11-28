// Contract S1-04 integration tests — harness/contracts/S1-04.md
// §12. These run ONLY on the CI android-it gate (contract §11).
// The completion event is counted by a harness callback wrapped
// around the play screen (contract §4): S1-04 writes nothing to
// the database and shows no end screen — that is S1-05.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
/// (contract §8) — wider than the screen — so it
/// scrolls horizontally (MUSE_STEPS §6, contract §8
/// clarification). Slot centres in the contract are
/// CONTENT coordinates; the visible centre subtracts
/// the current scroll offset, tracked here across the
/// drags of one test.
double _trayScroll = 0;

double _trayCenterY(WidgetTester tester) => 56 + _boardSide(tester) + 8 + 56;

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

Future<void> _dragOnBoard(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Completion event integration S1-04', () {
    testWidgets(
      'IT-J-05 completing the board fires the callback exactly once',
      (tester) async {
        var completions = 0;
        _trayScroll = 0;
        final image = await _testImage();
        await tester.pumpWidget(
          MaterialApp(
            home: JigsawPlayScreen(
              asset: _asset,
              image: image,
              rng: Random(42),
              onCompleted: () => completions++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final order = TrayOrder.shuffled(pieceCount: 9, rng: Random(42)).order;
        final board = _painter(tester).board;

        for (var piece = 0; piece < 9; piece++) {
          final home = board.homeOf(piece);
          await _dragFromTray(
            tester,
            order.indexOf(piece),
            _cellCenter(tester, home.row, home.col),
          );
        }

        expect(_painter(tester).board.isComplete, isTrue);
        expect(completions, 1);
      },
    );

    testWidgets(
      'IT-J-06 dragging after completion changes nothing and does not refire',
      (tester) async {
        var completions = 0;
        _trayScroll = 0;
        final image = await _testImage();
        await tester.pumpWidget(
          MaterialApp(
            home: JigsawPlayScreen(
              asset: _asset,
              image: image,
              rng: Random(42),
              onCompleted: () => completions++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final order = TrayOrder.shuffled(pieceCount: 9, rng: Random(42)).order;
        final board = _painter(tester).board;

        for (var piece = 0; piece < 9; piece++) {
          final home = board.homeOf(piece);
          await _dragFromTray(
            tester,
            order.indexOf(piece),
            _cellCenter(tester, home.row, home.col),
          );
        }
        expect(completions, 1);

        final home = board.homeOf(0);
        await _dragOnBoard(
          tester,
          _cellCenter(tester, home.row, home.col),
          _cellCenter(tester, (home.row + 1) % 3, home.col),
        );

        expect(_painter(tester).board.isHome(0), isTrue);
        expect(_painter(tester).board.isComplete, isTrue);
        expect(completions, 1);
      },
    );
  });
}
