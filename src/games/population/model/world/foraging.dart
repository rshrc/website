part of 'world.dart';

/// Upkeep multiplier per unit of squared climate mismatch.
const _climateCost = 8.0;

/// The eight directions a creature looks in, as unit vectors.
final _lookCos = List<double>.generate(8, (k) => math.cos(k * math.pi / 4));
final _lookSin = List<double>.generate(8, (k) => math.sin(k * math.pi / 4));

/// Finding food, moving, and paying for both.
extension _Foraging on World {
  /// One step of a creature's day: charging at an enemy, eating where it
  /// stands, or heading for greener land; then moving, and paying the
  /// energy it costs to live.
  void _forage(Creature creature, double years) {
    final genes = creature.genes;
    final patch = terrain.patchAt(creature.x, creature.y);
    // How hard it's moving, 0 to 1, which sets what moving costs.
    double effort;
    if (creature.raidingFor > 0) {
      // On the warpath: straight for the enemy, flat out.
      creature.raidingFor -= years;
      _faceTarget(creature);
      effort = 1;
    } else if (terrain.food[patch] > 0.2) {
      final eatingRate = 0.9 * math.pow(genes.size * genes.size, 0.75) * (1 + 0.15 * laws.shapeShare(genes, Shape.crescent));
      final bite = math.min(terrain.food[patch], eatingRate * years);
      terrain.food[patch] -= bite;
      creature.energy += bite * 20;
      creature.heading += _rng.gaussian(0, 0.6);
      // Eating only takes as long as the food lasts. With small steps that
      // never matters; with the big steps used at top speed, a creature that
      // clears its patch early spends the rest of the step on the move, and
      // pays for it, as it would have with small steps.
      final shareOfStepEating = bite / (eatingRate * years);
      effort = 0.1 * shareOfStepEating + 0.8 * (1 - shareOfStepEating);
    } else {
      creature.lookAroundIn -= years;
      if (creature.lookAroundIn <= 0) {
        _headForGreenestPatch(creature);
        // Every half year or so, and never more than every other step.
        creature.lookAroundIn = math.max(0.4 + _rng.nextDouble() * 0.3, 2 * years);
      }
      _faceTarget(creature);
      effort = 0.8;
    }

    final speed = genes.speed * effort * (1 - 0.15 * laws.shapeShare(genes, Shape.crescent));
    creature.x = terrain.wrapX(creature.x + math.cos(creature.heading) * speed * years);
    creature.y = terrain.wrapY(creature.y + math.sin(creature.heading) * speed * years);

    // Desert, and flood, are harsh: crossing them burns energy faster. It's what keeps
    // populations in their own valleys, and so what lets rival
    // civilizations last side by side and species drift apart.
    final desert = terrain.isHarsh(patch) ? laws.desertCost : 1.0;
    // The wrong climate costs energy: a creature built for the cold pays
    // several times its usual upkeep in the heat. It's what gives each
    // civilization a home it's hard to take from it.
    final mismatch = terrain.climate[patch] + climateNow - genes.idealClimate;
    final climate = 1 + _climateCost * mismatch * mismatch * (1 - 0.6 * laws.shapeShare(genes, Shape.round));
    creature.energy -= _upkeep(genes, effort) * desert * climate * years;
  }

  void _faceTarget(Creature creature) => creature.heading = math.atan2(
      Terrain.wrapDelta(creature.targetY - creature.y, height), Terrain.wrapDelta(creature.targetX - creature.x, width));

  /// Looks in eight directions, near and far alternately, and sets off for
  /// the greenest patch in sight, preferring nearer ones. The fan is turned
  /// by the creature's heading plus a little random wobble, so the
  /// directions never line up the same way twice.
  void _headForGreenestPatch(Creature creature) {
    final turn = creature.heading + (_rng.nextDouble() - 0.5) * 0.4;
    final turnCos = math.cos(turn), turnSin = math.sin(turn);
    final near = creature.genes.sight * 0.45, far = creature.genes.sight;
    var bestScore = -1.0;
    for (var k = 0; k < 8; k++) {
      final distance = k.isEven ? near : far;
      final dx = turnCos * _lookCos[k] - turnSin * _lookSin[k], dy = turnSin * _lookCos[k] + turnCos * _lookSin[k];
      final x = creature.x + dx * distance, y = creature.y + dy * distance;
      final score = terrain.food[terrain.patchAt(x, y)] / (1 + distance / 400);
      if (score > bestScore) {
        bestScore = score;
        creature.targetX = x;
        creature.targetY = y;
      }
    }
  }

  /// Energy spent a year: a body following Kleiber's law (mass to the ¾),
  /// muscle costing the square of the speed it's built for, eyes costing a
  /// little per pixel of sight, and a temper that costs to keep.
  double _upkeep(Genes genes, double effort) =>
      1.4 * math.pow(genes.size * genes.size, 0.75) * (1 + 0.06 * laws.shapeShare(genes, Shape.spiky)) +
      0.0012 * genes.speed * genes.speed * (0.25 + 0.75 * effort) * laws.movementCost(genes) +
      0.012 * genes.sight +
      1.5 * genes.aggression;
}
