// Contract S1-05 widget tests — harness/contracts/S1-05.md §10.
// Written and hash-locked BEFORE the completion screen exists
// (stacked-PR process). The Generator must not edit, skip, or
// loosen these tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/features/completion/completion_screen.dart';

Future<void> _pumpScreen(
  WidgetTester tester, {
  String puzzleName = 'Weaning the Calves',
  Duration elapsed = const Duration(seconds: 65),
  int? bestSeconds,
  VoidCallback? onPlayAgain,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CompletionScreen(
        puzzleName: puzzleName,
        elapsed: elapsed,
        bestSeconds: bestSeconds,
        onPlayAgain: onPlayAgain,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('WID-CP-01 shows the puzzle name with Completed semantics', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Weaning the Calves'), findsOneWidget);
    expect(find.bySemanticsLabel('Completed'), findsOneWidget);
  });

  testWidgets('WID-CP-02 formats the elapsed time as m:ss', (tester) async {
    await _pumpScreen(tester, elapsed: const Duration(seconds: 125));

    expect(find.text('Time: 2:05'), findsOneWidget);
  });

  testWidgets('WID-CP-03 shows the best time when bestSeconds is given', (
    tester,
  ) async {
    await _pumpScreen(tester, bestSeconds: 95);

    expect(find.text('Best: 1:35'), findsOneWidget);
  });

  testWidgets('WID-CP-04 hides the best time when bestSeconds is null', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.textContaining('Best:'), findsNothing);
  });

  testWidgets('WID-CP-05 Play again calls the onPlayAgain callback once', (
    tester,
  ) async {
    var calls = 0;
    await _pumpScreen(tester, onPlayAgain: () => calls++);

    await tester.tap(find.text('Play again'));
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('WID-CP-06 Back to themes pops until the first route', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Theme root'))),
      ),
    );
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const CompletionScreen(
          puzzleName: 'Weaning the Calves',
          elapsed: Duration(seconds: 65),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CompletionScreen), findsOneWidget);

    await tester.tap(find.text('Back to themes'));
    await tester.pumpAndSettle();

    expect(find.byType(CompletionScreen), findsNothing);
    expect(find.text('Theme root'), findsOneWidget);
  });
}
