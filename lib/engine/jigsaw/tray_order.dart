/// TrayOrder — the fixed display order of the piece tray, contract
/// E3 (harness/contracts/E3.md, decision 3; contract E1 decision 7).
/// Pure Dart: no Flutter imports, no dart:io, no clock. Randomness
/// only enters through the caller-supplied rng in [TrayOrder.shuffled].
library;

import 'dart:math';

/// A fixed permutation of every piece id `0..pieceCount-1`,
/// independent of the Board: placing or unplacing pieces never
/// changes it, so an unplaced piece returns to exactly its old tray
/// slot and a piece's Semantics number (`indexOf(id) + 1`, contract
/// E3 decision 3.4) never jumps when other pieces leave the tray.
class TrayOrder {
  TrayOrder._(List<int> order) : _order = List<int>.unmodifiable(order);

  /// A permutation shuffled with the caller-supplied [rng] (seeded
  /// by the caller). Throws [ArgumentError] if [pieceCount] < 1.
  factory TrayOrder.shuffled({required int pieceCount, required Random rng}) {
    if (pieceCount < 1) {
      throw ArgumentError.value(pieceCount, 'pieceCount', 'must be at least 1');
    }
    final order = List<int>.generate(pieceCount, (i) => i);
    order.shuffle(rng);
    return TrayOrder._(order);
  }

  /// Rebuilds a tray from a saved permutation (saves store the
  /// permutation itself, never a seed — contract E3 decision 3.2).
  /// Throws [ArgumentError] unless [order] is a true permutation of
  /// `0..order.length - 1`: empty, a duplicate id, a missing id, or
  /// an out-of-range id are all rejected.
  factory TrayOrder.fromList(List<int> order) {
    if (order.isEmpty) {
      throw ArgumentError.value(order, 'order', 'must not be empty');
    }
    final seen = <int>{};
    for (final id in order) {
      if (id < 0 || id >= order.length || !seen.add(id)) {
        throw ArgumentError.value(
          order,
          'order',
          'must be a permutation of 0..${order.length - 1}',
        );
      }
    }
    return TrayOrder._(order);
  }

  final List<int> _order;

  /// The full permutation, in tray display order. Unmodifiable:
  /// mutating it throws [UnsupportedError].
  List<int> get order => _order;

  int get length => _order.length;

  /// The position of a piece in the full permutation, or -1 when the
  /// id is not in this tray. Never changes as pieces are placed.
  int indexOf(int pieceId) => _order.indexOf(pieceId);

  /// The ids that are not placed, in tray order. Filtering is the
  /// caller's job (usually with `Board.isPlaced`); the permutation
  /// itself is untouched.
  List<int> visible(bool Function(int pieceId) isPlaced) =>
      _order.where((id) => !isPlaced(id)).toList();

  /// A mutable copy of the full permutation (for saving). Mutating
  /// the copy does not affect this TrayOrder.
  List<int> toList() => List<int>.of(_order);
}
