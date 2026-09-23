import '../../shared/page.dart';
import '../model/model.dart';
import 'session.dart';
import 'settings.dart';

/// The lines of controls under the board: what to add, how the whole bench
/// behaves, and the selected piece's own settings.
class Panel {
  final Session session;
  late final Controls _piece;

  /// Brings each of the selected piece's controls back in line with the
  /// piece, after something else changed it.
  final _syncs = <void Function()>[];

  /// How many pieces have been added, to set each new one a little apart.
  var _added = 0;

  Panel(this.session) {
    _addingLine();
    _benchLine();
    _piece = Controls.line();
    session
      ..onSelect = show
      ..onEdit = sync;
    show(session.selected);
  }

  void _addingLine() {
    final line = Controls.line()..label('add');
    for (final MapEntry(key: name, value: make) in catalogue.entries) {
      line.button(name, () {
        final step = (_added++ % 5).toDouble();
        session.add(make(440 + step * 30, 250 + step * 24));
      });
    }
  }

  void _benchLine() {
    final line = Controls.line();
    final scene = line.select('scene', scenes.keys.toList(), session.load);
    line
      ..choice('angles', ['on', 'off'], 'on', (v) => session.angles = v == 'on')
      ..choice('faint reflections', ['on', 'off'], 'on', (v) {
        session.bench.faint = v == 'on';
        session.changed();
      })
      ..choice('room', ['air', 'water'], 'air', (v) {
        session.bench.room = v == 'air' ? Medium.air : Medium.water;
        session.changed();
      })
      ..button('clear', () {
        scene.value = 'empty';
        session.load('empty');
      });
  }

  /// Shows the controls for [piece], or a hint when nothing is selected.
  void show(Piece? piece) {
    _piece.clear();
    _syncs.clear();
    if (piece == null) {
      _piece.label('select something to change it, or drag it about');
      return;
    }
    _piece.label(piece.name);
    for (final setting in settingsFor(piece)) {
      _syncs.add(_control(setting));
    }
    _piece
      ..button('copy', () => session.add(piece.copy()))
      ..button('remove', session.removeSelected, title: 'delete');
  }

  void sync() {
    for (final s in _syncs) {
      s();
    }
  }

  /// Builds a control for [setting]; returns how to bring it up to date.
  void Function() _control(Setting setting) {
    void Function(T) writing<T>(void Function(T) write) => (value) {
          write(value);
          session.changed();
          // One setting can move another: a wavelength switches a laser
          // off white; a new index makes the glass a custom material.
          sync();
        };

    switch (setting) {
      case Range s:
        final slider = _piece.slider(s.label, s.min, s.max, s.read(), writing(s.write), step: s.step, format: s.format);
        return () => slider.value = s.read();
      case Options s when s.options.length <= 3:
        final press = _piece.choice(s.label, s.options, s.read(), writing(s.write));
        return () => press(s.read());
      case Options s:
        final select = _piece.select(s.label, s.options, writing(s.write))..value = s.read();
        return () => select.value = s.read();
    }
  }
}
