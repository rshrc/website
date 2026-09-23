import 'dart:math' as math;
import 'dart:typed_data';

import '../../shared/rng.dart';

/// Body shapes. A creature carries two shape alleles, one from each parent,
/// and now and then one mutates into another. Each shape helps somewhere
/// different, so which shapes thrive depends on where, and how, you live.
enum Shape {
  /// Least surface for its size, so the wrong climate costs far less. A
  /// little clumsy on the move.
  round('round', 'weathers any climate'),

  /// Streamlined: moving costs much less. Weak in a fight.
  pointed('pointed', 'cheap to move'),

  /// Sturdy: wins fights, and lives longer. Heavy to move.
  square('square', 'strong and long-lived'),

  /// Rarely killed in a fight, hurts whoever attacks it, and shrugs off
  /// plagues more often. The spines cost energy to grow.
  spiky('spiky', 'hard to kill'),

  /// A scoop of a mouth: eats faster. A little slower.
  crescent('crescent', 'eats fast');

  final String label, advantage;

  const Shape(this.label, this.advantage);
}

/// A body: a pair of shape alleles, whichever parent each came from. Two
/// bodies with the same pair are the same body, in either order.
///
/// There's exactly one [Body] for each pair, made once and handed out by
/// [Body.of], so bodies compare by identity. The census counts every
/// creature's body every step; this keeps that cheap.
class Body {
  /// The pair, the shape listed first in [Shape] always first.
  final Shape first, second;

  Body._(this.first, this.second);

  factory Body.of(Shape a, Shape b) => _every[a.index * Shape.values.length + b.index];

  factory Body.pure(Shape shape) => Body.of(shape, shape);

  static final _every = [
    for (final a in Shape.values)
      for (final b in Shape.values) a.index <= b.index ? Body._(a, b) : Body._(b, a),
  ];

  bool get isHybrid => first != second;

  @override
  String toString() => '($first, $second)';
}

/// A creature's genes: five numbers and two shape alleles. Most are
/// trade-offs; [tint] is neutral and drifts freely.
class Genes {
  /// Top speed, px a year. Reaches food first; muscle costs the square of it.
  final double speed;

  /// Body size. Stores more, eats bigger bites, wins fights; costs more.
  final double size;

  /// How far it sees food and mates, px. A steady cost.
  final double sight;

  /// 0 to 1: how readily it fights creatures of other civilizations. Winning
  /// feeds you; the temper costs energy all the time.
  final double aggression;

  /// A neutral marker with no effect on survival. It changes a little in
  /// every birth and is only ever passed on, so it drifts: populations kept
  /// apart slowly come to differ in it, which you see as their colour.
  final double tint;

  /// 0 to 1: the climate it's built for, from cold (0) to hot (1). Living
  /// somewhere hotter or colder costs energy, more the further off.
  final double idealClimate;

  /// The two shape alleles, in the order they were inherited.
  final Shape firstShape, secondShape;

  const Genes({
    required this.speed,
    required this.size,
    required this.sight,
    required this.aggression,
    this.tint = 0,
    this.idealClimate = 0.5,
    this.firstShape = Shape.round,
    this.secondShape = Shape.round,
  });

  /// The bounds mutation keeps the body genes within.
  static const _speedLimits = (6.0, 140.0), _sizeLimits = (0.4, 2.5), _sightLimits = (10.0, 200.0);

  /// A random starting strategy, from a range that can make a living, so an
  /// early death comes from competition rather than a hopeless roll.
  factory Genes.founder(Rng rng, {required double idealClimate, required Shape shape}) => Genes(
        speed: rng.range(28, 48),
        size: rng.range(0.8, 1.2),
        sight: rng.range(35, 70),
        aggression: rng.range(0.02, 0.35),
        idealClimate: idealClimate,
        firstShape: shape,
        secondShape: shape,
      );

  /// A child of two parents: each gene is inherited whole from one parent or
  /// the other, like an allele, and one shape allele comes from each.
  factory Genes.cross(Genes parent, Genes partner, Rng rng) => Genes(
        speed: rng.chance(0.5) ? parent.speed : partner.speed,
        size: rng.chance(0.5) ? parent.size : partner.size,
        sight: rng.chance(0.5) ? parent.sight : partner.sight,
        aggression: rng.chance(0.5) ? parent.aggression : partner.aggression,
        tint: rng.chance(0.5) ? parent.tint : partner.tint,
        idealClimate: rng.chance(0.5) ? parent.idealClimate : partner.idealClimate,
        firstShape: rng.chance(0.5) ? parent.firstShape : parent.secondShape,
        secondShape: rng.chance(0.5) ? partner.firstShape : partner.secondShape,
      );

  /// How much of the body is [shape]: none, half, or all of it.
  double share(Shape shape) => (firstShape == shape ? 0.5 : 0) + (secondShape == shape ? 0.5 : 0);

  Body get body => Body.of(firstShape, secondShape);

  bool get isHybrid => firstShape != secondShape;

  /// A copy with every gene nudged by up to [rate]. The body genes are
  /// multiplied by e^noise, which keeps them positive and makes a 10%
  /// change as likely for big values as small; the rest are nudged up or
  /// down. A different shape is a rare, all-at-once change of one allele,
  /// and only when [shapesEvolve].
  Genes mutate(Rng rng, double rate, {required bool shapesEvolve}) {
    double scaled(double value, (double, double) limits) =>
        (value * math.exp(rng.gaussian(0, rate))).clamp(limits.$1, limits.$2);
    Shape maybeChange(Shape shape) =>
        shapesEvolve && rng.chance(rate * 0.3) ? Shape.values[rng.nextInt(Shape.values.length)] : shape;
    return Genes(
      speed: scaled(speed, _speedLimits),
      size: scaled(size, _sizeLimits),
      sight: scaled(sight, _sightLimits),
      aggression: (aggression + rng.gaussian(0, rate * 0.8)).clamp(0.0, 1.0),
      tint: tint + rng.gaussian(0, rate * 4),
      idealClimate: (idealClimate + rng.gaussian(0, rate * 0.4)).clamp(0.0, 1.0),
      firstShape: maybeChange(firstShape),
      secondShape: maybeChange(secondShape),
    );
  }

  /// How different two creatures are; see [GeneSpace]. Written out rather
  /// than built from [GeneSpace.write], because it runs for every candidate
  /// mate.
  double distanceTo(Genes other) {
    final speedGap = math.log(speed / other.speed) / GeneSpace.bodyStep,
        sizeGap = math.log(size / other.size) / GeneSpace.bodyStep,
        sightGap = math.log(sight / other.sight) / GeneSpace.bodyStep,
        aggressionGap = (aggression - other.aggression) / GeneSpace.aggressionStep,
        tintGap = tint - other.tint,
        climateGap = (idealClimate - other.idealClimate) / GeneSpace.climateStep;
    var shapeGapSquared = 0.0;
    for (final shape in Shape.values) {
      final gap = (share(shape) - other.share(shape)) * GeneSpace.shapeWeight;
      shapeGapSquared += gap * gap;
    }
    return math.sqrt(speedGap * speedGap +
        sizeGap * sizeGap +
        sightGap * sightGap +
        aggressionGap * aggressionGap +
        tintGap * tintGap +
        climateGap * climateGap +
        shapeGapSquared);
  }
}

/// Genes as a point in space, scaled so that one unit is roughly
/// "noticeably different": 20% in a body gene, 0.2 of aggression, 1 of
/// tint, 0.15 of climate. Each shape is an axis of its own.
abstract final class GeneSpace {
  static const bodyStep = 0.2, aggressionStep = 0.2, climateStep = 0.15;

  /// Two different pure shapes sit one unit apart.
  static const shapeWeight = 0.7071;

  static final dimensions = 6 + Shape.values.length;

  /// Writes [genes]' point into [out], starting at [offset].
  static void write(Genes genes, Float64List out, int offset) {
    out[offset] = math.log(genes.speed) / bodyStep;
    out[offset + 1] = math.log(genes.size) / bodyStep;
    out[offset + 2] = math.log(genes.sight) / bodyStep;
    out[offset + 3] = genes.aggression / aggressionStep;
    out[offset + 4] = genes.tint;
    out[offset + 5] = genes.idealClimate / climateStep;
    for (var k = 0; k < Shape.values.length; k++) {
      out[offset + 6 + k] = genes.share(Shape.values[k]) * shapeWeight;
    }
  }

  /// The squared distance between the point in [a] at [offsetA] and the
  /// one in [b] at [offsetB].
  static double distanceSquared(Float64List a, int offsetA, Float64List b, int offsetB) {
    var sum = 0.0;
    for (var k = 0; k < dimensions; k++) {
      final gap = a[offsetA + k] - b[offsetB + k];
      sum += gap * gap;
    }
    return sum;
  }
}
