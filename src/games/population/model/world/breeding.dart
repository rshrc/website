part of 'world.dart';

/// Genetic distance beyond which two creatures can't breed.
const incompatibleAt = 1.5;

/// Genetic distance beyond which two creatures of different species can't
/// have young together. Further than within a species, as hybrids are in
/// life: a horse and a donkey, too far apart to count as one species, can
/// still have a mule.
const crossSpeciesLimit = 2.5;

/// Years a creature waits for a mate before breeding alone.
const _patience = 6.0;

/// The fixed part of what a child costs, on top of a share of the parent's
/// energy. It puts a floor on how small a creature can usefully be.
const _birthCost = 9.0;

/// Growing old, dying, finding a mate and having young.
extension _Breeding on World {
  /// Ages [creature], and if it's time, has it die or have a child, who
  /// joins [newborn].
  void _liveAndBreed(Creature creature, double years, List<Creature> newborn) {
    creature.age += years;
    if (creature.energy > creature.energyCapacity) creature.energy = creature.energyCapacity;
    final squareBonus = 1 + 0.15 * laws.shapeShare(creature.genes, Shape.square);
    if (creature.energy <= 0) {
      _kill(creature, Death(_whyStarved(creature)));
      return;
    }
    if (creature.age > creature.lifespan * squareBonus) {
      _kill(creature, const Death(DeathCause.oldAge));
      return;
    }
    final readyToBreed = creature.age >= adulthood && creature.energy >= 0.7 * creature.energyCapacity;
    if (!readyToBreed) return;
    if (creatures.length + newborn.length >= creatureLimit) {
      _birthsLastHeldBack = time;
      return;
    }

    // Looking for a mate means searching everything in sight, so a creature
    // that found nobody waits a year before looking again.
    Creature? mate;
    if (time >= creature.nextMateSearch) {
      mate = _findMate(creature);
      if (mate == null) creature.nextMateSearch = time + 1;
    }
    if (mate == null) {
      creature.yearsWithoutMate += years;
      if (creature.yearsWithoutMate < _patience) return;
    }
    creature.yearsWithoutMate = 0;
    creature.energy = creature.energy * 0.45 - _birthCost;
    if (creature.energy <= 0) {
      _kill(creature, const Death(DeathCause.childbirth));
      return;
    }
    creature.children++;
    mate?.children++;
    if (mate != null && !identical(mate.species, creature.species)) _announceFirstCrossing(creature, mate);
    final inherited = mate == null ? creature.genes : Genes.cross(creature.genes, mate.genes, _rng);
    final genes = inherited.mutate(_rng, laws.mutation, shapesEvolve: laws.bodyShapes);
    newborn.add(Creature(
      id: _nextCreatureId++,
      species: creature.species,
      genes: genes,
      x: terrain.wrapX(creature.x + _rng.gaussian(0, 3)),
      y: terrain.wrapY(creature.y + _rng.gaussian(0, 3)),
      heading: _rng.range(0, math.pi * 2),
      energy: creature.energy,
      lifespan: _randomLifespan(),
      generation: creature.generation + 1,
    ));
  }

  /// What starved [creature]: flood, if it's standing in one; the wrong
  /// climate, if it had at least doubled its upkeep where it stands; the
  /// desert, if it's on desert; otherwise plain hunger.
  DeathCause _whyStarved(Creature creature) {
    final patch = terrain.patchAt(creature.x, creature.y);
    final mismatch = terrain.climate[patch] + climateNow - creature.genes.idealClimate;
    final climateStrain =
        _climateCost * mismatch * mismatch * (1 - 0.6 * laws.shapeShare(creature.genes, Shape.round));
    if (terrain.isFlooded(patch)) return DeathCause.flood;
    if (climateStrain >= 1) return mismatch > 0 ? DeathCause.heat : DeathCause.cold;
    if (terrain.isHarsh(patch)) return DeathCause.desert;
    return DeathCause.hunger;
  }

  /// The nearest adult in sight it can breed with. Genes decide: two of one
  /// species can have young if closer than [incompatibleAt]; two of
  /// different species, hybrids, if closer than the looser
  /// [crossSpeciesLimit]. Creatures prefer their own kind, and take another
  /// species only when none of their own is in sight.
  ///
  /// Peoples meet only in war: a creature can reach another civilization's
  /// creatures only while the two are mingling, through a war and a century
  /// after. Within its own lineage, it can reach any species at all.
  Creature? _findMate(Creature creature) {
    final civilization = creature.species.civilization;
    final mingling = diplomacy.inContactWith(civilization);
    final reach = creature.genes.sight * creature.genes.sight;
    Creature? ownKind, otherKind;
    var ownKindSquared = reach, otherKindSquared = reach;
    final cells = _neighbours.findCellsNear(creature.x, creature.y, creature.genes.sight);
    for (var k = 0; k < cells; k++) {
      for (var i = _neighbours.firstInCell(k); i != -1; i = _neighbours.nextInCell(i)) {
        final other = creatures[i];
        if (identical(other, creature) || other.isDead || other.age < adulthood) continue;
        final squared = terrain.distanceSquared(other.x, other.y, creature.x, creature.y);
        if (identical(other.species, creature.species)) {
          if (squared < ownKindSquared && creature.genes.distanceTo(other.genes) < incompatibleAt) {
            ownKindSquared = squared;
            ownKind = other;
          }
          continue;
        }
        // Another species: worth a look only while none of its own kind is
        // in sight, and only if it can be reached at all.
        if (ownKind != null || squared >= otherKindSquared) continue;
        final theirs = other.species.civilization;
        if (theirs != civilization && !(mingling != null && mingling.contains(theirs))) continue;
        if (creature.genes.distanceTo(other.genes) < crossSpeciesLimit) {
          otherKindSquared = squared;
          otherKind = other;
        }
      }
    }
    return ownKind ?? otherKind;
  }

  /// The first child of any two species is news: across peoples, of war's
  /// mingling; within one lineage, of sister species meeting again.
  void _announceFirstCrossing(Creature a, Creature b) {
    if (!_crossingsAnnounced.add((math.min(a.species.id, b.species.id), math.max(a.species.id, b.species.id)))) {
      return;
    }
    final bodies = laws.bodyShapes && a.genes.firstShape != b.genes.firstShape
        ? ', part ${a.genes.firstShape.label} and part ${b.genes.firstShape.label}'
        : '';
    _tell(EventKind.firstHybrid, 'The first children of ${a.species.aName} and ${b.species.aName} are born$bodies.',
        civilization: a.species.civilization);
  }
}
