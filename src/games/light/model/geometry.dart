import 'dart:math' as math;

/// Flat geometry for the bench: where a piece sits, and the surfaces light
/// can meet. Millimetres, y pointing down, angles in radians turning
/// clockwise on screen.

/// A position and a turn. Pieces describe their shape in their own frame,
/// with their axis along +x, and a pose carries it onto the bench.
class Pose {
  double x, y, angle;

  Pose(this.x, this.y, {this.angle = 0});

  (double, double) toWorld(double lx, double ly) {
    final c = math.cos(angle), s = math.sin(angle);
    return (x + lx * c - ly * s, y + lx * s + ly * c);
  }

  (double, double) toLocal(double wx, double wy) {
    final c = math.cos(angle), s = math.sin(angle), dx = wx - x, dy = wy - y;
    return (dx * c + dy * s, -dx * s + dy * c);
  }

  /// A direction (not a point) from the own frame onto the bench.
  (double, double) turn(double lx, double ly) {
    final c = math.cos(angle), s = math.sin(angle);
    return (lx * c - ly * s, lx * s + ly * c);
  }
}

/// Where a ray meets an edge: how far along the ray, and the edge's outward
/// normal there.
typedef Crossing = ({double t, double nx, double ny});

/// One surface, in bench coordinates.
sealed class Edge {
  /// Crossings closer than this are the surface the ray is just leaving.
  static const _near = 1e-3;

  /// Where the ray from ([ox], [oy]) heading along the unit vector
  /// ([dx], [dy]) first meets this edge, if it does.
  Crossing? crossing(double ox, double oy, double dx, double dy);
}

/// A straight edge from a to b. For a piece of glass the normal points out
/// of it; for something thin, like a mirror, it's just one of its sides.
final class LineEdge extends Edge {
  final double ax, ay, bx, by, nx, ny;

  LineEdge(this.ax, this.ay, this.bx, this.by, this.nx, this.ny);

  @override
  Crossing? crossing(double ox, double oy, double dx, double dy) {
    final ex = bx - ax, ey = by - ay;
    final den = dx * ey - dy * ex;
    if (den.abs() < 1e-12) return null;
    final wx = ax - ox, wy = ay - oy;
    final t = (wx * ey - wy * ex) / den;
    final u = (wx * dy - wy * dx) / den;
    if (t <= Edge._near || u < 0 || u > 1) return null;
    return (t: t, nx: nx, ny: ny);
  }
}

/// Part of a circle, from angle [from] clockwise through [sweep]. Its
/// outward normal points away from the centre if it [bulges], else towards
/// it.
final class ArcEdge extends Edge {
  final double cx, cy, r, from, sweep;
  final bool bulges;

  ArcEdge(this.cx, this.cy, this.r, this.from, this.sweep, {required this.bulges});

  @override
  Crossing? crossing(double ox, double oy, double dx, double dy) {
    final fx = ox - cx, fy = oy - cy;
    final b = fx * dx + fy * dy;
    final disc = b * b - (fx * fx + fy * fy - r * r);
    if (disc < 0) return null;
    final root = math.sqrt(disc);
    for (final t in [-b - root, -b + root]) {
      if (t <= Edge._near) continue;
      final px = fx + dx * t, py = fy + dy * t;
      final along = (math.atan2(py, px) - from) % (2 * math.pi);
      if (along <= sweep + 1e-9) {
        final sign = bulges ? 1 / r : -1 / r;
        return (t: t, nx: px * sign, ny: py * sign);
      }
    }
    return null;
  }
}

/// Builds a piece's edges from a shape written in its own frame.
class Outline {
  final Pose pose;
  final edges = <Edge>[];

  Outline(this.pose);

  void line(double ax, double ay, double bx, double by, {required double nx, required double ny}) {
    final (wax, way) = pose.toWorld(ax, ay);
    final (wbx, wby) = pose.toWorld(bx, by);
    final (wnx, wny) = pose.turn(nx, ny);
    edges.add(LineEdge(wax, way, wbx, wby, wnx, wny));
  }

  void arc(double cx, double cy, double r, double from, double sweep, {bool bulges = true}) {
    final (wx, wy) = pose.toWorld(cx, cy);
    edges.add(ArcEdge(wx, wy, r, from + pose.angle, sweep, bulges: bulges));
  }

  /// A convex polygon, its normals pointing away from the middle.
  void polygon(List<(double, double)> corners) {
    final (mx, my) = centroid(corners);
    for (var i = 0; i < corners.length; i++) {
      final (ax, ay) = corners[i];
      final (bx, by) = corners[(i + 1) % corners.length];
      final ex = bx - ax, ey = by - ay, len = math.sqrt(ex * ex + ey * ey);
      final outward = (ey * ((ax + bx) / 2 - mx) - ex * ((ay + by) / 2 - my)) >= 0;
      final sign = outward ? 1 / len : -1 / len;
      line(ax, ay, bx, by, nx: ey * sign, ny: -ex * sign);
    }
  }
}

(double, double) centroid(List<(double, double)> points) {
  var x = 0.0, y = 0.0;
  for (final (px, py) in points) {
    x += px / points.length;
    y += py / points.length;
  }
  return (x, y);
}

/// Whether ([x], [y]) is inside the convex polygon [corners], or within
/// [slack] of it.
bool insideConvex(List<(double, double)> corners, double x, double y, double slack) {
  final (mx, my) = centroid(corners);
  for (var i = 0; i < corners.length; i++) {
    final (ax, ay) = corners[i];
    final (bx, by) = corners[(i + 1) % corners.length];
    final ex = bx - ax, ey = by - ay, len = math.sqrt(ex * ex + ey * ey);
    // Signed distance from the edge, positive on the same side as the
    // middle.
    double side(double px, double py) => (ex * (py - ay) - ey * (px - ax)) / len;
    final inward = side(mx, my).sign;
    if (side(x, y) * inward < -slack) return false;
  }
  return true;
}
