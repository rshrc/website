import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../shared/page.dart';
import 'fractal.dart';

/// A fractal explorer. Click to zoom in, drag to move, scroll to zoom
/// smoothly.
void main() {
  final stage = Stage.find(aspect: 0.62);
  final readout = Readout();
  final renderer = _Renderer(stage);
  var detail = 1.0;
  View view = Place.all.first.view;

  late web.HTMLButtonElement juliaButton;
  late web.HTMLSelectElement goTo;

  void show(View next) {
    view = next;
    renderer.restart();
    juliaButton
      ..textContent = view.kind == Kind.julia ? 'back to Mandelbrot' : 'Julia set here'
      ..disabled = view.kind == Kind.burningShip;
  }

  // In the Mandelbrot set, every point c has a Julia set of its own, and the
  // Julia set looks like the Mandelbrot set does near c. So: zoom somewhere
  // interesting, then see its Julia set.
  void toggleJulia() {
    switch (view.kind) {
      case Kind.mandelbrot:
        show(View(Kind.julia, 0, 0, 3.4, jr: view.cx, ji: view.cy));
      case Kind.julia:
        show(View(Kind.mandelbrot, view.jr, view.ji, 0.05));
      case Kind.burningShip:
        break;
    }
  }

  void zoomCentre(double factor) => show(view.zoomAt(stage.width / 2, stage.height / 2, stage.width, stage.height, factor));

  final top = Controls.line();
  top.button('zoom out', () => zoomCentre(0.5), title: '−');
  juliaButton = top.button('Julia set here', toggleJulia, title: 'j');
  top.button('start again', () {
    goTo.value = Place.all.first.name;
    show(Place.all.first.view);
  }, title: 'r');
  goTo = top.select('go to', Place.all.map((p) => p.name).toList(), (name) {
    show(Place.all.firstWhere((p) => p.name == name).view);
  });
  Controls.line().slider('detail', 0.5, 4, detail, (v) {
    detail = v;
    renderer.restart();
  }, step: 0.25, format: (v) => '×${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}');

  onKey({
    '+': () => zoomCentre(2),
    '=': () => zoomCentre(2),
    '-': () => zoomCentre(0.5),
    'j': toggleJulia,
    'r': () {
      goTo.value = Place.all.first.name;
      show(Place.all.first.view);
    },
  });

  // ---- pointer: click zooms, drag pans, wheel zooms smoothly ------------------

  (double, double)? pressedAt;
  (double, double)? lastAt;
  var dragged = false;
  stage.canvas.addEventListener('pointerdown', ((web.PointerEvent e) {
    pressedAt = lastAt = stage.locate(e);
    dragged = false;
    stage.canvas.setPointerCapture(e.pointerId);
  }).toJS);
  stage.canvas.addEventListener('pointermove', ((web.PointerEvent e) {
    final start = pressedAt, last = lastAt;
    if (start == null || last == null) return;
    final now = stage.locate(e);
    if (!dragged && (now.$1 - start.$1).abs() + (now.$2 - start.$2).abs() < 5) return;
    dragged = true;
    show(view.panBy(now.$1 - last.$1, now.$2 - last.$2, stage.width));
    lastAt = now;
  }).toJS);
  stage.canvas.addEventListener('pointerup', ((web.PointerEvent e) {
    final start = pressedAt;
    pressedAt = lastAt = null;
    if (start == null || dragged) return;
    // A click zooms in; with shift held, out.
    show(view.zoomAt(start.$1, start.$2, stage.width, stage.height, e.shiftKey ? 0.5 : 2));
  }).toJS);
  stage.canvas.addEventListener('pointercancel', ((web.Event _) => pressedAt = lastAt = null).toJS);
  stage.canvas.addEventListener(
      'wheel',
      ((web.WheelEvent e) {
        e.preventDefault();
        final (x, y) = stage.locate(e);
        show(view.zoomAt(x, y, stage.width, stage.height, math.exp(-e.deltaY * 0.0025)));
      }).toJS,
      web.AddEventListenerOptions(passive: false));

  // ---- the loop -------------------------------------------------------------

  show(view);
  animate((_) {
    final limit = view.iterations(detail);
    renderer.work(view, limit);
    final names = {Kind.mandelbrot: 'Mandelbrot', Kind.julia: 'Julia', Kind.burningShip: 'Burning Ship'};
    final where = view.kind == Kind.julia
        ? 'c = ${_complex(view.jr, view.ji, 4)}'
        : 'centre ${_complex(view.cx, view.cy, _digits(view.span))}';
    final zoom = view.zoom < 1000 ? view.zoom.toStringAsFixed(view.zoom < 10 ? 1 : 0) : view.zoom.toStringAsExponential(1);
    final deepest = view.span <= View.deepest ? ' · as deep as a double can go' : '';
    readout.set('${names[view.kind]} · $where · zoom ×$zoom · $limit iterations'
        '${renderer.done ? '' : ' · drawing…'}$deepest');
  });
}

/// Enough decimal places to tell this view from its neighbours.
int _digits(double span) => (2 - math.log(span) / math.ln10).ceil().clamp(2, 15);

String _complex(double re, double im, int digits) =>
    '${re < 0 ? '−' : ''}${re.abs().toStringAsFixed(digits)} ${im < 0 ? '−' : '+'} ${im.abs().toStringAsFixed(digits)}i';

/// Draws a view into the canvas a slice at a time.
///
/// A new view is first drawn coarsely — one sample per 4×4 block of screen
/// pixels, which is sixteen times faster — so panning and zooming feel
/// immediate. Then it's redrawn at full resolution, a few rows per frame, so
/// the page never freezes however deep the zoom. Pixels are written straight
/// into an ImageData buffer, which is far faster than drawing rectangles.
class _Renderer {
  final Stage stage;
  web.ImageData? _image;
  Uint8ClampedList _px = Uint8ClampedList(0);
  int _w = 0, _h = 0;
  int _pass = 0, _row = 0;
  String _inkKey = '';
  (int, int, int) _fg = (17, 17, 17), _bg = (255, 255, 255);

  _Renderer(this.stage);

  bool get done => _pass >= 2;

  void restart() {
    _pass = 0;
    _row = 0;
  }

  void work(View view, int limit) {
    final canvas = stage.canvas;
    if (canvas.width != _w || canvas.height != _h) {
      _w = canvas.width;
      _h = canvas.height;
      _image = stage.ctx.createImageData(_w.toJS, _h);
      _px = _image!.data.toDart;
      restart();
    }
    final ink = Ink.read();
    if ('${ink.fg}${ink.bg}' != _inkKey) {
      _inkKey = '${ink.fg}${ink.bg}';
      _fg = _rgb(ink.fg, (17, 17, 17));
      _bg = _rgb(ink.bg, (255, 255, 255));
      restart();
    }
    if (done) return;

    final budget = Stopwatch()..start();
    final block = _pass == 0 ? 4 : 1;
    final logLimit = math.log(limit);
    final w = _w, h = _h, px = _px;
    final (fr, fg, fb) = _fg;
    final (br, bg, bb) = _bg;

    while (_row < h && budget.elapsedMilliseconds < 12) {
      final y = _row;
      for (var x = 0; x < w; x += block) {
        final (re, im) = view.at(x + block / 2, y + block / 2, w.toDouble(), h.toDouble());
        final nu = escape(view.kind, re, im, limit, jr: view.jr, ji: view.ji);
        // Ink for the set itself; outside, a wash from paper to ink that
        // darkens the longer a point held out, on a log scale because the
        // counts near the edge run into the hundreds.
        final s = nu < 0 ? 1.0 : math.pow((math.log(math.max(nu, 1)) / logLimit).clamp(0, 1), 1.6).toDouble();
        final r = br + (fr - br) * s, g = bg + (fg - bg) * s, b = bb + (fb - bb) * s;
        for (var dy = 0; dy < block && y + dy < h; dy++) {
          var i = ((y + dy) * w + x) * 4;
          for (var dx = 0; dx < block && x + dx < w; dx++) {
            px[i] = r.round();
            px[i + 1] = g.round();
            px[i + 2] = b.round();
            px[i + 3] = 255;
            i += 4;
          }
        }
      }
      _row += block;
    }
    stage.ctx.putImageData(_image!, 0, 0);
    if (_row >= h) {
      _pass++;
      _row = 0;
    }
  }
}

/// Reads a CSS colour written as #rgb or #rrggbb.
(int, int, int) _rgb(String css, (int, int, int) fallback) {
  var hex = css.trim();
  if (!hex.startsWith('#')) return fallback;
  hex = hex.substring(1);
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length != 6) return fallback;
  final v = int.tryParse(hex, radix: 16);
  if (v == null) return fallback;
  return ((v >> 16) & 255, (v >> 8) & 255, v & 255);
}
