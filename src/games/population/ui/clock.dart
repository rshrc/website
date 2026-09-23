import '../model/model.dart';

/// Runs the world at the pace the reader asks for, as far as the machine
/// allows, and measures the pace it actually managed.
class Clock {
  /// The speeds on offer, in years a second.
  static const speeds = [1, 2, 4, 8, 16, 32, 64, 100, 250, 500, 1000];

  bool isRunning = true;

  /// Years a second asked for.
  double yearsPerSecond = 4;

  /// Years a second actually achieved, smoothed.
  double achievedYearsPerSecond = 0;

  final rates = BirthAndDeathRates();

  double _ticksOwed = 0;

  /// Whether it's going so fast that creatures should be drawn plain.
  bool get isBlurring => isRunning && yearsPerSecond >= 250;

  /// Advances [world] by [seconds] of real time.
  void advance(World world, double seconds) {
    if (!isRunning) return;
    _ticksOwed += seconds * yearsPerSecond / World.tick;
    final budget = Stopwatch()..start();
    final yearBefore = world.time;
    // A frame's worth of work, a little more at the top speeds. On a busy
    // world the simulation runs slower than asked rather than freezing the
    // page, and the readout shows the real rate.
    final millisecondsAllowed = yearsPerSecond >= 250 ? 22 : (yearsPerSecond >= 64 ? 13 : 9);
    // Above ×100, bigger steps, up to eight ticks at a time: beyond that the
    // foraging race loses so much resolution that the world starts to evolve
    // differently, and a faster wrong answer isn't worth having.
    final ticksPerStep = (yearsPerSecond / 100).ceil().clamp(1, 8);
    while (_ticksOwed >= ticksPerStep && budget.elapsedMilliseconds < millisecondsAllowed) {
      world.step(ticks: ticksPerStep);
      _ticksOwed -= ticksPerStep;
    }
    // Too far behind to catch up: let it go.
    if (_ticksOwed > 4 * ticksPerStep) _ticksOwed = 0;
    if (seconds > 0) {
      achievedYearsPerSecond = achievedYearsPerSecond * 0.9 + (world.time - yearBefore) / seconds * 0.1;
    }
    rates.update(world);
  }
}

/// Births and deaths a year, averaged over the last few years, and what
/// the deaths were of.
class BirthAndDeathRates {
  final _samples = <({double year, int born, int died, Map<DeathCause, int> byCause})>[];
  int bornPerYear = 0, diedPerYear = 0;

  /// Deaths a year from each cause, commonest first, leaving out causes
  /// that round to none.
  List<(DeathCause, int)> diedPerYearOf = const [];

  void clear() => _samples.clear();

  void update(World world) {
    _samples.add((year: world.time, born: world.born, died: world.died, byCause: {...world.deathsByCause}));
    while (_samples.length > 2 && world.time - _samples.first.year > 5) {
      _samples.removeAt(0);
    }
    final oldest = _samples.first;
    final span = world.time - oldest.year;
    if (span <= 0.5) return;
    bornPerYear = ((world.born - oldest.born) / span).round();
    diedPerYear = ((world.died - oldest.died) / span).round();
    diedPerYearOf = [
      for (final MapEntry(key: cause, value: total) in world.deathsByCause.entries)
        (cause, ((total - (oldest.byCause[cause] ?? 0)) / span).round()),
    ].where((entry) => entry.$2 > 0).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }
}
