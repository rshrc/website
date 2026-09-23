import 'package:web/web.dart' as web;

import '../../shared/page.dart';
import '../../shared/sound.dart';
import '../model/model.dart';
import 'chart_view.dart';
import 'clock.dart';

/// How the next new world will start.
class NewWorldSettings {
  int civilizations = 3;
  int perCivilization = 60;
  LandSize landSize = LandSize.medium;
}

/// What a click on the map does.
enum Tool {
  follow('follow a creature'),
  meteor('drop a meteor'),
  rain('rain'),
  dry('dry the land');

  final String label;
  const Tool(this.label);
}

/// The map tool in hand, how big it reaches, and where the pointer is, to
/// show where it would land. Rain and dry work while the pointer is held
/// down, more the longer it's held.
class MapTool {
  Tool tool = Tool.follow;
  double radius = 80;
  (double, double)? pointer;
  bool isPressed = false;

  /// Whether the tool reaches over an area, and so its outline should show.
  bool get showsReach => tool != Tool.follow;

  /// Whether it's painting weather onto the land right now.
  bool get isPainting => isPressed && (tool == Tool.rain || tool == Tool.dry);
}

/// The lines of controls under the map, and their keyboard shortcuts.
class ControlPanel {
  final World world;
  final Clock clock;
  final MapTool mapTool;
  final web.HTMLCanvasElement map;

  late final web.HTMLButtonElement _playButton, _warButton, _soundButton;
  late final void Function(String) _pressTool;

  ControlPanel({
    required this.world,
    required this.clock,
    required this.mapTool,
    required this.map,
    required NewWorldSettings settings,
    required ChartView chart,
    required Sound sound,
    required void Function() startNewWorld,
  }) {
    _newWorldLine(settings, startNewWorld);
    _lawsLine();
    _mapToolLine();
    _actsLine(sound);
    _naturalEventsLine();
    Controls.line().choice('chart', Measure.values.map((m) => m.name).toList(), chart.measure.name,
        (name) => chart.measure = Measure.values.byName(name));

    onKey({
      ' ': togglePlaying,
      'n': startNewWorld,
      'f': () => chooseTool(Tool.follow),
      'm': () => chooseTool(Tool.meteor),
      'r': () => chooseTool(Tool.rain),
      'y': () => chooseTool(Tool.dry),
      'p': world.plague,
      'd': world.drought,
      'g': world.plenty,
      'w': world.war,
      'h': world.warming,
      'c': world.cooling,
    });
  }

  void togglePlaying() {
    clock.isRunning = !clock.isRunning;
    _playButton.textContent = clock.isRunning ? 'pause' : 'play';
  }

  void chooseTool(Tool tool) {
    mapTool.tool = tool;
    _pressTool(tool.label);
    map.style.cursor = tool == Tool.follow ? '' : 'cell';
  }

  void _newWorldLine(NewWorldSettings settings, void Function() startNewWorld) {
    Controls.line()
      ..slider('civilizations', 1, World.maxCivilizations.toDouble(), settings.civilizations.toDouble(),
          (v) => settings.civilizations = v.round())
      ..slider('creatures each', 10, 200, settings.perCivilization.toDouble(), (v) => settings.perCivilization = v.round(),
          step: 10)
      ..choice('land', LandSize.values.map((l) => l.name).toList(), settings.landSize.name,
          (name) => settings.landSize = LandSize.values.byName(name))
      ..button('start a new world', startNewWorld, title: 'n');
  }

  void _lawsLine() {
    final line = Controls.line();
    final laws = world.laws;
    _playButton = line.button('pause', togglePlaying, title: 'space');
    line
      ..slider('speed', 0, Clock.speeds.length - 1, Clock.speeds.indexOf(clock.yearsPerSecond.round()).toDouble(),
          (v) => clock.yearsPerSecond = Clock.speeds[v.round()].toDouble(),
          format: (v) => '×${Clock.speeds[v.round()]}')
      ..slider('food', 0.02, 0.15, laws.regrowth, (v) => laws.regrowth = v, step: 0.005)
      ..slider('mutation', 0, 0.15, laws.mutation, (v) => laws.mutation = v, step: 0.005)
      ..slider('fighting', 0, 3, laws.hostility, (v) {
        laws.hostility = v;
        // No fighting, no wars: the war button has nothing to start.
        _warButton
          ..disabled = v == 0
          ..title = v == 0 ? 'fighting is off' : 'w';
      }, step: 0.25, format: (v) => v == 0 ? 'none' : '×${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}')
      ..choice('body shapes', ['on', 'off'], 'on', (v) => laws.bodyShapes = v == 'on');
  }

  /// What a click on the map does, and how far it reaches.
  void _mapToolLine() {
    final line = Controls.line();
    _pressTool = line.choice('click the map to', [for (final tool in Tool.values) tool.label], mapTool.tool.label,
        (label) => chooseTool(Tool.values.firstWhere((tool) => tool.label == label)));
    line.slider('reach', 20, 300, mapTool.radius, (v) => mapTool.radius = v, step: 10);
  }

  /// Things the reader can make happen, whenever they like.
  void _actsLine(Sound sound) {
    final line = Controls.line();
    line
      ..button('plague', world.plague, title: 'p')
      ..button('drought', world.drought, title: 'd')
      ..button('age of plenty', world.plenty, title: 'g');
    _warButton = line.button('war', world.war, title: 'w');
    line
      ..button('warming', world.warming, title: 'h')
      ..button('cooling', world.cooling, title: 'c');
    _soundButton = line.button('sound on', () {
      sound.on = !sound.on;
      _soundButton.textContent = sound.on ? 'sound on' : 'sound off';
    });
  }

  /// Which of those also happen by themselves. All off: everything is the
  /// reader's.
  void _naturalEventsLine() {
    const kinds = {
      'meteors': [EventKind.meteor],
      'plagues': [EventKind.plague],
      'droughts': [EventKind.drought],
      'plenty': [EventKind.plenty],
      'wars': [EventKind.war],
      'climate change': [EventKind.warming, EventKind.cooling],
    };
    Controls.line().toggles('happens by itself:', kinds.keys.toList(), kinds.keys.toSet(), (name, on) {
      final events = kinds[name]!;
      on ? world.laws.naturalEvents.addAll(events) : world.laws.naturalEvents.removeAll(events);
    });
  }
}
