// Contract E1 tests — harness/contracts/E1.md.
// Written and hash-locked BEFORE any engine code (stacked-PR process,
// E1.md section 4 item 5). The Generator must not edit, skip, or loosen
// these tests.
import 'dart:math';

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

    test(
      'ENG-J-15 pieceAt reports the occupant; own-cell place is a no-op',
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
      },
    );

    test('ENG-J-16 invariants hold under a seeded operation sequence', () {
      final board = Board.square(4);
      final rng = Random(42);
      void checkInvariants() {
        var occupied = 0;
        var homeCount = 0;
        final seen = <int>{};
        for (var r = 0; r < 4; r++) {
          for (var c = 0; c < 4; c++) {
            final occupant = board.pieceAt(CellPos(r, c));
            if (occupant != null) {
              occupied++;
              expect(
                seen.add(occupant),
                isTrue,
                reason: 'piece $occupant occupies two cells',
              );
              expect(board.positionOf(occupant), CellPos(r, c));
              if (board.homeOf(occupant) == CellPos(r, c)) homeCount++;
            }
          }
        }
        expect(board.placedCount, occupied);
        expect(board.correctlyPlacedCount, homeCount);
        expect(
          board.correctlyPlacedCount,
          lessThanOrEqualTo(board.placedCount),
        );
        for (var id = 0; id < 16; id++) {
          expect(board.isPlaced(id), seen.contains(id));
        }
      }

      checkInvariants();
      for (var step = 0; step < 300; step++) {
        final piece = rng.nextInt(16);
        if (rng.nextBool()) {
          try {
            board.place(piece, CellPos(rng.nextInt(4), rng.nextInt(4)));
          } on StateError {
            // Occupied target cell: a legal outcome, state must be intact.
          }
        } else {
          board.unplace(piece);
        }
        checkInvariants();
      }
    });

    test('ENG-J-17 toMap and fromMap round-trip the board state', () {
      final board = Board.square(3);
      board.place(0, const CellPos(0, 0)); // home
      board.place(4, const CellPos(0, 2)); // wrong cell
      board.place(8, const CellPos(2, 2)); // home
      final restored = Board.fromMap(board.toMap());
      expect(restored.gridSize, 3);
      expect(restored.placedCount, board.placedCount);
      expect(restored.correctlyPlacedCount, board.correctlyPlacedCount);
      expect(restored.isComplete, board.isComplete);
      for (var id = 0; id < 9; id++) {
        expect(restored.positionOf(id), board.positionOf(id));
      }
      // Empty and complete boards round-trip too.
      final empty = Board.fromMap(Board.square(4).toMap());
      expect(empty.gridSize, 4);
      expect(empty.placedCount, 0);
      final full = Board.square(3);
      for (var id = 0; id < 9; id++) {
        full.place(id, full.homeOf(id));
      }
      final fullRestored = Board.fromMap(full.toMap());
      expect(fullRestored.isComplete, isTrue);
      expect(fullRestored.placedCount, 9);
      // Invalid maps are rejected as input errors.
      expect(
        () => Board.fromMap(const {
          'gridSize': 3,
          'placed': {
            '0': [0, 0],
            '1': [0, 0],
          },
        }),
        throwsArgumentError,
      );
      expect(
        () => Board.fromMap(const {
          'gridSize': 3,
          'placed': {
            '9': [0, 0],
          },
        }),
        throwsArgumentError,
      );
      expect(
        () => Board.fromMap(const {
          'gridSize': 3,
          'placed': {
            '0': [3, 0],
          },
        }),
        throwsArgumentError,
      );
      expect(
        () => Board.fromMap(const {'gridSize': 1, 'placed': {}}),
        throwsArgumentError,
      );
    });

    // Contract S1-04 §10 (decision 9): the upper bound that
    // E1/E2 left open, settled at the S1-04 design gate.
    test('ENG-J-54 gridSize is capped at 64', () {
      final board = Board.square(64);
      expect(board.gridSize, 64);
      expect(board.totalPieces, 4096);
      expect(() => Board.square(65), throwsArgumentError);
    });
  });
}
