import 'species.dart';

/// How badly one species was hit.
typedef SpeciesToll = ({Species species, int killed, double share});

/// A meteor strike, remembered: where, how big, and what it cost.
class MeteorStrike {
  final double year, x, y, radius;

  /// "the north-east", "the heartland".
  final String where;

  final int killed;

  /// Of everything alive just before, the share it killed.
  final double shareOfAllLife;

  /// Each species it hit, hardest hit first, as a share of that species.
  final List<SpeciesToll> tolls;

  /// How much dust it threw into the sky; see `World.dust`.
  final double dust;

  const MeteorStrike({
    required this.year,
    required this.x,
    required this.y,
    required this.radius,
    required this.where,
    required this.killed,
    required this.shareOfAllLife,
    required this.tolls,
    required this.dust,
  });

  /// "small meteor", "meteor", "great meteor", "colossal meteor".
  String get size => switch (radius) {
        < 60 => 'small meteor',
        < 130 => 'meteor',
        < 220 => 'great meteor',
        _ => 'colossal meteor',
      };

  /// How devastating it was, by the share of all life it took.
  String get devastation => switch (shareOfAllLife) {
        0 => 'harmless',
        < 0.02 => 'a glancing blow',
        < 0.1 => 'a heavy blow',
        < 0.3 => 'a catastrophe',
        _ => 'an extinction event',
      };

  /// The species it wiped out, every last one.
  Iterable<Species> get wipedOut => tolls.where((t) => t.share >= 1).map((t) => t.species);
}
