import 'dart:math' as math;

/// Two civilizations, the lower number first, so each pair has one key.
typedef CivilizationPair = (int, int);

CivilizationPair pairOf(int a, int b) => (math.min(a, b), math.max(a, b));

/// A war under way.
class War {
  final double began;

  /// The earliest it can end: a war runs its course, however it's going.
  final double earliestEnd;

  /// Deaths so far.
  int dead;

  War({required this.began, required this.earliestEnd, this.dead = 0});
}

/// Who is at war with whom, who has made peace, and whose creatures are in
/// contact. Pure bookkeeping: the world decides when things start and end,
/// and writes the chronicle.
class Diplomacy {
  final Map<CivilizationPair, War> wars = {};

  /// Kills between each pair since the last review.
  final Map<CivilizationPair, int> killsSinceReview = {};

  /// After a peace, the year before which the pair won't drift back into
  /// war on their own.
  final Map<CivilizationPair, double> truceUntil = {};

  /// Pairs whose creatures are in contact, and until when: all through a
  /// war — raids, captives, pillage — and for a century after the peace.
  /// Their creatures can mate, where their genes are close enough.
  final Map<CivilizationPair, double> inContactUntil = {};

  /// [wars] and [inContactUntil], looked up by civilization, for the
  /// questions asked every step.
  final Map<int, Set<int>> _enemies = {}, _inContactWith = {};

  void clear() {
    wars.clear();
    killsSinceReview.clear();
    truceUntil.clear();
    inContactUntil.clear();
    _enemies.clear();
    _inContactWith.clear();
  }

  bool atWar(int a, int b) => wars.containsKey(pairOf(a, b));

  /// The civilizations [civilization] is at war with, or null in peacetime.
  Set<int>? enemiesOf(int civilization) => _enemies[civilization];

  /// The other civilizations [civilization]'s creatures are in contact with.
  Set<int>? inContactWith(int civilization) => _inContactWith[civilization];

  bool inContact(int a, int b) => _inContactWith[a]?.contains(b) ?? false;

  void recordKill(int a, int b) {
    final pair = pairOf(a, b);
    killsSinceReview[pair] = (killsSinceReview[pair] ?? 0) + 1;
  }

  /// Starts [war] between [pair], and brings their creatures into contact
  /// for as long as it lasts.
  void startWar(CivilizationPair pair, War war) {
    wars[pair] = war;
    inContactUntil[pair] = double.infinity;
  }

  /// Ends the war between [pair] in [year], with a truce and a century of
  /// contact after.
  void makePeace(CivilizationPair pair, double year) {
    wars.remove(pair);
    truceUntil[pair] = year + 150;
    inContactUntil[pair] = year + 100;
  }

  bool inTruce(CivilizationPair pair, double year) => year < (truceUntil[pair] ?? 0);

  /// Brings the lookups up to date with [wars] and [inContactUntil],
  /// forgetting contact that has lapsed by [year].
  void refresh(double year) {
    _enemies.clear();
    for (final (a, b) in wars.keys) {
      (_enemies[a] ??= {}).add(b);
      (_enemies[b] ??= {}).add(a);
    }
    inContactUntil.removeWhere((pair, until) => year >= until);
    _inContactWith.clear();
    for (final (a, b) in inContactUntil.keys) {
      (_inContactWith[a] ??= {}).add(b);
      (_inContactWith[b] ??= {}).add(a);
    }
  }
}
