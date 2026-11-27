// Contract E4 tests — harness/contracts/E4.md (AnswerValidator,
// scramble). Written and hash-locked BEFORE the E4 engine code
// (stacked-PR process). The Generator must not edit, skip, or
// loosen these tests.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/engine/word/sentence.dart';
import 'package:game_puzzle/engine/word/validator.dart';

void main() {
  group('AnswerValidator E4', () {
    test('ENG-W-12 the original order is correct', () {
      final v = AnswerValidator(Sentence.parse('The lion sleeps.'));
      final check = v.check(const [0, 1, 2]);
      expect(check.status, WordCheckStatus.correct);
      expect(check.isCorrect, isTrue);
      expect(check.matchedAnswer, 'The lion sleeps.');
    });

    test('ENG-W-13 a wrong order is incorrect', () {
      final v = AnswerValidator(Sentence.parse('The lion sleeps.'));
      final check = v.check(const [1, 0, 2]);
      expect(check.status, WordCheckStatus.incorrect);
      expect(check.isCorrect, isFalse);
      expect(check.matchedAnswer, isNull);
    });

    test('ENG-W-14 an alternate order is correct', () {
      final v = AnswerValidator(
        Sentence.parse('The lion sleeps under the tree.'),
        alternates: const ['Under the tree the lion sleeps.'],
      );
      final check = v.check(const [3, 0, 5, 4, 1, 2]);
      expect(check.status, WordCheckStatus.correct);
      expect(check.matchedAnswer, 'Under the tree the lion sleeps.');
    });

    test('ENG-W-15 an order matching no answer is incorrect', () {
      final v = AnswerValidator(
        Sentence.parse('The lion sleeps under the tree.'),
        alternates: const ['Under the tree the lion sleeps.'],
      );
      final check = v.check(const [5, 4, 3, 2, 1, 0]);
      expect(check.status, WordCheckStatus.incorrect);
      expect(check.matchedAnswer, isNull);
    });

    test('ENG-W-16 capitalization differences still match an alternate', () {
      final v = AnswerValidator(
        Sentence.parse('the lion sleeps under the tree.'),
        alternates: const ['Under the tree the lion sleeps.'],
      );
      final check = v.check(const [3, 0, 5, 4, 1, 2]);
      expect(check.status, WordCheckStatus.correct);
      expect(check.matchedAnswer, 'Under the tree the lion sleeps.');
    });

    test('ENG-W-17 moved punctuation still matches an alternate', () {
      final v = AnswerValidator(
        Sentence.parse('The lion sleeps under the tree.'),
        alternates: const ['Under the tree, the lion sleeps'],
      );
      final check = v.check(const [3, 0, 5, 4, 1, 2]);
      expect(check.status, WordCheckStatus.correct);
      expect(check.matchedAnswer, 'Under the tree, the lion sleeps');
    });

    test('ENG-W-18 swapping two identical words stays correct', () {
      final v = AnswerValidator(
        Sentence.parse('The lion sleeps under the tree.'),
      );
      final check = v.check(const [4, 1, 2, 3, 0, 5]);
      expect(check.status, WordCheckStatus.correct);
      expect(check.matchedAnswer, 'The lion sleeps under the tree.');
    });

    test('ENG-W-19 a partial order is incomplete', () {
      final v = AnswerValidator(Sentence.parse('The lion sleeps.'));
      for (final partial in <List<int>>[
        [],
        [0, 1],
      ]) {
        final check = v.check(partial);
        expect(check.status, WordCheckStatus.incomplete);
        expect(check.isCorrect, isFalse);
        expect(check.matchedAnswer, isNull);
      }
    });

    test('ENG-W-20 duplicate or out-of-range indices throw', () {
      final v = AnswerValidator(Sentence.parse('The lion sleeps.'));
      expect(() => v.check(const [0, 0, 1]), throwsArgumentError);
      expect(() => v.check(const [-1, 0, 1]), throwsArgumentError);
      expect(() => v.check(const [0, 1, 3]), throwsArgumentError);
    });

    test('ENG-W-21 an alternate with a different key multiset throws', () {
      final s = Sentence.parse('The lion sleeps.');
      expect(
        () => AnswerValidator(s, alternates: const ['The lion runs.']),
        throwsArgumentError,
      );
      expect(
        () => AnswerValidator(s, alternates: const ['The lion']),
        throwsArgumentError,
      );
      expect(
        () => AnswerValidator(s, alternates: const ['The lion sleeps well.']),
        throwsArgumentError,
      );
    });

    test('ENG-W-22 an alternate differing only in case is deduplicated', () {
      final v = AnswerValidator(
        Sentence.parse('The lion sleeps.'),
        alternates: const ['THE LION SLEEPS.'],
      );
      expect(v.answers.length, 1);
      expect(v.answers, ['The lion sleeps.']);
    });

    test('ENG-W-23 cluster tokens compare against string answers by word', () {
      final s = Sentence.fromTokens(['Under the tree', 'the lion sleeps.']);
      final v = AnswerValidator(
        s,
        alternates: const ['The lion sleeps under the tree.'],
      );
      final alt = v.check(const [1, 0]);
      expect(alt.status, WordCheckStatus.correct);
      expect(alt.matchedAnswer, 'The lion sleeps under the tree.');
      final orig = v.check(const [0, 1]);
      expect(orig.status, WordCheckStatus.correct);
      expect(orig.matchedAnswer, 'Under the tree the lion sleeps.');
    });

    test('ENG-W-24 answers and tokens are unmodifiable', () {
      final s = Sentence.parse('The lion sleeps.');
      final v = AnswerValidator(s);
      expect(() => s.tokens.add(s.tokens.first), throwsUnsupportedError);
      expect(() => v.answers.add('extra'), throwsUnsupportedError);
    });
  });

  group('Scramble E4', () {
    test('ENG-W-25 scramble never returns a valid answer in 1000 seeds', () {
      final validators = [
        AnswerValidator(Sentence.parse('The lion sleeps.')),
        AnswerValidator(Sentence.parse('Lion sleeps.')),
        AnswerValidator(
          Sentence.parse('The lion sleeps under the tree.'),
          alternates: const ['Under the tree the lion sleeps.'],
        ),
      ];
      for (final v in validators) {
        for (var seed = 0; seed < 1000; seed++) {
          expect(v.accepts(v.scramble(Random(seed))), isFalse);
        }
      }
    });

    test('ENG-W-26 scramble is deterministic with a pinned value', () {
      final v = AnswerValidator(
        Sentence.parse('The lion sleeps under the tree.'),
      );
      final a = v.scramble(Random(7));
      final b = v.scramble(Random(7));
      expect(a, b);
      expect(a, [1, 3, 0, 5, 2, 4]);
      expect(v.accepts(a), isFalse);
    });

    test('ENG-W-27 canScramble is false when no wrong order exists', () {
      final one = AnswerValidator(Sentence.parse('Sleeps.'));
      expect(one.canScramble, isFalse);
      expect(one.scramble(Random(1)), [0]);
      final same = AnswerValidator(Sentence.parse('No no no.'));
      expect(same.canScramble, isFalse);
      expect(same.scramble(Random(1)).length, 3);
    });

    test('ENG-W-28 canScramble is false when alternates cover all orders', () {
      final v = AnswerValidator(
        Sentence.parse('Cat sleeps.'),
        alternates: const ['Sleeps cat.'],
      );
      expect(v.canScramble, isFalse);
      expect(v.scramble(Random(3)).length, 2);
    });
  });
}
