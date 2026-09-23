import 'dart:math' as math;

import '../../../shared/rng.dart';
import '../chronicle.dart';
import '../creature.dart';
import '../death.dart';
import '../diplomacy.dart';
import '../genes.dart';
import '../laws.dart';
import '../meteor_strike.dart';
import '../naming.dart';
import '../neighbour_grid.dart';
import '../speciation.dart';
import '../species.dart';
import '../terrain.dart';
import '../thinning.dart';
import '../trait_history.dart';

part 'foraging.dart';
part 'breeding.dart';
part 'fighting.dart';
part 'census.dart';
part 'nature.dart';

/// Civilizations on one land, competing for food and sometimes fighting,
/// evolving, and splitting into species.
///
/// Time: one simulated second is one year. Creatures live 55 to 80 years and
/// can breed from [adulthood].
///
/// Each step, every creature forages ([_forage]), perhaps picks a fight
/// ([_maybeFight]), and ages and perhaps breeds ([_liveAndBreed]). Every
/// ten years each species is checked for a split; every twenty, the wars
/// are reviewed.
class World {
  static const maxCivilizations = 16;

  /// One step, in years.
  static const tick = 1 / 30;

  /// The furthest the climate can shift from where it began: twenty degrees.
  static const maxClimateShift = 0.5;

  /// How fast the climate moves when it changes: 0.2 (eight degrees) takes
  /// fifty years, a couple of generations.
  static const _climateChangePerYear = 0.004;

  final laws = Laws();
  final chronicle = Chronicle();
  final diplomacy = Diplomacy();
  final traits = TraitHistory(maxCivilizations);
  final creatures = <Creature>[];

  /// Every species that ever lived, in order of appearance.
  final species = <Species>[];

  /// Just the living ones. Over a long run the dead vastly outnumber the
  /// living, and the work each step should only grow with the latter.
  final livingSpecies = <Species>[];

  late Terrain terrain;
  late NeighbourGrid _neighbours;
  late Rng _rng;

  LandSize landSize = LandSize.medium;
  int seed = 1, civilizations = 2;
  double time = 0;

  /// Births and deaths since the world began.
  int born = 0, died = 0;

  /// Every death since the world began, by cause.
  final deathsByCause = <DeathCause, int>{};

  /// The most creatures the land may hold: [LandSize.creatureLimit] for its
  /// size, set afresh by [reset].
  int creatureLimit = LandSize.medium.creatureLimit;

  /// Whether the [creatureLimit], not food, has held back births lately.
  bool get isAtCreatureLimit => time - _birthsLastHeldBack < 1;
  double _birthsLastHeldBack = double.negativeInfinity;

  /// Multiplier on regrowth: below 1 in a drought, above in an age of
  /// plenty, 1 otherwise.
  double weather = 1;
  double _weatherChangesBackAt = 0;

  /// How much warmer (above 0) or colder (below) every patch is than when
  /// the world began, in climate units: 0.25 is ten degrees. It creeps
  /// toward [climateShiftTarget] a little each year, so creatures have
  /// generations to adapt, or move.
  double climateShift = 0;
  double climateShiftTarget = 0;

  /// Dust in the sky from a great meteor, 0 (none) to 1: it cools the whole
  /// land and stunts plants everywhere, then settles over a decade or two.
  double dust = 0;

  /// How much colder full dust makes the land: ten degrees.
  static const _dustCooling = 0.25;

  /// The climate shift creatures feel now: [climateShift], less any dust.
  double get climateNow => climateShift - dust * _dustCooling;

  /// Every meteor strike, oldest first.
  final meteorStrikes = <MeteorStrike>[];

  /// When each change to the land was last told, by kind and place, so
  /// painting rain doesn't fill the chronicle with floods.
  final _lastToldOfLand = <String, double>{};

  int _nextCreatureId = 0;

  /// Pairs of species (by id) whose first child together has been told.
  final Set<(int, int)> _crossingsAnnounced = {};

  double _nextSpeciesCheck = 0, _nextWarReview = 20, _nextHistorySample = 0;
  bool _announcedLifeEnds = false;

  /// Time since plants last grew; they grow every other step.
  double _growthOwed = 0;

  World({int seed = 1, int civilizations = 2, LandSize landSize = LandSize.medium, int perCivilization = 60}) {
    reset(seed: seed, civilizations: civilizations, landSize: landSize, perCivilization: perCivilization);
  }

  double get width => terrain.width;
  double get height => terrain.height;

  bool get isDrought => weather < 1;
  bool get isPlenty => weather > 1;

  /// Starts over: new land, and [perCivilization] founders for each of
  /// [civilizations] civilizations. The [laws] stay as they are.
  void reset({required int seed, required int civilizations, LandSize? landSize, int perCivilization = 60}) {
    this.seed = seed;
    this.civilizations = civilizations.clamp(1, maxCivilizations);
    this.landSize = landSize ?? this.landSize;
    _rng = Rng(seed);
    terrain = Terrain.grow(this.landSize, _rng);
    _neighbours = NeighbourGrid(width, height);
    creatures.clear();
    species.clear();
    livingSpecies.clear();
    chronicle.clear();
    diplomacy.clear();
    traits.clear();
    time = 0;
    born = died = 0;
    deathsByCause.clear();
    _crossingsAnnounced.clear();
    creatureLimit = this.landSize.creatureLimit;
    _birthsLastHeldBack = double.negativeInfinity;
    weather = 1;
    _weatherChangesBackAt = 0;
    climateShift = climateShiftTarget = 0;
    dust = 0;
    meteorStrikes.clear();
    _lastToldOfLand.clear();
    _nextSpeciesCheck = 0;
    _nextWarReview = 20;
    _nextHistorySample = 0;
    _announcedLifeEnds = false;
    _growthOwed = 0;

    final homes = terrain.pickHomes(this.civilizations, _rng);
    for (var civilization = 0; civilization < this.civilizations; civilization++) {
      _settle(civilization, homes[civilization], perCivilization);
    }
    _takeCensus();
    _recordHistory();
    final names = civilizationNames.take(this.civilizations).toList();
    _tell(EventKind.founding, names.length == 1 ? '${names.single} settles the land.' : '${inWords(names)} settle the land.');
  }

  /// Founds [civilization] at [home]: one species, whose founders share a
  /// strategy suited to the home climate, with small differences.
  void _settle(int civilization, (double, double) home, int founders) {
    final (homeX, homeY) = home;
    final species = _newSpecies(civilization, parent: null);
    final shape = laws.bodyShapes ? Shape.values[_rng.nextInt(Shape.values.length)] : Shape.round;
    final strategy = Genes.founder(_rng, idealClimate: terrain.climate[terrain.patchAt(homeX, homeY)], shape: shape);
    for (var i = 0; i < founders; i++) {
      creatures.add(Creature(
        id: _nextCreatureId++,
        species: species,
        genes: strategy.mutate(_rng, 0.03, shapesEvolve: false),
        x: (homeX + _rng.gaussian(0, 25)) % width,
        y: (homeY + _rng.gaussian(0, 25)) % height,
        heading: _rng.range(0, math.pi * 2),
        energy: 0,
        lifespan: _randomLifespan(),
        generation: 0,
      )
        ..energy = 50 * strategy.size * strategy.size
        ..age = _rng.range(adulthood, 30));
    }
  }

  Species _newSpecies(int civilization, {required Species? parent}) {
    final newSpecies = Species(
      id: species.length,
      civilization: civilization,
      parent: parent,
      bornAt: time,
    );
    species.add(newSpecies);
    livingSpecies.add(newSpecies);
    return newSpecies;
  }

  double _randomLifespan() => _rng.range(55, 80);

  /// Kills [creature], and counts how.
  void _kill(Creature creature, Death death) {
    creature.die(death);
    creature.species.recentDeaths.add(death);
    deathsByCause.update(death.cause, (n) => n + 1, ifAbsent: () => 1);
  }

  void _tell(EventKind kind, String text, {int? civilization, double? x, double? y, double? radius}) =>
      chronicle.add(ChronicleEntry(time, kind, text, civilization: civilization, x: x, y: y, radius: radius));

  String _civilizationName(int civilization) => civilizationNames[civilization];

  // ---- the step ---------------------------------------------------------------

  /// Advances the world by [ticks] ticks' worth of time in one go. At the
  /// fastest speeds the page takes bigger steps, a little less precise but
  /// many times cheaper; everything is written per unit of time, so it still
  /// adds up to the same world, give or take.
  void step({int ticks = 1}) {
    final years = tick * ticks;
    _endWeatherIfDue();
    _driftClimate(years);
    _settleDust(years);
    if (laws.anyNaturalEvents) _maybeActOfNature(years);
    _growPlants(years, ticks);

    _neighbours.rebuild(creatures);
    final newborn = <Creature>[];
    for (final creature in creatures) {
      if (creature.isDead) continue;
      _forage(creature, years);
      if (creature.genes.aggression > 0.02 && laws.hostility > 0) _maybeFight(creature, years);
      if (!creature.isDead) _liveAndBreed(creature, years, newborn);
    }
    final before = creatures.length;
    creatures.removeWhere((c) => c.isDead);
    died += before - creatures.length;
    creatures.addAll(newborn);
    born += newborn.length;
    time += years;

    _takeCensus();
    if (creatures.isEmpty && !_announcedLifeEnds) {
      _announcedLifeEnds = true;
      _tell(EventKind.lifeEnds, 'Nothing lives on the land any more.');
    }
    if (time >= _nextSpeciesCheck) {
      _nextSpeciesCheck = time + 10;
      for (final species in livingSpecies) {
        species.recentDeaths.fade(0.6);
      }
      for (final candidate in livingSpecies.toList()) {
        _splitIfDivided(candidate);
      }
      _mergeAnyAlike();
    }
    if (time >= _nextWarReview) {
      _nextWarReview = time + 20;
      _reviewWars();
    }
    if (time >= _nextHistorySample) {
      _nextHistorySample = time + traits.sampleEvery;
      _recordHistory();
    }
  }

  /// Plants grow every other step, by two steps' worth: the same growth for
  /// half the work, on the biggest loop in the simulation.
  void _growPlants(double years, int ticks) {
    _growthOwed += years;
    if (_growthOwed < 2 * tick * ticks) return;
    final amount = laws.regrowth * weather * (1 - 0.6 * dust) * _growthOwed;
    terrain.regrow(amount, _growthOwed);
    _growthOwed = 0;
  }

  // ---- questions ----------------------------------------------------------------

  Creature? find(int id) {
    for (final creature in creatures) {
      if (creature.id == id) return creature;
    }
    return null;
  }

  /// The creature nearest ([x], [y]), if one is within [within].
  Creature? nearestCreature(double x, double y, {double within = 15}) {
    Creature? nearest;
    var nearestSquared = within * within;
    for (final creature in creatures) {
      final squared = terrain.distanceSquared(creature.x, creature.y, x, y);
      if (squared < nearestSquared) {
        nearestSquared = squared;
        nearest = creature;
      }
    }
    return nearest;
  }

  double get meanGeneration =>
      creatures.isEmpty ? 0 : creatures.fold(0, (sum, c) => sum + c.generation) / creatures.length;

  int headcountOf(int civilization) => creatures.where((c) => c.species.civilization == civilization).length;
}
