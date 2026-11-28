// Contract S1-06 performance tests —
// harness/contracts/S1-06.md §3/§4/§9. These run
// ONLY on the CI android-it gate (contract S1-04
// Đ11), driven in profile mode by
// test_driver/perf_driver.dart (SA-S6-3 step).
// Every number they produce is the EMULATOR gate
// and is labelled "indicative" (SA-S6-1): the
// p90 < 16 ms gate itself is settled on Paul's
// real low-end device and stays pending outside
// S1-06 — nothing here asserts a threshold.
//
// The scenario (SA-S6-2) pumps the play screen
// directly (the IT-J pattern, not the app shell —
// the shell/DB path is INT-CS territory) with the
// REAL a1p1 content: the bundled play.webp through
// the shell's own provider (ResizeImage width
// 1080, contract S1-05 §6), tray seed 42. The
// piece order is read from the painter at runtime,
// so the drags do not depend on the seed's exact
// permutation. Geometry and drag helpers follow
// contract S1-04 §8 exactly as IT-J does.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/features/jigsaw_play/jigsaw_board_painter.dart';
import 'package:game_puzzle/features/jigsaw_play/jigsaw_play_screen.dart';
import 'package:game_puzzle/services/asset_loader.dart';
import 'package:integration_test/integration_test.dart';

/// The real a1p1 record (content/manifest.json,
/// contract S1-05 §2) as the S1-01 loader derives
/// it: paths are relative to content/.
const PuzzleAsset _asset = PuzzleAsset(
  id: 'a1p1',
  theme: 'animals',
  level: 1,
  title: 'Weaning the Calves',
  textEn: 'Weaning the Calves, painted in 1879 by Rosa Bonheur.',
  playPath: 'packs/animals/1/a1p1/play.webp',
  thumbPath: 'packs/animals/1/a1p1/thumb.webp',
  creator: 'Rosa Bonheur',
  institution: 'the_met',
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
/// (contract S1-04 §8) — wider than the screen — so
/// it scrolls horizontally (MUSE_STEPS §6). Slot
/// centres in the contract are CONTENT coordinates;
/// the visible centre subtracts the current scroll
/// offset, tracked here across the drags of one
/// test and reset by _pumpPlay.
double _trayScroll = 0;

double _trayCenterY(WidgetTester tester) => 56 + _boardSide(tester) + 8 + 56;

double _scrollForSlot(WidgetTester tester, int slot) {
  final contentCenter = 16 + _cell(tester) * (slot + 0.5);
  final maxScroll = _cell(tester) * 9 - _boardSide(tester);
  final desired = contentCenter - (16 + _boardSide(tester) / 2);
  return desired.clamp(0.0, maxScroll);
}

/// Scrolls the tray strip (a horizontal tray drag
/// that is not a long-press pickup) until [slot] is
/// centred — part of the measured scenario
/// (SA-S6-2: the trace includes the tray scrolls).
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

Future<void> _pumpPlay(
  WidgetTester tester, {
  void Function(Duration)? onCompleted,
}) async {
  _trayScroll = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: JigsawPlayScreen(
        asset: _asset,
        image: const ResizeImage(
          AssetImage('content/packs/animals/1/a1p1/play.webp'),
          width: 1080,
        ),
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

/// Waits until the painter holds the decoded real
/// image (asset decode is real async work on
/// device; pumpAndSettle alone does not guarantee
/// it). Bounded: 200 rounds of pump + 50 ms.
Future<void> _waitForImage(WidgetTester tester) async {
  for (var i = 0; i < 200 && _painter(tester).image == null; i++) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// Long-press drag out of the tray (contract
/// S1-04 §9): scroll the slot into view, hold past
/// the long-press timeout, then move and release.
Future<void> _dragFromTray(WidgetTester tester, int slot, Offset to) async {
  await _scrollTrayTo(tester, slot);
  final gesture = await tester.startGesture(_slotCenter(tester, slot));
  await tester.pump(const Duration(milliseconds: 600));
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
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance S1-06 (emulator, indicative)', () {
    testWidgets(
      'PERF-01 touch-to-image time is measured and recorded, not gated',
      (tester) async {
        // SA-S6-4: the stopwatch starts at the
        // scenario's "touch" (the pump that opens
        // the play screen with the real content
        // image) and stops at the first frame whose
        // painter holds the decoded image.
        final stopwatch = Stopwatch()..start();
        await _pumpPlay(tester);
        await _waitForImage(tester);
        stopwatch.stop();

        expect(
          _painter(tester).image,
          isNotNull,
          reason: 'the real play image must decode and appear',
        );
        binding.reportData ??= <String, dynamic>{};
        binding.reportData!['touch_to_image_ms'] =
            stopwatch.elapsedMilliseconds;
        debugPrint(
          'PERF touch_to_image_ms=${stopwatch.elapsedMilliseconds} '
          '(indicative, emulator)',
        );
      },
    );

    testWidgets('PERF-02 traced full solve of a1p1 under traceAction', (
      tester,
    ) async {
      var completions = 0;
      await _pumpPlay(tester, onCompleted: (_) => completions++);
      await _waitForImage(tester);
      expect(_painter(tester).image, isNotNull);
      final order = _painter(tester).trayOrder.order;

      // SA-S6-2 + SA-S6-8: the trace wraps the
      // WHOLE drag sequence — all 9 pieces home,
      // tray scrolls included via the drag helper.
      await binding.traceAction(() async {
        for (var piece = 0; piece < 9; piece++) {
          await _placeHome(tester, piece, order);
        }
      }, reportKey: 'timeline');

      // The scenario really ran end to end; the
      // perf NUMBERS are read from the timeline
      // summary by the driver/CI and are indicative
      // only — no threshold is asserted here.
      expect(_painter(tester).board.isComplete, isTrue);
      expect(completions, 1);
    });
  });
}
