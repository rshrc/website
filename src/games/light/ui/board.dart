import 'dart:math' as math;

import '../../shared/page.dart';
import '../model/model.dart';
import 'annotate.dart';
import 'painter.dart';
import 'session.dart';

/// The canvas the bench is drawn on, and the conversion between its pixels
/// and the bench's millimetres.
class Board {
  final Stage stage;
  final Session session;

  Board(this.stage, this.session);

  /// Screen pixels per bench millimetre.
  double get scale => stage.width / Bench.width;

  (double, double) toBench((double, double) pixels) => (pixels.$1 / scale, pixels.$2 / scale);

  /// The hit nearest ([x], [y]) within a few pixels, preferring annotated
  /// ones and brighter rays.
  Hit? hitNear(double x, double y) {
    final reach = 9 / scale;
    Hit? best;
    var bestScore = double.infinity;
    for (final h in session.trace.hits) {
      if (h.intensity < 0.02) continue;
      final d = math.sqrt((h.x - x) * (h.x - x) + (h.y - y) * (h.y - y));
      if (d > reach) continue;
      final score = d - (h.marked ? reach : 0) - h.intensity * reach;
      if (score < bestScore) {
        bestScore = score;
        best = h;
      }
    }
    return best;
  }

  void draw() {
    final trace = session.trace, pieces = session.bench.pieces, selected = session.selected;
    final paint = Painter(stage.ctx, 1 / scale);
    final ctx = stage.ctx;
    ctx.save();
    stage.fill(Painter.background);
    ctx.scale(scale, scale);

    pieces.whereType<Glass>().forEach(paint.glass);
    paint.rays(trace.segments);
    for (final p in pieces) {
      paint.piece(p, selected: identical(p, selected));
    }
    paint.spots(trace.hits.where((h) => h.piece is Screen));

    if (selected case final Piece piece && final Focusing optic) paint.focus(piece, optic, session.bench.room);
    if (session.angles) _annotations(paint, trace.hits);
    if (session.hovered case final hit?) {
      paint.angles(hit);
      paint.ring(hit.x, hit.y, 5);
    }
    ctx.restore();
  }

  /// Angles at every annotated hit — each place once, since several lasers
  /// down one path would stack identical labels.
  void _annotations(Painter paint, List<Hit> hits) {
    final drawn = <(double, double)>[];
    final apart = 10 / scale;
    for (final h in hits) {
      if (!h.marked || identical(h, session.hovered)) continue;
      if (drawn.any((d) => (d.$1 - h.x).abs() + (d.$2 - h.y).abs() < apart)) continue;
      drawn.add((h.x, h.y));
      paint.angles(h, strength: 0.75);
    }
  }
}
