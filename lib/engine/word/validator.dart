/// Answer checking and scrambling for the word engine — contract
/// E4 (harness/contracts/E4.md, decisions 2–5). Pure Dart: no
/// Flutter imports, no clock. Randomness only enters through a
/// caller supplied [Random] (seeded by the caller).
library;

import 'dart:math' show Random;

import 'sentence.dart';

/// The outcome of checking a player order (contract E4, decision 3).
enum WordCheckStatus { incomplete, correct, incorrect }

/// The result of [AnswerValidator.check]. A pure value: checking
/// the same order always gives the same result.
final class WordCheck {
  const WordCheck._(this.status, this.matchedAnswer);

  final WordCheckStatus status;

  /// The answer string that matched, verbatim as supplied, when
  /// [status] is [WordCheckStatus.correct]; otherwise null.
  final String? matchedAnswer;

  bool get isCorrect => status == WordCheckStatus.correct;
}

/// Checks player orders against the list of valid answers for one
/// [Sentence] (contract E4, decision 2): the original sentence is
/// the implicit answer zero, and the caller may supply full-sentence
/// alternates. Comparison is by normalized key sequence (decision
/// 3), never by raw strings and never by grammar.
final class AnswerValidator {
  /// Throws [ArgumentError] when any alternate's normalized key
  /// multiset differs from the sentence's — bad content data fails
  /// here, at construction, not while a player is playing.
  AnswerValidator(Sentence sentence, {List<String> alternates = const []})
    : _sentence = sentence {
    final baseKeys = _keySequence(sentence);
    final baseMultiset = [...baseKeys]..sort();
    final answers = <String>[sentence.text];
    final answerKeys = <List<String>>[baseKeys];
    final seen = <String>{baseKeys.join('\u0001')};
    for (final alternate in alternates) {
      final altKeys = Sentence.normalizeWords(alternate);
      final altMultiset = [...altKeys]..sort();
      if (!_listEquals(altMultiset, baseMultiset)) {
        throw ArgumentError.value(
          alternate,
          'alternates',
          'must use the same words as the sentence',
        );
      }
      if (seen.add(altKeys.join('\u0001'))) {
        answers.add(alternate);
        answerKeys.add(altKeys);
      }
    }
    _answers = List<String>.unmodifiable(answers);
    _answerKeys = answerKeys;
  }

  final Sentence _sentence;
  late final List<String> _answers;
  late final List<List<String>> _answerKeys;

  /// The sentence this validator checks orders for.
  Sentence get sentence => _sentence;

  /// All accepted answers, original first, deduplicated by key
  /// sequence. Unmodifiable.
  List<String> get answers => _answers;

  static List<String> _keySequence(Sentence sentence) => [
    for (final token in sentence.tokens) ...token.keys,
  ];

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Checks a player [order] (token indices in the order the player
  /// arranged them). Throws [ArgumentError] for a duplicate, a
  /// negative, or an out-of-range index. A short order is
  /// [WordCheckStatus.incomplete]; a full order is correct when its
  /// key sequence equals at least one answer's, else incorrect.
  WordCheck check(List<int> order) {
    final n = _sentence.length;
    final seen = <int>{};
    for (final index in order) {
      if (index < 0 || index >= n || !seen.add(index)) {
        throw ArgumentError.value(
          order,
          'order',
          'indices must be distinct and within 0..${n - 1}',
        );
      }
    }
    if (order.length < n) {
      return const WordCheck._(WordCheckStatus.incomplete, null);
    }
    final sequence = [
      for (final index in order) ..._sentence.tokens[index].keys,
    ];
    for (var a = 0; a < _answerKeys.length; a++) {
      if (_listEquals(sequence, _answerKeys[a])) {
        return WordCheck._(WordCheckStatus.correct, _answers[a]);
      }
    }
    return const WordCheck._(WordCheckStatus.incorrect, null);
  }

  /// Whether [order] is a complete, accepted arrangement.
  bool accepts(List<int> order) => check(order).isCorrect;

  /// Whether at least one arrangement of the tokens is NOT a valid
  /// answer (contract E4, decision 5.4): the number of distinct key
  /// sequences the tokens can form exceeds the number of those
  /// sequences that are answers.
  bool get canScramble {
    final tuples = [for (final token in _sentence.tokens) token.keys];
    var realizableAnswers = 0;
    for (final answerKey in _answerKeys) {
      if (_segmentable(answerKey, tuples)) realizableAnswers++;
    }
    return _distinctSequences(tuples, cap: realizableAnswers) >
        realizableAnswers;
  }

  /// Whether [sequence] can be formed by concatenating the token
  /// key tuples, each used once. Single-word tokens always can
  /// (their multiset was validated at construction); cluster tokens
  /// are resolved by a small backtracking search.
  static bool _segmentable(List<String> sequence, List<List<String>> tuples) {
    if (tuples.every((t) => t.length == 1)) return true;
    final used = List<bool>.filled(tuples.length, false);
    final failed = <String>{};
    bool search(int pos) {
      if (pos == sequence.length) return true;
      final state = '$pos|${used.map((u) => u ? '1' : '0').join()}';
      if (failed.contains(state)) return false;
      for (var i = 0; i < tuples.length; i++) {
        if (used[i]) continue;
        final tuple = tuples[i];
        if (pos + tuple.length > sequence.length) continue;
        var matches = true;
        for (var k = 0; k < tuple.length; k++) {
          if (sequence[pos + k] != tuple[k]) {
            matches = false;
            break;
          }
        }
        if (!matches) continue;
        used[i] = true;
        if (search(pos + tuple.length)) return true;
        used[i] = false;
      }
      failed.add(state);
      return false;
    }

    return search(0);
  }

  /// The number of distinct key sequences formable from [tuples]
  /// (a multinomial over identical tuples), counted only up to
  /// `cap + 1` — the caller only needs to know whether it exceeds
  /// [cap].
  static int _distinctSequences(List<List<String>> tuples, {required int cap}) {
    final groups = <String, int>{};
    for (final tuple in tuples) {
      final key = tuple.join('\u0001');
      groups[key] = (groups[key] ?? 0) + 1;
    }
    var result = BigInt.one;
    final capBig = BigInt.from(cap);
    var remaining = tuples.length;
    for (final groupSize in groups.values) {
      result *= _binomial(remaining, groupSize);
      if (result > capBig) return cap + 1;
      remaining -= groupSize;
    }
    return result.toInt();
  }

  static BigInt _binomial(int n, int k) {
    var result = BigInt.one;
    for (var i = 0; i < k; i++) {
      result = result * BigInt.from(n - i) ~/ BigInt.from(i + 1);
    }
    return result;
  }

  /// A shuffled token order that is NOT a valid answer (contract
  /// E4, decision 5.2): Fisher–Yates via [Sentence.shuffle] on the
  /// same [random], at most [maxAttempts] tries, returning the
  /// first non-answer. When no wrong order exists
  /// ([canScramble] is false) every attempt is an answer, and the
  /// last attempt is returned without throwing. Deterministic for
  /// a seeded [random]. Throws [ArgumentError] when
  /// [maxAttempts] < 1.
  List<int> scramble(Random random, {int maxAttempts = 64}) {
    if (maxAttempts < 1) {
      throw ArgumentError.value(
        maxAttempts,
        'maxAttempts',
        'must be at least 1',
      );
    }
    var last = _sentence.shuffle(random);
    if (!accepts(last)) return last;
    for (var attempt = 1; attempt < maxAttempts; attempt++) {
      last = _sentence.shuffle(random);
      if (!accepts(last)) return last;
    }
    return last;
  }
}
