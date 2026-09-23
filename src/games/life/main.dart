import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../shared/page.dart';
import '../shared/rng.dart';
import 'sim.dart';

/// Conway's Game of Life. Click or drag to draw; pick a pattern to stamp it
/// where you click instead.
void main() {
  const cols = 120, rows = 75;
  final stage = Stage.find(aspect: rows / cols);
  final life = LifeSim(cols, rows);
  final rng = Rng(DateTime.now().millisecondsSinceEpoch);
  final readout = Readout();

  var running = false;
  var perSecond = 12.0;
  var owed = 0.0;
  var brush = 'draw';

  life.randomize(rng, 0.18);

  late web.HTMLButtonElement play;
  void setRunning(bool on) {
    running = on;
    play.textContent = on ? 'pause' : 'play';
  }

  final top = Controls.line();
  play = top.button('play', () => setRunning(!running), title: 'space');
  top.button('step', () {
    setRunning(false);
    life.step();
  }, title: 's');
  top.button('random', () => life.randomize(rng, 0.18), title: 'r');
  top.button('clear', () {
    setRunning(false);
    life.clear();
  }, title: 'c');

  final second = Controls.line();
  second.select('what a click does', ['draw', ...Pattern.all.map((p) => p.name)], (v) => brush = v);
  second.slider('speed', 1, 60, perSecond, (v) => perSecond = v, format: (v) => '${v.round()}/s');
  late web.HTMLInputElement ruleBox;
  ruleBox = second.text('rule', life.rule.notation, (text) {
    final rule = LifeRule.tryParse(text);
    if (rule != null) life.rule = rule;
    ruleBox.value = life.rule.notation;
  }, size: 7);

  // Open on a world already in motion.
  setRunning(true);

  onKey({
    ' ': () => setRunning(!running),
    's': () {
      setRunning(false);
      life.step();
    },
    'r': () => life.randomize(rng, 0.18),
    'c': () {
      setRunning(false);
      life.clear();
    },
  });

  // ---- drawing with the pointer ---------------------------------------------

  bool? painting;
  (int, int) cellAt(web.PointerEvent e) {
    final (x, y) = stage.locate(e);
    return ((x / stage.width * cols).floor().clamp(0, cols - 1), (y / stage.height * rows).floor().clamp(0, rows - 1));
  }

  stage.canvas.addEventListener('pointerdown', ((web.PointerEvent e) {
    final (x, y) = cellAt(e);
    if (brush != 'draw') {
      life.stamp(Pattern.all.firstWhere((p) => p.name == brush), x, y);
      return;
    }
    // Drawing pauses the world: most hand-drawn shapes would otherwise be
    // gone a generation after they were drawn. Press play when it's ready.
    setRunning(false);
    // The first cell decides: start on a live cell and the stroke erases.
    painting = !life.isAlive(x, y);
    life.set(x, y, painting!);
    stage.canvas.setPointerCapture(e.pointerId);
  }).toJS);
  stage.canvas.addEventListener('pointermove', ((web.PointerEvent e) {
    if (painting == null) return;
    final (x, y) = cellAt(e);
    life.set(x, y, painting!);
  }).toJS);
  for (final end in ['pointerup', 'pointercancel']) {
    stage.canvas.addEventListener(end, ((web.Event _) => painting = null).toJS);
  }

  // ---- the loop -------------------------------------------------------------

  animate((seconds) {
    if (running) {
      owed += seconds * perSecond;
      // Never more than a few generations per frame, however far behind.
      for (var i = 0; i < math.min(owed.floor(), 4); i++) {
        life.step();
      }
      owed -= owed.floor();
    }
    draw(stage, life);

    final settled = switch (life.period) {
      null => '',
      _ when life.population == 0 => ' · everything died',
      1 => ' · settled into a still life at generation ${life.settledAt}',
      final p => ' · repeating every $p generations since ${life.settledAt}',
    };
    readout.set('generation ${life.generation} · ${life.population} alive$settled');
  });
}

/// Live cells in the page's ink. Cells fade as they age, so still lifes
/// recede and whatever is changing stays dark.
void draw(Stage stage, LifeSim life) {
  final ink = Ink.read();
  final ctx = stage.ctx;
  stage.fill(ink.bg);
  final w = stage.width / life.width, h = stage.height / life.height;
  // A hairline gap between cells reads as a grid without drawing one.
  final gap = w > 5 ? 1.0 : 0.0;

  ctx.fillStyle = ink.fg.toJS;
  // Four shades, drawn one after another, so the colour is set four times a
  // frame instead of once per cell.
  const bands = [(1, 4, 1.0), (5, 20, 0.75), (21, 80, 0.5), (81, 255, 0.3)];
  for (final (from, to, alpha) in bands) {
    ctx.globalAlpha = alpha;
    for (var y = 0; y < life.height; y++) {
      for (var x = 0; x < life.width; x++) {
        final age = life.ageAt(x, y);
        if (age >= from && age <= to) ctx.fillRect(x * w, y * h, w - gap, h - gap);
      }
    }
  }
  ctx.globalAlpha = 1;
}
