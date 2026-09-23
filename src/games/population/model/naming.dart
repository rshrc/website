import 'dart:math' as math;

import 'genes.dart';
import 'species.dart';

/// Species names, the way naturalists give them: two words, the first for
/// the lineage (here, the founding civilization) and the second for what
/// sets this species apart — *Aru ferox*, the fierce Aru; *Belen gelidus*,
/// the Belen built for cold.

/// Epithets for each way a new species can differ from its parent, as
/// (more, less).
const _speedWords = ('velox', 'tardus'),
    _sizeWords = ('magnus', 'minor'),
    _sightWords = ('oculatus', 'myops'),
    _aggressionWords = ('ferox', 'mitis'),
    _climateWords = ('calidus', 'gelidus');

const _shapeWords = {
  Shape.round: 'rotundus',
  Shape.pointed: 'acutus',
  Shape.square: 'quadratus',
  Shape.spiky: 'spinosus',
  Shape.crescent: 'lunatus',
};

/// For where it split off, when nothing about its body stands out.
const _placeWords = {
  'north': 'borealis',
  'south': 'australis',
  'east': 'orientalis',
  'west': 'occidentalis',
  'heartland': 'centralis',
};

/// The second word of [child]'s name: whatever most clearly sets it apart
/// from [parent]; failing a clear difference, where it went ([compassPoint],
/// if it moved away); failing that, its biggest difference even if slight;
/// and only if there's truly nothing, "novus", new. A name already taken in
/// the lineage gets a numeral: *Aru ferox II*.
///
/// Colour counts as a difference too: the neutral tint gene drifts, and a
/// species can part from its parent on little else. Those are "discolor",
/// differently coloured.
String epithetFor(Species child, Species parent, {String? compassPoint, required List<Species> lineage}) {
  // How strongly each difference shows, 1 being just noticeable.
  double ratio(double a, double b) => (a / b - 1).abs() / 0.15;
  final candidates = <(double, String)>[
    (ratio(child.averageSpeed, parent.averageSpeed), _pick(child.averageSpeed > parent.averageSpeed, _speedWords)),
    (ratio(child.averageSize, parent.averageSize), _pick(child.averageSize > parent.averageSize, _sizeWords)),
    (ratio(child.averageSight, parent.averageSight), _pick(child.averageSight > parent.averageSight, _sightWords)),
    (
      (child.averageAggression - parent.averageAggression).abs() / 0.1,
      _pick(child.averageAggression > parent.averageAggression, _aggressionWords)
    ),
    (
      (child.averageIdealClimate - parent.averageIdealClimate).abs() / 0.1,
      _pick(child.averageIdealClimate > parent.averageIdealClimate, _climateWords)
    ),
    // A new body is the most visible change of all; colour, the least
    // telling, needs a bigger shift to count.
    if (child.commonestBody != parent.commonestBody)
      (1.5, _shapeWords[child.commonestBody.isHybrid ? child.commonestBody.second : child.commonestBody.first]!),
    ((child.averageTint - parent.averageTint).abs() / 1.2, 'discolor'),
  ]..sort((a, b) => b.$1.compareTo(a.$1));

  final (strength, strongest) = candidates.first;
  final place = compassPoint == null ? null : _placeWords[compassPoint.split('-').first];
  final word = strength >= 1 ? strongest : (place ?? (strength >= 0.25 ? strongest : 'novus'));

  final taken = lineage.where((s) => s.epithet == word || (s.epithet?.startsWith('$word ') ?? false)).length;
  return taken == 0 ? word : '$word ${_romanNumeral(math.min(taken + 1, 3999))}';
}

String _pick(bool more, (String, String) words) => more ? words.$1 : words.$2;

String _romanNumeral(int n) {
  const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1],
      numerals = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
  final out = StringBuffer();
  for (var i = 0; i < values.length; i++) {
    while (n >= values[i]) {
      out.write(numerals[i]);
      n -= values[i];
    }
  }
  return out.toString();
}
