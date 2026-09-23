import 'death.dart';
import 'genes.dart';

/// Names for the founding civilizations, in order. Each founding species
/// is named for its civilization, and every species descended from it
/// carries the name on as the first of two: "Aru", then "Aru ferox"…
const civilizationNames = [
  'Aru', 'Belen', 'Coro', 'Dasha', 'Elun', 'Fennet', 'Gault', 'Hiro', //
  'Isk', 'Jora', 'Kesh', 'Lumi', 'Moru', 'Nadi', 'Oro', 'Pell',
];

/// How many of a species were alive in a given year.
typedef Headcount = ({double year, int count});

/// A species: creatures that can interbreed. All descend from one founding
/// civilization; all but the founders split from a parent species.
class Species {
  /// Its place in the list of every species that ever lived.
  final int id;

  /// The founding civilization it descends from.
  final int civilization;

  /// The second word of its name, given when it split off, for what set it
  /// apart; see `epithetFor`. Null for the founders.
  String? epithet;

  final Species? parent;
  final double bornAt;
  double? diedAt;

  Species({required this.id, required this.civilization, this.parent, required this.bornAt});

  bool get isAlive => diedAt == null;

  /// How it came to split from its [parent], in words: "living apart in
  /// the north-west, in land 9° colder". Empty for the founders.
  String origin = '';

  /// Why its members have been dying, recent deaths counting most.
  final recentDeaths = DeathTally();

  /// Once it has died out, how its last members died, as a sentence.
  String fate = '';

  /// The species it merged back into, if it ended that way rather than
  /// dying out.
  Species? mergedInto;

  /// "Aru" for a founder, "Aru ferox" for a species descended from it.
  String get name => epithet == null ? civilizationNames[civilization] : '${civilizationNames[civilization]} $epithet';

  /// [name] with "a" or "an" before it.
  String get aName => '${'AEIOU'.contains(name[0]) ? 'an' : 'a'} $name';

  // ---- the census, taken every tick -----------------------------------------

  /// How many are alive.
  int count = 0;

  /// The average of each gene among the living.
  double averageSpeed = 0,
      averageSize = 0,
      averageSight = 0,
      averageAggression = 0,
      averageTint = 0,
      averageIdealClimate = 0;

  /// How many of each body are alive, in the order each was first counted,
  /// keyed by [_bodyKey]: a plain int is the cheapest key there is, and the
  /// census updates this for every creature every step.
  final Map<int, int> _bodyCounts = {};

  static int _bodyKey(Genes genes) {
    final a = genes.firstShape.index, b = genes.secondShape.index;
    return a <= b ? a * 8 + b : b * 8 + a;
  }

  /// The commonest body; the first counted, in a tie.
  Body get commonestBody {
    var commonest = 0, most = -1;
    _bodyCounts.forEach((key, count) {
      if (count > most) {
        most = count;
        commonest = key;
      }
    });
    return Body.of(Shape.values[commonest ~/ 8], Shape.values[commonest % 8]);
  }

  /// The species' average genes, as if they were one creature's.
  Genes get averageGenes => Genes(
        speed: averageSpeed,
        size: averageSize,
        sight: averageSight,
        aggression: averageAggression,
        tint: averageTint,
        idealClimate: averageIdealClimate,
        firstShape: commonestBody.first,
        secondShape: commonestBody.second,
      );

  /// Headcount over its lifetime, for the family tree. Thinned out when it
  /// gets long, so it always spans the species' whole life.
  final List<Headcount> headcounts = [];

  void clearCensus() {
    count = 0;
    averageSpeed = averageSize = averageSight = averageAggression = averageTint = averageIdealClimate = 0;
    _bodyCounts.clear();
  }

  /// Adds one living member's genes to the census.
  void countMember(Genes genes) {
    count += 1;
    averageSpeed += genes.speed;
    averageSize += genes.size;
    averageSight += genes.sight;
    averageAggression += genes.aggression;
    averageTint += genes.tint;
    averageIdealClimate += genes.idealClimate;
    _bodyCounts.update(_bodyKey(genes), (n) => n + 1, ifAbsent: () => 1);
  }

  /// Turns the census's running totals into averages.
  void finishCensus() {
    averageSpeed /= count;
    averageSize /= count;
    averageSight /= count;
    averageAggression /= count;
    averageTint /= count;
    averageIdealClimate /= count;
  }
}
