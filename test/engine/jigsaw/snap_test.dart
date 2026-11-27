import 'package:flutter_test/flutter_test.dart';
import 'package:game_puzzle/engine/jigsaw/board.dart';

void main() {
  group('Snap E2', () {
    test('ENG-J-18 snap at the exact centre', () {
      final board = Board.square(3);
      expect(board.snapTarget(1.5, 1.5, 0.2), const CellPos(1, 1));
    });

    test('ENG-J-19 snap at the tolerance boundary', () {
      final board = Board.square(3);
      expect(board.snapTarget(1.7, 1.5, 0.2), const CellPos(1, 1));
      expect(board.snapTarget(1.3, 1.5, 0.2), const CellPos(1, 1));
      expect(board.snapTarget(1.5, 1.7, 0.2), const CellPos(1, 1));
      expect(board.snapTarget(1.5, 1.3, 0.2), const CellPos(1, 1));
    });

    test('ENG-J-20 no snap just outside tolerance', () {
      final board = Board.square(3);
      expect(board.snapTarget(1.71, 1.5, 0.2), isNull);
      expect(board.snapTarget(1.5, 1.71, 0.2), isNull);
    });

    test('ENG-J-21 snap distance is Euclidean', () {
      final board = Board.square(3);
      // Offset (0.14, 0.14): distance ~0.198 <= 0.2 snaps.
      expect(board.snapTarget(1.64, 1.64, 0.2), const CellPos(1, 1));
      // Offset (0.15, 0.15): distance ~0.212 > 0.2 does not snap,
      // although each axis alone is within 0.2 (Chebyshev would snap).
      expect(board.snapTarget(1.65, 1.65, 0.2), isNull);
    });

    test('ENG-J-22 snap near board corners', () {
      final board = Board.square(3);
      expect(board.snapTarget(0.3, 0.3, 0.3), const CellPos(0, 0));
      expect(board.snapTarget(2.7, 2.7, 0.3), const CellPos(2, 2));
      expect(board.snapTarget(0.3, 2.7, 0.3), const CellPos(2, 0));
    });

    test('ENG-J-23 snap from just outside the board edge', () {
      final board = Board.square(3);
      // Distance from (0.5, -0.05) to centre (0.5, 0.5) is 0.55.
      expect(board.snapTarget(0.5, -0.05, 0.6), const CellPos(0, 0));
      expect(board.snapTarget(0.5, -0.05, 0.2), isNull);
    });

    test('ENG-J-24 invalid tolerance is rejected', () {
      final board = Board.square(3);
      for (final t in <double>[
        0,
        -0.2,
        1.01,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => board.snapTarget(1.5, 1.5, t),
          throwsArgumentError,
          reason: 'tolerance $t must be rejected',
        );
      }
    });

    test('ENG-J-25 far away drop does not snap', () {
      final board = Board.square(3);
      expect(board.snapTarget(10, 10, 0.2), isNull);
      expect(board.snapTarget(-5, 1.5, 0.2), isNull);
    });

    test('ENG-J-26 nearest centre wins and ties are deterministic', () {
      final board = Board.square(3);
      expect(board.snapTarget(1.4, 1.5, 1.0), const CellPos(1, 1));
      // Exactly midway between centres (0.5, 1.5) and (1.5, 1.5):
      // same row, smaller col wins.
      expect(board.snapTarget(1.0, 1.5, 1.0), const CellPos(1, 0));
    });

    test('ENG-J-27 snap does not mutate the board', () {
      final board = Board.square(3);
      board.place(0, const CellPos(0, 0));
      board.place(4, const CellPos(1, 1));
      final before = board.toMap();
      // An occupied cell is still returned: snap does not avoid it.
      expect(board.snapTarget(0.5, 0.5, 0.2), const CellPos(0, 0));
      board.snapTarget(1.5, 1.5, 0.2);
      board.snapTarget(10, 10, 0.2);
      board.snapTarget(2.5, 0.5, 0.5);
      expect(board.toMap(), before);
      expect(board.placedCount, 2);
      expect(board.correctlyPlacedCount, 2);
    });

    test('ENG-J-28 snap on config grid sizes 4 and 6', () {
      expect(Board.square(4).snapTarget(3.5, 3.5, 0.2), const CellPos(3, 3));
      expect(Board.square(6).snapTarget(0.5, 5.5, 0.2), const CellPos(5, 0));
    });

    test('ENG-J-29 non-finite coordinates are rejected', () {
      final board = Board.square(3);
      expect(() => board.snapTarget(double.nan, 1.5, 0.2), throwsArgumentError);
      expect(() => board.snapTarget(1.5, double.nan, 0.2), throwsArgumentError);
      expect(
        () => board.snapTarget(double.infinity, 1.5, 0.2),
        throwsArgumentError,
      );
      expect(
        () => board.snapTarget(1.5, double.negativeInfinity, 0.2),
        throwsArgumentError,
      );
    });
  });
}
