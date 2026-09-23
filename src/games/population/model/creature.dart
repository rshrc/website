import 'dart:math' as math;

import 'death.dart';
import 'genes.dart';
import 'species.dart';

/// The age, in years, at which a creature is full grown and can breed.
const adulthood = 8.0;

class Creature {
  /// Unique for the whole run, so the page can follow one creature.
  final int id;
  Species species;
  final Genes genes;
  final int generation;

  /// The age, in years, at which it dies of old age.
  final double lifespan;

  double x, y;

  /// The direction it's moving, in radians.
  double heading;
  double energy;
  double age = 0;
  int children = 0;
  bool isDead = false;

  /// How it died, once it has.
  Death? death;

  void die(Death death) {
    isDead = true;
    this.death = death;
  }

  // ---- what it's up to --------------------------------------------------------

  /// Where it's heading: the greenest patch it last saw, or an enemy.
  double targetX = 0, targetY = 0;

  /// Years until it next looks around for food.
  double lookAroundIn = 0;

  /// Years left chasing an enemy rather than grazing.
  double raidingFor = 0;

  /// Years it has been ready to breed without finding a mate.
  double yearsWithoutMate = 0;

  /// The year it can next search for a mate, after a search found nobody.
  double nextMateSearch = 0;

  Creature({
    required this.id,
    required this.species,
    required this.genes,
    required this.x,
    required this.y,
    required this.heading,
    required this.energy,
    required this.lifespan,
    required this.generation,
  });

  /// The most energy it can store.
  double get energyCapacity => 100 * genes.size * genes.size;

  /// How grown it is, from a hatchling's 0.45 to 1 at [adulthood].
  double get growth => math.min(1, 0.45 + 0.55 * age / adulthood);

  /// Body radius in world pixels.
  double get radius => (2 + 2 * genes.size) * growth;
}
