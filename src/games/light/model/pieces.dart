import 'dart:math' as math;

import 'colour.dart';
import 'geometry.dart';
import 'light.dart';
import 'medium.dart';

part 'glass.dart';

/// Everything that can sit on the bench.
///
/// Each piece knows its shape ([edges]), how to be picked up ([contains])
/// and what it does to light that meets it ([meet]). Sealed, so the page's
/// painting, controls and explanations — exhaustive switches over these
/// types — are pointed at by the compiler whenever a new kind is added.
sealed class Piece extends Pose {
  Piece(super.x, super.y, {super.angle});

  /// What it's called on the page.
  String get name;

  /// Its surfaces, on the bench.
  List<Edge> edges();

  /// Whether the bench point ([x], [y]) is on it, give or take [slack] mm.
  bool contains(double x, double y, double slack) {
    final (lx, ly) = toLocal(x, y);
    return containsLocal(lx, ly, slack);
  }

  /// [contains], for a point in the piece's own frame.
  bool containsLocal(double x, double y, double slack);

  /// How far it reaches above its origin, in its own frame.
  double get top;

  /// An identical piece.
  Piece clone();

  /// A copy set a little apart, so both can be seen.
  Piece copy() => clone()
    ..x += 24
    ..y += 24;

  /// Records what happens to the ray arriving at [at] and returns the rays
  /// that leave.
  List<Ray> meet(Arrival at);
}

/// A piece with a focal length: a lens or a curved mirror.
abstract interface class Focusing {
  /// In mm, negative for a diverging lens, for light of [nm] in [room].
  double focal(Medium room, [double nm = Medium.sodium]);

  /// Points worth marking on its axis, in its own frame: the focus, and the
  /// centre of curvature for a mirror.
  List<(double, String)> marks(Medium room);
}

/// A piece with a spherical surface of [radius], [height] tall.
mixin Curved {
  double get height;
  double get radius;

  /// Half the height, kept inside the circle.
  double get aperture => math.min(height / 2, radius * 0.97);

  /// How far the surface sinks over the [aperture].
  double get sag => radius - math.sqrt(radius * radius - aperture * aperture);

  /// Half the angle the surface spans, seen from its centre.
  double get halfAngle => math.asin(aperture / radius);
}

/// A light source. Its body blocks light; its aperture is its origin, and
/// it shines along its axis.
final class Laser extends Piece {
  static const bodyLength = 44.0, halfWidth = 8.0;

  /// White light, or one wavelength [nm].
  bool white;
  double nm;

  /// The beam's width in mm; zero for a single ray.
  double beam;

  Laser(super.x, super.y, {super.angle, this.white = true, this.nm = 532, this.beam = 0});

  @override
  String get name => 'laser';

  /// The rays it sends out: one per ray of the beam, or for white light one
  /// per wavelength of each.
  List<Ray> emit() {
    final count = beam <= 0 ? 1 : math.min(15, (beam / 10).round() + 2);
    final (dx, dy) = turn(1, 0);
    return [
      for (var k = 0; k < count; k++)
        ...() {
          final offset = count == 1 ? 0.0 : (k / (count - 1) - 0.5) * beam;
          final (x0, y0) = toWorld(0.01, offset);
          final middle = k == count ~/ 2;
          return white
              ? [
                  for (final w in whiteLight)
                    Ray(x0, y0, dx, dy, nm: w.nm, colour: w.colour, white: true, marked: middle && w.nm == whiteMarkedNm)
                ]
              : [Ray(x0, y0, dx, dy, nm: nm, colour: laserRgb(nm), marked: middle)];
        }(),
    ];
  }

  @override
  List<Edge> edges() =>
      (Outline(this)..polygon([(-bodyLength, -halfWidth), (0, -halfWidth), (0, halfWidth), (-bodyLength, halfWidth)]))
          .edges;

  @override
  bool containsLocal(double x, double y, double slack) =>
      x > -bodyLength - slack && x < slack && y.abs() < halfWidth + slack;

  @override
  double get top => halfWidth;

  @override
  Laser clone() => Laser(x, y, angle: angle, white: white, nm: nm, beam: beam);

  @override
  List<Ray> meet(Arrival at) {
    at.record(Event.absorbed, markable: false);
    return const [];
  }
}

/// A flat piece standing along its own y axis, [length] long: a mirror, a
/// screen, a filter.
sealed class Thin extends Piece {
  double length;

  Thin(super.x, super.y, {super.angle, required this.length});

  @override
  List<Edge> edges() => (Outline(this)..line(0, -length / 2, 0, length / 2, nx: 1, ny: 0)).edges;

  @override
  bool containsLocal(double x, double y, double slack) => x.abs() < slack && y.abs() < length / 2 + slack;

  @override
  double get top => length / 2;
}

final class Mirror extends Thin {
  Mirror(super.x, super.y, {super.angle, super.length = 160});

  @override
  String get name => 'mirror';

  @override
  Mirror clone() => Mirror(x, y, angle: angle, length: length);

  @override
  List<Ray> meet(Arrival at) => reflect(at);
}

/// Both sides of a mirror reflect everything.
List<Ray> reflect(Arrival at) {
  final (rx, ry) = at.reflection;
  at.record(Event.reflection, out: (rx, ry));
  return [at.ray.go(rx, ry)];
}

/// A half-silvered mirror: reflects [reflect] of the light, lets the rest
/// through.
final class Splitter extends Thin {
  double reflect;

  Splitter(super.x, super.y, {super.angle, super.length = 160, this.reflect = 0.5});

  @override
  String get name => 'splitter';

  @override
  Splitter clone() => Splitter(x, y, angle: angle, length: length, reflect: reflect);

  @override
  List<Ray> meet(Arrival at) {
    final (rx, ry) = at.reflection;
    at.record(Event.split, out: (rx, ry), reflected: reflect);
    return [at.ray.go(rx, ry, share: reflect), at.ray.go(at.ray.dx, at.ray.dy, share: 1 - reflect)];
  }
}

/// A transmission grating with [lines] per mm: order m leaves at
/// sin θ = sin θ_in + m λ / d.
final class Grating extends Thin {
  double lines;

  /// How the light divides between orders 0, ±1, ±2 and ±3 — roughly, as
  /// the real share depends on the shape of the grooves.
  static const _shares = [0.34, 0.2, 0.1, 0.03];

  Grating(super.x, super.y, {super.angle, super.length = 140, this.lines = 600});

  @override
  String get name => 'grating';

  /// The line spacing, in nm.
  double get spacing => 1e6 / lines;

  @override
  Grating clone() => Grating(x, y, angle: angle, length: length, lines: lines);

  @override
  List<Ray> meet(Arrival at) {
    final ray = at.ray;
    // Onward is against the facing normal; across is along the grating.
    final fx = -at.nx, fy = -at.ny, ax = -fy, ay = fx;
    final sinIn = ray.dx * ax + ray.dy * ay;
    final out = <Ray>[];
    for (var m = -3; m <= 3; m++) {
      final s = sinIn + m * ray.nm / spacing;
      if (s.abs() > 1) continue;
      final c = math.sqrt(1 - s * s);
      final ox = s * ax + c * fx, oy = s * ay + c * fy;
      if (m == 0) at.record(Event.diffraction, out: (ox, oy));
      out.add(ray.go(ox, oy, share: _shares[m.abs()], marked: m == 0));
    }
    return out;
  }
}

/// Passes wavelengths within [band] / 2 of [nm], stops the rest.
final class Filter extends Thin {
  double nm, band;

  Filter(super.x, super.y, {super.angle, super.length = 120, this.nm = 620, this.band = 60});

  @override
  String get name => 'filter';

  double get lowest => nm - band / 2;
  double get highest => nm + band / 2;

  @override
  Filter clone() => Filter(x, y, angle: angle, length: length, nm: nm, band: band);

  @override
  List<Ray> meet(Arrival at) {
    final ray = at.ray;
    if (ray.nm < lowest || ray.nm > highest) {
      at.record(Event.absorbed);
      return const [];
    }
    at.record(Event.filtered, out: (ray.dx, ray.dy));
    return [ray.go(ray.dx, ray.dy, share: 0.92)];
  }
}

/// Stops light and shows where it lands.
final class Screen extends Thin {
  Screen(super.x, super.y, {super.angle, super.length = 300});

  @override
  String get name => 'screen';

  @override
  Screen clone() => Screen(x, y, angle: angle, length: length);

  @override
  List<Ray> meet(Arrival at) {
    at.record(Event.absorbed);
    return const [];
  }
}

/// A spherical mirror: hollow towards +x, where its focus is, and convex
/// from behind.
final class CurvedMirror extends Piece with Curved implements Focusing {
  @override
  double height, radius;

  CurvedMirror(super.x, super.y, {super.angle, this.height = 180, this.radius = 360});

  @override
  String get name => 'curved mirror';

  @override
  double focal(Medium room, [double nm = Medium.sodium]) => radius / 2;

  @override
  List<(double, String)> marks(Medium room) => [(radius / 2, 'F'), (radius, 'C')];

  // Vertex at the origin; the circle's centre out along the axis.
  @override
  List<Edge> edges() => (Outline(this)..arc(radius, 0, radius, math.pi - halfAngle, 2 * halfAngle)).edges;

  @override
  bool containsLocal(double x, double y, double slack) =>
      x > -slack && x < sag + slack && y.abs() < aperture + slack;

  @override
  double get top => aperture;

  @override
  CurvedMirror clone() => CurvedMirror(x, y, angle: angle, height: height, radius: radius);

  @override
  List<Ray> meet(Arrival at) => reflect(at);
}
