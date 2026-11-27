// Contract E4 tests — harness/contracts/E4.md (Sentence, shuffle,
// WordBoard). Written and hash-locked BEFORE the E4 engine code
// (stacked-PR process). The Generator must not edit, skip, or
// loosen these tests. Pinned shuffle values are the output of the
// contract's Fisher-Yates (decision 5.1) under Dart's Random(seed).
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/engine/word/sentence.dart';
import 'package:game_puzzle/engine/word/validator.dart';

void main() {
  group('Sentence tokenizing E4', () {
    test('ENG-W-01 parse splits a sentence into word tokens', () {
      final s = Sentence.parse('The lion sleeps.');
      expect(s.length, 3);
      expect(s.tokens.map((t) => t.text), ['The', 'lion', 'sleeps.']);
      expect(s.tokens.map((t) => t.index), [0, 1, 2]);
      expect(s.tokens.map((t) => t.keys).toList(), [
        ['the'],
        ['lion'],
        ['sleeps'],
      ]);
      expect(s.text, 'The lion sleeps.');
    });

    test('ENG-W-02 punctuation stays attached to its word', () {
      final s = Sentence.parse('Hello, world! How are you?');
      expect(s.tokens.map((t) => t.text), [
        'Hello,',
        'world!',
        'How',
        'are',
        'you?',
      ]);
      expect(s.tokens.expand((t) => t.keys).toList(), [
        'hello',
        'world',
        'how',
        'are',
        'you',
      ]);
    });

    test('ENG-W-03 extra whitespace tabs and newlines collapse', () {
      final s = Sentence.parse('  The\t lion\n  sleeps.  ');
      expect(s.length, 3);
      expect(s.tokens.map((t) => t.text), ['The', 'lion', 'sleeps.']);
      expect(s.text, 'The lion sleeps.');
    });

    test('ENG-W-04 punctuation-only fragments merge into a neighbour', () {
      final mid = Sentence.parse('The lion — sleeps.');
      expect(mid.length, 3);
      expect(mid.tokens[1].text, 'lion —');
      expect(mid.tokens[1].keys, ['lion']);
      final lead = Sentence.parse('— The lion sleeps.');
      expect(lead.length, 3);
      expect(lead.tokens[0].text, '— The');
      expect(lead.tokens[0].keys, ['the']);
    });

    test('ENG-W-05 empty input throws ArgumentError', () {
      expect(() => Sentence.parse(''), throwsArgumentError);
      expect(() => Sentence.parse('   \n\t '), throwsArgumentError);
      expect(() => Sentence.parse('—'), throwsArgumentError);
      expect(() => Sentence.fromTokens(const []), throwsArgumentError);
    });

    test('ENG-W-06 fromTokens clusters give multi-word keys', () {
      final s = Sentence.fromTokens(['Under the tree', 'the lion sleeps.']);
      expect(s.length, 2);
      expect(s.tokens[0].keys, ['under', 'the', 'tree']);
      expect(s.tokens[1].keys, ['the', 'lion', 'sleeps']);
      expect(s.text, 'Under the tree the lion sleeps.');
    });

    test('ENG-W-07 normalizeWords strips ends and lowercases', () {
      expect(Sentence.normalizeWords("Don't  WELL-KNOWN.  (Sleeps)"), [
        "don't",
        'well-known',
        'sleeps',
      ]);
    });

    test('ENG-W-08 normalizeWords strips unicode punctuation at ends', () {
      expect(Sentence.normalizeWords('“Hello,” ‘world’ «again» –done–'), [
        'hello',
        'world',
        'again',
        'done',
      ]);
    });
  });

  group('Sentence shuffle E4', () {
    test('ENG-W-09 shuffle is deterministic and a valid permutation', () {
      final s = Sentence.parse('One two three four five six.');
      final a = s.shuffle(Random(42));
      final b = s.shuffle(Random(42));
      expect(a, b);
      expect(a, [4, 2, 5, 0, 3, 1]);
      final sorted = [...a]..sort();
      expect(sorted, [0, 1, 2, 3, 4, 5]);
    });

    test('ENG-W-10 a different seed gives a different pinned shuffle', () {
      final s = Sentence.parse('One two three four five six.');
      final a = s.shuffle(Random(43));
      expect(a, [4, 1, 3, 0, 5, 2]);
      expect(a, isNot(s.shuffle(Random(42))));
    });

    test('ENG-W-11 word engine files use no unseeded Random or clock', () {
      for (final path in [
        'lib/engine/word/sentence.dart',
        'lib/engine/word/validator.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('Random()'), isFalse, reason: path);
        expect(src.contains('DateTime.now'), isFalse, reason: path);
      }
    });
  });

  group('WordBoard E4', () {
    test('ENG-W-29 PickToken moves a token from pool to answer', () {
      final board = WordBoard.initial(const [2, 0, 1]);
      expect(board.order, [2, 0, 1]);
      expect(board.pool, [2, 0, 1]);
      expect(board.answer, isEmpty);
      final next = board.apply(const PickToken(0));
      expect(next.answer, [0]);
      expect(next.pool, [2, 1]);
      // The old board is immutable.
      expect(board.answer, isEmpty);
      expect(board.pool, [2, 0, 1]);
    });

    test('ENG-W-30 ReturnToken restores the pool position from order', () {
      var board = WordBoard.initial(const [2, 0, 1]);
      board = board.apply(const PickToken(0));
      board = board.apply(const PickToken(2));
      expect(board.answer, [0, 2]);
      expect(board.pool, [1]);
      board = board.apply(const ReturnToken(0));
      expect(board.answer, [2]);
      expect(board.pool, [0, 1]);
    });

    test('ENG-W-31 invalid commands follow the PlacePiece error split', () {
      final board = WordBoard.initial(const [0, 1, 2]);
      final before = board.toMap();
      expect(() => board.apply(const PickToken(7)), throwsArgumentError);
      expect(board.toMap(), before);
      final picked = board.apply(const PickToken(0));
      expect(() => picked.apply(const PickToken(0)), throwsStateError);
      expect(() => board.apply(const ReturnToken(1)), throwsStateError);
    });

    test('ENG-W-32 initial rejects non-permutations', () {
      expect(() => WordBoard.initial(const [0, 0, 1]), throwsArgumentError);
      expect(() => WordBoard.initial(const [0, 2]), throwsArgumentError);
      expect(() => WordBoard.initial(const [1, 2, 3]), throwsArgumentError);
      expect(() => WordBoard.initial(const []), throwsArgumentError);
    });

    test('ENG-W-33 toMap and fromMap round-trip with a pinned shape', () {
      final board = WordBoard.initial(const [
        2,
        0,
        1,
      ]).apply(const PickToken(2));
      final map = board.toMap();
      expect(map, {
        'v': 1,
        'order': [2, 0, 1],
        'answer': [2],
      });
      expect(map.keys.toSet(), {'v', 'order', 'answer'});
      final restored = WordBoard.fromMap(map);
      expect(restored.order, board.order);
      expect(restored.answer, board.answer);
      expect(restored.toMap(), map);
    });

    test('ENG-W-34 fromMap rejects malformed maps', () {
      expect(
        () => WordBoard.fromMap(const <String, Object?>{}),
        throwsFormatException,
      );
      expect(
        () => WordBoard.fromMap(const {
          'v': 2,
          'order': [0],
          'answer': <int>[],
        }),
        throwsFormatException,
      );
      expect(
        () => WordBoard.fromMap(const {
          'v': 1,
          'order': [0, 0],
          'answer': <int>[],
        }),
        throwsFormatException,
      );
      expect(
        () => WordBoard.fromMap(const {
          'v': 1,
          'order': [0, 1],
          'answer': [1, 1],
        }),
        throwsFormatException,
      );
      expect(
        () => WordBoard.fromMap(const {
          'v': 1,
          'order': [0, 1],
          'answer': [2],
        }),
        throwsFormatException,
      );
      expect(
        () => WordBoard.fromMap(const {
          'v': 1,
          'order': 'nope',
          'answer': <int>[],
        }),
        throwsFormatException,
      );
    });

    test('ENG-W-35 scramble then picking the original order solves', () {
      final sentence = Sentence.parse('The lion sleeps.');
      final validator = AnswerValidator(sentence);
      final order = validator.scramble(Random(11));
      var board = WordBoard.initial(order);
      for (final i in [0, 1, 2]) {
        board = board.apply(PickToken(i));
      }
      expect(board.isFull, isTrue);
      expect(validator.check(board.answer).status, WordCheckStatus.correct);
    });
  });
}
