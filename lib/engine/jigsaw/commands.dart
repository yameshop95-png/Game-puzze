/// PlacePiece command for the jigsaw engine — contract E3
/// (harness/contracts/E3.md). Pure Dart: no Flutter imports, no
/// dart:io, no clock, no randomness.
library;

import 'board.dart';

/// What a [PlacePiece] command did with the piece.
enum PlaceOutcome { placed, moved, noop, rejectedOccupied }

/// The result of applying a [PlacePiece] command. Compared by value
/// so the drag and tap entry paths can be checked for producing the
/// same result (contract E3, decision 2).
class PlaceResult {
  final PlaceOutcome outcome;

  /// Whether the piece is on its home cell after the command.
  final bool isCorrect;

  /// Whether this command just completed the board:
  /// `!before.isComplete && after.isComplete`, computed in apply.
  final bool justCompleted;

  /// The piece occupying the target cell; only non-null when
  /// [outcome] is [PlaceOutcome.rejectedOccupied].
  final int? occupantId;

  const PlaceResult({
    required this.outcome,
    required this.isCorrect,
    required this.justCompleted,
    this.occupantId,
  });

  @override
  bool operator ==(Object other) =>
      other is PlaceResult &&
      other.outcome == outcome &&
      other.isCorrect == isCorrect &&
      other.justCompleted == justCompleted &&
      other.occupantId == occupantId;

  @override
  int get hashCode =>
      Object.hash(outcome, isCorrect, justCompleted, occupantId);

  @override
  String toString() =>
      'PlaceResult($outcome, isCorrect: $isCorrect, '
      'justCompleted: $justCompleted, occupantId: $occupantId)';
}

/// The one command that places a piece, shared by drag-and-drop and
/// tap-to-place (MUSE_STEPS §E3). Immutable: the piece and the
/// target cell are fixed at construction.
class PlacePiece {
  final int pieceId;
  final CellPos slot;

  const PlacePiece(this.pieceId, this.slot);

  /// Applies the command to [board] and reports what happened.
  ///
  /// Everything is read and validated BEFORE any change (contract
  /// E1 decision 9, contract E3 decision 1): an unknown [pieceId] or
  /// an out-of-grid [slot] throws [ArgumentError] with the board
  /// untouched. An occupied target cell never throws: the command
  /// returns [PlaceOutcome.rejectedOccupied] with the board exactly
  /// as it was — the StateError guard inside Board.place is a safety
  /// net for programming errors, never control flow.
  PlaceResult apply(Board board) {
    final beforeComplete = board.isComplete;
    final occupant = board.pieceAt(slot);
    final current = board.positionOf(pieceId);
    if (current == slot) {
      return PlaceResult(
        outcome: PlaceOutcome.noop,
        isCorrect: board.isHome(pieceId),
        justCompleted: !beforeComplete && board.isComplete,
      );
    }
    if (occupant != null) {
      return PlaceResult(
        outcome: PlaceOutcome.rejectedOccupied,
        isCorrect: board.isHome(pieceId),
        justCompleted: !beforeComplete && board.isComplete,
        occupantId: occupant,
      );
    }
    final outcome = current == null ? PlaceOutcome.placed : PlaceOutcome.moved;
    if (current != null) {
      board.unplace(pieceId);
    }
    board.place(pieceId, slot);
    return PlaceResult(
      outcome: outcome,
      isCorrect: board.isHome(pieceId),
      justCompleted: !beforeComplete && board.isComplete,
    );
  }
}
