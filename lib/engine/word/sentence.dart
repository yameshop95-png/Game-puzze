/// Word engine: tokens, sentences and the word board — contract E4
/// (harness/contracts/E4.md). Pure Dart: no Flutter imports, no
/// dart:io, no clock. Randomness only enters through a caller
/// supplied [Random] (seeded by the caller).
library;

import 'dart:math' show Random;

/// One token of a sentence: a single word for parsed sentences, or a
/// caller-supplied cluster for [Sentence.fromTokens]. The [text] is
/// verbatim — case and attached punctuation are preserved; matching
/// is done on the normalized [keys] (contract E4, decision 3).
final class WordToken {
  const WordToken(this.index, this.text);

  /// Position in the original order, `0..n-1`.
  final int index;

  /// Verbatim text: original case and attached punctuation.
  final String text;

  /// Normalized keys of this token (contract E4, decision 3): one
  /// for a word token, several for a cluster token. Unmodifiable.
  List<String> get keys =>
      List<String>.unmodifiable(Sentence.normalizeWords(text));
}

/// An immutable sentence split into [WordToken]s (contract E4,
/// decision 1: a token is a word; punctuation stays attached).
final class Sentence {
  Sentence._(List<WordToken> tokens)
    : _tokens = List<WordToken>.unmodifiable(tokens);

  final List<WordToken> _tokens;

  /// Splits [text] on whitespace runs. A punctuation-only fragment
  /// (one whose normalized key is empty, e.g. an em dash standing
  /// alone) merges into the previous token, or into the next one
  /// when it leads the sentence; it never becomes a token of its
  /// own. Throws [ArgumentError] when no real word remains.
  factory Sentence.parse(String text) {
    final parts = text
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final tokenTexts = <String>[];
    var pendingPrefix = '';
    for (final part in parts) {
      if (Sentence.normalizeWords(part).isEmpty) {
        if (tokenTexts.isNotEmpty) {
          tokenTexts[tokenTexts.length - 1] = '${tokenTexts.last} $part';
        } else {
          pendingPrefix = pendingPrefix.isEmpty ? part : '$pendingPrefix $part';
        }
      } else {
        tokenTexts.add(pendingPrefix.isEmpty ? part : '$pendingPrefix $part');
        pendingPrefix = '';
      }
    }
    if (tokenTexts.isEmpty) {
      throw ArgumentError.value(text, 'text', 'must contain at least one word');
    }
    return Sentence._([
      for (var i = 0; i < tokenTexts.length; i++) WordToken(i, tokenTexts[i]),
    ]);
  }

  /// Builds a sentence from tokens the caller already split (the
  /// escape hatch for phrase/clause tokens later). Throws
  /// [ArgumentError] for an empty list, a blank token, or a token
  /// with no normalized key (punctuation only).
  factory Sentence.fromTokens(List<String> tokens) {
    if (tokens.isEmpty) {
      throw ArgumentError.value(tokens, 'tokens', 'must not be empty');
    }
    for (final token in tokens) {
      if (token.trim().isEmpty || Sentence.normalizeWords(token).isEmpty) {
        throw ArgumentError.value(
          tokens,
          'tokens',
          'every token must contain at least one word',
        );
      }
    }
    return Sentence._([
      for (var i = 0; i < tokens.length; i++) WordToken(i, tokens[i]),
    ]);
  }

  /// The sentence text: token texts joined by single spaces.
  String get text => _tokens.map((t) => t.text).join(' ');

  /// The tokens in original order. Unmodifiable.
  List<WordToken> get tokens => _tokens;

  /// Number of tokens.
  int get length => _tokens.length;

  /// A Fisher–Yates permutation of the token indices `0..length-1`
  /// driven by [random] (contract E4, decision 5.1): iterate `i`
  /// from the end, swap with `j = random.nextInt(i + 1)`. Pure: it
  /// never looks at any answer list and never changes the sentence.
  List<int> shuffle(Random random) {
    final order = List<int>.generate(length, (i) => i);
    for (var i = order.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = order[i];
      order[i] = order[j];
      order[j] = tmp;
    }
    return order;
  }

  /// The normalized keys of every word in [s], in order (contract
  /// E4, decision 3): each word is lowercased after stripping every
  /// leading/trailing character that is not a Unicode letter or
  /// digit; punctuation inside a word is kept. Words whose key is
  /// empty (punctuation only) are dropped.
  static List<String> normalizeWords(String s) {
    final keys = <String>[];
    for (final raw in s.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      final key = _normalizeWord(raw);
      if (key.isNotEmpty) keys.add(key);
    }
    return keys;
  }

  static String _normalizeWord(String word) {
    final runes = word.runes.toList();
    var start = 0;
    var end = runes.length;
    while (start < end && !_isLetterOrDigit(runes[start])) {
      start++;
    }
    while (end > start && !_isLetterOrDigit(runes[end - 1])) {
      end--;
    }
    if (start >= end) return '';
    return String.fromCharCodes(runes.sublist(start, end)).toLowerCase();
  }

  static final RegExp _letterOrDigit = RegExp(r'^[\p{L}\p{N}]$', unicode: true);

  static bool _isLetterOrDigit(int rune) =>
      _letterOrDigit.hasMatch(String.fromCharCode(rune));
}

/// A command on a [WordBoard] (contract E4, section 7). Sealed:
/// the only commands are [PickToken] and [ReturnToken].
sealed class WordCommand {
  const WordCommand();
}

/// Moves [tokenIndex] from the pool to the end of the answer row.
final class PickToken extends WordCommand {
  const PickToken(this.tokenIndex);
  final int tokenIndex;
}

/// Moves [tokenIndex] from the answer row back to the pool.
final class ReturnToken extends WordCommand {
  const ReturnToken(this.tokenIndex);
  final int tokenIndex;
}

/// The immutable state of one word puzzle in progress (contract E4,
/// section 7): the initial shuffled [order] plus the tokens the
/// player has moved into the [answer] row, in tap order. Commands
/// return a NEW board; a board never changes after construction.
final class WordBoard {
  WordBoard._(List<int> order, List<int> answer)
    : _order = List<int>.unmodifiable(order),
      _answer = List<int>.unmodifiable(answer);

  final List<int> _order;
  final List<int> _answer;

  /// A fresh board with the given initial (shuffled) [order].
  /// Throws [ArgumentError] unless [order] is a true permutation of
  /// `0..order.length - 1`; the empty list is rejected too.
  factory WordBoard.initial(List<int> order) {
    if (!_isPermutation(order)) {
      throw ArgumentError.value(
        order,
        'order',
        'must be a permutation of 0..${order.length - 1}',
      );
    }
    return WordBoard._(order, const []);
  }

  /// Rebuilds a board from [toMap] output. Throws [FormatException]
  /// on any malformed data: a missing key, a wrong type, a version
  /// other than 1, an order that is not a permutation, or an answer
  /// with duplicates or out-of-range indices.
  factory WordBoard.fromMap(Map<String, Object?> map) {
    final version = map['v'];
    final orderRaw = map['order'];
    final answerRaw = map['answer'];
    if (version != 1 || orderRaw is! List || answerRaw is! List) {
      throw const FormatException('malformed WordBoard map');
    }
    final order = <int>[];
    for (final element in orderRaw) {
      if (element is! int) {
        throw const FormatException('order must contain only ints');
      }
      order.add(element);
    }
    if (!_isPermutation(order)) {
      throw const FormatException('order is not a permutation');
    }
    final answer = <int>[];
    final seen = <int>{};
    for (final element in answerRaw) {
      if (element is! int ||
          element < 0 ||
          element >= order.length ||
          !seen.add(element)) {
        throw const FormatException('malformed answer in WordBoard map');
      }
      answer.add(element);
    }
    return WordBoard._(order, answer);
  }

  static bool _isPermutation(List<int> values) {
    if (values.isEmpty) return false;
    final seen = <int>{};
    for (final value in values) {
      if (value < 0 || value >= values.length || !seen.add(value)) {
        return false;
      }
    }
    return true;
  }

  /// The initial shuffled order. Unmodifiable.
  List<int> get order => _order;

  /// Tokens moved into the answer row, in tap order. Unmodifiable.
  List<int> get answer => _answer;

  /// Tokens still in the pool: [order] minus [answer], keeping the
  /// relative order of [order] — so a returned token reappears at
  /// exactly its old pool position.
  List<int> get pool => [
    for (final index in _order)
      if (!_answer.contains(index)) index,
  ];

  /// Whether every token has been moved into the answer row.
  bool get isFull => _answer.length == _order.length;

  /// Applies [command] and returns the resulting NEW board; this
  /// board is unchanged. Error split (contract E4, section 7,
  /// mirroring PlacePiece in E1/E3): an out-of-range token index
  /// throws [ArgumentError]; picking a token that already sits in
  /// the answer row, or returning one that does not, throws
  /// [StateError].
  WordBoard apply(WordCommand command) {
    return switch (command) {
      PickToken(:final tokenIndex) => _pick(tokenIndex),
      ReturnToken(:final tokenIndex) => _return(tokenIndex),
    };
  }

  WordBoard _pick(int tokenIndex) {
    _checkIndex(tokenIndex);
    if (_answer.contains(tokenIndex)) {
      throw StateError('token $tokenIndex is already in the answer row');
    }
    return WordBoard._(_order, [..._answer, tokenIndex]);
  }

  WordBoard _return(int tokenIndex) {
    _checkIndex(tokenIndex);
    if (!_answer.contains(tokenIndex)) {
      throw StateError('token $tokenIndex is not in the answer row');
    }
    return WordBoard._(_order, [
      for (final index in _answer)
        if (index != tokenIndex) index,
    ]);
  }

  void _checkIndex(int tokenIndex) {
    if (tokenIndex < 0 || tokenIndex >= _order.length) {
      throw ArgumentError.value(tokenIndex, 'tokenIndex', 'no such token');
    }
  }

  /// The saved form: exactly the keys `v`, `order`, `answer`. The
  /// permutation is stored, never a seed (same rule as E3 saves).
  Map<String, Object> toMap() => {
    'v': 1,
    'order': [..._order],
    'answer': [..._answer],
  };
}
