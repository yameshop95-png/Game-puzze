/// Board and piece model for the jigsaw engine — contract E1
/// (harness/contracts/E1.md). Pure Dart: no Flutter imports, no
/// dart:io, no clock, no unseeded randomness.
library;

import 'dart:math';

/// A cell on the grid. Immutable, compared by value.
class CellPos {
  final int row; // 0..N-1
  final int col; // 0..N-1
  const CellPos(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is CellPos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row, $col)';
}

/// An N×N jigsaw board. A piece's id is the index of its home cell,
/// `row * N + col` (0..N²-1): stable, deterministic, never random.
class Board {
  Board._(int gridSize)
    : _gridSize = gridSize,
      _cells = List<int?>.filled(gridSize * gridSize, null),
      _positions = List<CellPos?>.filled(gridSize * gridSize, null);

  /// Creates an N×N board with every piece in the tray.
  /// Throws [ArgumentError] if [gridSize] < 2.
  factory Board.square(int gridSize) {
    if (gridSize < 2) {
      throw ArgumentError.value(gridSize, 'gridSize', 'must be at least 2');
    }
    return Board._(gridSize);
  }

  /// Restores a board from a map produced by [toMap].
  /// Throws [ArgumentError] on any invalid data: a missing or
  /// non-integer gridSize, gridSize < 2, an unknown piece id, a cell
  /// outside the grid, two pieces in one cell, or a wrong value type.
  factory Board.fromMap(Map<String, Object?> map) {
    final gridSizeValue = map['gridSize'];
    if (gridSizeValue is! int) {
      throw ArgumentError.value(gridSizeValue, 'gridSize', 'must be an int');
    }
    final board = Board.square(gridSizeValue);
    final placedValue = map['placed'];
    if (placedValue == null) {
      return board;
    }
    if (placedValue is! Map) {
      throw ArgumentError.value(placedValue, 'placed', 'must be a map');
    }
    final seenCells = <CellPos>{};
    for (final entry in placedValue.entries) {
      final key = entry.key;
      final id = key is String ? int.tryParse(key) : null;
      // Only the canonical decimal form is accepted: "01", " 1" and
      // "+1" parse as 1 but are not keys toMap() would ever write, and
      // accepting them could silently move a piece.
      if (id == null || '$id' != key) {
        throw ArgumentError.value(
          key,
          'placed key',
          'must be a piece id in canonical form',
        );
      }
      final value = entry.value;
      if (value is! List ||
          value.length != 2 ||
          value[0] is! int ||
          value[1] is! int) {
        throw ArgumentError.value(
          value,
          'placed[$key]',
          'must be a [row, col] pair of ints',
        );
      }
      final pos = CellPos(value[0] as int, value[1] as int);
      if (!seenCells.add(pos)) {
        throw ArgumentError.value(
          pos,
          'placed[$key]',
          'two pieces in the same cell',
        );
      }
      // place() validates the id range and the cell bounds.
      board.place(id, pos);
    }
    return board;
  }

  final int _gridSize;

  /// Cell index -> occupying piece id, or null when the cell is empty.
  final List<int?> _cells;

  /// Piece id -> occupied cell, or null while the piece is in the tray.
  final List<CellPos?> _positions;

  int get gridSize => _gridSize;

  int get totalPieces => _gridSize * _gridSize;

  int _indexOf(CellPos pos) => pos.row * _gridSize + pos.col;

  void _checkPiece(int pieceId) {
    if (pieceId < 0 || pieceId >= totalPieces) {
      throw ArgumentError.value(pieceId, 'pieceId', 'no such piece');
    }
  }

  void _checkCell(CellPos pos) {
    if (pos.row < 0 ||
        pos.row >= _gridSize ||
        pos.col < 0 ||
        pos.col >= _gridSize) {
      throw ArgumentError.value(pos, 'pos', 'cell outside the grid');
    }
  }

  /// The home cell of a piece. Throws [ArgumentError] for unknown ids.
  CellPos homeOf(int pieceId) {
    _checkPiece(pieceId);
    return CellPos(pieceId ~/ _gridSize, pieceId % _gridSize);
  }

  /// Places a piece on a cell, moving it if it was placed elsewhere.
  /// Placing a piece onto the cell it already occupies is a no-op.
  /// Throws [ArgumentError] for an unknown id or an out-of-grid cell,
  /// and [StateError] if another piece occupies the target cell.
  void place(int pieceId, CellPos pos) {
    _checkPiece(pieceId);
    _checkCell(pos);
    final current = _positions[pieceId];
    if (current == pos) {
      return;
    }
    final occupant = _cells[_indexOf(pos)];
    if (occupant != null) {
      throw StateError('cell $pos is already occupied by piece $occupant');
    }
    if (current != null) {
      _cells[_indexOf(current)] = null;
    }
    _cells[_indexOf(pos)] = pieceId;
    _positions[pieceId] = pos;
  }

  /// Returns a piece to the tray. Unplacing a tray piece is a no-op.
  /// Throws [ArgumentError] for unknown ids.
  void unplace(int pieceId) {
    _checkPiece(pieceId);
    final current = _positions[pieceId];
    if (current != null) {
      _cells[_indexOf(current)] = null;
      _positions[pieceId] = null;
    }
  }

  /// The cell a piece occupies; null while it is in the tray.
  /// Throws [ArgumentError] for unknown ids.
  CellPos? positionOf(int pieceId) {
    _checkPiece(pieceId);
    return _positions[pieceId];
  }

  /// Whether the piece is placed on any cell.
  bool isPlaced(int pieceId) => positionOf(pieceId) != null;

  /// Whether the piece is placed on its home cell.
  bool isHome(int pieceId) => positionOf(pieceId) == homeOf(pieceId);

  /// The piece occupying a cell; null when the cell is empty.
  /// Throws [ArgumentError] for out-of-grid cells.
  int? pieceAt(CellPos pos) {
    _checkCell(pos);
    return _cells[_indexOf(pos)];
  }

  /// How many pieces are placed, on right or wrong cells alike.
  int get placedCount => _positions.where((pos) => pos != null).length;

  /// How many pieces are placed on their home cell.
  int get correctlyPlacedCount {
    var count = 0;
    for (var id = 0; id < totalPieces; id++) {
      if (_positions[id] != null && _positions[id] == homeOf(id)) {
        count++;
      }
    }
    return count;
  }

  /// Whether every piece is home.
  bool get isComplete => correctlyPlacedCount == totalPieces;

  /// The cell a drop point snaps to, or null when no cell centre is
  /// close enough (contract E2). [x] and [y] are the centre of the
  /// dragged piece in cell units (x along columns, y along rows); the
  /// centre of cell (row, col) is (col + 0.5, row + 0.5).
  /// [toleranceRatio] is the snap distance as a ratio of the cell
  /// side: the drop snaps to the nearest centre when the Euclidean
  /// distance to it is <= [toleranceRatio] (boundary included). Ties
  /// go to the smaller row, then the smaller col. An occupied cell is
  /// returned like any other; the caller decides what to do. This is
  /// a pure query: it never changes the board. Throws [ArgumentError]
  /// for a non-finite drop point or a tolerance outside (0, 1].
  CellPos? snapTarget(double x, double y, double toleranceRatio) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('drop point must be finite, got ($x, $y)');
    }
    if (!toleranceRatio.isFinite || toleranceRatio <= 0 || toleranceRatio > 1) {
      throw ArgumentError.value(
        toleranceRatio,
        'toleranceRatio',
        'must be finite and in (0, 1]',
      );
    }
    CellPos? best;
    var bestDistance = double.infinity;
    for (var row = 0; row < _gridSize; row++) {
      for (var col = 0; col < _gridSize; col++) {
        final dx = x - (col + 0.5);
        final dy = y - (row + 0.5);
        final distance = sqrt(dx * dx + dy * dy);
        if (distance < bestDistance) {
          bestDistance = distance;
          best = CellPos(row, col);
        }
      }
    }
    return bestDistance <= toleranceRatio ? best : null;
  }

  /// Exports the board state using JSON-basic types only:
  /// `{'gridSize': N, 'placed': {'<pieceId>': [row, col], ...}}`.
  /// Only placed pieces appear in `placed`.
  Map<String, Object?> toMap() {
    final placed = <String, Object?>{};
    for (var id = 0; id < totalPieces; id++) {
      final pos = _positions[id];
      if (pos != null) {
        placed['$id'] = <int>[pos.row, pos.col];
      }
    }
    return <String, Object?>{'gridSize': _gridSize, 'placed': placed};
  }
}
