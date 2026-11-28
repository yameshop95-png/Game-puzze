/// The word play screen (contract S2-01, SA-WP-1..9).
///
/// One scrolling column: a compact thumb header, the
/// "Your sentence" zone, a status line, and the "Word
/// bank" zone (SA-WP-6). Chips are real buttons keyed
/// by token index and zone; tapping a pool chip picks
/// the token, tapping an answer chip returns it — the
/// engine's [WordBoard] keeps the pool order, so a
/// returned token reappears at its old position.
///
/// The sentence, validator and first board are built
/// once in [initState]: the pool order is
/// `AnswerValidator.scramble(rng ?? Random())`, called
/// exactly once (contract §11). The stopwatch starts
/// in [initState] too (SA-WP-7): the sentence data is
/// synchronous, there is no image decode to wait for.
/// When the answer row is full it is checked at once
/// (SA-WP-4): correct locks the screen and fires
/// [onCompleted] exactly once; incorrect shows an
/// inline notice and keeps the row.
///
/// S2-04 completes the deferred SA-WP-9 semantics
/// (contract S2-04 §6, SA-J4-4): chips are labelled
/// by zone and position, the two zones are labelled
/// semantics containers, the wrong-row notice is a
/// live region, and completing the sentence sends
/// the same `Puzzle completed` announcement as the
/// jigsaw screen.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../engine/word/sentence.dart';
import '../../engine/word/validator.dart';
import '../../services/asset_loader.dart';

class WordPlayScreen extends StatefulWidget {
  final PuzzleAsset asset;
  final ImageProvider image;
  final Random? rng;

  /// Fired exactly once when the arranged sentence is
  /// accepted, carrying the measured solve time
  /// (SA-WP-4/SA-WP-7).
  final void Function(Duration elapsed)? onCompleted;

  const WordPlayScreen({
    super.key,
    required this.asset,
    required this.image,
    this.rng,
    this.onCompleted,
  });

  @override
  State<WordPlayScreen> createState() => _WordPlayScreenState();
}

class _WordPlayScreenState extends State<WordPlayScreen> {
  late final Sentence _sentence;
  late final AnswerValidator _validator;
  late final Stopwatch _stopwatch;
  late WordBoard _board;
  String? _notice;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final wordText = widget.asset.textEnWord;
    if (wordText == null) {
      // The shell only enables Words when a word
      // sentence exists (SA-WP-1); being built without
      // one is a wiring bug, never a player state.
      throw StateError(
        'WordPlayScreen requires asset.textEnWord (contract S2-01 §2)',
      );
    }
    _sentence = Sentence.parse(wordText);
    _validator = AnswerValidator(_sentence, alternates: widget.asset.textEnAlt);
    _board = WordBoard.initial(_validator.scramble(widget.rng ?? Random()));
    _stopwatch = Stopwatch()..start();
  }

  void _pick(int index) {
    if (_completed) return;
    final next = _board.apply(PickToken(index));
    String? notice;
    var justCompleted = false;
    if (next.isFull) {
      if (_validator.check(next.answer).isCorrect) {
        justCompleted = true;
      } else {
        notice = 'Not quite — try rearranging';
      }
    }
    setState(() {
      _board = next;
      _notice = notice;
      if (justCompleted) _completed = true;
    });
    if (justCompleted) {
      _stopwatch.stop();
      // SA-J4-4: completing the sentence is
      // announced (the wrong-row case is not — its
      // notice is a live region instead).
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Puzzle completed',
        TextDirection.ltr,
      );
      widget.onCompleted?.call(_stopwatch.elapsed);
    }
  }

  void _return(int index) {
    if (_completed) return;
    setState(() {
      _board = _board.apply(ReturnToken(index));
      // The row is no longer full, so the last check
      // no longer stands (SA-WP-4).
      _notice = null;
    });
  }

  Widget _chip(int index, {required bool inAnswer}) {
    final token = _sentence.tokens[index];
    // SA-J4-4 label: the verbatim token text plus
    // its zone — and, in the answer row, its
    // 1-based position within the row.
    final label = inAnswer
        ? '${token.text}, in your sentence, position '
              '${_board.answer.indexOf(index) + 1} of ${_board.answer.length}'
        : '${token.text}, in word bank';
    return Semantics(
      container: true,
      label: label,
      button: true,
      child: ElevatedButton(
        key: ValueKey('${inAnswer ? 'answer' : 'pool'}_$index'),
        onPressed: _completed
            ? null
            : () => inAnswer ? _return(index) : _pick(index),
        style: ElevatedButton.styleFrom(minimumSize: const Size(48, 48)),
        child: Text(token.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answer = _board.answer;
    final pool = _board.pool;
    final notice = _notice;
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image(
                    image: widget.image,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    // Same rule as the mode select header:
                    // a missing thumb renders an empty
                    // box, never an error.
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 64, height: 64),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.asset.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // SA-J4-4: each zone is a labelled
              // semantics container. The wrapper adds
              // no pixels — same children, same gaps —
              // so the layout and the golden are
              // unchanged.
              Semantics(
                container: true,
                label: 'Your sentence',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Excluded from semantics (the
                    // CompletionScreen pattern of
                    // SA-S5-3): the container already
                    // carries this label, otherwise the
                    // heading merges into it twice.
                    ExcludeSemantics(
                      child: Text(
                        'Your sentence',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: answer.isEmpty
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Tap the words below to build your sentence',
                                // grey.shade700, not Colors.grey:
                                // the placeholder must meet the
                                // text contrast guideline
                                // (contract S2-04a).
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final index in answer)
                                  _chip(index, inAnswer: true),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 20,
                child: notice == null
                    ? null
                    : Semantics(
                        // SA-J4-4: the notice reads
                        // itself out when it appears.
                        liveRegion: true,
                        child: Text(
                          notice,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Semantics(
                container: true,
                label: 'Word bank',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        'Word bank',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final index in pool) _chip(index, inAnswer: false),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
