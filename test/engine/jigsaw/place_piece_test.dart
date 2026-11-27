// Contract E3 tests — harness/contracts/E3.md (PlacePiece command).
// Written and hash-locked BEFORE the E3 engine code (stacked-PR
// process). The Generator must not edit, skip, or loosen these tests.
// Test names carry the gate ID (ENG-J-xx) followed by the Opus ID
// (E3-Pxx / E3-Cxx) — see the mapping table in E3.md section 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/engine/jigsaw/board.dart';
import 'package:game_puzzle/engine/jigsaw/commands.dart';

/// A 3x3 board completed by placing pieces directly (E1 API).
Board completedBoard() {
  final board = Board.square(3);
  for (var id = 0; id < board.totalPieces; id++) {
    board.place(id, board.homeOf(id));
  }
  return board;
}

void main() {
  group('PlacePiece E3', () {
    test('ENG-J-30 E3-P01 places a tray piece on an empty cell', () {
      final board = Board.square(3);
      final result = const PlacePiece(4, CellPos(1, 1)).apply(board);
      expect(result.outcome, PlaceOutcome.placed);
      expect(result.isCorrect, isTrue);
      expect(result.justCompleted, isFalse);
      expect(result.occupantId, isNull);
      expect(board.positionOf(4), const CellPos(1, 1));
      expect(board.placedCount, 1);
      // Placing on a wrong cell is still 'placed', just not correct.
      final wrong = const PlacePiece(0, CellPos(2, 2)).apply(board);
      expect(wrong.outcome, PlaceOutcome.placed);
      expect(wrong.isCorrect, isFalse);
      expect(board.positionOf(0), const CellPos(2, 2));
    });

    test('ENG-J-31 E3-P02 occupied cell is rejected and the board '
        'is unchanged', () {
      final board = Board.square(3);
      board.place(4, const CellPos(1, 1));
      final before = board.toMap();
      // Must return a result: a StateError escaping apply() fails here.
      final result = const PlacePiece(0, CellPos(1, 1)).apply(board);
      expect(result.outcome, PlaceOutcome.rejectedOccupied);
      expect(result.occupantId, 4);
      expect(result.justCompleted, isFalse);
      expect(board.toMap(), before);
      expect(board.isPlaced(0), isFalse);
    });

    test('ENG-J-32 E3-P03 placed piece moves to an empty cell', () {
      final board = Board.square(3);
      board.place(0, const CellPos(2, 2));
      final result = const PlacePiece(0, CellPos(0, 1)).apply(board);
      expect(result.outcome, PlaceOutcome.moved);
      expect(result.occupantId, isNull);
      expect(board.positionOf(0), const CellPos(0, 1));
      expect(board.pieceAt(const CellPos(2, 2)), isNull);
      expect(board.placedCount, 1);
    });

    test('ENG-J-33 E3-P04 rejected move leaves the piece where it was', () {
      final board = Board.square(3);
      board.place(0, const CellPos(2, 2));
      board.place(4, const CellPos(1, 1));
      final before = board.toMap();
      final result = const PlacePiece(0, CellPos(1, 1)).apply(board);
      expect(result.outcome, PlaceOutcome.rejectedOccupied);
      expect(result.occupantId, 4);
      // Not half-moved: the piece is still on its old cell.
      expect(board.positionOf(0), const CellPos(2, 2));
      expect(board.toMap(), before);
    });

    test('ENG-J-34 E3-P05 dropping on its own cell is a noop', () {
      final board = Board.square(3);
      board.place(4, const CellPos(1, 1));
      final before = board.toMap();
      final result = const PlacePiece(4, CellPos(1, 1)).apply(board);
      expect(result.outcome, PlaceOutcome.noop);
      expect(result.occupantId, isNull);
      expect(result.isCorrect, isTrue);
      expect(result.justCompleted, isFalse);
      expect(board.toMap(), before);
    });

    test('ENG-J-35 E3-P06 invalid piece id or cell throws ArgumentError', () {
      final board = Board.square(3);
      board.place(4, const CellPos(1, 1));
      final before = board.toMap();
      expect(
        () => const PlacePiece(-1, CellPos(0, 0)).apply(board),
        throwsArgumentError,
      );
      expect(
        () => const PlacePiece(9, CellPos(0, 0)).apply(board),
        throwsArgumentError,
      );
      expect(
        () => const PlacePiece(0, CellPos(-1, 0)).apply(board),
        throwsArgumentError,
      );
      expect(
        () => const PlacePiece(0, CellPos(0, 3)).apply(board),
        throwsArgumentError,
      );
      expect(board.toMap(), before);
    });

    test('ENG-J-36 E3-P07 drag and tap paths produce the same result', () {
      // Drag path: E2 snapTarget decides the cell, then the command.
      final dragBoard = Board.square(3);
      final snapped = dragBoard.snapTarget(1.5, 1.5, 0.2);
      expect(snapped, const CellPos(1, 1));
      final dragResult = PlacePiece(4, snapped!).apply(dragBoard);
      // Tap path: the command is built directly with the tapped cell.
      final tapBoard = Board.square(3);
      final tapResult = const PlacePiece(4, CellPos(1, 1)).apply(tapBoard);
      expect(dragResult, tapResult);
      expect(dragBoard.toMap(), tapBoard.toMap());
    });
  });

  group('PlacePiece completion E3', () {
    test('ENG-J-37 E3-C01 the last correct piece completes the board '
        'exactly once', () {
      final board = Board.square(3);
      for (var id = 0; id < 8; id++) {
        final early = PlacePiece(id, board.homeOf(id)).apply(board);
        expect(early.justCompleted, isFalse, reason: 'piece $id');
      }
      final last = PlacePiece(8, board.homeOf(8)).apply(board);
      expect(last.outcome, PlaceOutcome.placed);
      expect(last.justCompleted, isTrue);
      expect(board.isComplete, isTrue);
    });

    test('ENG-J-38 E3-C02 no completion event after the board is '
        'complete', () {
      final board = Board.square(3);
      PlaceResult? last;
      for (var id = 0; id < 9; id++) {
        last = PlacePiece(id, board.homeOf(id)).apply(board);
      }
      expect(last!.justCompleted, isTrue);
      final after = const PlacePiece(4, CellPos(1, 1)).apply(board);
      expect(after.outcome, PlaceOutcome.noop);
      expect(after.justCompleted, isFalse);
    });

    test('ENG-J-39 E3-C03 a move is completion-checked but cannot be '
        'the completing step', () {
      // Deviation documented in E3.md section 6: with one piece per
      // cell, a move can never be the step that completes the board
      // (the moved piece's wrong cell is another piece's home, so at
      // least two pieces are not home). This pins the closest
      // reachable boundary: 'moved' still gets justCompleted computed.
      final board = Board.square(2);
      board.place(0, const CellPos(0, 0));
      board.place(1, const CellPos(0, 1));
      board.place(3, const CellPos(1, 0)); // wrong: piece 2's home
      final moved = const PlacePiece(3, CellPos(1, 1)).apply(board);
      expect(moved.outcome, PlaceOutcome.moved);
      expect(moved.isCorrect, isTrue);
      expect(moved.justCompleted, isFalse); // piece 2 still in tray
      final last = const PlacePiece(2, CellPos(1, 0)).apply(board);
      expect(last.outcome, PlaceOutcome.placed);
      expect(last.justCompleted, isTrue);
      expect(board.isComplete, isTrue);
    });

    test('ENG-J-40 E3-C04 a board restored complete from a map fires '
        'no event', () {
      final restored = Board.fromMap(completedBoard().toMap());
      expect(restored.isComplete, isTrue);
      final first = const PlacePiece(4, CellPos(1, 1)).apply(restored);
      expect(first.outcome, PlaceOutcome.noop);
      expect(first.justCompleted, isFalse);
    });

    test('ENG-J-41 E3-C05 unplacing and replacing fires completion a '
        'second time', () {
      final board = Board.square(3);
      PlaceResult? last;
      for (var id = 0; id < 9; id++) {
        last = PlacePiece(id, board.homeOf(id)).apply(board);
      }
      expect(last!.justCompleted, isTrue);
      board.unplace(8);
      expect(board.isComplete, isFalse);
      final again = PlacePiece(8, board.homeOf(8)).apply(board);
      expect(again.justCompleted, isTrue);
      expect(board.isComplete, isTrue);
    });

    test('ENG-J-42 E3-C06 smallest board boundary completes', () {
      // Deviation documented in E3.md section 6: a 1x1 board cannot
      // exist (E1 pins gridSize >= 2), so this also pins that fact
      // and tests the smallest reachable boundary instead: a 2x2
      // board with exactly one piece left to place.
      expect(() => Board.square(1), throwsArgumentError);
      final board = Board.square(2);
      for (var id = 0; id < 3; id++) {
        final early = PlacePiece(id, board.homeOf(id)).apply(board);
        expect(early.justCompleted, isFalse, reason: 'piece $id');
      }
      final last = PlacePiece(3, board.homeOf(3)).apply(board);
      expect(last.justCompleted, isTrue);
      expect(board.isComplete, isTrue);
    });

    test('ENG-J-43 E3-C07 a full board with a wrong piece does not '
        'complete', () {
      final board = Board.square(2);
      const PlacePiece(0, CellPos(0, 0)).apply(board);
      const PlacePiece(1, CellPos(0, 1)).apply(board);
      const PlacePiece(2, CellPos(1, 1)).apply(board); // wrong cell
      final last = const PlacePiece(3, CellPos(1, 0)).apply(board);
      expect(last.outcome, PlaceOutcome.placed);
      expect(last.isCorrect, isFalse);
      expect(last.justCompleted, isFalse);
      expect(board.placedCount, 4);
      expect(board.isComplete, isFalse);
    });

    test('ENG-J-53 risk a rejection on a completed board does not '
        'fire completion', () {
      final board = completedBoard();
      final before = board.toMap();
      final result = const PlacePiece(0, CellPos(1, 1)).apply(board);
      expect(result.outcome, PlaceOutcome.rejectedOccupied);
      expect(result.occupantId, 4);
      expect(result.justCompleted, isFalse);
      expect(board.toMap(), before);
      expect(board.isComplete, isTrue);
    });
  });
}
