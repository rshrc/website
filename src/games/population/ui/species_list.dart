import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../model/model.dart';
import 'headings.dart';
import 'palette.dart';
import 'words.dart';

/// One line per species: a mark in its colour and shape, its name, how
/// many, and its average genes. Living species first, then the most recent
/// extinctions.
class SpeciesList {
  static const _mostShown = 12;

  final _list = web.document.createElement('ul') as web.HTMLUListElement..className = 'groups';

  /// Adds the list just before [element].
  SpeciesList(web.Element element) {
    element.before(_list);
    addHeading(_list, 'Species');
  }

  void show(World world, Palette palette) {
    final bodyShapes = world.laws.bodyShapes;
    final largestFirst = [...world.livingSpecies]..sort((a, b) => b.count.compareTo(a.count));
    final latestExtinctionsFirst = world.species.where((s) => !s.isAlive).toList()
      ..sort((a, b) => b.diedAt!.compareTo(a.diedAt!));
    _list.textContent = '';
    final shown = [
      ...largestFirst.take(_mostShown),
      ...latestExtinctionsFirst.take(math.max(0, 6 - largestFirst.length)),
    ];
    for (final species in shown) {
      _list.append(web.document.createElement('li') as web.HTMLLIElement
        ..append(web.document.createElement('span') as web.HTMLSpanElement
          ..className = 'dot'
          ..textContent = bodyShapes ? bodyGlyphs(species.commonestBody) : '●'
          ..style.color = palette.colour(species.civilization, species.averageTint, fade: species.isAlive ? 1 : 0.45))
        ..append(web.document.createElement('span') as web.HTMLSpanElement
          ..className = 'name'
          ..textContent = species.name)
        ..append(web.document.createTextNode(_about(species, bodyShapes: bodyShapes))));
    }
    if (largestFirst.length > _mostShown) {
      _list.append(web.document.createElement('li') as web.HTMLLIElement
        ..textContent = 'and ${largestFirst.length - _mostShown} more species');
    }
  }

  String _about(Species species, {required bool bodyShapes}) {
    if (species.mergedInto case final survivor?) {
      return 'merged back into ${survivor.name} in year ${withCommas(species.diedAt!.round())}';
    }
    if (!species.isAlive) {
      return 'died out in year ${withCommas(species.diedAt!.round())}${species.fate.isEmpty ? '' : '. ${species.fate}'}';
    }
    final parent = species.parent;
    return '${withCommas(species.count)} alive · speed ${species.averageSpeed.round()} · '
        'size ${species.averageSize.toStringAsFixed(2)} · sight ${species.averageSight.round()} · '
        'aggression ${species.averageAggression.toStringAsFixed(2)} · '
        'likes it ${climateWord(species.averageIdealClimate)}'
        '${bodyShapes ? ' · mostly ${bodyWords(species.commonestBody)}' : ''}'
        '${parent == null ? '' : ' · split from ${parent.name} in year ${withCommas(species.bornAt.round())}, ${species.origin}'}';
  }
}
