import 'dart:math' as math;
import 'dart:typed_data';

import '../../shared/rng.dart';

/// How big the land is, in world pixels.
enum LandSize {
  small(800, 520, 5000),
  medium(1100, 700, 5000),
  large(1600, 1000, 7000),
  huge(2400, 1500, 10000);

  final double width, height;

  /// The most creatures it may hold. Food runs out long before this in
  /// almost every world; it's a guard against a world so fertile the page
  /// would grind to a halt.
  final int creatureLimit;

  const LandSize(this.width, this.height, this.creatureLimit);
}

/// A fertile valley: a patch of good land fading out into desert.
class Valley {
  final double x, y;

  /// How far out, roughly, it stays fertile.
  final double spread;

  /// 0.3 to 1: how lush it is at its heart.
  final double richness;

  /// 0 (cold) to 1 (hot).
  final double climate;

  const Valley({required this.x, required this.y, required this.spread, required this.richness, required this.climate});
}

/// The land: a grid of square patches, each with its fertility, the food
/// growing on it now, and its climate. The edges wrap around, so walking
/// off the east edge brings you back from the west.
///
/// The land can also be disturbed, patch by patch: soaked by rain until it
/// floods, dried to dust, or scarred by a meteor. Disturbed land heals back
/// to how nature made it: moisture over a few generations and scars over a
/// century or so.
class Terrain {
  static const patchSize = 10.0;

  /// Food capacity below this is desert.
  static const desertBelow = 0.1;

  /// Moisture above this is flood.
  static const floodAbove = 1.8;

  /// Moisture can't rise past this, however hard it rains.
  static const wettest = 3.0;

  /// Years for disturbed moisture, and for meteor scars, to heal halfway.
  static const moistureHalfLife = 50.0, scarHalfLife = 60.0;

  final double width, height;
  final int columns, rows;

  /// Each patch's fertility: the most food it can hold.
  final Float64List fertility;

  /// The food on each patch now, up to its [fertility].
  final Float64List food;

  /// Each patch's climate, 0 (cold) to 1 (hot): the climate of the valley it
  /// belongs to, blending across the desert between.
  final Float64List climate;

  final List<Valley> valleys;

  /// Each patch's moisture: 1 as nature made it, 0 dust, above [floodAbove]
  /// flooded. Changes more food can grow, up to a point; see [capacity].
  final Float64List moisture;

  /// How healed each patch is from meteor strikes: 1 untouched, near 0 a
  /// fresh crater's heart.
  final Float64List health;

  /// Whether any patch is soaked, dried or scarred. While none is, growing
  /// skips the work of healing them.
  bool get isDisturbed => _isDisturbed;
  bool _isDisturbed = false;

  /// Whether anything has soaked, dried or scarred the land since it last
  /// grew; while it's still being worked on, it isn't called healed however
  /// slight the change.
  bool _touchedSinceGrowth = false;

  /// How many degrees one unit of climate is, for the page: the whole range
  /// from the coldest valley to the hottest is about forty degrees.
  static const degreesPerUnit = 40.0;

  /// The average climate over every patch, before any climate change.
  late final double meanClimate = climate.fold(0.0, (sum, c) => sum + c) / climate.length;

  Terrain._(this.width, this.height, this.columns, this.rows, this.valleys)
      : fertility = Float64List(columns * rows),
        food = Float64List(columns * rows),
        climate = Float64List(columns * rows),
        moisture = Float64List(columns * rows)..fillRange(0, columns * rows, 1),
        health = Float64List(columns * rows)..fillRange(0, columns * rows, 1);

  /// New land of [size]: valleys, each with a character of its own — some
  /// lush, some lean — and near-barren desert between them. In a lush valley
  /// it pays to sit and eat; in a lean one, to move and look. Populations in
  /// different valleys get pushed different ways, which is how species
  /// split. Every patch starts fully grown.
  factory Terrain.grow(LandSize size, Rng rng) {
    final width = size.width, height = size.height;
    final valleyCount = (12 * width * height / (1100 * 700)).round();
    final valleys = List.generate(
        valleyCount,
        (_) => Valley(
            x: rng.range(0, width),
            y: rng.range(0, height),
            spread: rng.range(77, 143),
            richness: rng.range(0.3, 1.0),
            climate: rng.nextDouble()));
    final terrain =
        Terrain._(width, height, (width / patchSize).ceil(), (height / patchSize).ceil(), valleys);
    terrain._shapeValleys();
    terrain.food.setAll(0, terrain.fertility);
    return terrain;
  }

  void _shapeValleys() {
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final x = (column + 0.5) * patchSize, y = (row + 0.5) * patchSize;
        // The nearest valley's pull sets the fertility; every valley's pull
        // blends into the climate.
        var strongestPull = 0.0, richness = 0.0, pullWeight = 0.0, weightedClimate = 0.0;
        for (final valley in valleys) {
          final dx = wrapDelta(x - valley.x, width), dy = wrapDelta(y - valley.y, height);
          final pull = math.exp(-(dx * dx + dy * dy) / (2 * valley.spread * valley.spread));
          if (pull > strongestPull) {
            strongestPull = pull;
            richness = valley.richness;
          }
          pullWeight += pull * pull;
          weightedClimate += pull * pull * valley.climate;
        }
        final index = row * columns + column;
        climate[index] = pullWeight > 0 ? weightedClimate / pullWeight : 0.5;
        // A smooth step from desert to valley floor.
        final rise = ((strongestPull - 0.3) / 0.4).clamp(0.0, 1.0);
        fertility[index] = 0.03 + 0.97 * rise * rise * (3 - 2 * rise) * richness;
      }
    }
  }

  /// The most food [patch] can hold now: its fertility, changed by how wet
  /// it is and how scarred.
  double capacity(int patch) => fertility[patch] * wetnessFactor(moisture[patch]) * health[patch];

  /// How moisture changes what can grow. Drier land grows less, down to a
  /// tenth at dust; wetter land more, up to half as much again at the flood
  /// line; past it, flooded land grows ever less.
  static double wetnessFactor(double moisture) {
    if (moisture <= 1) return 0.1 + 0.9 * moisture;
    if (moisture <= floodAbove) return 1 + 0.5 * (moisture - 1) / (floodAbove - 1);
    return math.max(0.05, 1.5 - 2 * (moisture - floodAbove));
  }

  bool isFlooded(int patch) => moisture[patch] > floodAbove;

  /// Whether crossing [patch] is hard going: desert, or flood.
  bool isHarsh(int patch) => capacity(patch) < desertBelow || isFlooded(patch);

  /// Grows food back over [years]: each patch recovers [amount] of what it's
  /// missing, plus a trickle, never past its [capacity]. Disturbed land also
  /// heals a little, and food it can no longer hold dies back.
  void regrow(double amount, double years) {
    final food = this.food, fertility = this.fertility;
    if (!_isDisturbed) {
      for (var i = 0; i < food.length; i++) {
        final most = fertility[i], now = food[i];
        if (now < most) food[i] = math.min(most, now + (most - now) * amount + 0.002 * amount);
      }
      return;
    }
    final moistureEase = 1 - math.pow(0.5, years / moistureHalfLife);
    final scarEase = 1 - math.pow(0.5, years / scarHalfLife);
    var furthestFromNature = 0.0;
    for (var i = 0; i < food.length; i++) {
      moisture[i] += (1 - moisture[i]) * moistureEase;
      health[i] += (1 - health[i]) * scarEase;
      furthestFromNature = math.max(furthestFromNature, math.max((moisture[i] - 1).abs(), 1 - health[i]));
      final most = capacity(i), now = food[i];
      if (now < most) {
        food[i] = math.min(most, now + (most - now) * amount + 0.002 * amount);
      } else if (now > most) {
        food[i] = most;
      }
    }
    final leftAlone = !_touchedSinceGrowth;
    _touchedSinceGrowth = false;
    // Close enough to nature, and left alone, to call it healed.
    if (furthestFromNature < 0.01 && leftAlone) {
      moisture.fillRange(0, moisture.length, 1);
      health.fillRange(0, health.length, 1);
      _isDisturbed = false;
    }
  }

  /// Strips every patch within [radius] of ([x], [y]) bare, and scars it:
  /// worst at the middle, healing over the next century or so.
  void strip(double x, double y, double radius) {
    _forPatchesNear(x, y, radius, (patch, closeness) {
      food[patch] = 0;
      health[patch] = math.min(health[patch], 0.1 + 0.9 * (1 - closeness) * (1 - closeness));
    });
    _isDisturbed = _touchedSinceGrowth = true;
  }

  /// Rains on the land within [radius] of ([x], [y]), by [amount] of
  /// moisture at the middle and less towards the edge; a negative [amount]
  /// dries it instead.
  void soak(double x, double y, double radius, double amount) {
    _forPatchesNear(x, y, radius, (patch, closeness) {
      moisture[patch] = (moisture[patch] + amount * closeness).clamp(0.0, wettest);
    });
    _isDisturbed = _touchedSinceGrowth = true;
  }

  /// Calls [visit] for every patch within [radius] of ([x], [y]), with how
  /// close to the middle it is: 1 at the middle, 0 at the edge.
  void _forPatchesNear(double x, double y, double radius, void Function(int patch, double closeness) visit) {
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final dx = wrapDelta((column + 0.5) * patchSize - x, width),
            dy = wrapDelta((row + 0.5) * patchSize - y, height);
        final squared = dx * dx + dy * dy;
        if (squared < radius * radius) visit(row * columns + column, 1 - math.sqrt(squared) / radius);
      }
    }
  }

  /// How much of the land's food is growing, 0 to 1.
  double get greenery {
    var growing = 0.0, possible = 0.0;
    for (var i = 0; i < food.length; i++) {
      growing += food[i];
      possible += fertility[i];
    }
    return growing / possible;
  }

  /// The index of the patch under ([x], [y]), wrapping around the edges.
  /// Points can be up to a creature's sight beyond the edge, never a whole
  /// map, so a couple of comparisons do what a modulo would, faster.
  int patchAt(double x, double y) {
    var column = (x / patchSize).floor(), row = (y / patchSize).floor();
    if (column >= columns) {
      column -= columns;
    } else if (column < 0) {
      column += columns;
    }
    if (row >= rows) {
      row -= rows;
    } else if (row < 0) {
      row += rows;
    }
    return row * columns + column;
  }

  double foodAt(double x, double y) => food[patchAt(x, y)];

  double wrapX(double x) => x >= width ? x - width : (x < 0 ? x + width : x);
  double wrapY(double y) => y >= height ? y - height : (y < 0 ? y + height : y);

  /// The shortest way across a wrapping [span] to cover [delta].
  static double wrapDelta(double delta, double span) =>
      delta > span / 2 ? delta - span : (delta < -span / 2 ? delta + span : delta);

  /// The squared distance between two points, the short way round.
  double distanceSquared(double x1, double y1, double x2, double y2) {
    final dx = wrapDelta(x1 - x2, width), dy = wrapDelta(y1 - y2, height);
    return dx * dx + dy * dy;
  }

  /// Where each of [count] civilizations starts: the middle of a valley of
  /// its own, richest valleys first, each as far from the others as the land
  /// allows. With more civilizations than valleys, some have to share.
  List<(double, double)> pickHomes(int count, Rng rng) {
    final richestFirst = [...valleys]..sort((a, b) => b.richness.compareTo(a.richness));
    final homes = <(double, double)>[];
    while (homes.length < count) {
      final unclaimed = richestFirst.where((v) => !homes.contains((v.x, v.y))).toList();
      if (unclaimed.isEmpty) {
        final shared = richestFirst[homes.length % richestFirst.length];
        homes.add(((shared.x + rng.gaussian(0, 40)) % width, (shared.y + rng.gaussian(0, 40)) % height));
        continue;
      }
      // Rich, and far from the homes already taken.
      double appeal(Valley valley) {
        var nearestHome = width + height;
        for (final (homeX, homeY) in homes) {
          final dx = wrapDelta(valley.x - homeX, width), dy = wrapDelta(valley.y - homeY, height);
          nearestHome = math.min(nearestHome, math.sqrt(dx * dx + dy * dy));
        }
        return valley.richness * nearestHome;
      }

      final best = unclaimed.reduce((a, b) => appeal(a) >= appeal(b) ? a : b);
      homes.add((best.x, best.y));
    }
    return homes;
  }

  /// "north-east", "west", or "heartland" for the middle.
  String compassPoint(double x, double y) {
    final northSouth = y < height / 3 ? 'north' : (y > height * 2 / 3 ? 'south' : '');
    final eastWest = x < width / 3 ? 'west' : (x > width * 2 / 3 ? 'east' : '');
    if (northSouth.isEmpty && eastWest.isEmpty) return 'heartland';
    return northSouth.isEmpty || eastWest.isEmpty ? '$northSouth$eastWest' : '$northSouth-$eastWest';
  }
}
