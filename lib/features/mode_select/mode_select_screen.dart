/// ModeSelectScreen — the mode picker shown after a
/// theme tap (contract S2-01 §2, SA-WP-1).
///
/// Shows the asset's thumb + title and two large
/// buttons, Jigsaw and Words. Words is disabled when
/// the asset has no word sentence
/// (`PuzzleAsset.textEnWord == null`, SA-WP-2): an
/// asset without an edited word sentence simply does
/// not offer word mode. Navigation itself lives in
/// the app shell — this screen only reports the
/// choice through its callbacks.
library;

import 'package:flutter/material.dart';

import '../../services/asset_loader.dart';

class ModeSelectScreen extends StatelessWidget {
  final PuzzleAsset asset;
  final ImageProvider image;
  final VoidCallback onJigsawSelected;
  final VoidCallback onWordsSelected;

  const ModeSelectScreen({
    super.key,
    required this.asset,
    required this.image,
    required this.onJigsawSelected,
    required this.onWordsSelected,
  });

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
                image: image,
                height: 160,
                fit: BoxFit.contain,
                // A missing thumb must never break the
                // picker: render an empty box instead of
                // surfacing the load error.
                errorBuilder: (_, _, _) => const SizedBox(height: 160),
              ),
              const SizedBox(height: 16),
              Text(
                asset.title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: onJigsawSelected,
                child: const Text('Jigsaw'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: asset.textEnWord == null ? null : onWordsSelected,
                child: const Text('Words'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
