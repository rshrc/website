import 'dart:math' as math;
import 'dart:typed_data';

import '../../shared/rng.dart';
import 'creature.dart';
import 'genes.dart';

/// How a species splits in two.
///
/// Its members are sorted into two clusters in gene space (k-means, k = 2).
/// It's a split if the clusters are too far apart to interbreed
/// ([incompatibleAt]), with a clear gap between them compared with how
/// spread out each is, and each cluster is big enough to matter.

/// Species smaller than this are never checked.
const _smallestToSplit = 40;

/// Neither side of a split may be smaller than this.
const _smallestSide = 12;

/// A few hundred members tell the shape of a species as well as thousands
/// would. The decision is made on a sample this big; only a real split
/// looks at everyone.
const _sampleSize = 300;

/// The members who should leave to form a new species — the smaller of the
/// two clusters — or null if [members] still belong together.
List<Creature>? findBreakaway(List<Creature> members, Rng rng, {required double incompatibleAt}) {
  if (members.length < _smallestToSplit) return null;
  final dims = GeneSpace.dimensions;

  final sampled = math.min(members.length, _sampleSize);
  final points = Float64List(sampled * dims);
  for (var i = 0; i < sampled; i++) {
    final member = members.length <= _sampleSize ? members[i] : members[rng.nextInt(members.length)];
    GeneSpace.write(member.genes, points, i * dims);
  }

  final (centreA, centreB) = _farApartPair(points, sampled, rng);
  if (!_settleClusters(points, sampled, centreA, centreB)) return null;

  // How tightly each sampled point sits around its own centre, against how
  // far apart the centres are.
  var squaredSpread = 0.0, sampledInB = 0;
  for (var i = 0; i < sampled; i++) {
    final toA = GeneSpace.distanceSquared(points, i * dims, centreA, 0),
        toB = GeneSpace.distanceSquared(points, i * dims, centreB, 0);
    squaredSpread += math.min(toA, toB);
    if (toB < toA) sampledInB++;
  }
  final spread = math.sqrt(squaredSpread / sampled);
  final gap = math.sqrt(GeneSpace.distanceSquared(centreA, 0, centreB, 0));
  if (gap < incompatibleAt || gap < 2.5 * spread || math.min(sampledInB, sampled - sampledInB) < _smallestSide) {
    return null;
  }

  // A split: now sort everyone.
  final point = Float64List(dims);
  final inB = List<bool>.filled(members.length, false);
  var countB = 0;
  for (var i = 0; i < members.length; i++) {
    GeneSpace.write(members[i].genes, point, 0);
    inB[i] = GeneSpace.distanceSquared(point, 0, centreB, 0) < GeneSpace.distanceSquared(point, 0, centreA, 0);
    if (inB[i]) countB++;
  }
  if (math.min(countB, members.length - countB) < _smallestSide) return null;
  final smallerIsB = countB <= members.length - countB;
  return [
    for (var i = 0; i < members.length; i++)
      if (inB[i] == smallerIsB) members[i],
  ];
}

/// Two sampled points far apart, as starting centres: from a random point,
/// the farthest from it, then the farthest from that, twice over; then the
/// farthest from where that ends.
(Float64List, Float64List) _farApartPair(Float64List points, int count, Rng rng) {
  final dims = GeneSpace.dimensions;
  int farthestFrom(Float64List from, int offset) {
    var farthest = -1.0, pick = offset ~/ dims;
    for (var i = 0; i < count; i++) {
      final d = GeneSpace.distanceSquared(points, i * dims, from, offset);
      if (d > farthest) {
        farthest = d;
        pick = i;
      }
    }
    return pick;
  }

  var far = rng.nextInt(count);
  for (var k = 0; k < 2; k++) {
    far = farthestFrom(points, far * dims);
  }
  final centreA = Float64List(dims)..setRange(0, dims, points, far * dims);
  final other = _farthestFromCentre(points, count, centreA, far);
  final centreB = Float64List(dims)..setRange(0, dims, points, other * dims);
  return (centreA, centreB);
}

int _farthestFromCentre(Float64List points, int count, Float64List centre, int fallback) {
  final dims = GeneSpace.dimensions;
  var farthest = -1.0, pick = fallback;
  for (var i = 0; i < count; i++) {
    final d = GeneSpace.distanceSquared(points, i * dims, centre, 0);
    if (d > farthest) {
      farthest = d;
      pick = i;
    }
  }
  return pick;
}

/// Ten rounds of k-means: each point joins the nearer centre, then each
/// centre moves to the middle of its points. False if a side empties.
bool _settleClusters(Float64List points, int count, Float64List centreA, Float64List centreB) {
  final dims = GeneSpace.dimensions;
  final totalA = Float64List(dims), totalB = Float64List(dims);
  for (var round = 0; round < 10; round++) {
    totalA.fillRange(0, dims, 0);
    totalB.fillRange(0, dims, 0);
    var countA = 0, countB = 0;
    for (var i = 0; i < count; i++) {
      final nearerB = GeneSpace.distanceSquared(points, i * dims, centreB, 0) <
          GeneSpace.distanceSquared(points, i * dims, centreA, 0);
      final total = nearerB ? totalB : totalA;
      for (var k = 0; k < dims; k++) {
        total[k] += points[i * dims + k];
      }
      nearerB ? countB++ : countA++;
    }
    if (countA == 0 || countB == 0) return false;
    for (var k = 0; k < dims; k++) {
      centreA[k] = totalA[k] / countA;
      centreB[k] = totalB[k] / countB;
    }
  }
  return true;
}
