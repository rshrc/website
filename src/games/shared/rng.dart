import 'dart:math' as math;

/// A small deterministic pseudo-random generator, shared by all three games.
///
/// `dart:math`'s [Random] makes no promise about producing the same stream
/// twice, and these worlds are meant to be reproducible: every page shows the
/// seed it started from, so typing the same number back in gives the same
/// universe. Xorshift32 is a handful of instructions, has a long enough period
/// for a simulation that lives in a browser tab, and — unlike most generators
/// — is trivial to reason about when a run misbehaves.
class Rng {
  int _state;

  /// Seeds the generator. Zero is the one state xorshift cannot escape, so it
  /// is quietly swapped for the golden-ratio constant.
  Rng(int seed) : _state = (seed & 0xffffffff) == 0 ? 0x9e3779b9 : seed & 0xffffffff;

  /// The seed a caller can show, store, or hand back to [Rng.new].
  static int seedFromString(String text) {
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  int _next() {
    var x = _state;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    return _state = x & 0xffffffff;
  }

  /// A double in [0, 1).
  double nextDouble() => _next() / 4294967296.0;

  /// An integer in [0, [max]).
  int nextInt(int max) => (nextDouble() * max).floor();

  /// A double in [[low], [high]).
  double range(double low, double high) => low + nextDouble() * (high - low);

  bool chance(double probability) => nextDouble() < probability;

  /// One draw from a normal distribution, Box–Muller with the second draw kept
  /// for the next call. Mutation and scatter both want a bell, not a box.
  double gaussian([double mean = 0, double deviation = 1]) {
    if (_spare != null) {
      final value = _spare!;
      _spare = null;
      return mean + value * deviation;
    }
    double u, v, s;
    do {
      u = nextDouble() * 2 - 1;
      v = nextDouble() * 2 - 1;
      s = u * u + v * v;
    } while (s >= 1 || s == 0);
    final scale = math.sqrt(-2 * math.log(s) / s);
    _spare = v * scale;
    return mean + u * scale * deviation;
  }

  double? _spare;

  T pick<T>(List<T> items) => items[nextInt(items.length)];
}
