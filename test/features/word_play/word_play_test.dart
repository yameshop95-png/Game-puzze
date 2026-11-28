// Contract S2-01 widget tests — harness/contracts/S2-01.md §12
// (SA-WP-1..SA-WP-9). Written and hash-locked BEFORE the screens
// exist (stacked-PR process). The Generator must not edit, skip,
// or loosen these tests.
//
// Chips are real buttons keyed by token index and zone
// (ValueKey('pool_<i>') / ValueKey('answer_<i>'), SA-WP-6), so
// tests drive the screen by key and never depend on the visual
// scramble order; Random(42) keeps every run deterministic.
// Widget tests use fake short-sentence assets (SA-WP-8); the
// real a1p1 record is exercised only by the INT-WP flow tests.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/features/jigsaw_play/jigsaw_play_screen.dart';
import 'package:game_puzzle/features/mode_select/mode_select_screen.dart';
import 'package:game_puzzle/features/word_play/word_play_screen.dart';
import 'package:game_puzzle/services/asset_loader.dart';

/// Six tokens: Every(0) calf(1) has(2) its(3) own(4) mood.(5).
const PuzzleAsset _asset = PuzzleAsset(
  id: 'w1',
  theme: 'animals',
  level: 1,
  title: 'Calf Study',
  textEn: 'A sample picture of calves.',
  textEnWord: 'Every calf has its own mood.',
  playPath: 'packs/animals/1/w1/play.webp',
  thumbPath: 'packs/animals/1/w1/thumb.webp',
  creator: 'Test Creator',
  institution: 'Test Museum',
);

/// Duplicate-token case (SA-WP-8): 'the' appears at index 0
/// and index 3 — the two chips share a text but not an index.
const PuzzleAsset _dupAsset = PuzzleAsset(
  id: 'w2',
  theme: 'animals',
  level: 1,
  title: 'Dog and Cat',
  textEn: 'A sample picture of pets.',
  textEnWord: 'the dog and the cat nap',
  playPath: 'packs/animals/1/w2/play.webp',
  thumbPath: 'packs/animals/1/w2/thumb.webp',
  creator: 'Test Creator',
  institution: 'Test Museum',
);

/// Alternate-answer case (SA-WP-3/SA-WP-8): the alternate is
/// the same key multiset in a different order.
const PuzzleAsset _altAsset = PuzzleAsset(
  id: 'w3',
  theme: 'animals',
  level: 1,
  title: 'Quick Fox',
  textEn: 'A sample picture of a fox.',
  textEnWord: 'the quick brown fox jumps',
  textEnAlt: ['the brown quick fox jumps'],
  playPath: 'packs/animals/1/w3/play.webp',
  thumbPath: 'packs/animals/1/w3/thumb.webp',
  creator: 'Test Creator',
  institution: 'Test Museum',
);

/// No word sentence: the Words button must be disabled
/// (SA-WP-1/SA-WP-2).
const PuzzleAsset _noWordAsset = PuzzleAsset(
  id: 'w4',
  theme: 'animals',
  level: 1,
  title: 'Silent Picture',
  textEn: 'A sample picture without words.',
  playPath: 'packs/animals/1/w4/play.webp',
  thumbPath: 'packs/animals/1/w4/thumb.webp',
  creator: 'Test Creator',
  institution: 'Test Museum',
);

const String _notice = 'Not quite — try rearranging';
const String _placeholder = 'Tap the words below to build your sentence';

/// A deterministic image generated in memory, exactly like
/// the WID-JP widget tests do: no PNG fixture lives in the
/// repo.
Future<MemoryImage> _testImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const colors = <Color>[
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.brown,
  ];
  for (var i = 0; i < 9; i++) {
    canvas.drawRect(
      Rect.fromLTWH((i % 3) * 100.0, (i ~/ 3) * 100.0, 100, 100),
      Paint()..color = colors[i],
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(300, 300);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return MemoryImage(data!.buffer.asUint8List());
}

Future<void> _pumpWord(
  WidgetTester tester, {
  PuzzleAsset asset = _asset,
  List<Duration>? completions,
}) async {
  final image = await tester.runAsync(_testImage);
  await tester.pumpWidget(
    MaterialApp(
      home: WordPlayScreen(
        asset: asset,
        image: image!,
        rng: Random(42),
        onCompleted: completions?.add,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapPool(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('pool_$index')));
  await tester.pump();
}

Future<void> _tapAnswer(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('answer_$index')));
  await tester.pump();
}

/// Picks every token in index order — the correct sentence.
Future<void> _solveInOrder(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await _tapPool(tester, i);
  }
}

/// The pool chips' visual (wrap) order: chip indices sorted
/// by row, then by column — the order WordBoard.pool must
/// preserve when a token is returned (engine E4).
List<int> _poolVisualOrder(WidgetTester tester, int count) {
  final entries = <(int, Offset)>[];
  for (var i = 0; i < count; i++) {
    final finder = find.byKey(ValueKey('pool_$i'));
    if (finder.evaluate().isNotEmpty) {
      entries.add((i, tester.getCenter(finder)));
    }
  }
  entries.sort((a, b) {
    final byRow = a.$2.dy.compareTo(b.$2.dy);
    return byRow != 0 ? byRow : a.$2.dx.compareTo(b.$2.dx);
  });
  return [for (final e in entries) e.$1];
}

void _useSmallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The 200% text-scale wrapper of the S1-06 WID-FS tests:
/// a MediaQuery override directly under MaterialApp
/// replaces only the textScaler.
Widget _scaledApp(Widget home) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2.0)),
        child: home,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'WID-WP-01 initial render shows the title, every pool chip, the empty answer placeholder and no notice',
    (tester) async {
      await _pumpWord(tester);

      expect(find.text('Calf Study'), findsOneWidget);
      expect(find.text('Your sentence'), findsOneWidget);
      expect(find.text('Word bank'), findsOneWidget);
      expect(find.text(_placeholder), findsOneWidget);
      expect(find.text(_notice), findsNothing);
      for (var i = 0; i < 6; i++) {
        expect(
          find.byKey(ValueKey('pool_$i')),
          findsOneWidget,
          reason: 'pool chip $i',
        );
        expect(find.byKey(ValueKey('answer_$i')), findsNothing);
      }
    },
  );

  testWidgets(
    'WID-WP-02 tapping a pool chip moves it to the answer row and tapping it there returns it to its pool position',
    (tester) async {
      await _pumpWord(tester);
      final initialOrder = _poolVisualOrder(tester, 6);
      expect(initialOrder, hasLength(6));

      await _tapPool(tester, 2);
      expect(find.byKey(const ValueKey('pool_2')), findsNothing);
      expect(find.byKey(const ValueKey('answer_2')), findsOneWidget);

      await _tapPool(tester, 0);
      await _tapAnswer(tester, 2);
      expect(find.byKey(const ValueKey('answer_2')), findsNothing);
      expect(find.byKey(const ValueKey('pool_2')), findsOneWidget);
      // The returned token reappears at its old pool position:
      // the visual order of the remaining pool chips is the
      // initial order with token 0 filtered out.
      expect(_poolVisualOrder(tester, 6), [
        for (final i in initialOrder)
          if (i != 0) i,
      ]);
    },
  );

  testWidgets(
    'WID-WP-03 a full but wrong row shows the notice, keeps the row and does not complete; rearranging then completes',
    (tester) async {
      final completions = <Duration>[];
      await _pumpWord(tester, completions: completions);

      // Swap the first two tokens: a full, incorrect row.
      for (final i in [1, 0, 2, 3, 4, 5]) {
        await _tapPool(tester, i);
      }
      expect(find.text(_notice), findsOneWidget);
      expect(completions, isEmpty);
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('answer_$i')), findsOneWidget);
      }

      // Returning one token clears the notice.
      await _tapAnswer(tester, 5);
      expect(find.text(_notice), findsNothing);
      for (final i in [4, 3, 2, 0, 1]) {
        await _tapAnswer(tester, i);
      }
      await _solveInOrder(tester, 6);
      expect(completions, hasLength(1));
    },
  );

  testWidgets(
    'WID-WP-04 the correct order fires onCompleted exactly once and locks the chips',
    (tester) async {
      final completions = <Duration>[];
      await _pumpWord(tester, completions: completions);

      await _solveInOrder(tester, 6);
      expect(completions, hasLength(1));

      // Locked: tapping a placed chip changes nothing.
      await _tapAnswer(tester, 0);
      expect(completions, hasLength(1));
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('answer_$i')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'WID-WP-05 duplicate tokens stay distinct by index and the sentence completes',
    (tester) async {
      final completions = <Duration>[];
      await _pumpWord(tester, asset: _dupAsset, completions: completions);

      expect(find.text('the'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('pool_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('pool_3')), findsOneWidget);

      await _solveInOrder(tester, 6);
      expect(completions, hasLength(1));
    },
  );

  testWidgets('WID-WP-06 an accepted alternate order completes the puzzle', (
    tester,
  ) async {
    final completions = <Duration>[];
    await _pumpWord(tester, asset: _altAsset, completions: completions);

    // 'the brown quick fox jumps' — the alternate of
    // 'the quick brown fox jumps' (token order 0,2,1,3,4).
    for (final i in [0, 2, 1, 3, 4]) {
      await _tapPool(tester, i);
    }
    expect(completions, hasLength(1));
  });

  testWidgets(
    'WID-WP-07 chips show the verbatim token text with case and attached punctuation',
    (tester) async {
      await _pumpWord(tester);

      expect(find.text('Every'), findsOneWidget);
      expect(find.text('mood.'), findsOneWidget);
      expect(find.text('mood'), findsNothing);
    },
  );

  testWidgets(
    'WID-WP-08 word play has no layout exception at 200% text on 320x568',
    (tester) async {
      _useSmallSurface(tester);
      final image = await tester.runAsync(_testImage);
      await tester.pumpWidget(
        _scaledApp(
          WordPlayScreen(asset: _asset, image: image!, rng: Random(42)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('WID-WP-09 golden of the word play screen', (tester) async {
    final image = await tester.runAsync(_testImage);
    await tester.pumpWidget(
      MaterialApp(
        home: WordPlayScreen(asset: _asset, image: image!, rng: Random(42)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calf Study'), findsOneWidget);
    // SA-WP-8: goldens are only compared on Linux.
    if (Platform.isLinux) {
      await expectLater(
        find.byType(WordPlayScreen),
        matchesGoldenFile('../../goldens/word_play.png'),
      );
    }
  }, tags: ['golden']);

  testWidgets(
    'WID-WP-10 mode select shows both modes, navigates to each play screen and disables Words without a word sentence',
    (tester) async {
      final image = (await tester.runAsync(_testImage))!;

      // Words path.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ModeSelectScreen(
              asset: _asset,
              image: image,
              // S2-03 mechanical update (contract
              // S2-03 §9): onJigsawSelected now carries
              // the grid size (SA-J3-1); this case
              // ignores it, assertions unchanged.
              onJigsawSelected: (gridSize) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => JigsawPlayScreen(asset: _asset, image: image),
                ),
              ),
              onWordsSelected: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WordPlayScreen(asset: _asset, image: image),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Calf Study'), findsOneWidget);
      expect(find.text('Jigsaw'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);

      await tester.tap(find.text('Words'));
      await tester.pumpAndSettle();
      expect(find.byType(WordPlayScreen), findsOneWidget);

      // Back to the mode select, then the Jigsaw path.
      // (Re-pumping a new MaterialApp would NOT reset the
      // navigator stack, so the routes are popped for real.)
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ModeSelectScreen), findsOneWidget);
      await tester.tap(find.text('Jigsaw'));
      await tester.pumpAndSettle();
      expect(find.byType(JigsawPlayScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // No word sentence: Words is disabled.
      await tester.pumpWidget(
        MaterialApp(
          home: ModeSelectScreen(
            asset: _noWordAsset,
            image: image,
            onJigsawSelected: (_) {},
            onWordsSelected: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final wordsButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Words'),
      );
      expect(wordsButton.onPressed, isNull);
      final jigsawButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Jigsaw'),
      );
      expect(jigsawButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'WID-WP-11 mode select has no layout exception at 200% text on 320x568',
    (tester) async {
      _useSmallSurface(tester);
      final image = await tester.runAsync(_testImage);
      await tester.pumpWidget(
        _scaledApp(
          ModeSelectScreen(
            asset: _asset,
            image: image!,
            onJigsawSelected: (_) {},
            onWordsSelected: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'WID-WP-12 mode select reports the chosen grid size, defaulting to 3',
    (tester) async {
      final image = (await tester.runAsync(_testImage))!;
      int? received;
      await tester.pumpWidget(
        MaterialApp(
          home: ModeSelectScreen(
            asset: _asset,
            image: image,
            onJigsawSelected: (gridSize) => received = gridSize,
            onWordsSelected: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grid size'), findsOneWidget);
      expect(find.text('3×3'), findsOneWidget);
      expect(find.text('4×4'), findsOneWidget);
      expect(find.text('6×6'), findsOneWidget);

      // SA-J3-1/J3-3: the screen always opens at
      // the 3x3 default — tapping Jigsaw without
      // touching the chips reports 3.
      await tester.tap(find.text('Jigsaw'));
      await tester.pumpAndSettle();
      expect(received, 3);

      await tester.tap(find.text('6×6'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jigsaw'));
      await tester.pumpAndSettle();
      expect(received, 6);

      await tester.tap(find.text('4×4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jigsaw'));
      await tester.pumpAndSettle();
      expect(received, 4);
    },
  );

  // ---- S2-04: Semantics + screen reader (SA-J4-4/6) ----

  testWidgets(
    'WID-WP-13 pool chips carry word-bank labels and both zones are labelled semantics containers',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpWord(tester);

      const tokens = ['Every', 'calf', 'has', 'its', 'own', 'mood.'];
      for (final token in tokens) {
        expect(
          find.bySemanticsLabel('$token, in word bank'),
          findsOneWidget,
          reason: token,
        );
      }
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.container &&
              w.properties.label == 'Your sentence',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.container &&
              w.properties.label == 'Word bank',
        ),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets(
    'WID-WP-14 answer chips are labelled with their position and returning one relabels the rest',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpWord(tester);

      await _tapPool(tester, 2); // has
      await _tapPool(tester, 0); // Every
      expect(
        find.bySemanticsLabel('has, in your sentence, position 1 of 2'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Every, in your sentence, position 2 of 2'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('has, in word bank'), findsNothing);

      await _tapAnswer(tester, 2);
      expect(find.bySemanticsLabel('has, in word bank'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Every, in your sentence, position 1 of 1'),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets('WID-WP-15 the wrong-row notice is a live region', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpWord(tester);

    for (final i in [1, 0, 2, 3, 4, 5]) {
      await _tapPool(tester, i);
    }
    expect(find.text(_notice), findsOneWidget);

    final node = tester.semantics.find(find.text(_notice));
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets(
    'WID-WP-16 a correct sentence announces Puzzle completed once; a wrong full row announces nothing',
    (tester) async {
      final handle = tester.ensureSemantics();
      final completions = <Duration>[];
      await _pumpWord(tester, completions: completions);

      List<String> drain() => [
        for (final a in tester.binding.takeAnnouncements()) a.message,
      ];
      drain();

      // Full but wrong: no announcement (the
      // notice is a live region instead, SA-J4-4).
      for (final i in [1, 0, 2, 3, 4, 5]) {
        await _tapPool(tester, i);
      }
      await tester.pump();
      expect(drain(), isEmpty);
      expect(completions, isEmpty);

      for (final i in [5, 4, 3, 2, 0, 1]) {
        await _tapAnswer(tester, i);
      }
      drain();
      await _solveInOrder(tester, 6);
      await tester.pump();
      expect(completions, hasLength(1));
      expect(drain().where((m) => m == 'Puzzle completed'), hasLength(1));
      handle.dispose();
    },
  );

  testWidgets('WID-WP-17 mode select meets the accessibility guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final image = (await tester.runAsync(_testImage))!;
    await tester.pumpWidget(
      MaterialApp(
        home: ModeSelectScreen(
          asset: _asset,
          image: image,
          onJigsawSelected: (_) {},
          onWordsSelected: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('WID-WP-18 word play meets the labeled tap target guideline', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpWord(tester);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
