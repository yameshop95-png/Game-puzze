/// The random puzzle picker — contract E6
/// (harness/contracts/E6.md). Pure Dart: the caller owns the
/// pool of owned puzzles, the recently-solved list, and the
/// seeded [Random]; this function keeps no state between calls.
library;

import 'dart:math' show Random;

/// Draws one puzzle id from [pool], excluding the puzzles the
/// player solved most recently.
///
/// [pool] holds owned puzzle ids (`<theme>_<level>_<nn>`) and
/// must not contain duplicates. [recentlySolved] lists solved
/// ids, most recent last. [k] is the no-repeat window (the game
/// value is 10, from config; the engine only receives it here).
///
/// The exclusion set is the `K_eff` nearest entries of
/// [recentlySolved] that belong to [pool], where
/// `K_eff = min(k, pool.length - 1)`. Entries outside [pool] are
/// ignored and do not consume window slots; duplicates count
/// once (exclusion is by set). The eligible list keeps pool
/// order and exactly one `rng.nextInt` is consumed per draw, so
/// a sequence of draws is deterministic for a given seed.
///
/// Returns `null` when [pool] is empty. Throws [ArgumentError]
/// when [k] is negative or [pool] contains duplicates — those
/// are programming errors and win over the empty-pool `null`.
/// Neither input list is mutated.
String? pick(
  List<String> pool,
  List<String> recentlySolved,
  int k,
  Random rng,
) {
  if (k < 0) {
    throw ArgumentError.value(k, 'k', 'must be >= 0');
  }
  final poolSet = <String>{};
  for (final id in pool) {
    if (!poolSet.add(id)) {
      throw ArgumentError.value(pool, 'pool', 'must not contain duplicates');
    }
  }
  if (pool.isEmpty) return null;

  final kEff = k < pool.length - 1 ? k : pool.length - 1;
  final excluded = <String>{};
  for (
    var i = recentlySolved.length - 1;
    i >= 0 && excluded.length < kEff;
    i--
  ) {
    final id = recentlySolved[i];
    if (poolSet.contains(id)) {
      excluded.add(id);
    }
  }
  final eligible = [
    for (final id in pool)
      if (!excluded.contains(id)) id,
  ];
  return eligible[rng.nextInt(eligible.length)];
}
