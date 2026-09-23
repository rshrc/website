import 'species.dart';

/// Why a creature died. Starving is split by what drove it: a creature whose
/// upkeep the wrong climate had at least doubled died of the heat or the
/// cold; one on desert starved there.
enum DeathCause {
  oldAge('of old age', 'died of old age', 'old age'),
  hunger('of hunger', 'starved', 'hunger'),
  heat('of the heat', 'died of the heat', 'heat'),
  cold('of the cold', 'died of the cold', 'cold'),
  desert('of hunger, out in the desert', 'starved in the desert', 'desert'),
  flood('in the floods', 'drowned in the floods', 'floods'),
  childbirth('giving birth', 'died giving birth', 'childbirth'),
  fight('in a fight', 'were killed in fights', 'fights'),
  meteor('under a meteor', 'were killed by a meteor', 'meteors'),
  plague('of plague', 'died of plague', 'plague');

  /// How one creature died: "died {how}".
  final String how;

  /// What many of a species did: "most of its last members {didWhat}".
  final String didWhat;

  /// A short name, for a list of causes.
  final String noun;

  const DeathCause(this.how, this.didWhat, this.noun);
}

/// One death: its cause, and for a fight, the killer's civilization.
class Death {
  final DeathCause cause;
  final int? killer;

  const Death(this.cause, [this.killer]);

  /// "of the heat", or "in a fight with one of the Belen".
  String get how =>
      killer == null ? cause.how : 'in a fight with one of the ${civilizationNames[killer!]}';

  /// "died of the heat", or "were killed by the Belen", for many.
  String get didWhat => killer == null ? cause.didWhat : 'were killed by the ${civilizationNames[killer!]}';

  @override
  bool operator ==(Object other) => other is Death && other.cause == cause && other.killer == killer;

  @override
  int get hashCode => Object.hash(cause, killer);
}

/// A running count of deaths by cause (and killer), which can fade so that
/// recent deaths count most.
class DeathTally {
  final Map<Death, double> _counts = {};

  void add(Death death) => _counts[death] = (_counts[death] ?? 0) + 1;

  /// Scales every count by [factor], so older deaths weigh less.
  void fade(double factor) => _counts.updateAll((_, count) => count * factor);

  /// The biggest causes, each with its share of all the deaths counted:
  /// at most [most], and none under [atLeast].
  List<(Death, double)> leading({int most = 3, double atLeast = 0.15}) {
    final total = _counts.values.fold(0.0, (sum, count) => sum + count);
    if (total == 0) return const [];
    final ranked = _counts.entries.map((e) => (e.key, e.value / total)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return ranked.where((entry) => entry.$2 >= atLeast).take(most).toList();
  }

  /// Why a species' last members died, as a sentence: "Most of its last
  /// members died of the heat; others were killed by the Aru."
  ///
  /// Old age is left out when anything else is to blame. Every species
  /// loses its old; what ends one is whatever kept the young from
  /// replacing them, so a species that only ever died of old age is said to
  /// have had too few young.
  String get lastMembersFate {
    final causes = leading(most: 4, atLeast: 0.1).where((c) => c.$1.cause != DeathCause.oldAge).toList();
    if (causes.isEmpty) {
      return _counts.isEmpty ? '' : 'Its last members died of old age, with too few young to replace them.';
    }
    final (top, topShare) = causes.first;
    final others = causes.length > 1 ? '; others ${causes[1].$1.didWhat}' : '';
    return '${topShare >= 0.5 ? 'Most' : 'Many'} of its last members ${top.didWhat}$others.';
  }
}
