import 'dart:js_interop';
import 'dart:math' as math;

import '../model/model.dart';
import 'painter.dart';

/// The geometry drawn over the light: normals and angles where rays meet
/// surfaces, and the axis and focal points of lenses and curved mirrors.
extension Annotate on Painter {
  /// The normal at [h], dashed, and arcs from it to the rays in and out,
  /// labelled in degrees. [strength] dims it when many are showing.
  void angles(Hit h, {double strength = 1}) {
    if (h.event == Event.absorbed || h.event == Event.filtered) return;
    // The ray's own colour, paled so the labels read.
    final ink = css(Rgb(_pale(h.colour.r), _pale(h.colour.g), _pale(h.colour.b)), 0.85 * strength);
    final normal = 34 * px;

    ctx.strokeStyle = 'rgba(255,255,255,${0.45 * strength})'.toJS;
    ctx.lineWidth = px;
    dashed([3, 3], () {
      ctx.beginPath();
      ctx.moveTo(h.x + h.nx * normal, h.y + h.ny * normal);
      ctx.lineTo(h.x - h.nx * normal, h.y - h.ny * normal);
      ctx.stroke();
    });

    ctx.strokeStyle = ink.toJS;
    ctx.fillStyle = ink.toJS;
    ctx.font = '${10.5 * px}px "Helvetica Neue", Helvetica, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    // In: between the normal on the near side and the way the ray came.
    _arc(h.x, h.y, math.atan2(h.ny, h.nx), math.atan2(-h.dy, -h.dx), 16, 30, h.incidence);
    // Out: from whichever half of the normal the ray leaves along.
    if ((h.ox, h.oy, h.outgoing) case (final ox?, final oy?, final out?)) {
      final back = ox * h.nx + oy * h.ny >= 0;
      final from = back ? math.atan2(h.ny, h.nx) : math.atan2(-h.ny, -h.nx);
      _arc(h.x, h.y, from, math.atan2(oy, ox), back ? 22 : 16, back ? 38 : 30, out);
    }
    ctx.textAlign = 'start';
    ctx.textBaseline = 'alphabetic';
  }

  /// The optical axis of [piece] and the points [Focusing.marks] names on
  /// it.
  void focus(Piece piece, Focusing optic, Medium room) {
    final marks = optic.marks(room).where((m) => m.$1.isFinite).toList();
    if (marks.isEmpty) return;
    final near = math.min(0.0, marks.map((m) => m.$1).reduce(math.min) - 30);
    final far = math.max(0.0, marks.map((m) => m.$1).reduce(math.max) + 30);
    final (x1, y1) = piece.toWorld(near, 0);
    final (x2, y2) = piece.toWorld(far, 0);
    ctx.strokeStyle = 'rgba(255,255,255,0.22)'.toJS;
    ctx.lineWidth = px;
    dashed([4, 5], () {
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
    });
    ctx.fillStyle = 'rgba(255,255,255,0.7)'.toJS;
    ctx.font = '${11 * px}px "Helvetica Neue", Helvetica, sans-serif';
    for (final (at, label) in marks) {
      final (x, y) = piece.toWorld(at, 0);
      dot(x, y, 2.5);
      ctx.fillText(label, x + 5 * px, y - 5 * px);
    }
  }

  /// An arc of [radius] pixels from angle [from] the short way round to
  /// [to], with [angle] written [labelAt] pixels out along its middle.
  void _arc(double x, double y, double from, double to, double radius, double labelAt, double angle) {
    if (angle < 0.004) return;
    var sweep = (to - from) % (2 * math.pi);
    if (sweep > math.pi) sweep -= 2 * math.pi;
    ctx.lineWidth = px;
    ctx.beginPath();
    ctx.arc(x, y, radius * px, from, from + sweep, sweep < 0);
    ctx.stroke();
    final mid = from + sweep / 2;
    ctx.fillText('${(angle * 180 / math.pi).toStringAsFixed(1)}°', x + math.cos(mid) * labelAt * px,
        y + math.sin(mid) * labelAt * px);
  }
}

double _pale(double channel) => 0.55 + 0.45 * channel.clamp(0, 1);
