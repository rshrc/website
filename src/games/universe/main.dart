import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../shared/page.dart';
import '../shared/rng.dart';
import '../shared/vec2.dart';
import 'sim.dart';

/// A physics sandbox. Pick a universe, change its laws while it runs, and
/// drag on the canvas to fling new bodies into it.
void main() {
  final stage = Stage.find(aspect: 0.62);
  final universe = Universe(stage.width, stage.height);
  final readout = Readout();
  var seed = DateTime.now().millisecondsSinceEpoch;

  var running = true;
  var trails = true;
  var preset = 'orbits';
  var newRadius = 6.0;
  var newCharge = 0.0;
  var owed = 0.0;

  // ---- controls -------------------------------------------------------------

  late web.HTMLButtonElement play;
  void setRunning(bool on) {
    running = on;
    play.textContent = on ? 'pause' : 'play';
  }

  final top = Controls.line();
  play = top.button('pause', () => setRunning(!running), title: 'space');
  top.button('step', () {
    setRunning(false);
    universe.step(1 / 60);
  }, title: 's');
  late void Function() reset;
  top.button('reset', () => reset(), title: 'r');
  top.button('empty', () => universe.clear(), title: 'c');
  final presetBox = top.select('universe', Universe.presets, (v) {
    preset = v;
    reset();
  });
  late web.HTMLButtonElement trailsButton;
  trailsButton = top.button('trails on', () {
    trails = !trails;
    trailsButton.textContent = trails ? 'trails on' : 'trails off';
  }, title: 't');

  // Gravity between bodies and the electric constant both span several
  // orders of magnitude between presets, so their sliders are logarithmic:
  // the far left is exactly zero, then 1 up to 10,000 (or 100,000).
  double fromLog(double s, int decades) => s <= 0 ? 0 : math.pow(10, s * decades).toDouble();
  double toLog(double v, int decades) => v <= 0 ? 0 : (math.log(v) / math.ln10 / decades).clamp(0, 1);
  String compact(double v) => v == 0
      ? 'off'
      : v >= 1000
          ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k'
          : v.toStringAsFixed(v < 10 ? 1 : 0);

  final laws = universe.laws;
  final forces = Controls.line();
  final gravity = forces.slider('pull down', 0, 1000, 0, (v) => laws.gravity = v, step: 10);
  final attraction = forces.slider('gravity', 0, 1, 0, (v) => laws.attraction = fromLog(v, 4),
      step: 0.001, format: (s) => compact(fromLog(s, 4)));
  final electric = forces.slider('charge', 0, 1, 0, (v) => laws.electric = fromLog(v, 5),
      step: 0.001, format: (s) => compact(fromLog(s, 5)));

  final medium = Controls.line();
  final wind = medium.slider('wind', -400, 400, 0, (v) => laws.wind = v, step: 10);
  final drag = medium.slider('drag', 0, 3, 0, (v) => laws.drag = v, step: 0.05);
  final bounce = medium.slider('bounce', 0, 1, 0.9, (v) => laws.restitution = v, step: 0.01);

  final world = Controls.line();
  final walls = world.select('walls', ['walls bounce', 'walls wrap', 'no walls'], (v) {
    laws.walls = {'walls bounce': Walls.bounce, 'walls wrap': Walls.wrap, 'no walls': Walls.open}[v]!;
  });
  final contact = world.select('contact', ['bodies bounce', 'bodies merge'], (v) {
    laws.contact = v == 'bodies merge' ? Contact.merge : Contact.bounce;
  });
  world.slider('new body', 2, 30, newRadius, (v) => newRadius = v, format: (v) => '${v.round()}px');
  world.select('new body charge', ['neutral', 'charge +', 'charge −'], (v) {
    newCharge = switch (v) { 'charge +' => 1.0, 'charge −' => -1.0, _ => 0.0 };
  });

  /// Brings every control in line with the laws, after a preset set them.
  void showLaws() {
    gravity.value = laws.gravity;
    attraction.value = toLog(laws.attraction, 4);
    electric.value = toLog(laws.electric, 5);
    wind.value = laws.wind;
    drag.value = laws.drag;
    bounce.value = laws.restitution;
    walls.value = switch (laws.walls) { Walls.bounce => 'walls bounce', Walls.wrap => 'walls wrap', Walls.open => 'no walls' };
    contact.value = laws.contact == Contact.merge ? 'bodies merge' : 'bodies bounce';
  }

  reset = () {
    seed++;
    universe
      ..width = stage.width
      ..height = stage.height
      ..preset(preset, Rng(seed));
    presetBox.value = preset;
    showLaws();
    _trailsFrom = null;
  };

  onKey({
    ' ': () => setRunning(!running),
    's': () {
      setRunning(false);
      universe.step(1 / 60);
    },
    'r': () => reset(),
    'c': () => universe.clear(),
    't': () => trailsButton.click(),
  });

  // ---- flinging -------------------------------------------------------------

  // Press to place a body; drag before letting go to throw it. The line
  // shows where it will go, and its length sets how fast.
  (double, double)? aimFrom;
  (double, double)? aimTo;
  stage.canvas.addEventListener('pointerdown', ((web.PointerEvent e) {
    aimFrom = aimTo = stage.locate(e);
    stage.canvas.setPointerCapture(e.pointerId);
  }).toJS);
  stage.canvas.addEventListener('pointermove', ((web.PointerEvent e) {
    if (aimFrom != null) aimTo = stage.locate(e);
  }).toJS);
  stage.canvas.addEventListener('pointerup', ((web.PointerEvent e) {
    final from = aimFrom;
    if (from == null) return;
    final to = stage.locate(e);
    const throwing = 2.5;
    if (universe.bodies.length < _maxBodies) {
      universe.add(Vec2(from.$1, from.$2),
          velocity: Vec2((to.$1 - from.$1) * throwing, (to.$2 - from.$2) * throwing),
          radius: newRadius,
          charge: newCharge);
    }
    aimFrom = aimTo = null;
  }).toJS);
  stage.canvas.addEventListener('pointercancel', ((web.Event _) => aimFrom = aimTo = null).toJS);

  web.window.addEventListener('resize', ((web.Event _) {
    universe
      ..width = stage.width
      ..height = stage.height;
    _trailsFrom = null;
  }).toJS);

  // ---- the loop -------------------------------------------------------------

  reset();
  animate((seconds) {
    if (running) {
      owed += seconds;
      // Fixed steps of 1/60 s keep the physics the same on a 120 Hz screen
      // as on a 60 Hz one; at most two per frame if the tab falls behind.
      var steps = 0;
      while (owed >= 1 / 60 && steps < 2) {
        universe.step(1 / 60);
        owed -= 1 / 60;
        steps++;
      }
      if (steps == 2) owed = 0;
    }
    draw(stage, universe, trails, aimFrom, aimTo, newRadius);

    final p = universe.momentum.length;
    readout.set('${universe.bodies.length} bodies · energy ${_sci(universe.energy)} · '
        'momentum ${_sci(p)} · ${universe.contactsLastStep} contacts');
  });
}

const _maxBodies = 700;

/// The ink colour the trails were last drawn in, so a theme change wipes the
/// canvas once instead of fading one background into another.
String? _trailsFrom;

void draw(Stage stage, Universe universe, bool trails, (double, double)? aimFrom, (double, double)? aimTo,
    double newRadius) {
  final ink = Ink.read();
  final ctx = stage.ctx;

  // Trails: instead of wiping the canvas, lay a mostly transparent sheet of
  // background over the last frame, so old positions fade out over a second.
  if (trails && _trailsFrom == ink.bg) {
    ctx.globalAlpha = 0.18;
    stage.fill(ink.bg);
    ctx.globalAlpha = 1;
  } else {
    stage.fill(ink.bg);
    _trailsFrom = ink.bg;
  }

  // Neutral and positive bodies are solid ink; negative ones are rings, so
  // charge reads without colour.
  ctx.fillStyle = ink.fg.toJS;
  ctx.beginPath();
  for (final b in universe.bodies) {
    if (b.charge < 0) continue;
    ctx.moveTo(b.x + b.radius, b.y);
    ctx.arc(b.x, b.y, b.radius, 0, math.pi * 2);
  }
  ctx.fill();

  ctx.strokeStyle = ink.fg.toJS;
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  for (final b in universe.bodies) {
    if (b.charge >= 0) continue;
    final r = math.max(b.radius - 0.6, 0.5);
    ctx.moveTo(b.x + r, b.y);
    ctx.arc(b.x, b.y, r, 0, math.pi * 2);
  }
  ctx.stroke();

  if (aimFrom != null && aimTo != null) {
    ctx.strokeStyle = ink.muted.toJS;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(aimFrom.$1, aimFrom.$2, newRadius, 0, math.pi * 2);
    ctx.moveTo(aimFrom.$1, aimFrom.$2);
    ctx.lineTo(aimTo.$1, aimTo.$2);
    ctx.stroke();
    // The next frame's trail sheet shouldn't smear the aiming line.
    _trailsFrom = null;
  }
}

/// Short, readable numbers for the readout: 1234 → 1.2k, 3.4e7 → 34M.
String _sci(double v) {
  final a = v.abs();
  final sign = v < 0 ? '−' : '';
  if (a < 1000) return '$sign${a.toStringAsFixed(a < 10 ? 1 : 0)}';
  const units = ['k', 'M', 'G', 'T', 'P'];
  var scaled = a, unit = -1;
  while (scaled >= 1000 && unit < units.length - 1) {
    scaled /= 1000;
    unit++;
  }
  return '$sign${scaled.toStringAsFixed(scaled < 10 ? 1 : 0)}${units[unit]}';
}
