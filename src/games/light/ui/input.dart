import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../shared/page.dart';
import '../model/model.dart';
import 'board.dart';
import 'handle.dart';
import 'session.dart';

/// The pointer and keyboard: press a piece to select it and drag it about,
/// drag the ring to turn it, scroll over it to nudge it, point anywhere
/// else to read what light is doing there.
class Input {
  final Board board;
  final Session session;

  /// What's being dragged, and whether by its handle (turning) or its body
  /// (moving, held at [_grab] from its origin).
  Piece? _dragging;
  var _turning = false;
  var _grab = (0.0, 0.0);

  Input(this.board, this.session) {
    final canvas = board.stage.canvas;
    canvas
      ..addEventListener('pointerdown', _down.toJS)
      ..addEventListener('pointermove', _move.toJS)
      ..addEventListener('pointerup', _release.toJS)
      ..addEventListener('pointercancel', _release.toJS)
      ..addEventListener('pointerleave', ((web.Event _) {
        if (_dragging == null) session.hovered = null;
      }).toJS)
      ..addEventListener('wheel', _wheel.toJS, web.AddEventListenerOptions(passive: false));

    void turnSelected(double degrees) {
      if (session.selected case final piece?) session.turn(piece, degrees);
    }

    onKey({
      'Delete': session.removeSelected,
      'Backspace': session.removeSelected,
      'Escape': () => session.select(null),
      '[': () => turnSelected(1),
      ']': () => turnSelected(-1),
      '{': () => turnSelected(15),
      '}': () => turnSelected(-15),
    });
  }

  (double, double) _at(web.MouseEvent e) => board.toBench(board.stage.locate(e));

  Piece? _pieceAt(double x, double y) => session.pieceAt(x, y, 8 / board.scale);

  bool _onHandle(Piece piece, double x, double y) {
    final (hx, hy) = handleOf(piece);
    return math.sqrt((x - hx) * (x - hx) + (y - hy) * (y - hy)) * board.scale < 11;
  }

  void _down(web.PointerEvent e) {
    final (x, y) = _at(e);
    final selected = session.selected;
    if (selected != null && _onHandle(selected, x, y)) {
      _hold(e, selected, turning: true);
      return;
    }
    final piece = _pieceAt(x, y);
    if (!identical(piece, selected)) session.select(piece);
    if (piece == null) return;
    _grab = (x - piece.x, y - piece.y);
    _hold(e, piece, turning: false);
  }

  void _hold(web.PointerEvent e, Piece piece, {required bool turning}) {
    _dragging = piece;
    _turning = turning;
    board.stage.canvas.setPointerCapture(e.pointerId);
  }

  void _move(web.PointerEvent e) {
    final (x, y) = _at(e);
    final piece = _dragging;
    if (piece == null) {
      session.hovered = board.hitNear(x, y);
      board.stage.canvas.style.cursor = _pieceAt(x, y) != null ? 'grab' : 'crosshair';
      return;
    }
    if (_turning) {
      session.edit(piece, () => piece.angle = _angleFor(piece, x, y, snap: e.shiftKey ? 15 : 0.5));
    } else {
      session.edit(piece, () {
        piece
          ..x = (x - _grab.$1).clamp(0, Bench.width)
          ..y = (y - _grab.$2).clamp(0, Bench.height);
      });
    }
  }

  /// The angle that puts [piece]'s handle under ([x], [y]), to the nearest
  /// [snap] degrees.
  double _angleFor(Piece piece, double x, double y, {required double snap}) {
    final (lx, ly) = handleLocal(piece);
    final raw = math.atan2(y - piece.y, x - piece.x) - math.atan2(ly, lx);
    final step = snap * math.pi / 180;
    return (raw / step).round() * step;
  }

  void _release(web.Event _) => _dragging = null;

  /// Scrolling over a piece turns it a degree a notch; elsewhere the page
  /// scrolls as usual.
  void _wheel(web.WheelEvent e) {
    final (x, y) = _at(e);
    final piece = _pieceAt(x, y);
    if (piece == null) return;
    e.preventDefault();
    if (!identical(piece, session.selected)) session.select(piece);
    session.turn(piece, e.deltaY > 0 ? -1 : 1);
  }
}
