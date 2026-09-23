import 'package:web/web.dart' as web;

import '../model/model.dart';
import 'headings.dart';

/// The last few things that happened, newest first.
class ChronicleList {
  static const _mostShown = 10;

  final _list = web.document.createElement('ol') as web.HTMLOListElement..className = 'chronicle';

  /// Whether something has happened since it was last shown.
  bool isStale = true;

  /// Adds the list just after [element].
  ChronicleList(web.Element element) {
    element.after(_list);
    addHeading(_list, 'Chronicle');
  }

  void show(World world) {
    if (!isStale) return;
    isStale = false;
    _list.textContent = '';
    for (final entry in world.chronicle.entries.reversed.take(_mostShown)) {
      _list.append(web.document.createElement('li') as web.HTMLLIElement
        ..append(web.document.createElement('span') as web.HTMLSpanElement
          ..className = 'year'
          ..textContent = 'year ${withCommas(entry.year.round())}')
        ..append(web.document.createTextNode(entry.text)));
    }
  }
}
