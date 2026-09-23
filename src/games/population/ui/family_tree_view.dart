import 'dart:js_interop';
import 'dart:math' as math;

import '../../shared/page.dart';
import '../model/model.dart';
import 'headings.dart';
import 'palette.dart';

/// Every species that ever lived, one row each, each just below the species
/// it split from. A row is a band from the year the species appeared to now
/// (or to its extinction), as thick as the species was numerous — so you
/// see it swell, dwindle and end — joined by a thin line to its parent.
class FamilyTreeView {
  final Stage stage;

  static const _top = 4.0, _rowHeight = 22.0, _labelFont = '12px Times, Georgia, serif';

  /// Over a long run there are far too many species to draw; past this
  /// many, only the living, their ancestors and the latest extinctions.
  static const _mostRows = 36;

  FamilyTreeView(this.stage) {
    addExplainedHeading(
        stage.canvas,
        'Family tree',
        'Each band is a species, from the year it appeared to now, or to the year it died out. Its thickness is how '
            'many were alive at the time. A thin grey line joins a species to the one it split from.');
  }

  void draw(World world, Palette palette) {
    final ink = palette.ink, ctx = stage.ctx;
    final rows = _rowsInOrder(world);
    stage.setHeight(math.min(_top + _rowHeight * rows.length + 4, 520));
    stage.fill(ink.bg);

    final plotWidth = stage.width - _labelsWidth(rows);
    final now = math.max(world.time, 1);
    double xOfYear(double year) => year / now * plotWidth;
    final rowHeight = math.min(_rowHeight, (stage.height - _top) / math.max(rows.length, 1));
    final middleOf = {for (final (i, species) in rows.indexed) species: _top + rowHeight * (i + 0.5)};

    // Thickness scales with the square root of the headcount, so small
    // species still show while big ones don't swamp the rows.
    var biggest = 1;
    for (final species in rows) {
      for (final (year: _, :count) in species.headcounts) {
        biggest = math.max(biggest, count);
      }
    }
    final halfRow = rowHeight * 0.42;
    double halfThickness(int count) => count == 0 ? 0 : math.max(0.8, halfRow * math.sqrt(count / biggest));

    for (final species in rows) {
      final middle = middleOf[species]!;
      if (species.parent case final parent?) {
        ctx.fillStyle = ink.muted.toJS;
        final parentMiddle = middleOf[parent]!;
        ctx.fillRect(xOfYear(species.bornAt).roundToDouble(), math.min(parentMiddle, middle), 1,
            (middle - parentMiddle).abs());
      }
      final history = species.headcounts;
      if (history.isEmpty) continue;
      // The band: along the top edge from birth to now, back along the
      // bottom.
      ctx
        ..fillStyle = palette.colour(species.civilization, species.averageTint, fade: species.isAlive ? 1 : 0.5).toJS
        ..beginPath();
      ctx.moveTo(xOfYear(history.first.year), middle);
      for (final (:year, :count) in history) {
        ctx.lineTo(xOfYear(year), middle - halfThickness(count));
      }
      final end = species.diedAt ?? world.time;
      final countNow = species.isAlive ? species.count : 0;
      ctx.lineTo(xOfYear(end), middle - halfThickness(countNow));
      ctx.lineTo(xOfYear(end), middle + halfThickness(countNow));
      for (final (:year, :count) in history.reversed) {
        ctx.lineTo(xOfYear(year), middle + halfThickness(count));
      }
      ctx.closePath();
      ctx.fill();
    }

    if (rowHeight >= 10) _drawNames(rows, middleOf, ink, plotWidth);
  }

  /// What's written after a species' name: how many, or when it ended.
  static String _after(Species species) => species.isAlive
      ? ' ${withCommas(species.count)}'
      : ' ${species.mergedInto == null ? 'died' : 'merged'} year ${withCommas(species.diedAt!.round())}';

  /// Room for the longest label, but never more than half the width.
  double _labelsWidth(List<Species> rows) {
    final ctx = stage.ctx..font = _labelFont;
    var widest = 100.0;
    for (final species in rows) {
      widest = math.max(widest, ctx.measureText('${species.name}${_after(species)}').width);
    }
    return math.min(widest + 16, stage.width / 2);
  }

  void _drawNames(List<Species> rows, Map<Species, double> middleOf, Ink ink, double plotWidth) {
    final ctx = stage.ctx;
    ctx
      ..font = _labelFont
      ..textBaseline = 'middle';
    for (final species in rows) {
      final middle = middleOf[species]!;
      ctx.fillStyle = (species.isAlive ? ink.fg : ink.muted).toJS;
      ctx.fillText(species.name, plotWidth + 8, middle);
      ctx.fillStyle = ink.muted.toJS;
      ctx.fillText(_after(species), plotWidth + 8 + ctx.measureText(species.name).width, middle);
    }
  }

  /// The species to show, each followed by its descendants: every living
  /// one, the ancestors that connect them, and the most recent extinctions.
  List<Species> _rowsInOrder(World world) {
    final shown = <Species>{};
    void showWithAncestors(Species? species) {
      for (; species != null && shown.add(species); species = species.parent) {}
    }

    world.livingSpecies.forEach(showWithAncestors);
    final latestExtinctionsFirst = world.species.where((s) => !s.isAlive).toList()
      ..sort((a, b) => b.diedAt!.compareTo(a.diedAt!));
    for (final species in latestExtinctionsFirst) {
      if (shown.length >= _mostRows) break;
      showWithAncestors(species);
    }

    final childrenOf = <Species, List<Species>>{};
    final founders = <Species>[];
    for (final species in world.species) {
      if (!shown.contains(species)) continue;
      final parent = species.parent;
      parent == null ? founders.add(species) : (childrenOf[parent] ??= []).add(species);
    }
    final rows = <Species>[];
    void addWithDescendants(Species species) {
      rows.add(species);
      childrenOf[species]?.forEach(addWithDescendants);
    }

    founders.forEach(addWithDescendants);
    return rows;
  }
}
