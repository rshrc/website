part of 'world.dart';

/// Counting who's alive, noticing who has died out or split apart, and
/// keeping the histories the page draws.
extension _Census on World {
  /// Recounts every living species and its average genes, and records any
  /// that have died out.
  void _takeCensus() {
    for (final species in livingSpecies) {
      species.clearCensus();
    }
    for (final creature in creatures) {
      creature.species.countMember(creature.genes);
    }
    for (final species in livingSpecies.toList()) {
      if (species.count > 0) {
        species.finishCensus();
      } else {
        _recordExtinction(species);
      }
    }
  }

  void _recordExtinction(Species extinct) {
    extinct.diedAt = time;
    if (extinct.mergedInto case final survivor?) {
      livingSpecies.remove(extinct);
      extinct.fate = 'Merged back into ${survivor.name} in year ${withCommas(time.round())}.';
      _tell(EventKind.merger,
          '${extinct.name} merges back into ${survivor.name}: interbreeding has made them one species again.',
          civilization: extinct.civilization);
      return;
    }
    extinct.headcounts.add((year: time, count: 0));
    livingSpecies.remove(extinct);
    // A finished history needs less detail; thinning it keeps a
    // million-year run's thousands of extinct species cheap to hold.
    while (extinct.headcounts.length > 60) {
      keepEveryOther(extinct.headcounts);
    }
    if (extinct.headcounts.last.count != 0) extinct.headcounts.add((year: time, count: 0));
    extinct.fate = extinct.recentDeaths.lastMembersFate;
    final lasted = 'after ${withCommas((time - extinct.bornAt).round())} years';
    final fate = extinct.fate.isEmpty ? '' : ' ${extinct.fate}';
    final civilizationSurvives = livingSpecies.any((s) => s.civilization == extinct.civilization && s.count > 0);
    if (civilizationSurvives) {
      _tell(EventKind.extinction, '${extinct.name} dies out, $lasted.$fate', civilization: extinct.civilization);
    } else {
      _tell(
          EventKind.civilizationLost,
          '${extinct.name} dies out, $lasted: the last of the ${_civilizationName(extinct.civilization)}.$fate',
          civilization: extinct.civilization);
    }
  }

  /// Adds today's headcount to every living species' history, and a sample
  /// to the chart's.
  void _recordHistory() {
    for (final species in livingSpecies) {
      species.headcounts.add((year: time, count: species.count));
      if (species.headcounts.length > 400) keepEveryOther(species.headcounts);
    }
    traits.record(creatures, climateShift: climateShift);
  }

  /// Two species of one lineage that live together and whose averages have
  /// grown this close have blurred back into one; the smaller joins the
  /// larger.
  static const _mergeBelow = 0.75;

  /// Merges any two species of one lineage that have interbred back into
  /// sameness: close in their average genes (see [_mergeBelow]) and living
  /// in the same country, not merely alike from afar.
  void _mergeAnyAlike() {
    for (final a in livingSpecies.toList()) {
      for (final b in livingSpecies.toList()) {
        if (a.id >= b.id || a.civilization != b.civilization || a.count == 0 || b.count == 0) continue;
        if (a.mergedInto != null || b.mergedInto != null) continue;
        if (a.averageGenes.distanceTo(b.averageGenes) >= _mergeBelow) continue;
        final aMembers = [for (final c in creatures) if (identical(c.species, a)) c];
        final bMembers = [for (final c in creatures) if (identical(c.species, b)) c];
        final aRange = _rangeOf(aMembers), bRange = _rangeOf(bMembers);
        final together = math.sqrt(terrain.distanceSquared(aRange.x, aRange.y, bRange.x, bRange.y)) <=
            aRange.spread + bRange.spread;
        if (!together) continue;
        final (survivor, absorbed, absorbedMembers) = a.count >= b.count ? (a, b, bMembers) : (b, a, aMembers);
        for (final member in absorbedMembers) {
          member.species = survivor;
        }
        absorbed.mergedInto = survivor;
      }
    }
    _takeCensus();
  }

  /// Splits [parent] in two if its members have come apart in gene space;
  /// see [findBreakaway]. The smaller group becomes a new species.
  void _splitIfDivided(Species parent) {
    final members = [
      for (final creature in creatures)
        if (identical(creature.species, parent)) creature,
    ];
    final leavers = findBreakaway(members, _rng, incompatibleAt: incompatibleAt);
    if (leavers == null) return;

    final leaving = Set<Creature>.identity()..addAll(leavers);
    final stayers = [
      for (final member in members)
        if (!leaving.contains(member)) member,
    ];
    final (:origin, :movedTo) = _whereTheySplit(leavers, stayers);
    final child = _newSpecies(parent.civilization, parent: parent)..origin = origin;
    for (final leaver in leavers) {
      leaver.species = child;
    }
    _takeCensus();
    child.epithet = epithetFor(child, parent,
        compassPoint: movedTo, lineage: species.where((s) => s.civilization == parent.civilization).toList());
    final differences = _howTheyDiffer(child, parent);
    _tell(
        EventKind.speciation,
        '${child.name} splits from ${parent.name}, ${child.origin}'
        '${differences.isEmpty ? '' : ' — ${inWords(differences)}'}.',
        civilization: parent.civilization);
  }

  /// Why [leavers] came apart from [stayers], as far as where they live
  /// tells: whether they live apart, and in what kind of land. Species that
  /// split without moving apart have found a different way of life among
  /// the rest.
  ({String origin, String? movedTo}) _whereTheySplit(List<Creature> leavers, List<Creature> stayers) {
    final away = _rangeOf(leavers), home = _rangeOf(stayers);
    final livesApart =
        math.sqrt(terrain.distanceSquared(away.x, away.y, home.x, home.y)) > away.spread + home.spread;
    final warmer = away.climate - home.climate, richer = away.fertility - home.fertility;
    final land = [
      if (warmer.abs() >= 0.1) '${(warmer.abs() * Terrain.degreesPerUnit).round()}° ${warmer > 0 ? 'warmer' : 'colder'}',
      if (richer.abs() >= 0.15) richer > 0 ? 'richer' : 'leaner',
    ];
    final changing = climateShift == climateShiftTarget
        ? ''
        : ' as the climate ${climateShiftTarget > climateShift ? 'warms' : 'cools'}';
    if (livesApart) {
      final compass = terrain.compassPoint(away.x, away.y);
      final inLand = land.isEmpty ? '' : ', in land ${land.join(' and ')}';
      return (origin: 'living apart in the $compass$inLand$changing', movedTo: compass);
    }
    if (land.isNotEmpty) return (origin: 'taking to land ${land.join(' and ')} nearby$changing', movedTo: null);
    return (origin: 'without moving apart, a different way of life among the rest', movedTo: null);
  }

  /// Where a group lives: its middle (averaged the wrap-around way, as
  /// angles, so a group straddling an edge has its middle at the edge), how
  /// far its members spread from that middle, and the average climate and
  /// fertility under them.
  ({double x, double y, double spread, double climate, double fertility}) _rangeOf(List<Creature> group) {
    var cosX = 0.0, sinX = 0.0, cosY = 0.0, sinY = 0.0, climate = 0.0, fertility = 0.0;
    for (final creature in group) {
      final angleX = creature.x / width * 2 * math.pi, angleY = creature.y / height * 2 * math.pi;
      cosX += math.cos(angleX);
      sinX += math.sin(angleX);
      cosY += math.cos(angleY);
      sinY += math.sin(angleY);
      final patch = terrain.patchAt(creature.x, creature.y);
      climate += terrain.climate[patch] + climateNow;
      fertility += terrain.capacity(patch);
    }
    final x = (math.atan2(sinX, cosX) / (2 * math.pi) * width) % width;
    final y = (math.atan2(sinY, cosY) / (2 * math.pi) * height) % height;
    var spread = 0.0;
    for (final creature in group) {
      spread += math.sqrt(terrain.distanceSquared(creature.x, creature.y, x, y));
    }
    return (
      x: x,
      y: y,
      spread: spread / group.length,
      climate: climate / group.length,
      fertility: fertility / group.length,
    );
  }

  /// What sets [child] apart from [parent], in words, for the chronicle.
  List<String> _howTheyDiffer(Species child, Species parent) {
    final childBody = child.commonestBody, parentBody = parent.commonestBody;
    return [
      if ((child.averageSpeed / parent.averageSpeed - 1).abs() > 0.15)
        child.averageSpeed > parent.averageSpeed ? 'faster' : 'slower',
      if ((child.averageSize / parent.averageSize - 1).abs() > 0.15)
        child.averageSize > parent.averageSize ? 'bigger' : 'smaller',
      if ((child.averageSight / parent.averageSight - 1).abs() > 0.15)
        child.averageSight > parent.averageSight ? 'sharper-eyed' : 'shorter-sighted',
      if ((child.averageAggression - parent.averageAggression).abs() > 0.1)
        child.averageAggression > parent.averageAggression ? 'fiercer' : 'gentler',
      if ((child.averageIdealClimate - parent.averageIdealClimate).abs() > 0.1)
        child.averageIdealClimate > parent.averageIdealClimate ? 'built for heat' : 'built for cold',
      if ((child.averageTint - parent.averageTint).abs() > 0.5) 'differently coloured',
      if (childBody != parentBody)
        childBody.isHybrid ? '${childBody.first.label}-${childBody.second.label}' : '${childBody.first.label}-bodied',
    ];
  }
}
