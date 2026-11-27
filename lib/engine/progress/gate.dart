/// The 75% progression gate — contract E5
/// (harness/contracts/E5.md). Pure Dart, no imports: the engine
/// receives the already-aggregated counts and the threshold from
/// the caller and never reads config, files, or content data.
library;

/// Returns true when the player has solved strictly more than
/// [threshold] of the [totalOwned] puzzles they own.
///
/// Throws [ArgumentError] for invalid inputs (see
/// [requiredSolved]). Returns false when [totalOwned] == 0 (the
/// gate cannot open yet — a valid state, not an error).
bool isUnlocked(int solvedOwned, int totalOwned, double threshold) {
  _validateThreshold(threshold);
  if (totalOwned < 0) {
    throw ArgumentError.value(totalOwned, 'totalOwned', 'must be >= 0');
  }
  if (solvedOwned < 0) {
    throw ArgumentError.value(solvedOwned, 'solvedOwned', 'must be >= 0');
  }
  if (solvedOwned > totalOwned) {
    throw ArgumentError.value(
      solvedOwned,
      'solvedOwned',
      'must be <= totalOwned',
    );
  }
  if (totalOwned == 0) return false;
  return solvedOwned >= requiredSolved(totalOwned, threshold);
}

/// The minimum number of owned puzzles the player must solve to
/// unlock the next level.
///
/// Defined as floor(threshold × totalOwned) + 1 — the smallest
/// integer whose share of [totalOwned] is strictly greater than
/// [threshold]. Throws [ArgumentError] for invalid inputs.
/// Returns 1 when [totalOwned] == 0.
int requiredSolved(int totalOwned, double threshold) {
  _validateThreshold(threshold);
  if (totalOwned < 0) {
    throw ArgumentError.value(totalOwned, 'totalOwned', 'must be >= 0');
  }
  return (threshold * totalOwned).floor() + 1;
}

/// The threshold must lie in (0, 1] and be finite (contract E5,
/// decision 3). NaN fails both comparisons below, so it is
/// checked explicitly.
void _validateThreshold(double threshold) {
  if (threshold <= 0 ||
      threshold > 1 ||
      threshold.isNaN ||
      threshold.isInfinite) {
    throw ArgumentError.value(threshold, 'threshold', 'must be in (0, 1]');
  }
}
