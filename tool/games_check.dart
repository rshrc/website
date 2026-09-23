// Runs the game simulations headlessly on the Dart VM and checks that
// they behave: known Life patterns have their known periods, collisions
// conserve momentum, the population game's groups live, compete and evolve,
// the fractal maths knows in from out, and light obeys the laws of optics.
//
//   dart run tool/games_check.dart     (or: make games-check)
//
// The simulations have no web imports, which is what makes this possible.

import 'dart:io';

import 'dart:math' as math;

import '../src/games/fractals/fractal.dart';
import '../src/games/light/model/model.dart' as light;
import '../src/games/life/sim.dart';
import '../src/games/population/model/model.dart' as population;
import '../src/games/shared/rng.dart';
import '../src/games/shared/vec2.dart';
import '../src/games/universe/sim.dart';

var _failures = 0;

void check(String what, bool ok, [String detail = '']) {
  stdout.writeln('${ok ? 'ok  ' : 'FAIL'} $what${detail.isEmpty ? '' : '  ($detail)'}');
  if (!ok) _failures++;
}

void main() {
  lifeChecks();
  universeChecks();
  populationChecks();
  fractalChecks();
  lightChecks();
  stdout.writeln(_failures == 0 ? '\nall good' : '\n$_failures failed');
  exit(_failures == 0 ? 0 : 1);
}

LifeSim runUntilSettled(LifeSim sim, int limit) {
  while (sim.period == null && sim.generation < limit) {
    sim.step();
  }
  return sim;
}

void lifeChecks() {
  Pattern named(String name) => Pattern.all.firstWhere((p) => p.name == name);

  final block = LifeSim(12, 12)..stamp(Pattern.plaintext('block', 'OO\nOO'), 6, 6);
  runUntilSettled(block, 10);
  check('life: a block is a still life', block.period == 1 && block.population == 4);

  final blinker = LifeSim(12, 12)..stamp(Pattern.plaintext('blinker', 'OOO'), 6, 6);
  runUntilSettled(blinker, 10);
  check('life: a blinker has period 2', blinker.period == 2);

  final pulsar = LifeSim(40, 40)..stamp(named('pulsar'), 20, 20);
  runUntilSettled(pulsar, 20);
  check('life: the pulsar has period 3', pulsar.period == 3, 'got ${pulsar.period}');

  // A glider moves one cell diagonally every 4 generations, so on a 20x20
  // torus the whole world repeats after 80.
  final glider = LifeSim(20, 20)..stamp(named('glider'), 10, 10);
  runUntilSettled(glider, 200);
  check('life: a glider laps a 20x20 torus in 80 generations', glider.period == 80 && glider.population == 5,
      'period ${glider.period}');

  final gun = LifeSim(120, 80)..stamp(named('Gosper glider gun'), 30, 20);
  final start = gun.population;
  for (var i = 0; i < 120; i++) {
    gun.step();
  }
  check('life: the Gosper gun keeps firing', gun.population > start + 15, '$start -> ${gun.population} cells');

  final highlife = LifeRule.tryParse('b36/S23');
  check('life: rules parse either order and case',
      highlife?.notation == 'B36/S23' && LifeRule.tryParse('S23/B3')?.notation == 'B3/S23');
  check('life: nonsense is not a rule', LifeRule.tryParse('B9/S23') == null && LifeRule.tryParse('hello') == null);
}

double relative(double a, double b) => (a - b).abs() / math.max(a.abs(), 1e-9);

void universeChecks() {
  // A closed torus of elastic bodies and no external forces: momentum is
  // conserved exactly by construction, energy nearly so.
  final box = Universe(400, 300)..laws.walls = Walls.wrap..laws.restitution = 1;
  final rng = Rng(7);
  for (var i = 0; i < 120; i++) {
    box.add(Vec2(rng.range(0, 400), rng.range(0, 300)),
        velocity: Vec2(rng.gaussian(0, 60), rng.gaussian(0, 60)), radius: rng.range(3, 7));
  }
  final p0 = box.momentum, e0 = box.kineticEnergy;
  var contacts = 0;
  for (var i = 0; i < 600; i++) {
    box.step(1 / 60);
    contacts += box.contactsLastStep;
  }
  final p1 = box.momentum;
  check('universe: elastic contacts conserve momentum', (p1 - p0).length < 1e-6 * (1 + p0.length),
      '$contacts contacts, drift ${(p1 - p0).length.toStringAsExponential(1)}');
  check('universe: elastic contacts keep kinetic energy', relative(box.kineticEnergy, e0) < 0.02,
      '${(100 * relative(box.kineticEnergy, e0)).toStringAsFixed(2)}% change');

  final putty = Universe(400, 300)..laws.walls = Walls.wrap..laws.restitution = 0;
  final rng2 = Rng(7);
  for (var i = 0; i < 120; i++) {
    putty.add(Vec2(rng2.range(0, 400), rng2.range(0, 300)),
        velocity: Vec2(rng2.gaussian(0, 60), rng2.gaussian(0, 60)), radius: rng2.range(3, 7));
  }
  final before = putty.kineticEnergy;
  for (var i = 0; i < 600; i++) {
    putty.step(1 / 60);
  }
  check('universe: putty contacts lose energy', putty.kineticEnergy < before * 0.5,
      '${before.round()} -> ${putty.kineticEnergy.round()}');

  // Two bodies in a circular orbit: semi-implicit Euler should keep the orbit
  // closed and the total energy steady for many revolutions.
  final orbit = Universe(1000, 1000)..laws.attraction = 1000..laws.walls = Walls.open;
  final sun = orbit.add(const Vec2(500, 500), radius: 20);
  final r = 200.0, v = math.sqrt(orbit.laws.attraction * sun.mass / r);
  final planet = orbit.add(Vec2(500 + r, 500), velocity: Vec2(0, v), radius: 2);
  // Give the sun the opposite momentum so the pair's centre of mass stays put.
  sun.vy = -planet.mass * v / sun.mass;
  final energyStart = orbit.energy;
  var closest = double.infinity, furthest = 0.0;
  for (var i = 0; i < 60 * 60; i++) {
    orbit.step(1 / 60);
    final d = (planet.position - sun.position).length;
    closest = math.min(closest, d);
    furthest = math.max(furthest, d);
  }
  check('universe: an orbit stays closed for a minute of sim time', closest > r * 0.95 && furthest < r * 1.05,
      'radius ${closest.toStringAsFixed(1)}..${furthest.toStringAsFixed(1)}');
  check('universe: orbital energy is conserved', relative(orbit.energy, energyStart) < 0.01,
      '${(100 * relative(orbit.energy, energyStart)).toStringAsFixed(3)}% drift');

  // Merging keeps mass and momentum.
  final merger = Universe(400, 400)..laws.contact = Contact.merge..laws.walls = Walls.open;
  merger.add(const Vec2(195, 200), velocity: const Vec2(30, 0), radius: 10);
  merger.add(const Vec2(205, 200), velocity: const Vec2(-10, 5), radius: 5);
  final massBefore = merger.bodies.fold(0.0, (m, b) => m + b.mass);
  final pBefore = merger.momentum;
  merger.step(1 / 60);
  check('universe: merging keeps mass and momentum',
      merger.bodies.length == 1 &&
          relative(merger.bodies.single.mass, massBefore) < 1e-9 &&
          (merger.momentum - pBefore).length < 1e-9);

  // Every preset builds and runs without losing its mind.
  for (final name in Universe.presets) {
    final u = Universe(900, 600)..preset(name, Rng(1));
    final count = u.bodies.length;
    for (var i = 0; i < 300; i++) {
      u.step(1 / 60);
    }
    final finite = u.bodies.every((b) => b.x.isFinite && b.y.isFinite && b.vx.isFinite && b.vy.isFinite);
    check('universe: preset "$name" runs', finite && u.bodies.isNotEmpty, '$count -> ${u.bodies.length} bodies');
  }

  final solar = Universe(900, 600)..preset('orbits', Rng(4));
  final planets = solar.bodies.length;
  for (var i = 0; i < 60 * 60; i++) {
    solar.step(1 / 60);
  }
  final sunNow = solar.bodies.reduce((a, b) => a.mass > b.mass ? a : b);
  check('universe: the solar system keeps its planets and stays centred',
      solar.bodies.length == planets && (sunNow.position - const Vec2(450, 300)).length < 20,
      '${solar.bodies.length}/$planets bodies after a minute, sun ${(sunNow.position - const Vec2(450, 300)).length.toStringAsFixed(1)}px from centre');

  final settle = Universe(900, 600)..preset('rain', Rng(3));
  for (var i = 0; i < 60 * 20; i++) {
    settle.step(1 / 60);
  }
  final meanSpeed = settle.bodies.fold(0.0, (s, b) => s + b.velocity.length) / settle.bodies.length;
  check('universe: rain settles into a pile', meanSpeed < 15, 'mean speed ${meanSpeed.toStringAsFixed(1)} px/s');
}

void populationChecks() {
  population.World run(int seed, int civilizations, double years,
      {bool natural = false, population.LandSize landSize = population.LandSize.medium}) {
    final world = population.World(seed: seed, civilizations: civilizations, landSize: landSize)
      ..laws.allNaturalEvents = natural;
    while (world.time < years) {
      world.step();
    }
    return world;
  }

  bool happened(population.World world, population.EventKind kind) => world.chronicle.entries.any((e) => e.kind == kind);
  int timesHappened(population.World world, population.EventKind kind) =>
      world.chronicle.entries.where((e) => e.kind == kind).length;

  final first = run(42, 2, 100), second = run(42, 2, 100);
  check('population: the same seed grows the same world',
      first.creatures.length == second.creatures.length && first.terrain.greenery == second.terrain.greenery,
      '${first.creatures.length} alive after 100 years');

  for (final civilizations in [1, 4, 9, population.World.maxCivilizations]) {
    final world = population.World(
        seed: 3, civilizations: civilizations, landSize: population.LandSize.large, perCivilization: 20);
    check('population: starts with $civilizations civilization${civilizations == 1 ? '' : 's'}',
        world.species.length == civilizations &&
            world.creatures.map((c) => c.species.civilization).toSet().length == civilizations &&
            world.creatures.length == civilizations * 20);
  }
  for (final size in population.LandSize.values) {
    final world = population.World(seed: 1, civilizations: 2, landSize: size);
    check('population: ${size.name} land is ${size.width.round()}×${size.height.round()}',
        world.width == size.width &&
            world.creatures.every((c) => c.x >= 0 && c.x < size.width && c.y >= 0 && c.y < size.height));
  }

  var survived = 0, splits = 0, worldsWithSplits = 0, peak = 0, wars = 0;
  for (var seed = 1; seed <= 6; seed++) {
    final world = run(seed, 2, 2000);
    if (world.creatures.isNotEmpty) survived++;
    final worldSplits = world.species.where((s) => s.parent != null).length;
    splits += worldSplits;
    if (worldSplits > 0) worldsWithSplits++;
    wars += timesHappened(world, population.EventKind.war);
    peak = math.max(peak,
        world.traits.of(population.Measure.population).expand((h) => h).fold(0, (m, v) => math.max(m, v.round())));
  }
  check('population: life goes on for 2,000 years', survived == 6, '$survived of 6 worlds');
  check('population: new species arise in most worlds', worldsWithSplits >= 4,
      '$splits speciations, in $worldsWithSplits of 6 worlds');
  check('population: wars break out, but not constantly', wars >= 3 && wars <= 60, '$wars wars in 6 worlds');
  final limit = population.LandSize.medium.creatureLimit;
  check('population: food, not the safety cap, limits numbers', peak < limit * 0.9, 'peak $peak of $limit');

  // Fighting off means peace, even with natural wars switched on and the
  // war button pressed.
  final peaceful = population.World(seed: 2, civilizations: 3);
  peaceful.laws
    ..naturalEvents.clear()
    ..naturalEvents.add(population.EventKind.war)
    ..hostility = 0;
  final refused = !peaceful.war();
  while (peaceful.time < 3000) {
    peaceful.step(ticks: 8);
  }
  check('population: with fighting off, no war ever starts',
      refused && !happened(peaceful, population.EventKind.war));

  // Turning fighting off ends a war under way.
  final ceasefire = population.World(seed: 2, civilizations: 3)..laws.naturalEvents.clear();
  ceasefire.war(years: 500);
  while (ceasefire.time < 30) {
    ceasefire.step();
  }
  ceasefire.laws.hostility = 0;
  while (ceasefire.time < 60) {
    ceasefire.step();
  }
  check('population: turning fighting off ends the wars', happened(ceasefire, population.EventKind.peace));

  population.Species? child;
  for (var seed = 1; seed <= 8 && child == null; seed++) {
    final world = run(seed, 1, 2000);
    for (final species in world.species) {
      if (species.parent != null && species.count > 20 && species.parent!.count > 20) child = species;
    }
  }
  final parent = child?.parent;
  population.Genes averageOf(population.Species s) => population.Genes(
      speed: s.averageSpeed, size: s.averageSize, sight: s.averageSight, aggression: s.averageAggression, tint: s.averageTint);
  check('population: a new species differs from its parent',
      child != null && averageOf(child).distanceTo(averageOf(parent!)) > 1,
      child == null ? 'no living parent and child in 8 worlds' : '${child.name} vs ${parent!.name}');

  final rng = Rng(5);
  const mum = population.Genes(speed: 20, size: 1, sight: 50, aggression: 0.1, tint: -1),
      dad = population.Genes(speed: 80, size: 2, sight: 150, aggression: 0.9, tint: 1);
  final kids = List.generate(200, (_) => population.Genes.cross(mum, dad, rng));
  check('population: each gene comes whole from one parent',
      kids.every((k) =>
              (k.speed == 20 || k.speed == 80) &&
              (k.size == 1 || k.size == 2) &&
              (k.sight == 50 || k.sight == 150) &&
              (k.aggression == 0.1 || k.aggression == 0.9) &&
              (k.tint == -1 || k.tint == 1)) &&
          kids.any((k) => k.speed == 20 && k.size == 2));

  // Shape is two alleles: a child gets one from each parent, so a round
  // parent and a square one make round-square hybrids, and two hybrids can
  // have pure children again.
  const roundOne = population.Genes(speed: 30, size: 1, sight: 50, aggression: 0.1);
  const squareOne = population.Genes(
      speed: 30, size: 1, sight: 50, aggression: 0.1, firstShape: population.Shape.square, secondShape: population.Shape.square);
  final firstCross = List.generate(100, (_) => population.Genes.cross(roundOne, squareOne, rng));
  final secondCross = List.generate(400, (_) => population.Genes.cross(firstCross[0], firstCross[1], rng));
  final pure = secondCross.where((g) => !g.isHybrid).length;
  check('population: shape alleles come one from each parent',
      firstCross.every((g) =>
              g.isHybrid && g.share(population.Shape.round) == 0.5 && g.share(population.Shape.square) == 0.5) &&
          pure > 120 &&
          pure < 280,
      'second generation: $pure of 400 pure, about half expected');

  var hybrids = 0;
  for (var seed = 1; seed <= 3; seed++) {
    final world = population.World(seed: seed, civilizations: 3)..laws.naturalEvents.clear();
    while (world.time < 100) {
      world.step();
    }
    world.war(years: 80);
    while (world.time < 350) {
      world.step(ticks: 2);
    }
    hybrids += world.chronicle.entries
        .where((e) => e.kind == population.EventKind.firstHybrid && _peoplesNamed(e.text) >= 2)
        .length;
  }
  check('population: war brings peoples into contact, and close enough ones have young together', hybrids >= 2,
      '$hybrids first crossings between peoples');

  final plainWorld = population.World(seed: 3, civilizations: 3);
  plainWorld.laws
    ..naturalEvents.clear()
    ..bodyShapes = false;
  plainWorld.reset(seed: 3, civilizations: 3);
  while (plainWorld.time < 400) {
    plainWorld.step(ticks: 2);
  }
  check('population: with body shapes off, everyone stays round',
      plainWorld.creatures.every((c) => c.genes.body == population.Body.pure(population.Shape.round)));

  // The neutral tint gene drifts: after a few hundred years, creatures of one
  // civilization no longer share one colour.
  final drift = run(2, 1, 400);
  final tints = drift.creatures.map((c) => c.genes.tint).toList()..sort();
  final spread = tints[(tints.length * 0.9).floor()] - tints[(tints.length * 0.1).floor()];
  check('population: the neutral tint gene drifts', spread > 0.5, 'middle 80% spans ${spread.toStringAsFixed(2)}');

  final struck = run(9, 2, 50);
  final target = struck.creatures.first;
  final killed = struck.meteor(target.x, target.y);
  final strike = struck.chronicle.entries.last;
  check('population: a meteor kills what it lands on, and says how much of each species',
      killed > 0 && strike.kind == population.EventKind.meteor && strike.text.contains('% of'), strike.text);
  // Meteors are remembered, and a big one's dust reaches everyone.
  final great = run(9, 3, 100);
  final beforeImpact = great.creatures.length;
  great.meteor(great.creatures.first.x, great.creatures.first.y, radius: 280);
  final remembered = great.meteorStrikes.single;
  final unstruck = run(9, 3, 100);
  final dustCooled = great.climateNow < -0.15;
  while (great.time < 115) {
    great.step();
  }
  while (unstruck.time < 115) {
    unstruck.step();
  }
  check('population: a meteor strike is remembered, with its size and toll',
      remembered.size == 'colossal meteor' &&
          remembered.killed > 0 &&
          (remembered.shareOfAllLife - remembered.killed / beforeImpact).abs() < 1e-9 &&
          remembered.tolls.isNotEmpty,
      '${remembered.devastation}: ${remembered.killed} of $beforeImpact');
  check("population: a great meteor's dust cools the land and withers plants everywhere",
      dustCooled && great.terrain.greenery < unstruck.terrain.greenery,
      'greenery ${great.terrain.greenery.toStringAsFixed(2)} vs ${unstruck.terrain.greenery.toStringAsFixed(2)}');
  while (great.time < 250) {
    great.step(ticks: 4);
  }
  check('population: the dust settles', great.dust == 0 && happened(great, population.EventKind.dustSettles));

  // Rain and drought painted onto the land: a little rain feeds more
  // creatures, a flood or a dust bowl empties it, and it all heals.
  int livingNear(population.World world, double x, double y) =>
      world.creatures.where((c) => world.terrain.distanceSquared(c.x, c.y, x, y) < 150 * 150).length;
  population.World settled() => run(3, 3, 100);
  final spot = settled().creatures[180];
  final outcomes = <String, int>{};
  for (final (name, weather) in [
    ('untouched', (population.World w) {}),
    ('gentle rain', (population.World w) => w.rainOn(spot.x, spot.y, radius: 150, amount: 0.0004)),
    ('flood', (population.World w) => w.rainOn(spot.x, spot.y, radius: 150, amount: 0.3)),
    ('drought', (population.World w) => w.dryOut(spot.x, spot.y, radius: 150, amount: 0.3)),
  ]) {
    final world = settled();
    while (world.time < 160) {
      weather(world);
      world.step();
    }
    outcomes[name] = livingNear(world, spot.x, spot.y);
    if (name == 'flood') outcomes['drowned'] = world.deathsByCause[population.DeathCause.flood] ?? 0;
    if (name == 'drought') {
      while (world.time < 600) {
        world.step(ticks: 4);
      }
      outcomes['healed'] = world.terrain.isDisturbed ? 0 : 1;
    }
  }
  check('population: gentle rain feeds more creatures', outcomes['gentle rain']! > outcomes['untouched']!,
      '${outcomes['gentle rain']} against ${outcomes['untouched']}');
  check('population: floods and droughts drive creatures out',
      outcomes['flood']! < outcomes['untouched']! / 3 && outcomes['drought']! < outcomes['untouched']! / 3 &&
          outcomes['drowned']! > 0,
      'flood ${outcomes['flood']}, drought ${outcomes['drought']}, untouched ${outcomes['untouched']}; '
      '${outcomes['drowned']} drowned');
  check('population: the land heals once left alone', outcomes['healed'] == 1);

  final sick = run(9, 2, 50);
  final beforePlague = sick.creatures.length;
  sick.plague();
  check('population: a plague takes a big share of one species', sick.creatures.length < beforePlague * 0.85,
      '$beforePlague -> ${sick.creatures.length}');
  final dry = run(9, 2, 50)..drought(years: 10);
  final wasDrought = dry.isDrought;
  while (dry.time < 70) {
    dry.step();
  }
  check('population: droughts end',
      wasDrought && dry.weather == 1 && happened(dry, population.EventKind.droughtEnds));

  // Climate change comes on gradually, and creatures adapt to it: their
  // ideal climate follows the land's, compared with an untouched twin.
  double meanIdealClimate(population.World world) =>
      world.creatures.fold(0.0, (sum, c) => sum + c.genes.idealClimate) / world.creatures.length;
  var warmedBy = 0.0, cooledBy = 0.0, survivedChange = 0;
  for (var seed = 1; seed <= 3; seed++) {
    population.World twin() => population.World(seed: seed, civilizations: 3)..laws.naturalEvents.clear();
    final control = twin(), warmed = twin(), cooled = twin();
    for (final world in [control, warmed, cooled]) {
      while (world.time < 200) {
        world.step(ticks: 2);
      }
    }
    warmed.warming(by: 0.3);
    cooled.cooling(by: 0.3);
    final gradual = warmed.climateShift == 0 && warmed.climateShiftTarget == 0.3;
    while (warmed.time < 230) {
      warmed.step(ticks: 2);
    }
    if (!gradual || warmed.climateShift >= 0.3 || warmed.climateShift <= 0) warmedBy = double.nan;
    for (final world in [control, warmed, cooled]) {
      while (world.time < 1500) {
        world.step(ticks: 4);
      }
      if (world.creatures.isNotEmpty) survivedChange++;
    }
    warmedBy += meanIdealClimate(warmed) - meanIdealClimate(control);
    cooledBy += meanIdealClimate(control) - meanIdealClimate(cooled);
  }
  check('population: under a warming climate, creatures evolve to like it warmer', warmedBy / 3 > 0.15,
      'ideal climate ${(warmedBy / 3).toStringAsFixed(2)} above an unwarmed twin, on average');
  check('population: under a cooling one, colder', cooledBy / 3 > 0.08,
      'ideal climate ${(cooledBy / 3).toStringAsFixed(2)} below an uncooled twin, on average');
  check('population: life adapts to climate change rather than ending', survivedChange == 9);

  // Nature's own climate change wanders but stays within bounds.
  final wandering = population.World(seed: 3, civilizations: 3);
  wandering.laws
    ..naturalEvents.clear()
    ..naturalEvents.addAll([population.EventKind.warming, population.EventKind.cooling]);
  var furthest = 0.0;
  while (wandering.time < 8000) {
    wandering.step(ticks: 8);
    furthest = math.max(furthest, wandering.climateShift.abs());
  }
  final shifts = timesHappened(wandering, population.EventKind.warming) +
      timesHappened(wandering, population.EventKind.cooling);
  check('population: the climate changes by itself, within bounds',
      shifts >= 5 && furthest <= population.World.maxClimateShift && furthest > 0.05,
      '$shifts changes in 8,000 years, at most ${(furthest * population.Terrain.degreesPerUnit).round()}° off');

  // Every death has a cause, the counts add up, and they're sensible: old
  // age and hunger are the common ends.
  final mortal = run(1, 3, 1500, natural: true);
  final counted = mortal.deathsByCause.values.fold(0, (sum, n) => sum + n);
  final commonest = (mortal.deathsByCause.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  check('population: every death has a cause', counted == mortal.died && commonest == population.DeathCause.oldAge,
      '${mortal.died} deaths, ${mortal.deathsByCause.length} causes, commonest ${commonest.noun}');
  final extinct = mortal.species.where((s) => !s.isAlive).toList();
  check('population: extinct species say how their last members died',
      extinct.every((s) => s.fate.isNotEmpty) &&
          mortal.chronicle.entries
              .where((e) => e.kind == population.EventKind.extinction || e.kind == population.EventKind.civilizationLost)
              .every((e) => e.text.contains('last members')),
      '${extinct.length} extinct');

  // New species get names of their own, say how they split, and never
  // share a name with a relative.
  final named = <String>[], origins = <String>[];
  var namesUnique = true, sisterCrossings = 0;
  for (var seed = 1; seed <= 4; seed++) {
    final world = run(seed, 3, 3000);
    sisterCrossings += world.chronicle.entries
        .where((e) => e.kind == population.EventKind.firstHybrid && _peoplesNamed(e.text) == 1)
        .length;
    final descendants = world.species.where((s) => s.parent != null).toList();
    namesUnique &= descendants.map((s) => s.name).toSet().length == descendants.length;
    named.addAll(descendants.map((s) => s.name));
    origins.addAll(descendants.map((s) => s.origin));
  }
  check('population: new species are named for what sets them apart, no two alike',
      named.isNotEmpty && named.every((n) => n.split(' ').length >= 2) && namesUnique, named.take(5).join(', '));
  check('population: sister species can still have young together, where their genes allow', sisterCrossings > 0,
      '$sisterCrossings first crossings within a lineage');
  check('population: every split says how it came about',
      origins.every((o) => o.startsWith('living apart') || o.startsWith('taking to') || o.startsWith('without moving')),
      '${origins.where((o) => o.startsWith('living apart')).length} apart, '
      '${origins.where((o) => o.startsWith('taking to')).length} to new land, '
      '${origins.where((o) => o.startsWith('without')).length} in place');

  // The creature limit scales with the land, holds, and says when it bites.
  check('population: the huge land holds up to 10,000',
      population.World(seed: 1, landSize: population.LandSize.huge).creatureLimit == 10000);
  final crowded = population.World(seed: 4, civilizations: 3)
    ..laws.naturalEvents.clear()
    ..creatureLimit = 400;
  var sawLimit = false, most = 0;
  while (crowded.time < 100) {
    crowded.step(ticks: 2);
    sawLimit |= crowded.isAtCreatureLimit;
    most = math.max(most, crowded.creatures.length);
  }
  check('population: at the creature limit births are held back, and it says so', sawLimit && most <= 400,
      'at most $most of 400');

  final follow = run(4, 2, 30);
  final one = follow.creatures[7];
  check('population: a creature can be found again by id',
      identical(follow.find(one.id), one) && identical(follow.nearestCreature(one.x, one.y, within: 0.01), one));

  final lived = run(4, 3, 1500, natural: true);
  check('population: each species has a headcount history over its whole life',
      lived.species.every((s) =>
          s.headcounts.isNotEmpty &&
          s.headcounts.length <= 400 &&
          (s.headcounts.first.year - s.bornAt).abs() < 20 &&
          (s.isAlive ? lived.time - s.headcounts.last.year < 20 : s.headcounts.last.count == 0)),
      '${lived.species.length} species');

  // Founders are adapted to the climate of their home valley.
  final homes = population.World(seed: 5, civilizations: 6);
  final adapted = homes.creatures
      .where((c) => (homes.terrain.climate[homes.terrain.patchAt(c.x, c.y)] - c.genes.idealClimate).abs() < 0.2)
      .length;
  check('population: founders are built for their home climate', adapted > homes.creatures.length * 0.8,
      '$adapted of ${homes.creatures.length}');

  // Coarse steps, used above ×100, should grow much the same world.
  var fine = 0, coarse = 0;
  for (var seed = 1; seed <= 3; seed++) {
    final fineWorld = population.World(seed: seed, civilizations: 3)..laws.allNaturalEvents = false;
    final coarseWorld = population.World(seed: seed, civilizations: 3)..laws.allNaturalEvents = false;
    while (fineWorld.time < 600) {
      fineWorld.step();
    }
    while (coarseWorld.time < 600) {
      coarseWorld.step(ticks: 8);
    }
    fine += fineWorld.creatures.length;
    coarse += coarseWorld.creatures.length;
  }
  check('population: coarse steps grow a similar world', coarse > fine * 0.7 && coarse < fine * 1.4,
      '$fine alive with fine steps, $coarse with coarse, over 3 worlds');

  // Deep time: 20,000 years at the coarsest step. The living-species list
  // stays honest and extinct species' histories stay small.
  final deep = population.World(seed: 6, civilizations: 4, landSize: population.LandSize.large);
  while (deep.time < 20000) {
    deep.step(ticks: 8);
  }
  check('population: 20,000 years later, the books still balance',
      deep.livingSpecies.every((s) => s.isAlive && s.count > 0) &&
          deep.species.where((s) => s.isAlive).length == deep.livingSpecies.length &&
          deep.species.where((s) => !s.isAlive).every((s) => s.headcounts.length <= 62),
      '${deep.creatures.length} alive, ${deep.livingSpecies.length} living species of ${deep.species.length} ever');

  // Natural events: all off means nothing happens by itself; one on means
  // only that kind does.
  const nature = {
    population.EventKind.meteor,
    population.EventKind.plague,
    population.EventKind.drought,
    population.EventKind.plenty,
  };
  final quiet = population.World(seed: 8, civilizations: 3)..laws.naturalEvents.clear();
  while (quiet.time < 3000) {
    quiet.step(ticks: 8);
  }
  check('population: with natural events off, nothing happens by itself',
      !quiet.chronicle.entries.any((e) => nature.contains(e.kind)));
  final meteors = population.World(seed: 8, civilizations: 3);
  meteors.laws
    ..naturalEvents.clear()
    ..naturalEvents.add(population.EventKind.meteor);
  while (meteors.time < 5000) {
    meteors.step(ticks: 8);
  }
  final kinds = meteors.chronicle.entries.where((e) => nature.contains(e.kind)).map((e) => e.kind).toSet();
  check('population: with only meteors on, only meteors fall',
      kinds.length == 1 && kinds.single == population.EventKind.meteor,
      '${timesHappened(meteors, population.EventKind.meteor)} meteors in 5,000 years');

  final fight = population.World(seed: 2, civilizations: 4)..laws.naturalEvents.clear();
  while (fight.time < 100) {
    fight.step();
  }
  final declared = fight.war(years: 40);
  while (fight.time < 200) {
    fight.step(ticks: 3);
  }
  check('population: a declared war breaks out and ends in peace',
      declared &&
          happened(fight, population.EventKind.war) &&
          (happened(fight, population.EventKind.peace) ||
              fight.creatures.map((c) => c.species.civilization).toSet().length < 4));

  final eventful = run(4, 2, 3000, natural: true);
  final acts = eventful.chronicle.entries.where((e) => nature.contains(e.kind)).length;
  check("population: nature's acts happen now and then", acts >= 4 && acts <= 40, '$acts acts in 3,000 years');
  final samples = eventful.traits.length;
  check('population: history always covers year 0 to now',
      samples <= population.TraitHistory.maxSamples && (samples - 1) * eventful.traits.sampleEvery >= 3000 * 0.9,
      '$samples samples, one per ${eventful.traits.sampleEvery} years');
}

/// How many different peoples a chronicle line names.
int _peoplesNamed(String text) => population.civilizationNames.where((name) => RegExp('\\b$name\\b').hasMatch(text)).length;

void fractalChecks() {
  bool inside(Kind k, double x, double y, {double jr = 0, double ji = 0}) => escape(k, x, y, 2000, jr: jr, ji: ji) < 0;

  check('fractals: known points of the Mandelbrot set are in it',
      inside(Kind.mandelbrot, 0, 0) && inside(Kind.mandelbrot, -1, 0) && inside(Kind.mandelbrot, -0.1226, 0.7449) &&
          inside(Kind.mandelbrot, -1.7549, 0) && inside(Kind.mandelbrot, 0.25, 0));
  check('fractals: known points outside it escape',
      !inside(Kind.mandelbrot, 0.5, 0.5) && !inside(Kind.mandelbrot, -2.1, 0) && !inside(Kind.mandelbrot, 0.26, 0) &&
          !inside(Kind.mandelbrot, 0, 1.1));

  // The shortcut for the cardioid and bulb must agree with iterating.
  var disagree = 0;
  for (var i = 0; i < 4000; i++) {
    final x = -1.3 + (i % 80) / 80 * 1.6, y = -0.7 + (i ~/ 80) / 50 * 1.4;
    var zr = 0.0, zi = 0.0, n = 0;
    while (zr * zr + zi * zi <= 4 && n < 3000) {
      final t = zr * zr - zi * zi + x;
      zi = 2 * zr * zi + y;
      zr = t;
      n++;
    }
    if ((n >= 3000) != inside(Kind.mandelbrot, x, y)) disagree++;
  }
  check('fractals: the shortcut agrees with plain iteration', disagree <= 8, '$disagree of 4000 points differ');

  check('fractals: the Julia set of c = 0 is the unit disc',
      inside(Kind.julia, 0.7, 0.7) && !inside(Kind.julia, 0.72, 0.72) && inside(Kind.julia, -0.99, 0));

  final far = escape(Kind.mandelbrot, 2, 2, 100), near = escape(Kind.mandelbrot, -0.75, 0.05, 1000);
  check('fractals: points nearer the set take longer to escape', near > far * 5,
      '${far.toStringAsFixed(2)} vs ${near.toStringAsFixed(1)}');

  const view = View(Kind.mandelbrot, -0.6, 0, 3.5);
  final before = view.at(200, 150, 800, 500);
  final zoomed = view.zoomAt(200, 150, 800, 500, 3);
  final after = zoomed.at(200, 150, 800, 500);
  check('fractals: zooming keeps the point under the pointer',
      (before.$1 - after.$1).abs() < 1e-12 && (before.$2 - after.$2).abs() < 1e-12 && (zoomed.zoom / view.zoom - 3).abs() < 1e-9);
  check('fractals: zoom stops where doubles run out', view.zoomAt(0, 0, 800, 500, 1e20).span == View.deepest);
  check('fractals: deeper views get more iterations', view.iterations(1) < zoomed.iterations(1));
  // Every place in the menu should show detail, not a flat wash: across a
  // coarse grid of samples, the slow-to-escape tenth should take several
  // times longer than the quick tenth. (Counting "inside" points wouldn't do:
  // some Julia sets, like the dendrite, are all hairline and no inside.)
  for (final place in Place.all) {
    final v = place.view, limit = v.iterations(1);
    final values = [
      for (var i = 0; i < 48 * 30; i++)
        switch (v.at((i % 48) + 0.5, (i ~/ 48) + 0.5, 48, 30)) {
          (final re, final im) => escape(v.kind, re, im, limit, jr: v.jr, ji: v.ji),
        },
    ].map((nu) => nu < 0 ? limit.toDouble() : nu).toList()
      ..sort();
    final spread = values[1296] / values[144];
    check('fractals: "${place.name}" shows detail', spread > 5, 'slow tenth ${spread.toStringAsFixed(0)}× the quick');
  }
}

void lightChecks() {
  double deg(double d) => d * math.pi / 180;
  List<light.Hit> hits(List<light.Piece> pieces, {bool faint = true}) => (light.Bench('empty')
        ..faint = faint
        ..pieces.addAll(pieces))
      .trace()
      .hits;

  // Snell's law at every refraction in the standard scene.
  final refractions = light.Bench('Snell’s law').trace().hits.where((h) => h.event == light.Event.refraction).toList();
  final worst = refractions
      .map((h) => (h.n1 * math.sin(h.incidence) - h.n2 * math.sin(h.outgoing!)).abs())
      .fold(0.0, math.max);
  check('light: refraction obeys n1 sin θ1 = n2 sin θ2', refractions.length >= 2 && worst < 1e-9, 'off by $worst');

  // A mirror sends light back at the angle it came in.
  for (final a in [10.0, 33.0, 60.0]) {
    final h = hits([light.Laser(100, 300, white: false), light.Mirror(500, 300, angle: deg(a))]).first;
    check('light: a mirror at $a° reflects at the angle of incidence',
        h.event == light.Event.reflection && (h.incidence - h.outgoing!).abs() < 1e-9 && (h.incidence - deg(a)).abs() < 1e-9);
  }

  // Inside crown glass the critical angle is about 41°: just under it some
  // light gets out of the half disc, just over it none does.
  light.Hit flatFace(double at) {
    final aim = deg(-at);
    return hits([
      light.HalfDisc(520, 330, radius: 200, angle: math.pi),
      light.Laser(520 - 330 * math.cos(aim), 330 - 330 * math.sin(aim), angle: aim, white: false, nm: light.Medium.sodium),
    ], faint: false)
        .firstWhere((h) => (h.x - 520).abs() < 1e-6 && (h.y - 330).abs() < 1e-6);
  }

  final critical = light.HalfDisc(0, 0).critical(light.Medium.air) * 180 / math.pi;
  check('light: below the critical angle light gets out', flatFace(critical - 1).event == light.Event.refraction,
      'critical ${critical.toStringAsFixed(2)}°');
  check('light: past the critical angle it all reflects', flatFace(critical + 1).event == light.Event.totalInternal);

  // Fresnel: at normal incidence glass reflects ((n − 1) / (n + 1))², 4%.
  final normal = hits([light.Laser(100, 300, white: false, nm: light.Medium.sodium), light.Block(500, 300)]).first;
  final expected = math.pow((1.517 - 1.0003) / (1.517 + 1.0003), 2);
  check('light: glass head on reflects about 4%', (normal.reflected - expected).abs() < 1e-9,
      '${(normal.reflected * 100).toStringAsFixed(2)}%');

  // A prism bends violet further than red.
  double leaving(double nm) {
    final exit = hits([light.Laser(90, 470, angle: deg(-24), white: false, nm: nm), light.Prism(420, 330)], faint: false)
        .where((h) => h.event == light.Event.refraction)
        .elementAt(1);
    return math.atan2(exit.oy!, exit.ox!);
  }

  check('light: a prism bends violet more than red', leaving(410) > leaving(680) + deg(1),
      '${((leaving(410) - leaving(680)) * 180 / math.pi).toStringAsFixed(2)}° apart');

  // A thin lens brings a narrow parallel beam to a focus at f.
  final lens = light.Lens(400, 310, height: 200, radius: 900);
  final focus = (light.Bench('empty')
        ..faint = false
        ..pieces.addAll([light.Laser(100, 310, white: false, nm: light.Medium.sodium, beam: 30), lens]))
      .trace();
  final f = lens.focal(light.Medium.air);
  final beyond = focus.segments.where((s) => s.x1 > 400 && (s.y1 - 310).abs() > 1);
  final crossings = [for (final s in beyond) s.x1 + (310 - s.y1) * (s.x2 - s.x1) / (s.y2 - s.y1)];
  final meanCross = crossings.reduce((a, b) => a + b) / crossings.length;
  check('light: a lens focuses at its focal length', (meanCross - (400 + f)).abs() < f * 0.02,
      'f ${f.toStringAsFixed(1)}, rays cross at ${(meanCross - 400).toStringAsFixed(1)}');

  // A grating's first order leaves at sin θ = λ / d.
  final grating = (light.Bench('empty')
        ..pieces.addAll([light.Laser(100, 310, white: false, nm: 500), light.Grating(400, 310, lines: 500)]))
      .trace();
  final orders = grating.segments.where((s) => (s.x1 - 400).abs() < 1e-6).toList();
  final firstOrder = math.asin(500 / 2000);
  check('light: a grating sends order 1 to sin θ = λ/d',
      orders.any((s) => (math.atan2(s.y2 - s.y1, s.x2 - s.x1).abs() - firstOrder).abs() < 1e-9),
      '${orders.length} orders');

  // A splitter's two halves carry all the light between them.
  final split = (light.Bench('empty')
        ..pieces.addAll([light.Laser(100, 300, white: false), light.Splitter(400, 300, angle: deg(45), reflect: 0.3)]))
      .trace();
  final after = split.segments.where((s) => (s.x1 - 400).abs() < 1e-6).map((s) => s.intensity).toList()..sort();
  check('light: a splitter shares light out, none lost',
      after.length == 2 && (after[0] - 0.3).abs() < 1e-12 && (after[1] - 0.7).abs() < 1e-12, '$after');

  // White light's colours add up to white.
  final sum = light.whiteLight.map((w) => w.colour).reduce((a, b) => a + b);
  check('light: the spectrum adds up to white', (sum.r - sum.g).abs() < 1e-9 && (sum.g - sum.b).abs() < 1e-9);

  // Every piece in the add row has a shape, and can be picked up by it.
  for (final MapEntry(key: name, value: make) in light.catalogue.entries) {
    final piece = make(500, 300);
    check('light: a $name has a shape and can be picked up', piece.edges().isNotEmpty && piece.contains(500, 300, 2));
  }

  for (final scene in light.scenes.keys) {
    final t = light.Bench(scene).trace();
    check('light: the "$scene" scene traces', !t.cut && (scene == 'empty' || t.hits.isNotEmpty), '${t.rays} rays');
  }
}
