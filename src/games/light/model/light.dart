import 'dart:math' as math;

import 'colour.dart';
import 'medium.dart';
import 'pieces.dart';

/// Rays, and what happens to them where they meet a surface.

/// What the whole bench is filled with, and whether glass surfaces also
/// send back the few percent Fresnel says they reflect, as faint rays.
class Surroundings {
  final Medium room;
  final bool faint;

  const Surroundings({this.room = Medium.air, this.faint = true});
}

/// A ray of one wavelength, starting at ([x], [y]) and heading along the
/// unit vector ([dx], [dy]).
class Ray {
  final double x, y, dx, dy;
  final double nm;
  final Rgb colour;

  /// Whether it's part of white light, rather than a laser of one colour.
  final bool white;

  /// How much of the light that left the laser is still in it.
  final double intensity;

  /// The piece of glass it's travelling through, if any.
  final Glass? inside;

  /// How many surfaces it has met so far.
  final int depth;

  /// Whether this is the ray the page annotates: the middle of a beam,
  /// the middle of white light.
  final bool marked;

  const Ray(this.x, this.y, this.dx, this.dy,
      {required this.nm,
      required this.colour,
      this.white = false,
      this.intensity = 1,
      this.inside,
      this.depth = 0,
      this.marked = false});

  /// The same ray, having reached ([x], [y]).
  Ray at(double x, double y) => Ray(x, y, dx, dy,
      nm: nm, colour: colour, white: white, intensity: intensity, inside: inside, depth: depth, marked: marked);

  /// The ray carrying on from where it is in a new direction with [share]
  /// of its light, still in the same medium unless it [crosses] into
  /// [into] (null for the room).
  Ray go(double dx, double dy, {double share = 1, bool crosses = false, Glass? into, bool? marked}) => Ray(x, y, dx, dy,
      nm: nm,
      colour: colour,
      white: white,
      intensity: intensity * share,
      inside: crosses ? into : inside,
      depth: depth + 1,
      marked: marked ?? this.marked);
}

enum Event { reflection, refraction, totalInternal, split, diffraction, filtered, absorbed }

/// Something that happened to a ray where it met a surface, kept so the
/// page can draw the normal and the angles, and explain them.
class Hit {
  final Event event;
  final Piece piece;
  final double x, y;

  /// The normal on the side the ray came from, and the ray's direction in.
  final double nx, ny, dx, dy;

  /// The main ray out, if any: reflected, refracted, or order zero.
  final double? ox, oy;

  /// Refractive index before and after; the share reflected.
  final double n1, n2, reflected;

  /// For refraction: whether the ray is going into the piece, not out.
  final bool entering;

  final double nm, intensity;
  final Rgb colour;
  final bool white;

  /// Whether the page annotates this hit when angles are on.
  final bool marked;

  const Hit(this.event, this.piece, this.x, this.y,
      {required this.nx,
      required this.ny,
      required this.dx,
      required this.dy,
      this.ox,
      this.oy,
      required this.n1,
      required this.n2,
      this.reflected = 0,
      this.entering = false,
      required this.nm,
      required this.intensity,
      required this.colour,
      required this.white,
      required this.marked});

  double get incidence => math.acos((-(dx * nx + dy * ny)).clamp(-1.0, 1.0));

  /// The angle of the ray out from the normal, on whichever side it leaves.
  double? get outgoing => ox == null ? null : math.acos((ox! * nx + oy! * ny).abs().clamp(0.0, 1.0));

  /// Past this angle of incidence nothing gets through, if there is one.
  double? get critical => n2 < n1 ? math.asin(n2 / n1) : null;
}

/// A ray arriving at a piece: everything the piece needs to decide what
/// happens next, and the means to record it.
class Arrival {
  final Ray ray;
  final Piece piece;

  /// The surface normal on the side the ray came from.
  final double nx, ny;

  /// Whether the ray arrived against the edge's outward normal, which for
  /// glass means from outside it.
  final bool fromOutside;

  final Surroundings surroundings;
  final void Function(Hit) _record;

  Arrival(this.ray, this.piece, this.nx, this.ny, this.surroundings, this._record, {required this.fromOutside});

  /// The cosine of the angle of incidence.
  double get cosI => -(ray.dx * nx + ray.dy * ny);

  /// The medium the ray is in as it arrives.
  Medium get here => ray.inside?.medium ?? surroundings.room;

  /// The direction the law of reflection sends it: out at the angle it
  /// came in.
  (double, double) get reflection => (ray.dx + 2 * cosI * nx, ray.dy + 2 * cosI * ny);

  /// Notes what happened here.
  void record(Event event,
      {(double, double)? out, double? n2, double reflected = 0, bool entering = false, bool markable = true}) {
    final n1 = here.at(ray.nm);
    _record(Hit(event, piece, ray.x, ray.y,
        nx: nx,
        ny: ny,
        dx: ray.dx,
        dy: ray.dy,
        ox: out?.$1,
        oy: out?.$2,
        n1: n1,
        n2: n2 ?? n1,
        reflected: reflected,
        entering: entering,
        nm: ray.nm,
        intensity: ray.intensity,
        colour: ray.colour,
        white: ray.white,
        marked: markable && ray.marked && ray.intensity > 0.2));
  }
}
