part of 'pieces.dart';

/// A solid piece of some [medium] that light crosses into and out of,
/// bending as it goes.
sealed class Glass extends Piece {
  Medium medium;

  Glass(super.x, super.y, {super.angle, required this.medium});

  /// Snell's law for the ray that gets through, Fresnel's equations for how
  /// much reflects anyway, and total internal reflection when nothing can
  /// get through.
  @override
  List<Ray> meet(Arrival at) {
    final ray = at.ray;
    final entering = at.fromOutside;
    final n1 = at.here.at(ray.nm);
    final n2 = entering ? medium.at(ray.nm) : at.surroundings.room.at(ray.nm);
    final (rx, ry) = at.reflection;
    final cosI = at.cosI;
    final eta = n1 / n2;
    final k = 1 - eta * eta * (1 - cosI * cosI);
    if (k < 0) {
      at.record(Event.totalInternal, out: (rx, ry), n2: n2, reflected: 1);
      return [ray.go(rx, ry)];
    }
    // n1 sin θ1 = n2 sin θ2.
    final cosT = math.sqrt(k);
    final tx = eta * ray.dx + (eta * cosI - cosT) * at.nx, ty = eta * ray.dy + (eta * cosI - cosT) * at.ny;
    // Averaged over the two polarisations, since a laser pointer's light is
    // a mix of both.
    final rs = (n1 * cosI - n2 * cosT) / (n1 * cosI + n2 * cosT);
    final rp = (n1 * cosT - n2 * cosI) / (n1 * cosT + n2 * cosI);
    final share = (rs * rs + rp * rp) / 2;
    at.record(Event.refraction, out: (tx, ty), n2: n2, reflected: share, entering: entering);
    return [
      ray.go(tx, ty, share: 1 - share, crosses: true, into: entering ? this : null),
      if (at.surroundings.faint) ray.go(rx, ry, share: share, marked: false),
    ];
  }

  /// The critical angle for light inside it trying to get out into [room].
  double critical(Medium room) => math.asin(math.min(1, room.index / medium.index));
}

/// An isosceles prism, [side] long on its two equal sides, apex up.
final class Prism extends Glass {
  double side;

  /// The angle at the apex, in degrees.
  double apex;

  Prism(super.x, super.y, {super.angle, super.medium = Medium.flint, this.side = 170, this.apex = 60});

  @override
  String get name => 'prism';

  /// Apex first, centred on the centroid.
  List<(double, double)> get corners {
    final half = apex * math.pi / 360;
    final w = side * math.sin(half), h = side * math.cos(half);
    return [(0, -2 * h / 3), (w, h / 3), (-w, h / 3)];
  }

  @override
  List<Edge> edges() => (Outline(this)..polygon(corners)).edges;

  @override
  bool containsLocal(double x, double y, double slack) => insideConvex(corners, x, y, slack);

  @override
  double get top => -corners.first.$2;

  @override
  Prism clone() => Prism(x, y, angle: angle, medium: medium, side: side, apex: apex);
}

final class Block extends Glass {
  double width, height;

  Block(super.x, super.y, {super.angle, super.medium = Medium.crown, this.width = 220, this.height = 120});

  @override
  String get name => 'block';

  List<(double, double)> get corners {
    final w = width / 2, h = height / 2;
    return [(-w, -h), (w, -h), (w, h), (-w, h)];
  }

  @override
  List<Edge> edges() => (Outline(this)..polygon(corners)).edges;

  @override
  bool containsLocal(double x, double y, double slack) =>
      x.abs() < width / 2 + slack && y.abs() < height / 2 + slack;

  @override
  double get top => height / 2;

  @override
  Block clone() => Block(x, y, angle: angle, medium: medium, width: width, height: height);
}

/// Focal points either side of a lens, at ±f.
List<(double, String)> _lensMarks(double f) => [(f, 'F'), (-f, 'F')];

/// A symmetric biconvex lens: two arcs meeting in a sharp edge.
final class Lens extends Glass with Curved implements Focusing {
  @override
  double height, radius;

  Lens(super.x, super.y, {super.angle, super.medium = Medium.crown, this.height = 160, this.radius = 220});

  @override
  String get name => 'lens';

  /// The thick-lens lensmaker's equation, with R1 = R and R2 = −R.
  @override
  double focal(Medium room, [double nm = Medium.sodium]) {
    final n = medium.at(nm) / room.at(nm), r = radius, d = 2 * sag;
    return 1 / ((n - 1) * (2 / r - (n - 1) * d / (n * r * r)));
  }

  @override
  List<(double, String)> marks(Medium room) => _lensMarks(focal(room));

  @override
  List<Edge> edges() => (Outline(this)
        ..arc(radius - sag, 0, radius, math.pi - halfAngle, 2 * halfAngle)
        ..arc(sag - radius, 0, radius, -halfAngle, 2 * halfAngle))
      .edges;

  @override
  bool containsLocal(double x, double y, double slack) => x.abs() < sag + slack && y.abs() < aperture + slack;

  @override
  double get top => aperture;

  @override
  Lens clone() => Lens(x, y, angle: angle, medium: medium, height: height, radius: radius);
}

/// A symmetric biconcave lens, [waist] thick in the middle.
final class DivergingLens extends Glass with Curved implements Focusing {
  static const waist = 8.0;

  @override
  double height, radius;

  DivergingLens(super.x, super.y, {super.angle, super.medium = Medium.crown, this.height = 160, this.radius = 180});

  @override
  String get name => 'diverging lens';

  /// The thick-lens lensmaker's equation, with R1 = −R and R2 = R.
  @override
  double focal(Medium room, [double nm = Medium.sodium]) {
    final n = medium.at(nm) / room.at(nm), r = radius;
    return 1 / ((n - 1) * (-2 / r - (n - 1) * waist / (n * r * r)));
  }

  @override
  List<(double, String)> marks(Medium room) => _lensMarks(focal(room));

  // In order round the outline, so the page can draw it as one path.
  @override
  List<Edge> edges() {
    final w = waist / 2, a = aperture, s = sag, r = radius, phi = halfAngle;
    return (Outline(this)
          ..arc(-w - r, 0, r, -phi, 2 * phi, bulges: false)
          ..line(-w - s, a, w + s, a, nx: 0, ny: 1)
          ..arc(w + r, 0, r, math.pi - phi, 2 * phi, bulges: false)
          ..line(w + s, -a, -w - s, -a, nx: 0, ny: -1))
        .edges;
  }

  @override
  bool containsLocal(double x, double y, double slack) =>
      x.abs() < waist / 2 + sag + slack && y.abs() < aperture + slack;

  @override
  double get top => aperture;

  @override
  DivergingLens clone() => DivergingLens(x, y, angle: angle, medium: medium, height: height, radius: radius);
}

/// Half a disc, flat face along its own y axis and its origin at the middle
/// of that face — aim there to meet the flat face at any angle you like.
final class HalfDisc extends Glass {
  double radius;

  HalfDisc(super.x, super.y, {super.angle, super.medium = Medium.crown, this.radius = 110});

  @override
  String get name => 'half disc';

  @override
  List<Edge> edges() => (Outline(this)
        ..line(0, -radius, 0, radius, nx: -1, ny: 0)
        ..arc(0, 0, radius, -math.pi / 2, math.pi))
      .edges;

  @override
  bool containsLocal(double x, double y, double slack) =>
      x > -slack && x * x + y * y < (radius + slack) * (radius + slack);

  @override
  double get top => radius;

  @override
  HalfDisc clone() => HalfDisc(x, y, angle: angle, medium: medium, radius: radius);
}

/// A round drop, water unless told otherwise.
final class Drop extends Glass {
  double radius;

  Drop(super.x, super.y, {super.angle, super.medium = Medium.water, this.radius = 80});

  @override
  String get name => 'drop';

  @override
  List<Edge> edges() => (Outline(this)..arc(0, 0, radius, 0, 2 * math.pi)).edges;

  @override
  bool containsLocal(double x, double y, double slack) => x * x + y * y < (radius + slack) * (radius + slack);

  @override
  double get top => radius;

  @override
  Drop clone() => Drop(x, y, angle: angle, medium: medium, radius: radius);
}
