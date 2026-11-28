import 'package:flutter/material.dart';

import 'theme_progress.dart';

/// The theme select screen (contract S1-03): five
/// theme cards from the fixed catalog, each card
/// showing a lock badge while the gate to that
/// theme's next level is closed (SA-UI-1).
///
/// The screen is standalone (SA-UI-4): it receives
/// its data source and its selection callback from
/// outside and never touches `main.dart` or the app
/// shell — wiring happens in S1-04. A theme itself
/// is never locked, so every card stays tappable;
/// the lock is only the next level's gate state.
class ThemeSelectScreen extends StatefulWidget {
  final ThemeProgressProvider provider;
  final void Function(String themeId) onThemeSelected;

  const ThemeSelectScreen({
    super.key,
    required this.provider,
    required this.onThemeSelected,
  });

  @override
  State<ThemeSelectScreen> createState() => _ThemeSelectScreenState();
}

class _ThemeSelectScreenState extends State<ThemeSelectScreen> {
  late Future<List<ThemeViewModel>> _themes;

  @override
  void initState() {
    super.initState();
    _themes = widget.provider.loadThemes();
  }

  void _retry() {
    setState(() {
      _themes = widget.provider.loadThemes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<ThemeViewModel>>(
          future: _themes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: Semantics(
                  container: true,
                  label: 'Loading',
                  child: ExcludeSemantics(child: CircularProgressIndicator()),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Failed to load themes.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final themes = snapshot.data ?? const <ThemeViewModel>[];
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: themes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final theme = themes[index];
                return _ThemeCard(
                  theme: theme,
                  onTap: () => widget.onThemeSelected(theme.themeId),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// One theme card. The semantics label lives on the
/// card's tap target (SA-UI-7): the plain theme name,
/// or the name plus ', locked' while the next
/// level's gate is closed. The lock badge is an overlay in the
/// top-right corner and never covers the name
/// (SA-UI-1).
class _ThemeCard extends StatelessWidget {
  final ThemeViewModel theme;
  final VoidCallback onTap;

  const _ThemeCard({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locked = theme.nextLevelLocked;
    // The Semantics widget is the card's only
    // semantics node (label + tap action together, so
    // the labeled-tap-target guideline sees one
    // tappable node with a label). The GestureDetector
    // handles pointer taps and is excluded from
    // semantics — an InkWell would create its own
    // unlabeled tap node next to this one.
    return Semantics(
      container: true,
      button: true,
      label: locked ? '${theme.displayName}, locked' : theme.displayName,
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onTap: onTap,
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 72,
            child: Stack(
              children: [
                Center(
                  child: ExcludeSemantics(
                    child: Text(
                      theme.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                if (locked)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: ExcludeSemantics(child: Icon(Icons.lock)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
