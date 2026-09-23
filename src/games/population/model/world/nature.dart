part of 'world.dart';

/// Meteors, plagues, droughts, ages of plenty, wars, and the weather you can
/// paint onto the land: things the page can make happen whenever it likes,
/// and (most of them) that nature makes happen now and then by itself, if
/// the [Laws.naturalEvents] allow.
extension ActsOfNature on World {
  /// Everything within [radius] of ([x], [y]) dies, the ground is stripped
  /// bare and scarred for a century, and a big enough meteor throws dust
  /// into the sky that cools the whole land and stunts plants everywhere.
  /// The strike is remembered in [meteorStrikes]. Returns how many died.
  int meteor(double x, double y, {double radius = 80}) {
    final aliveBefore = creatures.length;
    final killedPerSpecies = <Species, int>{};
    final countBefore = {for (final species in livingSpecies) species: species.count};
    var killed = 0;
    for (final creature in creatures) {
      if (terrain.distanceSquared(creature.x, creature.y, x, y) < radius * radius && !creature.isDead) {
        _kill(creature, const Death(DeathCause.meteor));
        killed++;
        killedPerSpecies[creature.species] = (killedPerSpecies[creature.species] ?? 0) + 1;
      }
    }
    creatures.removeWhere((c) => c.isDead);
    died += killed;
    terrain.strip(x, y, radius);

    // Dust from any meteor over 100 across, up to a sky-full at 300.
    final dustRaised = ((radius - 100) / 200).clamp(0.0, 1.0);
    dust = math.min(1, dust + dustRaised);

    final tolls = [
      for (final MapEntry(key: species, value: count) in killedPerSpecies.entries)
        (species: species, killed: count, share: count / math.max(countBefore[species] ?? count, 1)),
    ]..sort((a, b) => b.share.compareTo(a.share));
    final strike = MeteorStrike(
      year: time,
      x: x,
      y: y,
      radius: radius,
      where: terrain.compassPoint(x, y),
      killed: killed,
      shareOfAllLife: aliveBefore == 0 ? 0 : killed / aliveBefore,
      tolls: tolls,
      dust: dustRaised,
    );
    meteorStrikes.add(strike);

    // Told before the census, so the chronicle has the strike before the
    // extinctions it caused.
    final worstHit = [
      for (final toll in tolls.take(3))
        '${(toll.share * 100).round()}% of ${toll.species.name}${toll.share >= 1 ? ', wiped out' : ''}',
    ];
    final toll = killed == 0
        ? 'Nothing lived there.'
        : '$killed killed, ${(strike.shareOfAllLife * 100).toStringAsFixed(strike.shareOfAllLife < 0.1 ? 1 : 0)}% '
            'of all life: ${inWords(worstHit)}.';
    final sky = dustRaised == 0 ? '' : ' Its dust darkens the sky: the whole land cools, and plants wither everywhere.';
    _tell(EventKind.meteor,
        'A ${strike.size} strikes the ${strike.where}, '
        '${strike.devastation}. $toll$sky',
        x: x, y: y, radius: radius);
    _takeCensus();
    return killed;
  }

  /// Rain on the land within [radius] of ([x], [y]): [amount] more
  /// moisture at the middle, less toward the edge. A little makes the land
  /// richer; too much, and it floods.
  void rainOn(double x, double y, {required double radius, required double amount}) {
    terrain.soak(x, y, radius, amount);
    if (terrain.isFlooded(terrain.patchAt(x, y))) {
      _tellOfLand(EventKind.flood, x, y, (where) => 'Floods spread across $where.');
    }
  }

  /// Dries the land within [radius] of ([x], [y]), the way [rainOn] wets
  /// it. Dry enough, and it's dust.
  void dryOut(double x, double y, {required double radius, required double amount}) {
    terrain.soak(x, y, radius, -amount);
    if (terrain.moisture[terrain.patchAt(x, y)] < 0.15) {
      _tellOfLand(EventKind.dustBowl, x, y, (where) => '${where[0].toUpperCase()}${where.substring(1)} dries to dust.');
    }
  }

  /// Tells of a change to the land around ([x], [y]), unless the same was
  /// told of the same place in the last twenty years.
  void _tellOfLand(EventKind kind, double x, double y, String Function(String where) text) {
    final compass = terrain.compassPoint(x, y);
    final where = compass == 'heartland' ? 'the heartland' : 'the $compass';
    final key = '${kind.name} $where';
    if (time - (_lastToldOfLand[key] ?? double.negativeInfinity) < 20) return;
    _lastToldOfLand[key] = time;
    _tell(kind, text(where), x: x, y: y);
  }

  /// Disease spreads best in crowds: it strikes the most numerous species
  /// and kills about half of it.
  void plague() {
    final candidates = livingSpecies.where((s) => s.count > 0).toList();
    if (candidates.isEmpty) return;
    final victim = candidates.reduce((a, b) => a.count >= b.count ? a : b);
    var killed = 0;
    for (final creature in creatures) {
      final resistance = 0.25 * laws.shapeShare(creature.genes, Shape.spiky);
      if (identical(creature.species, victim) && _rng.chance(0.5 - resistance)) {
        _kill(creature, const Death(DeathCause.plague));
        killed++;
      }
    }
    creatures.removeWhere((c) => c.isDead);
    died += killed;
    _takeCensus();
    _tell(EventKind.plague, 'A plague sweeps through ${victim.name}. $killed die.', civilization: victim.civilization);
  }

  /// Plants grow at a quarter of their usual rate for [years].
  void drought({double years = 40}) {
    weather = 0.25;
    _weatherChangesBackAt = time + years;
    _tell(EventKind.drought, 'A drought begins.');
  }

  /// Plants grow at more than twice their usual rate for [years].
  void plenty({double years = 30}) {
    weather = 2.2;
    _weatherChangesBackAt = time + years;
    _tell(EventKind.plenty, 'An age of plenty begins.');
  }

  /// Starts the climate warming by [by] (0.25 is ten degrees), a little each
  /// year until it has. Warming on top of warming adds up, to at most
  /// [maxClimateShift].
  void warming({double by = 0.2}) => _changeClimate(by);

  /// Starts the climate cooling by [by], the way [warming] warms it.
  void cooling({double by = 0.2}) => _changeClimate(-by);

  void _changeClimate(double by) {
    climateShiftTarget = (climateShiftTarget + by).clamp(-World.maxClimateShift, World.maxClimateShift);
    final warmer = climateShiftTarget > climateShift;
    final heading = (climateShiftTarget * Terrain.degreesPerUnit).round() == 0
        ? 'back to where it was at the start'
        : 'until it is ${degreesFromStart(climateShiftTarget)}';
    _tell(warmer ? EventKind.warming : EventKind.cooling,
        'The climate begins to ${warmer ? 'warm' : 'cool'}, $heading.');
  }

  /// Sets the two largest civilizations not already at war against each
  /// other for [years]: their creatures turn fierce toward one another and
  /// go looking for a fight. Returns false, and starts nothing, if fighting
  /// is off or there's no pair to fight.
  bool war({double years = 60}) {
    if (laws.hostility == 0) return false;
    final largestFirst = {for (final creature in creatures) creature.species.civilization}.toList()
      ..sort((a, b) => headcountOf(b).compareTo(headcountOf(a)));
    final atPeace = [
      for (var i = 0; i < largestFirst.length; i++)
        for (var j = i + 1; j < largestFirst.length; j++)
          if (!diplomacy.atWar(largestFirst[i], largestFirst[j])) pairOf(largestFirst[i], largestFirst[j]),
    ];
    if (atPeace.isEmpty) return false;
    final pair = atPeace.first;
    diplomacy
      ..startWar(pair, War(began: time, earliestEnd: time + years))
      ..refresh(time);
    _announceWar(pair);
    return true;
  }

  /// Lets the dust settle: half of it every eight years.
  void _settleDust(double years) {
    if (dust == 0) return;
    dust *= math.pow(0.5, years / 8);
    if (dust < 0.01) {
      dust = 0;
      _tell(EventKind.dustSettles, 'The dust settles, and the sun returns.');
    }
  }

  /// Moves the climate a little toward where it's heading, and says so when
  /// it gets there.
  void _driftClimate(double years) {
    if (climateShift == climateShiftTarget) return;
    final step = World._climateChangePerYear * years;
    final gap = climateShiftTarget - climateShift;
    if (gap.abs() <= step) {
      climateShift = climateShiftTarget;
      _tell(EventKind.climateSettles, 'The climate settles, ${degreesFromStart(climateShift)}.');
    } else {
      climateShift += gap.sign * step;
    }
  }

  /// Nature's climate wanders both ways, but leans back toward where it
  /// began the further it has strayed: ten degrees warmer, it's three times
  /// as likely to cool as to warm again.
  void _naturalClimateChange() {
    final warmer = _rng.chance(0.5 - climateShiftTarget);
    final by = _rng.range(0.08, 0.25);
    warmer ? warming(by: by) : cooling(by: by);
  }

  void _endWeatherIfDue() {
    if (_weatherChangesBackAt <= 0 || time < _weatherChangesBackAt) return;
    if (isDrought) {
      _tell(EventKind.droughtEnds, 'The rains return.');
    } else {
      _tell(EventKind.plentyEnds, 'The age of plenty ends.');
    }
    weather = 1;
    _weatherChangesBackAt = 0;
  }

  /// Each switched-on kind of natural event happens about once every
  /// thousand years, at random.
  void _maybeActOfNature(double years) {
    final kinds = laws.naturalEvents;
    if (!_rng.chance(years * kinds.length / 1000)) return;
    switch (kinds.elementAt(_rng.nextInt(kinds.length))) {
      case EventKind.meteor when creatures.isNotEmpty:
        // Nature's meteors land where there's life to hit.
        final target = creatures[_rng.nextInt(creatures.length)];
        meteor(target.x, target.y, radius: _rng.range(50, 110));
      case EventKind.plague when creatures.length > 300:
        plague();
      case EventKind.drought when _weatherChangesBackAt == 0:
        drought(years: _rng.range(25, 60));
      case EventKind.plenty when _weatherChangesBackAt == 0:
        plenty(years: _rng.range(20, 40));
      case EventKind.war:
        war();
      case EventKind.warming || EventKind.cooling:
        _naturalClimateChange();
      default:
        break;
    }
  }
}

/// [shift] in words: "8° warmer than at the start", or "as it was at the
/// start".
String degreesFromStart(double shift) {
  final degrees = (shift * Terrain.degreesPerUnit).round();
  if (degrees == 0) return 'as it was at the start';
  return '${degrees.abs()}° ${degrees > 0 ? 'warmer' : 'colder'} than at the start';
}
