// Contract E6 tests — harness/contracts/E6.md (random picker:
// pick). Written and hash-locked BEFORE the E6 engine code
// (stacked-PR process). The Generator must not edit, skip, or
// loosen these tests. Seed-pinned values were computed with an
// independent Dart script implementing the contract algorithm
// (eligible = pool minus the K_eff nearest in-pool entries of
// recentlySolved, walked from the most recent; one nextInt).
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/engine/content_mode/random_picker.dart';

String aid(int n) => 'animals_1_${n.toString().padLeft(2, '0')}';

void main() {
  final pool6 = [for (var i = 1; i <= 6; i++) aid(i)];
  final pool3 = [aid(1), aid(2), aid(3)];
  final pool4 = [for (var i = 1; i <= 4; i++) aid(i)];

  test('ENG-R-01 same seed gives the same consecutive sequence', () {
    final rng = Random(42);
    final recent = <String>[];
    final seq = <String?>[];
    for (var i = 0; i < 5; i++) {
      final r = pick(pool6, recent, 10, rng);
      seq.add(r);
      recent.add(r!);
    }
    expect(seq, [aid(2), aid(5), aid(1), aid(4), aid(6)]);
  });

  test('ENG-R-02 1000 draws never repeat a puzzle inside the window', () {
    final pool25 = [for (var i = 1; i <= 25; i++) aid(i)];
    final rng = Random(123);
    final recent = <String>[];
    for (var i = 0; i < 1000; i++) {
      final window = recent.length <= 10
          ? recent
          : recent.sublist(recent.length - 10);
      final r = pick(pool25, recent, 10, rng);
      expect(r, isNotNull);
      expect(
        window.contains(r),
        isFalse,
        reason: 'draw $i repeated $r inside the last-10 window',
      );
      recent.add(r!);
    }
  });

  test('ENG-R-03 a pool of one always returns its single puzzle', () {
    expect(pick([aid(1)], <String>[], 10, Random(0)), aid(1));
    expect(pick([aid(1)], [aid(1)], 10, Random(0)), aid(1));
    final rng = Random(5);
    final recent = <String>[];
    for (var i = 0; i < 5; i++) {
      final r = pick([aid(1)], recent, 10, rng);
      expect(r, aid(1));
      recent.add(r!);
    }
  });

  test('ENG-R-04 a pool of two with K=10 never repeats the latest', () {
    final pool2 = [aid(1), aid(2)];
    for (var seed = 0; seed <= 9; seed++) {
      expect(pick(pool2, [aid(1)], 10, Random(seed)), aid(2));
    }
    final rng = Random(3);
    final recent = <String>[];
    String? prev;
    for (var i = 0; i < 10; i++) {
      final r = pick(pool2, recent, 10, rng);
      expect(r, isNotNull);
      expect(
        r == prev,
        isFalse,
        reason: 'draw $i repeated the previous puzzle',
      );
      prev = r;
      recent.add(r!);
    }
  });

  test('ENG-R-05 only the K_eff nearest are excluded, older can return', () {
    final recent = [aid(1), aid(2), aid(3)];
    for (var seed = 0; seed <= 49; seed++) {
      final r = pick(pool6, recent, 2, Random(seed));
      expect(
        r == aid(2) || r == aid(3),
        isFalse,
        reason: 'seed $seed drew a puzzle inside the window',
      );
    }
    expect(pick(pool6, recent, 2, Random(1)), aid(1));
  });

  test('ENG-R-06 out-of-pool entries are ignored and use no window slot', () {
    final recent = [aid(1), 'space_1_99'];
    for (var seed = 0; seed <= 49; seed++) {
      expect(
        pick(pool3, recent, 1, Random(seed)) == aid(1),
        isFalse,
        reason: 'seed $seed drew the excluded puzzle',
      );
    }
    expect(pick(pool3, recent, 1, Random(1)), aid(2));
  });

  test('ENG-R-07 duplicates in recentlySolved exclude as a set', () {
    final recent = [aid(2), aid(1), aid(1)];
    final seen = <String?>{};
    for (var seed = 0; seed <= 49; seed++) {
      final r = pick(pool4, recent, 2, Random(seed));
      expect(
        r == aid(3) || r == aid(4),
        isTrue,
        reason: 'seed $seed drew an excluded puzzle',
      );
      seen.add(r);
    }
    expect(seen, {aid(3), aid(4)});
    expect(pick(pool4, recent, 2, Random(0)), aid(4));
  });

  test('ENG-R-08 an empty pool returns null', () {
    expect(pick(<String>[], <String>[], 10, Random(0)), isNull);
    expect(pick(<String>[], [aid(1)], 10, Random(0)), isNull);
  });

  test('ENG-R-09 a negative k throws ArgumentError', () {
    expect(() => pick(pool6, <String>[], -1, Random(0)), throwsArgumentError);
    expect(
      () => pick(<String>[], <String>[], -1, Random(0)),
      throwsArgumentError,
    );
  });

  test('ENG-R-10 a pool with duplicate entries throws ArgumentError', () {
    expect(
      () => pick([aid(1), aid(2), aid(1)], <String>[], 10, Random(0)),
      throwsArgumentError,
    );
  });

  test('ENG-R-11 k of zero excludes nothing', () {
    final recent = [aid(1), aid(2)];
    final seen = <String?>{};
    for (var seed = 0; seed <= 49; seed++) {
      seen.add(pick(pool3, recent, 0, Random(seed)));
    }
    expect(seen, {aid(1), aid(2), aid(3)});
    expect(pick(pool3, recent, 0, Random(3)), aid(2));
  });

  test('ENG-R-12 the eligible list preserves pool order', () {
    final pool = ['ocean_1_03', 'ocean_1_01', 'ocean_1_02'];
    expect(pick(pool, ['ocean_1_01'], 10, Random(1)), 'ocean_1_03');
  });

  test('ENG-R-13 pick does not mutate its input lists', () {
    final pool = List<String>.of(pool6);
    final recent = [aid(1), aid(2)];
    pick(pool, recent, 10, Random(0));
    expect(pool, pool6);
    expect(recent, [aid(1), aid(2)]);
  });

  test('ENG-R-14 a short recentlySolved excludes all of its puzzles', () {
    final recent = [aid(1), aid(2), aid(3)];
    for (var seed = 0; seed <= 49; seed++) {
      final r = pick(pool6, recent, 10, Random(seed));
      expect(
        recent.contains(r),
        isFalse,
        reason: 'seed $seed drew a recently solved puzzle',
      );
    }
  });

  test('ENG-R-15 purity of the content_mode engine', () {
    final src = File(
      'lib/engine/content_mode/random_picker.dart',
    ).readAsStringSync();
    expect(src.contains('DateTime.now'), isFalse);
    expect(src.contains('Random('), isFalse);
  });
}
