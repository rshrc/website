part of 'world.dart';

/// Fights between creatures, and the wars they add up to.
extension _Fighting on World {
  /// Now and then a creature is in the mood for a fight — the more
  /// aggressive, the more often — and picks one with the first creature of
  /// another civilization it's touching, or else goes looking for one.
  /// Only looking when in the mood keeps this cheap: most creatures, most of
  /// the time, aren't.
  void _maybeFight(Creature creature, double years) {
    final enemies = diplomacy.enemiesOf(creature.species.civilization);
    // Everyone has some fight in them; aggression adds more, and a war
    // multiplies it several times over.
    final mood = (0.1 + creature.genes.aggression) * laws.hostility * (enemies == null ? 1 : 6);
    if (!_rng.chance(math.min(1, mood * years * 3))) return;
    if (!_attackSomeoneTouching(creature)) _huntForEnemy(creature, enemies);
  }

  /// Fights the first creature of another civilization [attacker] is
  /// touching. Returns whether there was anyone to fight.
  bool _attackSomeoneTouching(Creature attacker) {
    final reach = attacker.radius + 6;
    final cells = _neighbours.findCellsNear(attacker.x, attacker.y, reach);
    for (var k = 0; k < cells; k++) {
      for (var i = _neighbours.firstInCell(k); i != -1; i = _neighbours.nextInCell(i)) {
        final other = creatures[i];
        if (other.isDead || other.species.civilization == attacker.species.civilization) continue;
        final touching = reach + other.radius;
        if (terrain.distanceSquared(other.x, other.y, attacker.x, attacker.y) > touching * touching) continue;
        _fight(attacker, other);
        return true;
      }
    }
    return false;
  }

  /// The stronger usually wins. Most fights end with the loser fleeing hurt,
  /// half its energy gone to the winner; about one in four is to the death
  /// — one in twelve for a spiky loser, whose spines also cost the winner.
  void _fight(Creature attacker, Creature defender) {
    final attackerStrength = _strength(attacker.genes), defenderStrength = _strength(defender.genes);
    final (winner, loser) = _rng.chance(attackerStrength / (attackerStrength + defenderStrength))
        ? (attacker, defender)
        : (defender, attacker);
    final taken = 0.5 * math.max(loser.energy, 0);
    loser.energy -= taken;
    winner.energy += taken;
    final spikes = laws.shapeShare(loser.genes, Shape.spiky);
    winner.energy -= spikes * (0.25 * taken + 5);
    loser.heading = math.atan2(loser.y - winner.y, loser.x - winner.x);
    if (_rng.chance(0.25 - 0.17 * spikes) || loser.energy <= 0) {
      _kill(loser, Death(DeathCause.fight, winner.species.civilization));
      diplomacy.recordKill(attacker.species.civilization, defender.species.civilization);
    }
  }

  /// How strong a creature is in a fight: bigger and fiercer is stronger;
  /// square bodies hit hardest, pointed ones worst.
  double _strength(Genes genes) =>
      genes.size *
      (0.4 + genes.aggression) *
      (1 + 0.5 * laws.shapeShare(genes, Shape.square) - 0.2 * laws.shapeShare(genes, Shape.pointed));

  /// Sets off after the nearest enemy in sight: a declared enemy if there's
  /// a war on, otherwise, for the truly fierce, anyone of another
  /// civilization.
  void _huntForEnemy(Creature hunter, Set<int>? enemies) {
    if (enemies == null && hunter.genes.aggression < 0.4) return;
    Creature? prey;
    var nearestSquared = hunter.genes.sight * hunter.genes.sight;
    final cells = _neighbours.findCellsNear(hunter.x, hunter.y, hunter.genes.sight);
    for (var k = 0; k < cells; k++) {
      for (var i = _neighbours.firstInCell(k); i != -1; i = _neighbours.nextInCell(i)) {
        final other = creatures[i];
        final theirs = other.species.civilization;
        if (other.isDead || theirs == hunter.species.civilization || (enemies != null && !enemies.contains(theirs))) {
          continue;
        }
        final squared = terrain.distanceSquared(other.x, other.y, hunter.x, hunter.y);
        if (squared < nearestSquared) {
          nearestSquared = squared;
          prey = other;
        }
      }
    }
    if (prey == null) return;
    hunter
      ..targetX = prey.x
      ..targetY = prey.y
      ..lookAroundIn = 1.5
      ..raidingFor = 1.5;
  }

  /// Every twenty years: a pair of civilizations killing each other at a
  /// high rate, and not in a truce, goes to war. Every war runs its course —
  /// thirty to a hundred years — and ends in a peace and a truce, however
  /// much fighting is still going on.
  void _reviewWars() {
    for (final MapEntry(key: pair, value: kills) in diplomacy.killsSinceReview.entries) {
      final war = diplomacy.wars[pair];
      if (war != null) {
        war.dead += kills;
      } else if (kills >= 40 && !diplomacy.inTruce(pair, time)) {
        diplomacy.startWar(pair, War(began: time - 20, dead: kills, earliestEnd: time + _rng.range(30, 100)));
        _announceWar(pair);
      }
    }
    for (final MapEntry(key: pair, value: war) in diplomacy.wars.entries.toList()) {
      final bothAlive = creatures.any((c) => c.species.civilization == pair.$1) &&
          creatures.any((c) => c.species.civilization == pair.$2);
      if (bothAlive && time < war.earliestEnd && laws.hostility != 0) continue;
      diplomacy.makePeace(pair, time);
      if (bothAlive) {
        _tell(
            EventKind.peace,
            'The ${_civilizationName(pair.$1)} and the ${_civilizationName(pair.$2)} make peace after '
            '${withCommas((time - war.began).round())} years of war; ${withCommas(war.dead)} dead.',
            civilization: pair.$1);
      }
    }
    diplomacy.refresh(time);
    diplomacy.killsSinceReview.clear();
  }

  void _announceWar(CivilizationPair pair) => _tell(EventKind.war,
      'War breaks out between the ${_civilizationName(pair.$1)} and the ${_civilizationName(pair.$2)}.',
      civilization: pair.$1);
}
