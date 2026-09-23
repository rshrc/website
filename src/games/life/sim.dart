import 'dart:collection';
import 'dart:typed_data';

import '../shared/rng.dart';

/// A Life-like rule in B/S notation: which neighbour counts bring a dead cell
/// to life, and which let a live one survive. Conway's own is B3/S23.
class LifeRule {
  final Set<int> birth;
  final Set<int> survive;

  const LifeRule._(this.birth, this.survive);

  static const conway = LifeRule._({3}, {2, 3});

  /// Reads `B3/S23` (any case, either order). Returns null for anything that
  /// isn't a rule, so the page can leave the old one running.
  static LifeRule? tryParse(String text) {
    final match = RegExp(r'^\s*b([0-8]*)\s*/\s*s([0-8]*)\s*$', caseSensitive: false).firstMatch(text) ??
        RegExp(r'^\s*s([0-8]*)\s*/\s*b([0-8]*)\s*$', caseSensitive: false).firstMatch(text);
    if (match == null) return null;
    final bFirst = text.trim().toLowerCase().startsWith('b');
    Set<int> digits(String s) => s.split('').map(int.parse).toSet();
    final b = digits(match.group(bFirst ? 1 : 2)!);
    final s = digits(match.group(bFirst ? 2 : 1)!);
    return LifeRule._(b, s);
  }

  String get notation => 'B${(birth.toList()..sort()).join()}/S${(survive.toList()..sort()).join()}';

  @override
  String toString() => notation;
}

/// A named starting shape, drawn in the plaintext format the Life community
/// has used for decades: `O` is alive, `.` is dead, one row per line.
class Pattern {
  final String name;
  final List<(int, int)> cells;
  final int width, height;

  Pattern._(this.name, this.cells, this.width, this.height);

  factory Pattern.plaintext(String name, String rows) {
    final lines = rows.trim().split('\n').map((l) => l.trim()).toList();
    final cells = <(int, int)>[];
    for (var y = 0; y < lines.length; y++) {
      for (var x = 0; x < lines[y].length; x++) {
        if (lines[y][x] == 'O') cells.add((x, y));
      }
    }
    final width = lines.fold(0, (w, l) => l.length > w ? l.length : w);
    return Pattern._(name, cells, width, lines.length);
  }

  static final all = [
    Pattern.plaintext('glider', '''
      .O.
      ..O
      OOO'''),
    Pattern.plaintext('lightweight spaceship', '''
      .O..O
      O....
      O...O
      OOOO.'''),
    Pattern.plaintext('pulsar', '''
      ..OOO...OOO..
      .............
      O....O.O....O
      O....O.O....O
      O....O.O....O
      ..OOO...OOO..
      .............
      ..OOO...OOO..
      O....O.O....O
      O....O.O....O
      O....O.O....O
      .............
      ..OOO...OOO..'''),
    Pattern.plaintext('Gosper glider gun', '''
      ........................O...........
      ......................O.O...........
      ............OO......OO............OO
      ...........O...O....OO............OO
      OO........O.....O...OO..............
      OO........O...O.OO....O.O...........
      ..........O.....O.......O...........
      ...........O...O....................
      ............OO......................'''),
    Pattern.plaintext('R-pentomino', '''
      .OO
      OO.
      .O.'''),
    Pattern.plaintext('acorn', '''
      .O.....
      ...O...
      OO..OOO'''),
    Pattern.plaintext('diehard', '''
      ......O.
      OO......
      .O...OOO'''),
  ];
}

/// Conway's Game of Life on a torus: the right edge wraps to the left, the
/// bottom to the top, so nothing ever falls off the world.
///
/// Each cell stores its age rather than a bare alive/dead bit — 0 is dead, 1
/// was just born, and it counts up to 255 while the cell survives. The page
/// uses that to fade long-lived cells, which makes still lifes recede and
/// leaves the interesting, changing parts in full ink.
class LifeSim {
  final int width, height;
  Uint8List _cells, _next;
  LifeRule rule;

  int generation = 0;
  int population = 0;

  /// Set once the whole grid returns to a state it has been in before. A
  /// still life has period 1, a blinker period 2, and so on. On a torus even a
  /// lone glider eventually comes back around, which counts: the world as a
  /// whole really is repeating.
  int? period;

  /// The generation at which [period] was first noticed.
  int? settledAt;

  /// Generation each recent grid state was seen at, keyed by a hash of which
  /// cells are alive. Bounded, oldest out first, so a chaotic soup can run all
  /// night without the page growing.
  final _seen = LinkedHashMap<int, int>();
  static const _memory = 4096;

  LifeSim(this.width, this.height, {this.rule = LifeRule.conway})
      : _cells = Uint8List(width * height),
        _next = Uint8List(width * height);

  bool isAlive(int x, int y) => _cells[_index(x, y)] != 0;
  int ageAt(int x, int y) => _cells[_index(x, y)];

  int _index(int x, int y) => (y % height + height) % height * width + (x % width + width) % width;

  /// Any hand edit starts the search for a cycle over: the history no longer
  /// describes this world.
  void _edited() {
    _seen.clear();
    period = null;
    settledAt = null;
  }

  void set(int x, int y, bool alive) {
    final i = _index(x, y);
    final was = _cells[i] != 0;
    if (was == alive) return;
    _cells[i] = alive ? 1 : 0;
    population += alive ? 1 : -1;
    _edited();
  }

  void clear() {
    _cells.fillRange(0, _cells.length, 0);
    population = 0;
    generation = 0;
    _edited();
  }

  void randomize(Rng rng, double density) {
    population = 0;
    for (var i = 0; i < _cells.length; i++) {
      final alive = rng.chance(density);
      _cells[i] = alive ? 1 : 0;
      if (alive) population++;
    }
    generation = 0;
    _edited();
  }

  /// Draws [pattern] centred on ([cx], [cy]), on top of whatever is there.
  void stamp(Pattern pattern, int cx, int cy) {
    final ox = cx - pattern.width ~/ 2, oy = cy - pattern.height ~/ 2;
    for (final (x, y) in pattern.cells) {
      final i = _index(ox + x, oy + y);
      if (_cells[i] == 0) population++;
      _cells[i] = 1;
    }
    _edited();
  }

  void step() {
    final w = width, h = height;
    final cells = _cells, next = _next;
    final birth = List<bool>.generate(9, rule.birth.contains);
    final survive = List<bool>.generate(9, rule.survive.contains);
    var alive = 0;
    // Two independent 32-bit hashes of the live cells, packed into one number
    // below 2^53 so it stays exact when compiled to JavaScript.
    var h1 = 0x811c9dc5, h2 = 0x1505;

    for (var y = 0; y < h; y++) {
      final up = ((y - 1 + h) % h) * w, row = y * w, down = ((y + 1) % h) * w;
      for (var x = 0; x < w; x++) {
        final left = (x - 1 + w) % w, right = (x + 1) % w;
        var n = 0;
        if (cells[up + left] != 0) n++;
        if (cells[up + x] != 0) n++;
        if (cells[up + right] != 0) n++;
        if (cells[row + left] != 0) n++;
        if (cells[row + right] != 0) n++;
        if (cells[down + left] != 0) n++;
        if (cells[down + x] != 0) n++;
        if (cells[down + right] != 0) n++;

        final i = row + x;
        final age = cells[i];
        final lives = age != 0 ? survive[n] : birth[n];
        if (lives) {
          next[i] = age == 0 ? 1 : (age < 255 ? age + 1 : 255);
          alive++;
          h1 = ((h1 ^ i) * 0x01000193) & 0xffffffff;
          h2 = ((h2 * 33) ^ i) & 0x1fffff;
        } else {
          next[i] = 0;
        }
      }
    }

    _next = cells;
    _cells = next;
    population = alive;
    generation++;

    if (period == null) {
      final key = h1 * 0x200000 + h2;
      final before = _seen[key];
      if (before != null) {
        period = generation - before;
        settledAt = generation;
      } else {
        _seen[key] = generation;
        if (_seen.length > _memory) _seen.remove(_seen.keys.first);
      }
    }
  }
}
