// Contract S1-04 integration tests — harness/contracts/S1-04.md
// §12. These run ONLY on the CI android-it gate (contract §11),
// never as a local gate: the local machine has no emulator.
// Geometry follows contract §8 and is computed from the real
// surface size at runtime. The test image is generated
// deterministically in memory (contract §2) — no PNG fixture.
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
  final trayTop = 56 + _boardSide(tester) + 8;
  return Offset(16 + cell * (slot + 0.5), trayTop + 56);
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
  void Function()? onCompleted,
}) async {
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

Future<void> _dragFromTray(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Jigsaw snap integration S1-04', () {
    testWidgets('IT-J-01 drag within tolerance snaps the piece home', (
      tester,
    ) async {
      await _pumpPlay(tester);
      final order = _seededOrder();
      final piece = order.first;
      final home = _painter(tester).board.homeOf(piece);

      await _dragFromTray(
        tester,
        _slotCenter(tester, 0),
        _cellCenter(tester, home.row, home.col),
      );

      expect(_painter(tester).board.isHome(piece), isTrue);
    });

    testWidgets('IT-J-02 drop outside tolerance does not snap', (tester) async {
      await _pumpPlay(tester);
      final order = _seededOrder();
      final piece = order.first;

      await _dragFromTray(tester, _slotCenter(tester, 0), const Offset(17, 57));

      final board = _painter(tester).board;
      expect(board.isPlaced(piece), isFalse);
      expect(board.placedCount, 0);
    });

    testWidgets('IT-J-03 drop on a wrong empty cell stays there', (
      tester,
    ) async {
      await _pumpPlay(tester);
      final order = _seededOrder();
      final piece = order.first;
      final home = _painter(tester).board.homeOf(piece);
      final wrongRow = (home.row + 1) % 3;

      await _dragFromTray(
        tester,
        _slotCenter(tester, 0),
        _cellCenter(tester, wrongRow, home.col),
      );

      final board = _painter(tester).board;
      expect(board.positionOf(piece), CellPos(wrongRow, home.col));
      expect(board.isHome(piece), isFalse);
    });

    testWidgets(
      'IT-J-04 drop on an occupied cell returns the piece to the tray',
      (tester) async {
        await _pumpPlay(tester);
        final order = _seededOrder();
        final first = order[0];
        final second = order[1];
        final home = _painter(tester).board.homeOf(first);

        await _dragFromTray(
          tester,
          _slotCenter(tester, 0),
          _cellCenter(tester, home.row, home.col),
        );
        expect(_painter(tester).board.isHome(first), isTrue);

        await _dragFromTray(
          tester,
          _slotCenter(tester, 1),
          _cellCenter(tester, home.row, home.col),
        );

        final board = _painter(tester).board;
        expect(board.isHome(first), isTrue);
        expect(board.isPlaced(second), isFalse);
        expect(board.placedCount, 1);
      },
    );
  });
}
