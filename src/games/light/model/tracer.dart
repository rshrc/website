import 'colour.dart';
import 'geometry.dart';
import 'light.dart';
import 'pieces.dart';

/// Follows every ray from every laser until it leaves the bench, is
/// absorbed, fades out, or has bounced too often.

/// A straight run of light.
class RaySegment {
  final double x1, y1, x2, y2;
  final Rgb colour;
  final double intensity;

  const RaySegment(this.x1, this.y1, this.x2, this.y2, this.colour, this.intensity);
}

class Trace {
  final segments = <RaySegment>[];
  final hits = <Hit>[];
  var rays = 0;

  /// Whether tracing stopped early at [maxSegments].
  var cut = false;

  static const maxSegments = 60000;
}

/// A cap on bounces, so two parallel mirrors can't trap the tracer.
const _maxDepth = 80;

/// Rays dimmer than this aren't worth following.
const _dimmest = 0.004;

Trace traceLight(List<Piece> pieces, Surroundings surroundings, {required double width, required double height}) {
  final trace = Trace();
  final surfaces = [
    for (final piece in pieces)
      for (final edge in piece.edges()) (edge, piece),
  ];
  final queue = [
    for (final laser in pieces.whereType<Laser>()) ...laser.emit(),
  ];

  while (queue.isNotEmpty) {
    if (trace.segments.length > Trace.maxSegments) {
      trace.cut = true;
      break;
    }
    final ray = queue.removeLast();
    trace.rays++;

    // The nearest surface in the ray's way.
    Crossing? nearest;
    Piece? owner;
    for (final (edge, piece) in surfaces) {
      final c = edge.crossing(ray.x, ray.y, ray.dx, ray.dy);
      if (c != null && (nearest == null || c.t < nearest.t)) {
        nearest = c;
        owner = piece;
      }
    }

    // The bench's own edges swallow whatever reaches them.
    final wall = _distanceToWall(ray, width, height);
    final t = nearest == null || nearest.t > wall ? wall : nearest.t;
    final px = ray.x + ray.dx * t, py = ray.y + ray.dy * t;
    trace.segments.add(RaySegment(ray.x, ray.y, px, py, ray.colour, ray.intensity));
    if (nearest == null || owner == null || t == wall || ray.depth >= _maxDepth) continue;

    final fromOutside = ray.dx * nearest.nx + ray.dy * nearest.ny < 0;
    final (nx, ny) = fromOutside ? (nearest.nx, nearest.ny) : (-nearest.nx, -nearest.ny);
    final arrival = Arrival(ray.at(px, py), owner, nx, ny, surroundings, trace.hits.add, fromOutside: fromOutside);
    queue.addAll(owner.meet(arrival).where((r) => r.intensity >= _dimmest));
  }
  return trace;
}

double _distanceToWall(Ray ray, double width, double height) {
  var t = double.infinity;
  if (ray.dx > 0) t = (width - ray.x) / ray.dx;
  if (ray.dx < 0) t = -ray.x / ray.dx;
  if (ray.dy > 0 && (height - ray.y) / ray.dy < t) t = (height - ray.y) / ray.dy;
  if (ray.dy < 0 && -ray.y / ray.dy < t) t = -ray.y / ray.dy;
  return t < 0 ? 0 : t;
}
