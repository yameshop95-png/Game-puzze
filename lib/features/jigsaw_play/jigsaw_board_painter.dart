import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/jigsaw/board.dart';
import '../../engine/jigsaw/tray_order.dart';

/// Paints the whole play area — board, tray, hint border
/// and the lifted piece — from ONE decoded [ui.Image]
/// (contract S1-04 §1/§2, MUSE_STEPS §6: never cut the
/// picture into per-piece images; each piece is a
/// `drawImageRect` from its home region of the source).
///
/// The painter is also the tests' window into the screen
/// (contract §11): pieces have no widgets of their own,
/// so widget/integration tests read [board], [trayOrder]
/// and [hintCell] through the painter attached to the
/// `jigsaw-board-painter` CustomPaint. S2-02 adds
/// [selectedPieceId] to that window (contract S2-02 §8):
/// the piece chosen by the tap-to-place path, read by
/// tests exactly like [hintCell].
///
/// Geometry (contract §8), in body-local coordinates
/// (the body starts right under the AppBar, so the
/// board's local top is the global boardTop of 56):
/// board square at (16, 0) with side `size.width - 32`;
/// tray strip at `boardSide + 8` with height 112; tray
/// slot `i` is the piece's index in the FULL [TrayOrder]
/// permutation (contract §8 clarification: slots are
/// stable, placed pieces leave gaps).
class JigsawBoardPainter extends CustomPainter {
  /// The decoded picture, or null while it is still
  /// loading (or failed to load): pieces then paint as
  /// flat colours so the board stays playable/testable.
  final ui.Image? image;

  final Board board;
  final TrayOrder trayOrder;

  /// The piece currently lifted by a drag, drawn at
  /// [dragCenter] instead of its board/tray position.
  final int? dragPieceId;

  /// Centre of the dragged piece, body-local.
  final Offset? dragCenter;

  /// The cell lit by Hint (contract §3), or null.
  final CellPos? hintCell;

  /// The piece selected by tap-to-place (contract
  /// S2-02, SA-J2-1/7), or null when nothing is
  /// selected. Drawn with a dark-blue 3px border —
  /// deliberately a different colour from the yellow
  /// Hint border so the two can show at once.
  final int? selectedPieceId;

  /// Horizontal scroll offset of the tray strip. The
  /// tray holds gridSize^2 slots of one cell each
  /// (contract §8), which is wider than the screen, so
  /// the strip scrolls (MUSE_STEPS §6): a slot's
  /// visible centre is its content centre minus this
  /// offset.
  final double trayScrollOffset;

  /// Bumped by the screen on every board mutation —
  /// [Board] is mutable, so identity alone cannot
  /// drive [shouldRepaint].
  final int boardVersion;

  const JigsawBoardPainter({
    required this.image,
    required this.board,
    required this.trayOrder,
    required this.dragPieceId,
    required this.dragCenter,
    required this.hintCell,
    required this.selectedPieceId,
    required this.trayScrollOffset,
    required this.boardVersion,
  });

  static const double boardLeft = 16;
  static const double trayGap = 8;
  static const double trayHeight = 112;

  @override
  void paint(Canvas canvas, Size size) {
    final gridSize = board.gridSize;
    final boardSide = size.width - 32;
    final cell = boardSide / gridSize;
    final trayTop = boardSide + trayGap;

    // Board bed + grid.
    final boardRect = Rect.fromLTWH(boardLeft, 0, boardSide, boardSide);
    canvas.drawRect(boardRect, Paint()..color = const Color(0xFFE0E0E0));
    final gridPaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = 1;
    for (var i = 0; i <= gridSize; i++) {
      canvas.drawLine(
        Offset(boardLeft + cell * i, 0),
        Offset(boardLeft + cell * i, boardSide),
        gridPaint,
      );
      canvas.drawLine(
        Offset(boardLeft, cell * i),
        Offset(boardLeft + boardSide, cell * i),
        gridPaint,
      );
    }

    // Tray bed.
    canvas.drawRect(
      Rect.fromLTWH(0, trayTop, size.width, trayHeight),
      Paint()..color = const Color(0xFFF5F5F5),
    );

    // Placed pieces at their cells (the dragged one is
    // drawn last, at the pointer).
    for (var id = 0; id < board.totalPieces; id++) {
      if (id == dragPieceId) continue;
      final pos = board.positionOf(id);
      if (pos != null) {
        _drawPiece(
          canvas,
          id,
          Rect.fromLTWH(boardLeft + cell * pos.col, cell * pos.row, cell, cell),
        );
      }
    }

    // Unplaced pieces at their stable tray slots,
    // shifted by the tray's scroll offset.
    for (var id = 0; id < board.totalPieces; id++) {
      if (id == dragPieceId || board.isPlaced(id)) continue;
      final slot = trayOrder.indexOf(id);
      final centre = Offset(
        boardLeft + cell * slot + cell / 2 - trayScrollOffset,
        trayTop + trayHeight / 2,
      );
      _drawPiece(
        canvas,
        id,
        Rect.fromCenter(center: centre, width: cell, height: cell),
      );
    }

    // Hint border over the lit home cell (contract §3).
    final hint = hintCell;
    if (hint != null) {
      canvas.drawRect(
        Rect.fromLTWH(boardLeft + cell * hint.col, cell * hint.row, cell, cell),
        Paint()
          ..color = const Color(0xFFFFD600)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Selection border over the tap-selected piece
    // (contract S2-02 §8, SA-J2-7): 3px dark blue,
    // wherever the piece currently sits — its board
    // cell or its tray slot (drawn at the visible,
    // scroll-shifted position like the piece itself).
    // The dragged piece is skipped: it is drawn at
    // the pointer below, and a real drag has already
    // cleared the selection in the screen's state.
    final selected = selectedPieceId;
    if (selected != null && selected != dragPieceId) {
      final pos = board.positionOf(selected);
      final Rect rect;
      if (pos != null) {
        rect = Rect.fromLTWH(
          boardLeft + cell * pos.col,
          cell * pos.row,
          cell,
          cell,
        );
      } else {
        final slot = trayOrder.indexOf(selected);
        final centre = Offset(
          boardLeft + cell * slot + cell / 2 - trayScrollOffset,
          trayTop + trayHeight / 2,
        );
        rect = Rect.fromCenter(center: centre, width: cell, height: cell);
      }
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF1565C0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // The lifted piece follows the pointer.
    final dragId = dragPieceId;
    final centre = dragCenter;
    if (dragId != null && centre != null) {
      _drawPiece(
        canvas,
        dragId,
        Rect.fromCenter(center: centre, width: cell, height: cell),
      );
    }
  }

  void _drawPiece(Canvas canvas, int pieceId, Rect dst) {
    final gridSize = board.gridSize;
    final home = board.homeOf(pieceId);
    final img = image;
    if (img != null) {
      final src = Rect.fromLTWH(
        home.col * img.width / gridSize,
        home.row * img.height / gridSize,
        img.width / gridSize,
        img.height / gridSize,
      );
      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      canvas.drawRect(
        dst,
        Paint()
          ..color = HSLColor.fromAHSL(
            1,
            (pieceId * 40) % 360,
            0.6,
            0.55,
          ).toColor(),
      );
    }
    canvas.drawRect(
      dst,
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(JigsawBoardPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.boardVersion != boardVersion ||
      oldDelegate.dragPieceId != dragPieceId ||
      oldDelegate.dragCenter != dragCenter ||
      oldDelegate.hintCell != hintCell ||
      oldDelegate.selectedPieceId != selectedPieceId ||
      oldDelegate.trayScrollOffset != trayScrollOffset;
}
