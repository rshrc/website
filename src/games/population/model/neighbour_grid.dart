import 'dart:math' as math;
import 'dart:typed_data';

import 'creature.dart';

/// Finds creatures near a point without checking every creature.
///
/// The land is cut into square cells, and each cell keeps a linked list of
/// the creatures in it, threaded through two integer arrays — the first
/// creature in each cell, and the next creature after each one — so
/// rebuilding it every step allocates nothing. A search allocates nothing
/// either:
///
/// ```dart
/// final cells = grid.findCellsNear(x, y, reach);
/// for (var k = 0; k < cells; k++) {
///   for (var i = grid.firstInCell(k); i != -1; i = grid.nextInCell(i)) {
///     final other = creatures[i];
///   }
/// }
/// ```
///
/// Searches run for every creature spoiling for a fight and every one
/// looking for a mate, every step, which is why it's plain loops rather
/// than an iterator or a callback: both measured markedly slower.
class NeighbourGrid {
  static const cellSize = 50.0;

  final int columns, rows;
  Int32List _firstInCell = Int32List(0), _nextInCell = Int32List(0);

  /// The cells the last search found, as indices into [_firstInCell].
  final Int32List _foundCells;

  NeighbourGrid(double width, double height)
      : columns = (width / cellSize).ceil(),
        rows = (height / cellSize).ceil(),
        _foundCells = Int32List((width / cellSize).ceil() * (height / cellSize).ceil());

  /// Files every creature under the cell it stands in, by its index in
  /// [creatures].
  void rebuild(List<Creature> creatures) {
    if (_firstInCell.length != columns * rows) _firstInCell = Int32List(columns * rows);
    if (_nextInCell.length < creatures.length) _nextInCell = Int32List(creatures.length * 2);
    _firstInCell.fillRange(0, _firstInCell.length, -1);
    for (var i = 0; i < creatures.length; i++) {
      final creature = creatures[i];
      final int cell = math.min<int>((creature.y / cellSize).floor(), rows - 1) * columns +
          math.min<int>((creature.x / cellSize).floor(), columns - 1);
      _nextInCell[i] = _firstInCell[cell];
      _firstInCell[cell] = i;
    }
  }

  /// Finds the cells within [reach] of ([x], [y]), wrapping around the
  /// edges, and returns how many there are. Their creatures include the
  /// dead and whoever is asking; the caller decides who counts. Each search
  /// replaces the last.
  int findCellsNear(double x, double y, double reach) {
    final cellsOut = (reach / cellSize).ceil();
    final firstColumn = (x / cellSize).floor() - cellsOut, firstRow = (y / cellSize).floor() - cellsOut;
    final columnsToVisit = math.min(2 * cellsOut + 1, columns), rowsToVisit = math.min(2 * cellsOut + 1, rows);
    var found = 0;
    for (var rowStep = 0; rowStep < rowsToVisit; rowStep++) {
      final row = ((firstRow + rowStep) % rows + rows) % rows;
      for (var columnStep = 0; columnStep < columnsToVisit; columnStep++) {
        final column = ((firstColumn + columnStep) % columns + columns) % columns;
        _foundCells[found++] = row * columns + column;
      }
    }
    return found;
  }

  /// The index of the first creature in found cell [k], or -1 if it's empty.
  int firstInCell(int k) => _firstInCell[_foundCells[k]];

  /// The index of the creature after creature [i] in its cell, or -1.
  int nextInCell(int i) => _nextInCell[i];
}
