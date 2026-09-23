/// What kind of thing happened.
enum EventKind {
  founding,
  speciation,

  /// Two species of one lineage interbreed until they're one again.
  merger,
  extinction,

  /// A civilization's last species dies out.
  civilizationLost,
  war,
  peace,

  /// Two civilizations have a child together for the first time.
  firstHybrid,
  meteor,
  plague,
  drought,
  droughtEnds,
  plenty,
  plentyEnds,

  /// The climate starts to warm, or to cool, and settles once it has.
  warming,
  cooling,
  climateSettles,

  /// Land soaked past the flood line, or dried to dust.
  flood,
  dustBowl,

  /// A great meteor's dust clears from the sky.
  dustSettles,

  /// Nothing is left alive.
  lifeEnds;

  /// The acts of nature (and history) that can also happen by themselves.
  static const natural = [meteor, plague, drought, plenty, war, warming, cooling];
}

/// One line of the chronicle.
class ChronicleEntry {
  final double year;
  final EventKind kind;
  final String text;

  /// The civilization it concerns, if any.
  final int? civilization;

  /// Where it happened, and how far it reached, for events that happen
  /// somewhere.
  final double? x, y, radius;

  const ChronicleEntry(this.year, this.kind, this.text, {this.civilization, this.x, this.y, this.radius});
}

/// Everything notable that has happened, oldest first.
class Chronicle {
  final List<ChronicleEntry> entries = [];
  int _announced = 0;

  void add(ChronicleEntry entry) => entries.add(entry);

  /// Entries since the last call, for the page to announce.
  List<ChronicleEntry> news() {
    final fresh = entries.sublist(_announced);
    _announced = entries.length;
    return fresh;
  }

  void clear() {
    entries.clear();
    _announced = 0;
  }
}

/// A whole number with thousands separators: 1511 → 1,511.
String withCommas(int n) {
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '−' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// "a", "a and b", "a, b and c".
String inWords(List<String> items) =>
    items.length < 2 ? items.join() : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
