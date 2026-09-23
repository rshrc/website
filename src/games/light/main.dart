import 'package:web/web.dart' as web;

import '../shared/page.dart';
import 'model/model.dart';
import 'ui/board.dart';
import 'ui/explain.dart';
import 'ui/input.dart';
import 'ui/panel.dart';
import 'ui/session.dart';

/// An optical bench. Place lasers, mirrors, prisms and lenses, drag them
/// about, turn them by their handles, and point at any place light meets a
/// surface to read the angles there.
///
/// The optics live in model/, with no web imports; ui/ puts them on the
/// page. This file only wires the two together.
void main() {
  web.document.getElementById('stage')!.parentElement!.classList.add('wide');
  final stage = Stage.find(aspect: Bench.height / Bench.width);
  final session = Session(Bench());
  final board = Board(stage, session);
  Panel(session);
  Input(board, session);
  final readout = Readout();

  var drawnWidth = 0.0;
  animate((_) {
    if (!session.stale && stage.width == drawnWidth) return;
    session.stale = false;
    drawnWidth = stage.width;
    board.draw();
    readout.set(status(session));
  });
}
