/// CompletionScreen — the end-of-puzzle screen (contract
/// S1-05 §4, decision SA-S5-3).
///
/// Shows the puzzle name, the measured time as
/// "Time: `m:ss`", and "Best: `m:ss`" when a best
/// time is known. "Play again" calls the shell-supplied
/// [onPlayAgain] (the shell pops this screen and pushes
/// a fresh play screen for the same asset); with no
/// callback it simply pops. "Back to themes" pops to
/// the first route. The whole scaffold carries the
/// Semantics label 'Completed'.
library;

import 'package:flutter/material.dart';

class CompletionScreen extends StatelessWidget {
  final String puzzleName;
  final Duration elapsed;
  final int? bestSeconds;

  /// Supplied by the app shell (SA-S5-3/SA-S5-5): pops
  /// this screen and pushes a new play screen for the
  /// same asset. Optional so the widget stands alone in
  /// tests; without it, Play again pops this screen.
  final VoidCallback? onPlayAgain;

  const CompletionScreen({
    super.key,
    required this.puzzleName,
    required this.elapsed,
    this.bestSeconds,
    this.onPlayAgain,
  });

  /// Formats a duration as `<m>:<ss>`: total minutes,
  /// then the remaining seconds zero-padded to two
  /// digits (125 seconds -> "2:05").
  static String formatClock(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds - minutes * 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final best = bestSeconds;
    return Semantics(
      container: true,
      label: 'Completed',
      child: Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The plain texts are excluded from semantics
              // (the theme card's SA-UI-7 pattern): otherwise
              // they merge into the 'Completed' container
              // label. The buttons keep their own nodes.
              ExcludeSemantics(
                child: Text(
                  puzzleName,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ExcludeSemantics(child: Text('Time: ${formatClock(elapsed)}')),
              if (best != null) ...[
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: Text('Best: ${formatClock(Duration(seconds: best))}'),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final callback = onPlayAgain;
                  if (callback != null) {
                    callback();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Play again'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Back to themes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
