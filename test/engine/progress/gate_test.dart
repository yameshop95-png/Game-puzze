// Contract E5 tests — harness/contracts/E5.md (75% gate:
// isUnlocked / requiredSolved). Written and hash-locked BEFORE
// the E5 engine code (stacked-PR process). The Generator must
// not edit, skip, or loosen these tests. All expected values are
// hand-computed from the normative formula
// requiredSolved(n, t) = floor(t * n) + 1 using binary-exact
// thresholds only (0.75, 0.5, 0.25, 0.125, 1.0).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/engine/progress/gate.dart';

void main() {
  group('requiredSolved / isUnlocked at the game threshold 0.75', () {
    test('ENG-P-01 required for a full level of 25 is 19', () {
      expect(requiredSolved(25, 0.75), 19);
    });

    test('ENG-P-02 the unlock boundary for 25 is 19 solved', () {
      expect(isUnlocked(19, 25, 0.75), isTrue);
      expect(isUnlocked(18, 25, 0.75), isFalse);
    });

    test('ENG-P-03 required for a partial level of 10 is 8', () {
      expect(requiredSolved(10, 0.75), 8);
    });

    test('ENG-P-04 the unlock boundary for 10 is 8 solved', () {
      expect(isUnlocked(8, 10, 0.75), isTrue);
      expect(isUnlocked(7, 10, 0.75), isFalse);
    });

    test('ENG-P-05 a total of 1 requires its single puzzle', () {
      expect(requiredSolved(1, 0.75), 1);
      expect(isUnlocked(0, 1, 0.75), isFalse);
      expect(isUnlocked(1, 1, 0.75), isTrue);
    });

    test('ENG-P-06 a total of 2 requires both puzzles', () {
      expect(requiredSolved(2, 0.75), 2);
      expect(isUnlocked(1, 2, 0.75), isFalse);
      expect(isUnlocked(2, 2, 0.75), isTrue);
    });

    test('ENG-P-07 a total of 3 requires all three puzzles', () {
      expect(requiredSolved(3, 0.75), 3);
      expect(isUnlocked(2, 3, 0.75), isFalse);
      expect(isUnlocked(3, 3, 0.75), isTrue);
    });

    test('ENG-P-08 exactly 75 percent of 4 is not enough', () {
      // floor(0.75 * 4) + 1 = 4: the rule is strictly greater.
      expect(requiredSolved(4, 0.75), 4);
      expect(isUnlocked(3, 4, 0.75), isFalse);
      expect(isUnlocked(4, 4, 0.75), isTrue);
    });
  });

  group('other binary-exact thresholds', () {
    test('ENG-P-09 threshold 0.5 over 10 requires 6', () {
      expect(requiredSolved(10, 0.5), 6);
      expect(isUnlocked(5, 10, 0.5), isFalse);
      expect(isUnlocked(6, 10, 0.5), isTrue);
    });

    test('ENG-P-10 threshold 0.25 over 8 requires 3', () {
      expect(requiredSolved(8, 0.25), 3);
      expect(isUnlocked(2, 8, 0.25), isFalse);
      expect(isUnlocked(3, 8, 0.25), isTrue);
    });

    test('ENG-P-11 threshold 0.125 over 8 requires 2', () {
      expect(requiredSolved(8, 0.125), 2);
      expect(isUnlocked(1, 8, 0.125), isFalse);
      expect(isUnlocked(2, 8, 0.125), isTrue);
    });

    test('ENG-P-12 threshold 1 requires more than the total', () {
      expect(requiredSolved(25, 1.0), 26);
      expect(requiredSolved(4, 1.0), 5);
    });

    test('ENG-P-13 threshold 1 never unlocks', () {
      expect(isUnlocked(25, 25, 1.0), isFalse);
      expect(isUnlocked(4, 4, 1.0), isFalse);
    });
  });

  group('edge inputs', () {
    test('ENG-P-14 owning nothing is locked, not an error', () {
      expect(isUnlocked(0, 0, 0.75), isFalse);
    });

    test('ENG-P-15 required for owning nothing is 1, not an error', () {
      expect(requiredSolved(0, 0.75), 1);
    });

    test('ENG-P-16 negative solvedOwned throws ArgumentError', () {
      expect(() => isUnlocked(-1, 25, 0.75), throwsArgumentError);
    });

    test('ENG-P-17 negative totalOwned throws in isUnlocked', () {
      expect(() => isUnlocked(0, -1, 0.75), throwsArgumentError);
    });

    test('ENG-P-18 solved above total throws ArgumentError', () {
      expect(() => isUnlocked(26, 25, 0.75), throwsArgumentError);
      // The error wins over the totalOwned == 0 edge case.
      expect(() => isUnlocked(1, 0, 0.75), throwsArgumentError);
    });

    test('ENG-P-19 negative totalOwned throws in requiredSolved', () {
      expect(() => requiredSolved(-1, 0.75), throwsArgumentError);
    });

    test('ENG-P-20 a threshold of zero throws ArgumentError', () {
      expect(() => isUnlocked(19, 25, 0.0), throwsArgumentError);
      expect(() => requiredSolved(25, 0.0), throwsArgumentError);
    });

    test('ENG-P-21 a negative threshold throws ArgumentError', () {
      expect(() => isUnlocked(19, 25, -0.5), throwsArgumentError);
      expect(() => requiredSolved(25, -0.5), throwsArgumentError);
    });

    test('ENG-P-22 a threshold above one throws ArgumentError', () {
      expect(() => isUnlocked(19, 25, 1.5), throwsArgumentError);
      expect(() => requiredSolved(25, 1.5), throwsArgumentError);
    });

    test('ENG-P-23 a NaN threshold throws ArgumentError', () {
      expect(() => isUnlocked(19, 25, double.nan), throwsArgumentError);
      expect(() => requiredSolved(25, double.nan), throwsArgumentError);
    });

    test('ENG-P-24 an infinite threshold throws ArgumentError', () {
      expect(() => isUnlocked(19, 25, double.infinity), throwsArgumentError);
      expect(() => requiredSolved(25, double.infinity), throwsArgumentError);
    });
  });

  group('monotonicity', () {
    test('ENG-P-25 unlocking is monotone in solvedOwned', () {
      var seenUnlocked = false;
      for (var s = 0; s <= 25; s++) {
        final unlocked = isUnlocked(s, 25, 0.75);
        if (seenUnlocked) {
          expect(unlocked, isTrue, reason: 's = $s');
        }
        if (unlocked) seenUnlocked = true;
        expect(unlocked, s >= 19, reason: 's = $s');
      }
    });

    test('ENG-P-26 requiredSolved never decreases as totalOwned grows', () {
      var previous = requiredSolved(0, 0.75);
      for (var n = 1; n <= 50; n++) {
        final current = requiredSolved(n, 0.75);
        expect(current, greaterThanOrEqualTo(previous), reason: 'n = $n');
        previous = current;
      }
    });
  });

  group('purity', () {
    test('ENG-P-27 the gate file is pure Dart with no imports', () {
      final src = File('lib/engine/progress/gate.dart').readAsStringSync();
      expect(src.contains('DateTime.now'), isFalse);
      expect(src.contains('Random('), isFalse);
      final importLines = src
          .split('\n')
          .where((line) => line.trimLeft().startsWith('import '));
      expect(importLines, isEmpty);
    });
  });
}
