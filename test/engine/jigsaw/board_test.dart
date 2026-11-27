// Contract E1 tests — harness/contracts/E1.md.
// Written and hash-locked BEFORE any engine code (stacked-PR process,
// E1.md section 4 item 5). The Generator must not edit, skip, or loosen
// these tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/engine/jigsaw/board.dart';

void main() {
  group('Board E1', () {
    test('ENG-J-01 board 3x3 has 9 unique pieces', () {
      final board = Board.square(3);
      expect(board.gridSize, 3);
      expect(board.totalPieces, 9);
      for (var id = 0; id < 9; id++) {
        expect(() => board.homeOf(id), returnsNormally);
      }
    });

    test('ENG-J-02 homes cover every cell exactly once', () {
      final board = Board.square(3);
      final homes = <CellPos>{};
      for (var id = 0; id < 9; id++) {
        final home = board.homeOf(id);
        expect(home, CellPos(id ~/ 3, id % 3));
        homes.add(home);
      }
      expect(homes.length, 9);
    });

    test('ENG-J-03 config grid sizes 4 and 6', () {
      expect(Board.square(4).totalPieces, 16);
      expect(Board.square(6).totalPieces, 36);
    });

    test('ENG-J-04 new board starts empty', () {
      final board = Board.square(3);
      expect(board.placedCount, 0);
      expect(board.correctlyPlacedCount, 0);
      expect(board.isComplete, isFalse);
      for (var id = 0; id < 9; id++) {
        expect(board.positionOf(id), isNull);
        expect(board.isPlaced(id), isFalse);
        expect(board.isHome(id), isFalse);
      }
      expect(board.pieceAt(const CellPos(0, 0)), isNull);
      expect(board.pieceAt(const CellPos(2, 2)), isNull);
    });

    test('ENG-J-05 placing a piece at home', () {
      final board = Board.square(3);
      board.place(4, const CellPos(1, 1));
      expect(board.isPlaced(4), isTrue);
      expect(board.isHome(4), isTrue);
      expect(board.placedCount, 1);
      expect(board.correctlyPlacedCount, 1);
      expect(board.positionOf(4), const CellPos(1, 1));
      expect(board.pieceAt(const CellPos(1, 1)), 4);
    });

    test('ENG-J-06 placing a piece on a wrong cell', () {
      final board = Board.square(3);
      board.place(0, const CellPos(2, 2));
      expect(board.isPlaced(0), isTrue);
      expect(board.isHome(0), isFalse);
      expect(board.placedCount, 1);
      expect(board.correctlyPlacedCount, 0);
      expect(board.isComplete, isFalse);
    });

    test('ENG-J-07 complete only when every piece is home', () {
      final board = Board.square(3);
      for (var id = 0; id < 7; id++) {
        board.place(id, board.homeOf(id));
      }
      // Last two pieces swapped onto each other's homes.
      board.place(7, const CellPos(2, 2));
      board.place(8, const CellPos(2, 1));
      expect(board.placedCount, 9);
      expect(board.correctlyPlacedCount, 7);
      expect(board.isComplete, isFalse);
      board.unplace(7);
      board.unplace(8);
      board.place(7, const CellPos(2, 1));
      board.place(8, const CellPos(2, 2));
      expect(board.correctlyPlacedCount, 9);
      expect(board.isComplete, isTrue);

      final other = Board.square(3);
      for (var id = 0; id < 8; id++) {
        other.place(id, other.homeOf(id));
      }
      expect(other.placedCount, 8);
      expect(other.isComplete, isFalse);
    });

    test('ENG-J-08 unplace returns the piece to the tray', () {
      final board = Board.square(3);
      board.place(4, const CellPos(1, 1));
      expect(board.placedCount, 1);
      expect(board.correctlyPlacedCount, 1);
      board.unplace(4);
      expect(board.positionOf(4), isNull);
      expect(board.pieceAt(const CellPos(1, 1)), isNull);
      expect(board.placedCount, 0);
      expect(board.correctlyPlacedCount, 0);
      expect(board.isComplete, isFalse);
      expect(() => board.unplace(4), returnsNormally);
    });

    test('ENG-J-09 placing the same piece twice moves it', () {
      final board = Board.square(3);
      board.place(0, const CellPos(2, 2));
      expect(board.placedCount, 1);
      board.place(0, const CellPos(0, 1));
      expect(board.placedCount, 1);
      expect(board.positionOf(0), const CellPos(0, 1));
      expect(board.pieceAt(const CellPos(2, 2)), isNull);
      expect(board.pieceAt(const CellPos(0, 1)), 0);
    });

    test('ENG-J-10 a cell holds at most one piece', () {
      final board = Board.square(3);
      board.place(0, const CellPos(0, 0));
      board.place(1, const CellPos(0, 1));
      expect(() => board.place(1, const CellPos(0, 0)), throwsStateError);
      expect(board.pieceAt(const CellPos(0, 0)), 0);
      expect(board.pieceAt(const CellPos(0, 1)), 1);
      expect(board.positionOf(1), const CellPos(0, 1));
      expect(board.placedCount, 2);
      expect(board.correctlyPlacedCount, 2);
      // Tray case: piece 1 back in the tray still cannot enter cell X.
      board.unplace(1);
      expect(() => board.place(1, const CellPos(0, 0)), throwsStateError);
      expect(board.positionOf(1), isNull);
      expect(board.placedCount, 1);
      expect(board.pieceAt(const CellPos(0, 0)), 0);
    });

    test('ENG-J-11 invalid grid sizes are rejected', () {
      expect(() => Board.square(0), throwsArgumentError);
      expect(() => Board.square(1), throwsArgumentError);
      expect(() => Board.square(-3), throwsArgumentError);
    });

    test('ENG-J-12 unknown piece ids are rejected', () {
      final board = Board.square(3);
      expect(() => board.homeOf(9), throwsArgumentError);
      expect(() => board.place(-1, const CellPos(0, 0)), throwsArgumentError);
      expect(() => board.unplace(99), throwsArgumentError);
      expect(() => board.positionOf(9), throwsArgumentError);
      expect(() => board.isPlaced(-1), throwsArgumentError);
      expect(() => board.isHome(42), throwsArgumentError);
    });

    test('ENG-J-13 board creation is deterministic', () {
      final a = Board.square(4);
      final b = Board.square(4);
      for (var id = 0; id < 16; id++) {
        expect(a.homeOf(id), b.homeOf(id));
        expect(a.homeOf(id), CellPos(id ~/ 4, id % 4));
      }
    });

    test('ENG-J-14 out-of-grid cells are rejected', () {
      final board = Board.square(3);
      board.place(0, const CellPos(0, 0));
      const badCells = [CellPos(-1, 0), CellPos(0, 3), CellPos(3, 0)];
      for (final cell in badCells) {
        expect(() => board.place(1, cell), throwsArgumentError);
        expect(() => board.pieceAt(cell), throwsArgumentError);
        expect(board.placedCount, 1);
        expect(board.positionOf(0), const CellPos(0, 0));
      }
      // Moving the already-placed piece 0 out of the grid also fails and
      // leaves it where it was.
      expect(() => board.place(0, const CellPos(3, 0)), throwsArgumentError);
      expect(board.positionOf(0), const CellPos(0, 0));
      expect(board.pieceAt(const CellPos(0, 0)), 0);
      expect(board.placedCount, 1);
    });

    test('ENG-J-15 pieceAt reports the occupant; own-cell place is a no-op',
        () {
      final board = Board.square(3);
      expect(board.pieceAt(const CellPos(1, 1)), isNull);
      board.place(4, const CellPos(1, 1));
      expect(board.pieceAt(const CellPos(1, 1)), 4);
      expect(() => board.place(4, const CellPos(1, 1)), returnsNormally);
      expect(board.placedCount, 1);
      expect(board.correctlyPlacedCount, 1);
      expect(board.positionOf(4), const CellPos(1, 1));
      expect(board.pieceAt(const CellPos(1, 1)), 4);
    });
  });
}
