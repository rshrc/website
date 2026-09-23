import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../model/model.dart';
import 'headings.dart';

/// Every meteor strike, remembered: newest first, each with its size,
/// where it fell, how devastating it was, and who it hit hardest.
class MeteorList {
  static const _mostShown = 8;

  final _list = web.document.createElement('ol') as web.HTMLOListElement..className = 'chronicle';
  late final web.HTMLHeadingElement _heading;

  /// How many strikes the list shows, to rebuild it only when there's news.
  int _shownFor = -1;

  /// Adds the list just after [element]. It stays hidden until the first
  /// strike.
  MeteorList(web.Element element) {
    element.after(_list);
    _heading = addHeading(_list, 'Meteor strikes');
    _setVisible(false);
  }

  void _setVisible(bool visible) {
    _list.style.display = visible ? '' : 'none';
    _heading.style.display = visible ? '' : 'none';
  }

  void show(World world) {
    final strikes = world.meteorStrikes;
    if (strikes.length == _shownFor) return;
    _shownFor = strikes.length;
    _setVisible(strikes.isNotEmpty);
    _list.textContent = '';
    for (final strike in strikes.reversed.take(_mostShown)) {
      _list.append(web.document.createElement('li') as web.HTMLLIElement
        ..append(web.document.createElement('span') as web.HTMLSpanElement
          ..className = 'year'
          ..textContent = 'year ${withCommas(strike.year.round())}')
        ..append(web.document.createTextNode(_about(strike))));
    }
    if (strikes.length > _mostShown) {
      _list.append(web.document.createElement('li') as web.HTMLLIElement
        ..textContent = 'and ${strikes.length - _mostShown} earlier');
    }
  }

  String _about(MeteorStrike strike) {
    final size = '${strike.size[0].toUpperCase()}${strike.size.substring(1)}, ${(strike.radius * 2).round()} across';
    if (strike.killed == 0) return '$size, in the ${strike.where}: harmless.';
    final percent = (strike.shareOfAllLife * 100).toStringAsFixed(strike.shareOfAllLife < 0.1 ? 1 : 0);
    final hardest = strike.tolls.first;
    final wiped = strike.wipedOut.map((s) => s.name).toList();
    return '$size, in the ${strike.where}: ${strike.devastation}. ${withCommas(strike.killed)} killed, '
        '$percent% of all life; hardest hit ${hardest.species.name}, '
        '${(math.min(1.0, hardest.share) * 100).round()}%'
        '${wiped.isEmpty ? '' : '; wiped out ${inWords(wiped)}'}'
        '${strike.dust > 0 ? '; dust darkened the sky' : ''}.';
  }
}
