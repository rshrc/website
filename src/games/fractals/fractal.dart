import 'dart:math' as math;

/// The fractals on offer. All three are escape-time fractals: iterate a
/// simple formula on a complex number and count how long it takes to fly off
/// to infinity. Points that never do are in the set.
enum Kind {
  /// z → z² + c, starting from z = 0, with c the point on screen.
  mandelbrot,

  /// z → z² + c again, but c is fixed and z starts at the point on screen.
  /// Every point of the Mandelbrot set has its own Julia set.
  julia,

  /// z → (|Re z| + i|Im z|)² + c. Folding z into one quadrant each step turns
  /// the Mandelbrot's curves into masts and rigging.
  burningShip,
}

/// What the screen is looking at: which fractal, where, and how close.
class View {
  final Kind kind;

  /// The complex number at the centre of the screen.
  final double cx, cy;

  /// How wide the screen is, in complex units.
  final double span;

  /// The fixed c of a Julia set. Ignored for the others.
  final double jr, ji;

  const View(this.kind, this.cx, this.cy, this.span, {this.jr = 0, this.ji = 0});

  /// Doubles have 52 bits of precision; zoomed further than this, the
  /// neighbouring pixels are the same number and the picture turns to blocks.
  static const deepest = 1e-13;

  /// How much closer than the starting view this is.
  double get zoom => 3.5 / span;

  /// The complex number under screen point ([px], [py]) on a screen [w] by
  /// [h]. Screen y grows downward; imaginary numbers grow upward.
  (double, double) at(double px, double py, double w, double h) =>
      (cx + (px / w - 0.5) * span, cy - (py - h / 2) / w * span);

  /// Zooms by [factor] (above 1 is closer), keeping the point under the
  /// pointer where it is — the way maps zoom.
  View zoomAt(double px, double py, double w, double h, double factor) {
    final (x, y) = at(px, py, w, h);
    final next = math.max(span / factor, deepest);
    final kept = next / span;
    return View(kind, x + (cx - x) * kept, y + (cy - y) * kept, next, jr: jr, ji: ji);
  }

  View panBy(double dx, double dy, double w) => View(kind, cx - dx / w * span, cy + dy / w * span, span, jr: jr, ji: ji);

  /// Iterations needed to tell in from out at this depth: the closer you
  /// look, the longer points near the edge take to decide. [detail] scales it.
  int iterations(double detail) =>
      ((120 + 60 * math.log(math.max(1, zoom)) / math.ln2) * detail).round().clamp(40, 6000);
}

/// How quickly the point (x, y) escapes, as a smooth number rather than a
/// whole count, so the shading has no bands. Returns -1 for points still
/// bounded after [limit] iterations: the set itself.
double escape(Kind kind, double x, double y, int limit, {double jr = 0, double ji = 0}) {
  double zr, zi, cr, ci;
  switch (kind) {
    case Kind.mandelbrot:
      // Most of the set's area is the main cardioid and the circle to its
      // left. Points inside either never escape, and a formula says so at
      // once instead of running every iteration.
      final q = (x - 0.25) * (x - 0.25) + y * y;
      if (q * (q + (x - 0.25)) <= 0.25 * y * y) return -1;
      if ((x + 1) * (x + 1) + y * y <= 0.0625) return -1;
      zr = 0;
      zi = 0;
      cr = x;
      ci = y;
    case Kind.julia:
      zr = x;
      zi = y;
      cr = jr;
      ci = ji;
    case Kind.burningShip:
      zr = 0;
      zi = 0;
      cr = x;
      // Flipped so the ship sails upright.
      ci = -y;
  }

  const bailout = 256.0; // a big radius makes the smoothing more exact
  var n = 0;
  var r2 = zr * zr, i2 = zi * zi;
  while (r2 + i2 <= bailout && n < limit) {
    if (kind == Kind.burningShip) {
      zi = 2 * zr.abs() * zi.abs() + ci;
    } else {
      zi = 2 * zr * zi + ci;
    }
    zr = r2 - i2 + cr;
    r2 = zr * zr;
    i2 = zi * zi;
    n++;
  }
  if (n >= limit) return -1;
  // The standard smoothing: how far past the bailout it landed says how far
  // between two whole iteration counts the point "really" escaped.
  final logModulus = math.log(r2 + i2) / 2;
  return n + 1 - math.log(logModulus / math.ln2) / math.ln2;
}

/// Somewhere worth looking.
class Place {
  final String name;
  final View view;
  const Place(this.name, this.view);

  static const all = [
    Place('the whole Mandelbrot set', View(Kind.mandelbrot, -0.6, 0, 3.5)),
    Place('seahorse valley', View(Kind.mandelbrot, -0.7453, 0.1127, 0.012)),
    Place('elephant valley', View(Kind.mandelbrot, 0.2821, 0.0103, 0.03)),
    Place("a seahorse's tail", View(Kind.mandelbrot, -0.7453, 0.1127, 0.0016)),
    Place('a baby Mandelbrot', View(Kind.mandelbrot, -1.7549, 0, 0.05)),
    Place('Julia: a dendrite', View(Kind.julia, 0, 0, 3.4, jr: 0, ji: 1)),
    Place("Julia: Douady's rabbit", View(Kind.julia, 0, 0, 3.4, jr: -0.1226, ji: 0.7449)),
    Place('Julia: a spiral galaxy', View(Kind.julia, 0, 0, 3.4, jr: -0.8, ji: 0.156)),
    Place('the Burning Ship', View(Kind.burningShip, -0.4, 0.62, 4.2)),
    Place("the Burning Ship's mast", View(Kind.burningShip, -1.762, 0.028, 0.09)),
  ];
}
