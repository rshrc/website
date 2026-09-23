import 'creature.dart';
import 'thinning.dart';

/// What the chart can show for each civilization over time.
enum Measure { population, speed, size, sight, aggression, climate }

/// For each [Measure], each civilization's value over the whole run: its
/// headcount, or the average of one of its genes.
///
/// Sampled every [sampleEvery] years. When the samples fill up, every other
/// one is dropped and the interval doubles, so the history always covers
/// year 0 to now.
class TraitHistory {
  static const maxSamples = 600;

  final int civilizations;
  final Map<Measure, List<List<double>>> samples;

  /// The world's climate shift at each sample; see [World.climateShift].
  final List<double> climateShifts = [];
  double sampleEvery = 0.5;

  TraitHistory(this.civilizations)
      : samples = {
          for (final measure in Measure.values) measure: List.generate(civilizations, (_) => <double>[]),
        };

  /// The samples for [measure], one list per civilization.
  List<List<double>> of(Measure measure) => samples[measure]!;

  int get length => samples[Measure.population]!.first.length;

  void clear() {
    sampleEvery = 0.5;
    climateShifts.clear();
    for (final perCivilization in samples.values) {
      for (final list in perCivilization) {
        list.clear();
      }
    }
  }

  /// Adds a sample of every measure for every civilization.
  void record(List<Creature> creatures, {required double climateShift}) {
    climateShifts.add(climateShift);
    for (final measure in Measure.values) {
      final totals = List.filled(civilizations, 0.0), counts = List.filled(civilizations, 0);
      for (final creature in creatures) {
        final civilization = creature.species.civilization;
        counts[civilization]++;
        totals[civilization] += _valueOf(measure, creature);
      }
      for (var civilization = 0; civilization < civilizations; civilization++) {
        // A dead civilization's traits have no value; NaN leaves a gap.
        final value = measure == Measure.population
            ? totals[civilization]
            : (counts[civilization] == 0 ? double.nan : totals[civilization] / counts[civilization]);
        samples[measure]![civilization].add(value);
      }
    }
    if (length >= maxSamples) {
      for (final perCivilization in samples.values) {
        perCivilization.forEach(keepEveryOther);
      }
      keepEveryOther(climateShifts);
      sampleEvery *= 2;
    }
  }

  static double _valueOf(Measure measure, Creature creature) => switch (measure) {
        Measure.population => 1,
        Measure.speed => creature.genes.speed,
        Measure.size => creature.genes.size,
        Measure.sight => creature.genes.sight,
        Measure.aggression => creature.genes.aggression,
        Measure.climate => creature.genes.idealClimate,
      };
}
