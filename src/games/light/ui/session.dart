import 'dart:math' as math;

import '../model/model.dart';

/// What the page is showing: the bench, what's selected, what's pointed at,
/// and the latest trace, redone only when something changes.
///
/// No web imports; the board, the controls and the pointer all read and
/// change the page through this.
class Session {
  final Bench bench;

  Session(this.bench);

  /// Called when the selection changes, to show its controls.
  void Function(Piece?)? onSelect;

  /// Called when the selected piece changes by some means other than its
  /// controls — dragged, or turned — so they can catch up.
  void Function()? onEdit;

  /// Whether the board needs drawing again.
  var stale = true;

  Trace? _trace;
  Trace get trace => _trace ??= bench.trace();

  Piece? _selected;
  Piece? get selected => _selected;

  Hit? _hovered;
  Hit? get hovered => _hovered;
  set hovered(Hit? hit) {
    if (identical(hit, _hovered)) return;
    _hovered = hit;
    stale = true;
  }

  var _angles = true;
  bool get angles => _angles;
  set angles(bool on) {
    _angles = on;
    stale = true;
  }

  /// Something on the bench changed: trace it again.
  void changed() {
    _trace = null;
    _hovered = null;
    stale = true;
  }

  void select(Piece? piece) {
    _selected = piece;
    stale = true;
    onSelect?.call(piece);
  }

  void add(Piece piece) {
    bench.pieces.add(piece);
    changed();
    select(piece);
  }

  void removeSelected() {
    final piece = _selected;
    if (piece == null) return;
    bench.pieces.remove(piece);
    changed();
    select(null);
  }

  void load(String scene) {
    bench.load(scene);
    changed();
    select(null);
  }

  /// Moves or turns [piece] from outside its controls.
  void edit(Piece piece, void Function() change) {
    change();
    changed();
    if (identical(piece, _selected)) onEdit?.call();
  }

  /// Turns [piece] anticlockwise by [degrees].
  void turn(Piece piece, double degrees) => edit(piece, () => piece.angle -= degrees * math.pi / 180);

  /// The topmost piece at the bench point ([x], [y]), give or take [slack].
  Piece? pieceAt(double x, double y, double slack) {
    for (final piece in bench.pieces.reversed) {
      if (piece.contains(x, y, slack)) return piece;
    }
    return null;
  }
}
