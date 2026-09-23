import 'chronicle.dart';
import 'genes.dart';

/// The laws of the world that can be changed while it runs.
class Laws {
  /// Share of an eaten patch that grows back each year.
  double regrowth = 0.06;

  /// Spread of the mutation per gene per birth.
  double mutation = 0.05;

  /// Multiplier on how often creatures of different civilizations fight.
  /// Zero is a peaceful world: nobody fights, no war can start, and any war
  /// under way ends at the next review.
  double hostility = 1;

  /// How many times the usual upkeep crossing desert costs.
  double desertCost = 1.5;

  /// Whether body shapes matter. Off, every shape counts as a plain body
  /// with no advantages, no shape mutates, and new worlds start all round.
  bool bodyShapes = true;

  /// Which acts of nature (and history) happen by themselves now and then.
  /// Empty means everything is up to you.
  final Set<EventKind> naturalEvents = {...EventKind.natural};

  bool get anyNaturalEvents => naturalEvents.isNotEmpty;

  /// Switches every natural event on or off at once.
  set allNaturalEvents(bool on) => on ? naturalEvents.addAll(EventKind.natural) : naturalEvents.clear();

  /// How much of [genes]' body is [shape], as far as the laws are concerned.
  double shapeShare(Genes genes, Shape shape) => bodyShapes ? genes.share(shape) : 0;

  /// What [genes] pay to move, relative to a plain body: the average of its
  /// two shapes' costs.
  double movementCost(Genes genes) => bodyShapes
      ? (_movementCostOf[genes.firstShape.index] + _movementCostOf[genes.secondShape.index]) / 2
      : 1;

  /// What each shape pays to move, in the order of [Shape].
  static const _movementCostOf = [1.05, 0.88, 1.12, 1.0, 1.0];
}
