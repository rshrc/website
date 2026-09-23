import 'dart:math' as math;
import 'dart:typed_data';

import '../shared/rng.dart';
import '../shared/vec2.dart';

/// What happens at the edge of the world.
enum Walls {
  /// Bodies bounce off the edges, losing energy by [Laws.restitution].
  bounce,

  /// The world is a torus: leave on the right, come back on the left.
  wrap,

  /// There are no edges. Bodies that drift far enough away are forgotten.
  open,
}

/// What happens when two bodies touch.
enum Contact {
  /// They push apart, with [Laws.restitution] deciding how much of their
  /// approach speed survives the bounce.
  bounce,

  /// They become one body, keeping their combined mass and momentum. With
  /// mutual gravity switched on, this is how a dust cloud becomes planets.
  merge,
}

/// The laws of nature for one universe. Every field is live: change it while
/// the simulation runs and the next step obeys the new law.
///
/// Units are pixels and seconds. A body's mass defaults to its area in
/// pixels (so a body of radius 10 weighs 100), but can be set separately.
class Laws {
  /// Uniform downward pull, like standing on a planet. px/s².
  double gravity = 0;

  /// Newton's constant for the pull every body exerts on every other body.
  double attraction = 0;

  /// Coulomb's constant. Like charges repel, unlike attract.
  double electric = 0;

  /// A steady sideways push. px/s², positive is rightwards.
  double wind = 0;

  /// Linear drag, the fraction of velocity lost per second to the medium.
  double drag = 0;

  /// How bouncy collisions are: 1 loses nothing, 0 is putty.
  double restitution = 0.9;

  Walls walls = Walls.bounce;
  Contact contact = Contact.bounce;

  void reset() {
    gravity = attraction = electric = wind = drag = 0;
    restitution = 0.9;
    walls = Walls.bounce;
    contact = Contact.bounce;
  }
}

class Body {
  double x, y, vx, vy;
  double radius;
  double mass;
  double charge;
  bool _dead = false;

  /// Stable identity, so the page can keep each body's colour and trail.
  final int id;

  Body._(this.id, this.x, this.y, this.vx, this.vy, this.radius, this.mass, this.charge);
  Vec2 get position => Vec2(x, y);
  Vec2 get velocity => Vec2(vx, vy);
}

/// A small 2D rigid-circle physics engine.
///
/// Each step is split into substeps. A substep integrates with semi-implicit
/// Euler — velocity first, then position from the new velocity — which keeps
/// orbits closed where plain Euler would spiral them outwards. Then it finds
/// and resolves contacts, then applies the walls.
///
/// Contact detection uses a uniform grid: each body only checks the bodies in
/// its own and neighbouring cells, so a box of gas costs roughly one check per
/// neighbour rather than one per pair. Mutual gravity and electric force are
/// all-pairs by nature, so when either is on, that part is O(n²) — which is
/// why the page caps the body count.
///
/// Circles only: no rotation, no friction between surfaces.
class Universe {
  double width, height;
  final laws = Laws();
  final List<Body> bodies = [];

  double time = 0;

  /// Contacts resolved during the last [step], for the page's readout.
  int contactsLastStep = 0;

  int _nextId = 0;

  Universe(this.width, this.height);

  /// Adds a body. Its [mass] defaults to its area, radius².
  Body add(Vec2 position, {Vec2 velocity = Vec2.zero, double radius = 6, double? mass, double charge = 0}) {
    final body =
        Body._(_nextId++, position.x, position.y, velocity.x, velocity.y, radius, mass ?? radius * radius, charge);
    bodies.add(body);
    return body;
  }

  void clear() {
    bodies.clear();
    time = 0;
  }

  void step(double dt, {int substeps = 4}) {
    contactsLastStep = 0;
    final h = dt / substeps;
    for (var s = 0; s < substeps; s++) {
      _accelerate(h);
      for (final b in bodies) {
        b.x += b.vx * h;
        b.y += b.vy * h;
      }
      _contacts();
      _walls();
      bodies.removeWhere((b) => b._dead);
    }
    time += dt;
  }

  // ---- forces ---------------------------------------------------------------

  void _accelerate(double h) {
    final laws = this.laws;
    final n = bodies.length;
    final damping = math.exp(-laws.drag * h);

    if (_ax.length < n) {
      _ax = Float64List(n * 2);
      _ay = Float64List(n * 2);
    }
    final ax = _ax, ay = _ay;
    for (var i = 0; i < n; i++) {
      ax[i] = laws.wind;
      ay[i] = laws.gravity;
    }

    final g = laws.attraction, k = laws.electric;
    if (g != 0 || k != 0) {
      for (var i = 0; i < n; i++) {
        final a = bodies[i];
        final ma = a.mass;
        for (var j = i + 1; j < n; j++) {
          final b = bodies[j];
          final dx = b.x - a.x, dy = b.y - a.y;
          final soft = _softening(a, b);
          final r2 = dx * dx + dy * dy + soft * soft;
          final inv3 = 1 / (r2 * math.sqrt(r2));
          final mb = b.mass;
          // Gravity pulls together; like charges push apart. One number says
          // how hard, per unit of (mass × mass), along the line between them.
          final pull = (g * ma * mb - k * a.charge * b.charge) * inv3;
          ax[i] += pull * dx / ma;
          ay[i] += pull * dy / ma;
          ax[j] -= pull * dx / mb;
          ay[j] -= pull * dy / mb;
        }
      }
    }

    for (var i = 0; i < n; i++) {
      final b = bodies[i];
      b.vx = (b.vx + ax[i] * h) * damping;
      b.vy = (b.vy + ay[i] * h) * damping;
    }
  }

  Float64List _ax = Float64List(0), _ay = Float64List(0);

  /// Plummer softening: the pull between two bodies stops growing once they
  /// are closer than about their radii, instead of heading to infinity. The
  /// potential in [energy] uses the same length, so the two stay consistent.
  static double _softening(Body a, Body b) => 0.5 * (a.radius + b.radius);

  // ---- contacts -------------------------------------------------------------

  Int32List _head = Int32List(0), _link = Int32List(0);

  void _contacts() {
    final n = bodies.length;
    if (n < 2) return;

    var largest = 1.0;
    for (final b in bodies) {
      if (b.radius > largest) largest = b.radius;
    }
    final cell = largest * 2;
    // In an open universe bodies wander off-screen; the grid covers wherever
    // they are, not just the visible box.
    var minX = 0.0, minY = 0.0, maxX = width, maxY = height;
    for (final b in bodies) {
      if (b.x < minX) minX = b.x;
      if (b.y < minY) minY = b.y;
      if (b.x > maxX) maxX = b.x;
      if (b.y > maxY) maxY = b.y;
    }
    final cols = math.min(((maxX - minX) / cell).floor() + 1, 512);
    final rows = math.min(((maxY - minY) / cell).floor() + 1, 512);
    final cw = (maxX - minX) / cols + 1e-9, ch = (maxY - minY) / rows + 1e-9;

    if (_head.length < cols * rows) _head = Int32List(cols * rows);
    if (_link.length < n) _link = Int32List(n * 2);
    final head = _head, link = _link;
    head.fillRange(0, cols * rows, -1);

    int col(Body b) => ((b.x - minX) / cw).floor().clamp(0, cols - 1);
    int row(Body b) => ((b.y - minY) / ch).floor().clamp(0, rows - 1);

    for (var i = 0; i < n; i++) {
      final c = row(bodies[i]) * cols + col(bodies[i]);
      link[i] = head[c];
      head[c] = i;
    }

    for (var i = 0; i < n; i++) {
      final a = bodies[i];
      if (a._dead) continue;
      final cx = col(a), cy = row(a);
      for (var y = cy - 1; y <= cy + 1; y++) {
        if (y < 0 || y >= rows) continue;
        for (var x = cx - 1; x <= cx + 1; x++) {
          if (x < 0 || x >= cols) continue;
          for (var j = head[y * cols + x]; j != -1; j = link[j]) {
            // Every pair once: the lower index handles it.
            if (j <= i) continue;
            final b = bodies[j];
            if (b._dead || a._dead) continue;
            _touch(a, b);
          }
        }
      }
    }
  }

  void _touch(Body a, Body b) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final reach = a.radius + b.radius;
    final d2 = dx * dx + dy * dy;
    if (d2 >= reach * reach) return;

    contactsLastStep++;
    if (laws.contact == Contact.merge) {
      _merge(a, b);
      return;
    }

    final d = math.sqrt(d2);
    // Two bodies exactly on top of each other have no normal; pick one.
    final nx = d > 1e-9 ? dx / d : 1.0, ny = d > 1e-9 ? dy / d : 0.0;
    final ia = 1 / a.mass, ib = 1 / b.mass;

    // Push them apart so they no longer overlap, the lighter one further.
    final overlap = reach - d;
    final share = overlap / (ia + ib);
    a.x -= nx * share * ia;
    a.y -= ny * share * ia;
    b.x += nx * share * ib;
    b.y += ny * share * ib;

    // Exchange momentum along the line between centres, but only if they are
    // still approaching — separating bodies that overlap are left to part.
    final approach = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
    if (approach >= 0) return;
    final impulse = -(1 + laws.restitution) * approach / (ia + ib);
    a.vx -= impulse * ia * nx;
    a.vy -= impulse * ia * ny;
    b.vx += impulse * ib * nx;
    b.vy += impulse * ib * ny;
  }

  /// The heavier body swallows the lighter. Mass, momentum, charge and the
  /// centre of mass all carry over; so does area, so the radius grows as the
  /// square root of the two areas added.
  void _merge(Body a, Body b) {
    final (keep, gone) = a.mass >= b.mass ? (a, b) : (b, a);
    final m1 = keep.mass, m2 = gone.mass, m = m1 + m2;
    keep.x = (keep.x * m1 + gone.x * m2) / m;
    keep.y = (keep.y * m1 + gone.y * m2) / m;
    keep.vx = (keep.vx * m1 + gone.vx * m2) / m;
    keep.vy = (keep.vy * m1 + gone.vy * m2) / m;
    keep.charge += gone.charge;
    keep.mass = m;
    keep.radius = math.sqrt(keep.radius * keep.radius + gone.radius * gone.radius);
    gone._dead = true;
  }

  // ---- walls ----------------------------------------------------------------

  void _walls() {
    final e = laws.restitution;
    switch (laws.walls) {
      case Walls.bounce:
        for (final b in bodies) {
          final r = b.radius;
          if (b.x < r) {
            b.x = r;
            if (b.vx < 0) b.vx = -b.vx * e;
          } else if (b.x > width - r) {
            b.x = width - r;
            if (b.vx > 0) b.vx = -b.vx * e;
          }
          if (b.y < r) {
            b.y = r;
            if (b.vy < 0) b.vy = -b.vy * e;
          } else if (b.y > height - r) {
            b.y = height - r;
            if (b.vy > 0) b.vy = -b.vy * e;
          }
        }
      case Walls.wrap:
        for (final b in bodies) {
          b.x = (b.x % width + width) % width;
          b.y = (b.y % height + height) % height;
        }
      case Walls.open:
        final margin = math.max(width, height);
        for (final b in bodies) {
          if (b.x < -margin || b.x > width + margin || b.y < -margin || b.y > height + margin) b._dead = true;
        }
    }
  }

  // ---- measurements ---------------------------------------------------------

  /// Total momentum. With no walls, drag, wind or uniform gravity in play,
  /// every law above conserves it, and the page shows it drifting when they
  /// don't.
  Vec2 get momentum {
    var px = 0.0, py = 0.0;
    for (final b in bodies) {
      px += b.mass * b.vx;
      py += b.mass * b.vy;
    }
    return Vec2(px, py);
  }

  double get kineticEnergy {
    var e = 0.0;
    for (final b in bodies) {
      e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy);
    }
    return e;
  }

  /// Kinetic plus every potential the current laws define. Elastic contacts
  /// and conservative forces keep this steady; drag, putty-like contacts and
  /// merging bleed it away.
  double get energy {
    var e = kineticEnergy;
    final g = laws.attraction, k = laws.electric;
    final n = bodies.length;
    for (var i = 0; i < n; i++) {
      final a = bodies[i];
      // Height measured up from the floor, since screen y grows downward.
      e += a.mass * laws.gravity * (height - a.y);
      e -= a.mass * laws.wind * a.x;
      if (g == 0 && k == 0) continue;
      for (var j = i + 1; j < n; j++) {
        final b = bodies[j];
        final dx = b.x - a.x, dy = b.y - a.y, soft = _softening(a, b);
        final r = math.sqrt(dx * dx + dy * dy + soft * soft);
        e += (-g * a.mass * b.mass + k * a.charge * b.charge) / r;
      }
    }
    return e;
  }

  // ---- presets --------------------------------------------------------------

  static const presets = ['orbits', 'accretion', 'billiards', 'gas', 'rain', 'crystal'];

  /// Clears the world and sets up one of [presets], laws included.
  void preset(String name, Rng rng) {
    clear();
    laws.reset();
    final cx = width / 2, cy = height / 2, span = math.min(width, height);

    switch (name) {
      case 'orbits':
        // A sun and planets on circular orbits: v = √(GM/r). The planets are
        // made light — a few ten-thousandths of the sun — because planets as
        // heavy as their size suggests, this close together, throw each
        // other out of the system within seconds. Real planets are spaced
        // many "Hill radii" apart; at this mass, these are too.
        laws
          ..attraction = 4000
          ..walls = Walls.open
          ..contact = Contact.merge;
        final sun = add(Vec2(cx, cy), radius: span * 0.045);
        final gm = laws.attraction * sun.mass;
        for (var i = 0; i < 7; i++) {
          final r = span * (0.12 + i * 0.055);
          final angle = rng.range(0, math.pi * 2);
          final v = math.sqrt(gm / r);
          add(sun.position + Vec2.polar(angle, r),
              velocity: Vec2.polar(angle + math.pi / 2, v), radius: rng.range(1.5, 3.5), mass: 0.05);
        }
        // The sun takes the opposite of the planets' momentum, so the system
        // as a whole stays put instead of drifting off the screen.
        final drift = momentum;
        sun
          ..vx -= drift.x / sun.mass
          ..vy -= drift.y / sun.mass;
      case 'accretion':
        // A slowly turning cloud of dust that gravity gathers into planets.
        laws
          ..attraction = 60
          ..walls = Walls.open
          ..contact = Contact.merge;
        for (var i = 0; i < 350; i++) {
          final r = span * 0.42 * math.sqrt(rng.nextDouble());
          final angle = rng.range(0, math.pi * 2);
          add(Vec2(cx, cy) + Vec2.polar(angle, r),
              velocity: Vec2.polar(angle + math.pi / 2, r * 0.12) + Vec2(rng.gaussian(0, 3), rng.gaussian(0, 3)),
              radius: rng.range(1.5, 3));
        }
      case 'billiards':
        laws
          ..restitution = 0.96
          ..drag = 0.35;
        final ball = span * 0.028;
        var placed = 0;
        for (var rowIndex = 0; rowIndex < 5; rowIndex++) {
          for (var k = 0; k <= rowIndex; k++) {
            add(Vec2(width * 0.68 + rowIndex * ball * 1.75, cy + (k - rowIndex / 2) * ball * 2.02), radius: ball);
            placed++;
          }
        }
        assert(placed == 15);
        add(Vec2(width * 0.2, cy + rng.gaussian(0, 1)), velocity: Vec2(span * 2.4, 0), radius: ball);
      case 'gas':
        // Perfectly elastic, no forces: speeds spread out towards the
        // Maxwell–Boltzmann distribution however they started.
        laws.restitution = 1;
        for (var i = 0; i < 260; i++) {
          add(Vec2(rng.range(10, width - 10), rng.range(10, height - 10)),
              velocity: Vec2.polar(rng.range(0, math.pi * 2), 120), radius: 4);
        }
      case 'rain':
        laws
          ..gravity = 500
          ..restitution = 0.35
          ..drag = 0.05;
        for (var i = 0; i < 220; i++) {
          add(Vec2(rng.range(10, width - 10), rng.range(-height * 1.2, height * 0.3)),
              velocity: Vec2(rng.gaussian(0, 20), 0), radius: rng.range(3, 8));
        }
      case 'crystal':
        // Charged bodies in a thick medium: they repel each other into a
        // lattice while drag soaks up the motion.
        laws
          ..electric = 60000
          ..drag = 1.5
          ..restitution = 0.5;
        for (var i = 0; i < 90; i++) {
          add(Vec2(cx + rng.gaussian(0, span * 0.08), cy + rng.gaussian(0, span * 0.08)), radius: 5, charge: 1);
        }
      default:
        throw ArgumentError.value(name, 'name', 'not one of $presets');
    }
  }
}
