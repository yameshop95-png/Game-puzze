// Contract S1-06 text-scale tests —
// harness/contracts/S1-06.md §6/§9 (SA-S6-5).
// Written and hash-locked BEFORE any UI fix
// (stacked-PR process): an overflow these tests
// expose is a real UI bug, fixed minimally on the
// feat branch — the tests are never loosened.
//
// Every case pumps one screen on a 320x568 dp
// surface with TextScaler.linear(2.0) (the exact
// form MUSE_STEPS §S1-06 pins) and requires
// tester.takeException() to be null after settle:
// the §6 rule that layout overflow only shows when
// 200% text meets a narrow screen.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/features/completion/completion_screen.dart';
import 'package:game_puzzle/features/jigsaw_play/jigsaw_play_screen.dart';
import 'package:game_puzzle/features/theme_select/theme_progress.dart';
import 'package:game_puzzle/features/theme_select/theme_select_screen.dart';
import 'package:game_puzzle/services/asset_loader.dart';

/// Sets the 320x568 dp surface (contract §6).
void _useSmallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The app under the settled text scale: a
/// MediaQuery override directly under MaterialApp
/// replaces only the textScaler (size stays the
/// view's), so every screen below sees
/// TextScaler.linear(2.0).
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

class _FakeThemeProvider implements ThemeProgressProvider {
  @override
  Future<List<ThemeViewModel>> loadThemes() async => [
    for (final info in themeCatalog)
      ThemeViewModel(
        themeId: info.id,
        displayName: info.displayName,
        puzzleCount: 10,
        // Animals carries a solve so the "<n>
        // solved" line renders (the card's second
        // text line — its tightest fit), Landscapes
        // is locked so the badge renders.
        solvedCount: info.id == 'animals' ? 1 : 0,
        nextLevelLocked: info.id == 'landscapes',
      ),
  ];
}

const PuzzleAsset _asset = PuzzleAsset(
  id: 'animals_1_01',
  theme: 'animals',
  level: 1,
  title: 'Red Fox',
  textEn: 'A red fox sits in the grass.',
  playPath: 'packs/animals/1/animals_1_01/play.webp',
  thumbPath: 'packs/animals/1/animals_1_01/thumb.webp',
  creator: 'John James Audubon',
  institution: 'Smithsonian Institution',
);

/// A deterministic 3x3 image (nine coloured
/// cells), generated in memory exactly like the
/// WID-JP widget tests do: no PNG fixture lives in
/// the repo.
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

void main() {
  testWidgets(
    'WID-FS-01 theme select has no layout exception at 200% text on 320x568',
    (tester) async {
      _useSmallSurface(tester);
      await tester.pumpWidget(
        _scaledApp(
          ThemeSelectScreen(
            provider: _FakeThemeProvider(),
            onThemeSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ThemeSelectScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'WID-FS-02 jigsaw play has no layout exception at 200% text on 320x568',
    (tester) async {
      _useSmallSurface(tester);
      final image = await tester.runAsync(_testImage);
      await tester.pumpWidget(
        _scaledApp(
          JigsawPlayScreen(asset: _asset, image: image!, rng: Random(42)),
        ),
      );
      // Let the screen's own image stream resolve
      // from the cache (the WID-JP pattern).
      await tester.runAsync(() async {
        await precacheImage(
          image,
          tester.element(find.byType(JigsawPlayScreen)),
        );
      });
      await tester.pumpAndSettle();

      expect(find.byType(JigsawPlayScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'WID-FS-03 completion has no layout exception at 200% text on 320x568',
    (tester) async {
      _useSmallSurface(tester);
      await tester.pumpWidget(
        _scaledApp(
          const CompletionScreen(
            puzzleName: 'Weaning the Calves',
            elapsed: Duration(seconds: 65),
            bestSeconds: 95,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CompletionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
