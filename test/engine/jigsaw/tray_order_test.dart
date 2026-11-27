// Contract E3 tests — harness/contracts/E3.md (TrayOrder).
// Written and hash-locked BEFORE the E3 engine code (stacked-PR
// process). The Generator must not edit, skip, or loosen these tests.
// Test names carry the gate ID (ENG-J-xx) followed by the Opus ID
// (E3-Txx) — see the mapping table in E3.md section 5.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/engine/jigsaw/tray_order.dart';

void main() {
  group('TrayOrder E3', () {
    test('ENG-J-44 E3-T01 shuffled order is a permutation of all ids',
        () {
      final tray = TrayOrder.shuffled(pieceCount: 9, rng: Random(42));
      expect(tray.length, 9);
      final sorted = tray.toList()..sort();
      expect(sorted, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('ENG-J-45 E3-T02 the same seed gives the same order', () {
      final a = TrayOrder.shuffled(pieceCount: 9, rng: Random(7));
      final b = TrayOrder.shuffled(pieceCount: 9, rng: Random(7));
      expect(a.toList(), b.toList());
    });

    test('ENG-J-46 E3-T03 toList and fromList round-trip', () {
      final tray = TrayOrder.shuffled(pieceCount: 9, rng: Random(3));
      final restored = TrayOrder.fromList(tray.toList());
      expect(restored.toList(), tray.toList());
      expect(restored.length, tray.length);
    });

    test('ENG-J-47 E3-T04 fromList rejects non-permutations', () {
      expect(
        () => TrayOrder.fromList(const [0, 0, 1]),
        throwsArgumentError,
      ); // duplicate
      expect(
        () => TrayOrder.fromList(const [0, 2]),
        throwsArgumentError,
      ); // missing 1 / out of range for length 2
      expect(
        () => TrayOrder.fromList(const [0, 1, 3]),
        throwsArgumentError,
      ); // out of range
      expect(
        () => TrayOrder.fromList(const []),
        throwsArgumentError,
      ); // empty
    });

    test('ENG-J-48 E3-T05 visible hides placed pieces', () {
      final tray = TrayOrder.fromList(const [3, 0, 4, 1, 2]);
      final visible = tray.visible((id) => id == 0 || id == 4);
      expect(visible, [3, 1, 2]);
    });

    test('ENG-J-49 E3-T06 an unplaced piece returns to its old tray '
        'slot', () {
      final tray = TrayOrder.fromList(const [2, 0, 1]);
      final placed = <int>{};
      expect(tray.visible(placed.contains), [2, 0, 1]);
      placed.add(0);
      expect(tray.visible(placed.contains), [2, 1]);
      placed.remove(0);
      expect(tray.visible(placed.contains), [2, 0, 1]);
      expect(tray.indexOf(0), 1);
    });

    test('ENG-J-50 E3-T07 indexOf is stable', () {
      final tray = TrayOrder.fromList(const [5, 3, 0, 4, 1, 2]);
      expect(tray.indexOf(5), 0);
      expect(tray.indexOf(0), 2);
      expect(tray.indexOf(2), 5);
      expect(tray.indexOf(99), -1);
      tray.visible((id) => id == 5 || id == 3);
      tray.visible((_) => false);
      expect(tray.indexOf(5), 0);
      expect(tray.indexOf(2), 5);
    });

    test('ENG-J-51 E3-T08 order cannot be mutated', () {
      final tray = TrayOrder.fromList(const [1, 0, 2]);
      expect(() => tray.order.add(3), throwsUnsupportedError);
      expect(() => tray.order[0] = 9, throwsUnsupportedError);
      final copy = tray.toList();
      copy.add(99);
      copy[0] = 7;
      expect(tray.length, 3);
      expect(tray.toList(), [1, 0, 2]);
    });

    test('ENG-J-52 E3-T09 pieceCount below one is rejected', () {
      expect(
        () => TrayOrder.shuffled(pieceCount: 0, rng: Random(1)),
        throwsArgumentError,
      );
      expect(
        () => TrayOrder.shuffled(pieceCount: -3, rng: Random(1)),
        throwsArgumentError,
      );
    });
  });
}
