import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/features/theme_select/theme_progress.dart';
import 'package:game_puzzle/features/theme_select/theme_select_screen.dart';

/// Fake provider for widget tests (contract S1-03,
/// SA-UI-3): the handler decides what each call does,
/// so a test can model success, a pending load, or a
/// failure followed by a successful retry.
class FakeThemeProgressProvider implements ThemeProgressProvider {
  FakeThemeProgressProvider(this._handler);

  final Future<List<ThemeViewModel>> Function() _handler;

  int calls = 0;

  @override
  Future<List<ThemeViewModel>> loadThemes() {
    calls++;
    return _handler();
  }
}

ThemeViewModel vm(
  String id,
  String name, {
  bool locked = false,
  int solved = 0,
}) {
  return ThemeViewModel(
    themeId: id,
    displayName: name,
    puzzleCount: 10,
    solvedCount: solved,
    nextLevelLocked: locked,
  );
}

/// The catalog in SA-UI-2 order, Landscapes locked.
List<ThemeViewModel> catalogModels() => [
  vm('animals', 'Animals'),
  vm('landscapes', 'Landscapes', locked: true),
  vm('space', 'Space'),
  vm('maps', 'Maps'),
  vm('landmarks', 'Landmarks'),
];

Future<void> pumpScreen(
  WidgetTester tester,
  ThemeProgressProvider provider, {
  void Function(String themeId)? onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ThemeSelectScreen(
        provider: provider,
        onThemeSelected: onSelected ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets(
    'WID-TS-01 catalog shows all 5 themes in catalog order with SA-UI-2 names',
    (tester) async {
      await pumpScreen(
        tester,
        FakeThemeProgressProvider(() async => catalogModels()),
      );
      await tester.pumpAndSettle();

      const names = ['Animals', 'Landscapes', 'Space', 'Maps', 'Landmarks'];
      for (final name in names) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      final tops = [
        for (final name in names) tester.getTopLeft(find.text(name)).dy,
      ];
      for (var i = 1; i < tops.length; i++) {
        expect(
          tops[i],
          greaterThan(tops[i - 1]),
          reason: 'catalog order at index $i',
        );
      }
    },
  );

  testWidgets(
    'WID-TS-02 lock badge shows exactly on cards whose next level is locked',
    (tester) async {
      await pumpScreen(
        tester,
        FakeThemeProgressProvider(() async => catalogModels()),
      );
      await tester.pumpAndSettle();
      // catalogModels() has exactly one locked theme.
      expect(find.byIcon(Icons.lock), findsOneWidget);

      // Unmount first: the screen keeps its state (and
      // its first future) if the same widget type is
      // pumped again at the same position.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await pumpScreen(
        tester,
        FakeThemeProgressProvider(
          () async => [
            vm('animals', 'Animals'),
            vm('landscapes', 'Landscapes'),
            vm('space', 'Space'),
            vm('maps', 'Maps'),
            vm('landmarks', 'Landmarks'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock), findsNothing);
    },
  );

  testWidgets(
    'WID-TS-01b a theme with solves shows its solved count text and label',
    (tester) async {
      await pumpScreen(
        tester,
        FakeThemeProgressProvider(
          () async => [
            vm('animals', 'Animals', solved: 1),
            vm('landscapes', 'Landscapes'),
            vm('space', 'Space'),
            vm('maps', 'Maps'),
            vm('landmarks', 'Landmarks'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // SA-S5-6: the solved line appears only on the theme
      // that has solves, and the card label carries it.
      expect(find.text('1 solved'), findsOneWidget);
      expect(find.bySemanticsLabel('Animals theme, 1 solved'), findsOneWidget);
      expect(find.bySemanticsLabel('Space theme'), findsOneWidget);
    },
  );

  testWidgets(
    'WID-TS-03 card semantics labels are the theme name plus " theme", plus ", locked" when locked',
    (tester) async {
      await pumpScreen(
        tester,
        FakeThemeProgressProvider(() async => catalogModels()),
      );
      await tester.pumpAndSettle();

      // SA-S5-6 label format (S1-05): "<Name> theme", with
      // the SA-UI-7 ", locked" suffix kept after it.
      expect(find.bySemanticsLabel('Animals theme'), findsOneWidget);
      expect(find.bySemanticsLabel('Landscapes theme, locked'), findsOneWidget);
      expect(find.bySemanticsLabel('Landscapes'), findsNothing);
      expect(find.bySemanticsLabel('Space theme'), findsOneWidget);
      expect(find.bySemanticsLabel('Maps theme'), findsOneWidget);
      expect(find.bySemanticsLabel('Landmarks theme'), findsOneWidget);
    },
  );

  testWidgets('WID-TS-04 tapping an unlocked card reports its theme id once', (
    tester,
  ) async {
    final selected = <String>[];
    await pumpScreen(
      tester,
      FakeThemeProgressProvider(() async => catalogModels()),
      onSelected: selected.add,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Space'));
    await tester.pump();
    expect(selected, ['space']);
  });

  testWidgets(
    'WID-TS-05 tapping a card with a lock badge still selects the theme',
    (tester) async {
      final selected = <String>[];
      await pumpScreen(
        tester,
        FakeThemeProgressProvider(() async => catalogModels()),
        onSelected: selected.add,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Landscapes'));
      await tester.pump();
      expect(selected, ['landscapes']);
    },
  );

  testWidgets('WID-TS-06 meets labeledTapTargetGuideline', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(
      tester,
      FakeThemeProgressProvider(() async => catalogModels()),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('WID-TS-07 meets androidTapTargetGuideline', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(
      tester,
      FakeThemeProgressProvider(() async => catalogModels()),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets(
    'WID-TS-08 loading state shows a progress indicator with Loading semantics',
    (tester) async {
      final completer = Completer<List<ThemeViewModel>>();
      await pumpScreen(
        tester,
        FakeThemeProgressProvider(() => completer.future),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(find.text('Animals'), findsNothing);

      completer.complete(catalogModels());
      await tester.pumpAndSettle();
      expect(find.text('Animals'), findsOneWidget);
    },
  );

  testWidgets(
    'WID-TS-09 error state shows a Retry button and retry reloads the catalog',
    (tester) async {
      var attempt = 0;
      final provider = FakeThemeProgressProvider(() async {
        attempt++;
        if (attempt == 1) {
          throw Exception('manifest unavailable');
        }
        return catalogModels();
      });
      await pumpScreen(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load themes.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
      expect(find.bySemanticsLabel('Retry'), findsOneWidget);
      expect(provider.calls, 1);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(provider.calls, 2);
      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('Landmarks'), findsOneWidget);
    },
  );

  testWidgets('WID-TS-10 golden of the theme select screen', (tester) async {
    await pumpScreen(
      tester,
      FakeThemeProgressProvider(
        () async => [
          vm('animals', 'Animals'),
          vm('landscapes', 'Landscapes', locked: true),
          vm('space', 'Space'),
          vm('maps', 'Maps', locked: true),
          vm('landmarks', 'Landmarks'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Animals'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNWidgets(2));
    // SA-UI-5: goldens are only compared on Linux.
    if (Platform.isLinux) {
      await expectLater(
        find.byType(ThemeSelectScreen),
        matchesGoldenFile('../../goldens/theme_select.png'),
      );
    }
  });
}
