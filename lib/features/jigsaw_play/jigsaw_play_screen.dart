import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';

import '../../engine/jigsaw/board.dart';
import '../../engine/jigsaw/commands.dart';
import '../../engine/jigsaw/tray_order.dart';
import '../../services/asset_loader.dart';
import 'jigsaw_board_painter.dart';

/// The 3x3 jigsaw play screen (contract S1-04).
///
/// One [Listener] over the whole play area drives every
/// drag (MUSE_STEPS §6): pieces have no widgets of
/// their own, hit-testing is done against the engine,
/// and a second pointer is ignored while one is active.
/// Dragging out of the tray starts with a long-press;
/// a piece already on the board drags directly
/// (contract §9). The board itself only changes when a
/// drop resolves through [PlacePiece] (contract §7),
/// so a rejected or out-of-tolerance drop simply ends
/// the visual drag — the piece is back where it was.
class JigsawPlayScreen extends StatefulWidget {
  final PuzzleAsset asset;
  final ImageProvider image;
  final Random? rng;
  final double snapToleranceRatio;
  final int gridSize;
  final void Function()? onCompleted;

  const JigsawPlayScreen({
    super.key,
    required this.asset,
    required this.image,
    this.rng,
    this.snapToleranceRatio = 0.2,
    this.gridSize = 3,
    this.onCompleted,
  });

  @override
  State<JigsawPlayScreen> createState() => _JigsawPlayScreenState();
}

class _JigsawPlayScreenState extends State<JigsawPlayScreen> {
  late final Board _board;
  late final TrayOrder _trayOrder;
  int _boardVersion = 0;

  ui.Image? _uiImage;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  bool _showPreview = false;
  bool _completed = false;
  CellPos? _hintCell;
  Timer? _hintTimer;

  // Drag state machine (contract §8/§9). At most one
  // pointer is tracked; _dragPieceId is set once a drag
  // has actually begun (immediately for board pieces,
  // after the long-press for tray pieces).
  int? _activePointer;
  Offset _downPos = Offset.zero;
  Offset _lastPos = Offset.zero;
  int? _pendingTrayPiece;
  Timer? _longPressTimer;
  int? _dragPieceId;
  Offset? _dragCenter;
  Offset _grabOffset = Offset.zero;

  // Tray scrolling (contract §8 clarification): the
  // strip is wider than the screen, so a tray gesture
  // that moves before the long-press fires — or that
  // starts on empty tray bed — scrolls the strip
  // instead of picking a piece up (MUSE_STEPS §6).
  double _trayScroll = 0;
  bool _scrollingTray = false;
  double _downTrayScroll = 0;

  @override
  void initState() {
    super.initState();
    _board = Board.square(widget.gridSize);
    _trayOrder = TrayOrder.shuffled(
      pieceCount: _board.totalPieces,
      rng: widget.rng ?? Random(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _imageStream?.key) return;
    final oldListener = _imageListener;
    if (oldListener != null) _imageStream?.removeListener(oldListener);
    final listener = ImageStreamListener(
      (info, _) {
        if (mounted) setState(() => _uiImage = info.image);
      },
      // A missing play image (e.g. the shell wiring before
      // real content exists) must never crash the screen:
      // the painter falls back to flat colours.
      onError: (_, _) {},
    );
    stream.addListener(listener);
    _imageStream = stream;
    _imageListener = listener;
  }

  @override
  void dispose() {
    final listener = _imageListener;
    if (listener != null) _imageStream?.removeListener(listener);
    _hintTimer?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  double get _screenWidth => MediaQuery.sizeOf(context).width;
  double get _boardSide => _screenWidth - 32;
  double get _cell => _boardSide / widget.gridSize;

  /// Body-local centre of a board cell (the body's top is
  /// the board's top — contract §8).
  Offset _cellCentre(CellPos pos) =>
      Offset(16 + _cell * (pos.col + 0.5), _cell * (pos.row + 0.5));

  /// Body-local VISIBLE centre of a piece's stable
  /// tray slot: its content centre (contract §8)
  /// minus the strip's scroll offset.
  Offset _slotCentre(int pieceId) {
    final slot = _trayOrder.indexOf(pieceId);
    return Offset(
      16 + _cell * (slot + 0.5) - _trayScroll,
      _boardSide +
          JigsawBoardPainter.trayGap +
          JigsawBoardPainter.trayHeight / 2,
    );
  }

  double get _maxTrayScroll => _cell * _board.totalPieces - _boardSide;

  /// Hit-tests a body-local point: a placed piece on the
  /// board, or an unplaced piece in the tray. Returns the
  /// piece id and whether it sits in the tray.
  ({int pieceId, bool fromTray})? _hitTest(Offset pos) {
    final cell = _cell;
    if (pos.dx >= 16 &&
        pos.dx < 16 + _boardSide &&
        pos.dy >= 0 &&
        pos.dy < _boardSide) {
      final col = ((pos.dx - 16) / cell).floor();
      final row = (pos.dy / cell).floor();
      final piece = _board.pieceAt(CellPos(row, col));
      if (piece != null) return (pieceId: piece, fromTray: false);
      return null;
    }
    final trayTop = _boardSide + JigsawBoardPainter.trayGap;
    if (pos.dy >= trayTop && pos.dy < trayTop + JigsawBoardPainter.trayHeight) {
      final slot = ((pos.dx + _trayScroll - 16) / cell).floor();
      if (slot < 0 || slot >= _trayOrder.length) return null;
      final piece = _trayOrder.order[slot];
      if (!_board.isPlaced(piece)) return (pieceId: piece, fromTray: true);
    }
    return null;
  }

  bool _inTray(Offset pos) {
    final trayTop = _boardSide + JigsawBoardPainter.trayGap;
    return pos.dy >= trayTop &&
        pos.dy < trayTop + JigsawBoardPainter.trayHeight;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_completed || _activePointer != null) return;
    final hit = _hitTest(event.localPosition);
    if (hit == null) {
      // Empty tray bed: the gesture scrolls the strip.
      if (_inTray(event.localPosition)) {
        _activePointer = event.pointer;
        _downPos = event.localPosition;
        _lastPos = event.localPosition;
        _downTrayScroll = _trayScroll;
        _scrollingTray = true;
      }
      return;
    }
    _activePointer = event.pointer;
    _downPos = event.localPosition;
    _lastPos = event.localPosition;
    _downTrayScroll = _trayScroll;
    if (hit.fromTray) {
      _pendingTrayPiece = hit.pieceId;
      _longPressTimer = Timer(kLongPressTimeout, () {
        if (mounted && _pendingTrayPiece == hit.pieceId) {
          _pendingTrayPiece = null;
          _beginDrag(hit.pieceId, _lastPos);
        }
      });
    } else {
      _beginDrag(hit.pieceId, event.localPosition);
    }
  }

  void _beginDrag(int pieceId, Offset pointerPos) {
    final centre = _board.isPlaced(pieceId)
        ? _cellCentre(_board.positionOf(pieceId)!)
        : _slotCentre(pieceId);
    setState(() {
      _dragPieceId = pieceId;
      _grabOffset = centre - pointerPos;
      _dragCenter = centre;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    _lastPos = event.localPosition;
    if (_dragPieceId != null) {
      setState(() => _dragCenter = event.localPosition + _grabOffset);
      return;
    }
    if (_pendingTrayPiece != null &&
        (event.localPosition - _downPos).distance > 18) {
      // Moved before the long-press fired: not a pickup —
      // the gesture becomes a tray scroll instead
      // (contract §8 clarification + MUSE_STEPS §6).
      _longPressTimer?.cancel();
      _pendingTrayPiece = null;
      _scrollingTray = true;
    }
    if (_scrollingTray) {
      final next = (_downTrayScroll + _downPos.dx - event.localPosition.dx)
          .clamp(0.0, _maxTrayScroll);
      setState(() => _trayScroll = next);
    }
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _longPressTimer?.cancel();
    _pendingTrayPiece = null;
    _scrollingTray = false;
    _activePointer = null;
    final pieceId = _dragPieceId;
    final centre = _dragCenter;
    if (pieceId == null || centre == null) {
      setState(() {
        _dragPieceId = null;
        _dragCenter = null;
      });
      return;
    }
    // The drop point is the piece centre, in cell units
    // (contract E2 via S1-04 §7). The board changes only
    // here, through the shared PlacePiece command.
    final target = _board.snapTarget(
      (centre.dx - 16) / _cell,
      centre.dy / _cell,
      widget.snapToleranceRatio,
    );
    var justCompleted = false;
    if (target != null) {
      final result = PlacePiece(pieceId, target).apply(_board);
      _boardVersion++;
      justCompleted = result.justCompleted;
    }
    setState(() {
      _dragPieceId = null;
      _dragCenter = null;
      if (justCompleted) _completed = true;
    });
    if (justCompleted && !_completedFired) {
      _completedFired = true;
      widget.onCompleted?.call();
    }
  }

  bool _completedFired = false;

  void _onHint() {
    final unplaced = _trayOrder.visible(_board.isPlaced);
    if (unplaced.isEmpty) return;
    _hintTimer?.cancel();
    setState(() => _hintCell = _board.homeOf(unplaced.first));
    _hintTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _hintCell = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final boardSide = _boardSide;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.asset.title),
        actions: [
          // A raw Listener, not a GestureDetector: the
          // detector's onTapDown only fires after the
          // gesture arena resolves (on release, against
          // the button's own recognizer), but Preview
          // must show WHILE pressed (contract §3).
          Listener(
            onPointerDown: (_) => setState(() => _showPreview = true),
            onPointerUp: (_) => setState(() => _showPreview = false),
            onPointerCancel: (_) => setState(() => _showPreview = false),
            child: TextButton(onPressed: () {}, child: const Text('Preview')),
          ),
          TextButton(onPressed: _onHint, child: const Text('Hint')),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              key: const ValueKey('jigsaw-board-painter'),
              painter: JigsawBoardPainter(
                image: _uiImage,
                board: _board,
                trayOrder: _trayOrder,
                dragPieceId: _dragPieceId,
                dragCenter: _dragCenter,
                hintCell: _hintCell,
                trayScrollOffset: _trayScroll,
                boardVersion: _boardVersion,
              ),
            ),
          ),
          if (_showPreview)
            Positioned(
              left: 16,
              top: 0,
              width: boardSide,
              height: boardSide,
              child: Opacity(
                key: const ValueKey('jigsaw-preview-overlay'),
                opacity: 0.7,
                child: Image(image: widget.image, fit: BoxFit.fill),
              ),
            ),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerEnd,
              onPointerCancel: _onPointerEnd,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}
