/// ModeSelectScreen — the mode picker shown after a
/// theme tap (contract S2-01 §2, SA-WP-1).
///
/// Shows the asset's thumb + title, the grid-size
/// chip row (contract S2-03 §2, SA-J3-1: "3×3 /
/// 4×4 / 6×6" under a "Grid size" label, default
/// 3×3) and two large buttons, Jigsaw and Words.
/// The grid size applies to Jigsaw only — Words
/// ignores it. Words is disabled when the asset
/// has no word sentence
/// (`PuzzleAsset.textEnWord == null`, SA-WP-2): an
/// asset without an edited word sentence simply
/// does not offer word mode. The chosen size is
/// NOT persisted (SA-J3-3): this screen always
/// opens at 3×3. Navigation itself lives in the
/// app shell — this screen only reports the
/// choice through its callbacks.
library;

import 'package:flutter/material.dart';

import '../../services/asset_loader.dart';

class ModeSelectScreen extends StatefulWidget {
  final PuzzleAsset asset;
  final ImageProvider image;
  final void Function(int gridSize) onJigsawSelected;
  final VoidCallback onWordsSelected;

  const ModeSelectScreen({
    super.key,
    required this.asset,
    required this.image,
    required this.onJigsawSelected,
    required this.onWordsSelected,
  });

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  /// The grid sizes the picker offers, in display
  /// order (the `gridSizes` of
  /// config/game_config.json, contract S2-03 §2).
  static const List<int> _gridSizes = [3, 4, 6];

  /// The selected grid size; always starts at the
  /// 3×3 default (SA-J3-1/J3-3).
  int _gridSize = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image(
                image: widget.image,
                height: 160,
                fit: BoxFit.contain,
                // A missing thumb must never break the
                // picker: render an empty box instead of
                // surfacing the load error.
                errorBuilder: (_, _, _) => const SizedBox(height: 160),
              ),
              const SizedBox(height: 16),
              Text(
                widget.asset.title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Grid size',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // A Wrap, not a Row (contract S2-03 §2):
              // the chips sit on one row when there is
              // room and wrap instead of overflowing
              // at 200% text on a narrow screen.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final size in _gridSizes)
                    ChoiceChip(
                      label: Text('$size×$size'),
                      selected: _gridSize == size,
                      onSelected: (_) => setState(() => _gridSize = size),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => widget.onJigsawSelected(_gridSize),
                child: const Text('Jigsaw'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: widget.asset.textEnWord == null
                    ? null
                    : widget.onWordsSelected,
                child: const Text('Words'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
