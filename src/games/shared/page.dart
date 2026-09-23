import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

/// The browser side every game shares: a crisp canvas, the site's colours,
/// and controls written as plain text, the way the rest of the site is.
///
/// Games keep their simulation in a separate file with no web imports; this
/// is the only place that knows it's running in a browser.

/// The site's colour tokens, read from CSS so the canvas follows the theme
/// toggle and the OS setting with no second copy of the palette in Dart.
class Ink {
  final String fg, muted, rule, bg, link;

  Ink._(this.fg, this.muted, this.rule, this.bg, this.link);

  static Ink read() {
    final style = web.window.getComputedStyle(web.document.documentElement!);
    String token(String name) => style.getPropertyValue(name).trim();
    return Ink._(token('--fg'), token('--muted'), token('--rule'), token('--bg'), token('--link'));
  }
}

/// A canvas that fills its container's width at a fixed aspect ratio and
/// draws at the screen's real pixel density, so cells stay sharp on a phone.
/// Drawing code works in CSS pixels; [width] and [height] are in those.
class Stage {
  final web.HTMLCanvasElement canvas;
  final web.CanvasRenderingContext2D ctx;
  double aspect;
  double width = 0, height = 0;

  Stage._(this.canvas, this.aspect) : ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D {
    fit();
    web.window.addEventListener('resize', ((web.Event _) => fit()).toJS);
  }

  /// Takes over the `<canvas id="stage">` the page template provides.
  factory Stage.find({double aspect = 0.62}) =>
      Stage._(web.document.getElementById('stage') as web.HTMLCanvasElement, aspect);

  /// A new canvas placed right after [anchor].
  factory Stage.after(web.Element anchor, String id, {double aspect = 0.1}) {
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement..id = id;
    anchor.after(canvas);
    return Stage._(canvas, aspect);
  }

  /// A second canvas, added under the main one — for a chart, say.
  factory Stage.below(String id, {double aspect = 0.25}) {
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement..id = id;
    web.document.getElementById('stage')!.parentElement!.append(canvas);
    return Stage._(canvas, aspect);
  }

  void fit() {
    final ratio = web.window.devicePixelRatio;
    width = canvas.parentElement!.clientWidth.toDouble();
    height = (width * aspect).roundToDouble();
    canvas.style
      ..width = '${width}px'
      ..height = '${height}px';
    canvas.width = (width * ratio).round();
    canvas.height = (height * ratio).round();
    ctx.setTransform(ratio.toJS, 0, 0, ratio, 0, 0);
  }

  /// Changes the canvas's height, keeping its width. Does nothing if the
  /// height would stay within a pixel of what it is.
  void setHeight(double pixels) {
    if ((pixels - height).abs() < 1) return;
    aspect = pixels / width;
    fit();
  }

  /// Where a pointer event landed, in CSS pixels from the canvas corner.
  (double, double) locate(web.MouseEvent e) {
    final box = canvas.getBoundingClientRect();
    return (e.preciseX - box.left, e.preciseY - box.top);
  }

  void fill(String colour) {
    ctx.fillStyle = colour.toJS;
    ctx.fillRect(0, 0, width, height);
  }
}

/// A line of controls: text buttons separated by middots, like the filters
/// on the shelf page. Everything returns the element it made, for callers
/// that need to relabel it later.
class Controls {
  final web.HTMLElement _line;

  Controls._(this._line);

  /// Adds a fresh line to the `<div id="controls">` in the page template.
  factory Controls.line({String className = 'controls'}) {
    final p = web.document.createElement('p') as web.HTMLParagraphElement..className = className;
    web.document.getElementById('controls')!.append(p);
    return Controls._(p);
  }

  void _gap() {
    if (_joined) {
      _joined = false;
      return;
    }
    if (_line.childNodes.length > 0) _line.append(web.document.createTextNode(' · '));
  }

  var _joined = false;

  /// Plain text that leads into whatever comes next, with no middot
  /// between them: "add laser · mirror".
  void label(String text) {
    _gap();
    _line.append(web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'label'
      ..textContent = '$text ');
    _joined = true;
  }

  /// Empties the line, for controls that change with what's selected.
  void clear() {
    _line.textContent = '';
    _joined = false;
  }

  web.HTMLButtonElement button(String label, void Function() onPress, {String? title}) {
    _gap();
    final b = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..textContent = label;
    if (title != null) b.title = title;
    b.addEventListener('click', ((web.Event _) => onPress()).toJS);
    _line.append(b);
    return b;
  }

  /// A labelled range input. [format] turns the value into the text shown
  /// beside it.
  Slider slider(String label, double min, double max, double value, void Function(double) onChange,
      {double step = 1, String Function(double)? format}) {
    _gap();
    final wrap = web.document.createElement('label') as web.HTMLLabelElement..className = 'slider';
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'range'
      ..min = '$min'
      ..max = '$max'
      ..step = '$step'
      ..value = '$value';
    final shown = web.document.createElement('span') as web.HTMLSpanElement..className = 'value';
    String text(double v) => format?.call(v) ?? (step >= 1 ? v.round().toString() : v.toStringAsFixed(2));
    shown.textContent = text(value);
    input.addEventListener('input', ((web.Event _) {
      final v = double.parse(input.value);
      shown.textContent = text(v);
      onChange(v);
    }).toJS);
    wrap
      ..append(web.document.createTextNode('$label '))
      ..append(input)
      ..append(web.document.createTextNode(' '))
      ..append(shown);
    _line.append(wrap);
    return Slider._(input, shown, text);
  }

  /// A label and a row of options, one of them pressed, like the filters on
  /// the shelf page. Returns a function that presses an option from code,
  /// without calling [onChange].
  void Function(String) choice(String label, List<String> options, String selected, void Function(String) onChange) {
    _gap();
    _line.append(web.document.createTextNode('$label '));
    final buttons = <web.HTMLButtonElement>[];
    for (final (i, option) in options.indexed) {
      if (i > 0) _line.append(web.document.createTextNode(' '));
      final b = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..textContent = option
        ..ariaPressed = '${option == selected}';
      b.addEventListener('click', ((web.Event _) {
        for (final other in buttons) {
          other.ariaPressed = '${identical(other, b)}';
        }
        onChange(option);
      }).toJS);
      buttons.add(b);
      _line.append(b);
    }
    return (option) {
      for (final b in buttons) {
        b.ariaPressed = '${b.textContent == option}';
      }
    };
  }

  /// A label and a row of options that each switch on and off by
  /// themselves, pressed when on.
  void toggles(String label, List<String> options, Set<String> on, void Function(String option, bool on) onChange) {
    _gap();
    _line.append(web.document.createTextNode('$label '));
    for (final (i, option) in options.indexed) {
      if (i > 0) _line.append(web.document.createTextNode(' '));
      final b = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..textContent = option
        ..ariaPressed = '${on.contains(option)}';
      b.addEventListener('click', ((web.Event _) {
        final now = b.ariaPressed != 'true';
        b.ariaPressed = '$now';
        onChange(option, now);
      }).toJS);
      _line.append(b);
    }
  }

  web.HTMLSelectElement select(String label, List<String> options, void Function(String) onChange) {
    _gap();
    final s = web.document.createElement('select') as web.HTMLSelectElement..ariaLabel = label;
    for (final o in options) {
      s.append(web.document.createElement('option') as web.HTMLOptionElement
        ..value = o
        ..textContent = o);
    }
    s.addEventListener('change', ((web.Event _) => onChange(s.value)).toJS);
    _line.append(s);
    return s;
  }

  web.HTMLInputElement text(String label, String value, void Function(String) onCommit, {int size = 8}) {
    _gap();
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'text'
      ..value = value
      ..size = size
      ..ariaLabel = label
      ..spellcheck = false;
    input.addEventListener('change', ((web.Event _) => onCommit(input.value)).toJS);
    _line
      ..append(web.document.createTextNode('$label '))
      ..append(input);
    return input;
  }
}

/// A slider made by [Controls.slider].
class Slider {
  final web.HTMLInputElement input;
  final web.HTMLSpanElement _shown;
  final String Function(double) _text;

  Slider._(this.input, this._shown, this._text);

  /// Moves the slider from code — when a preset changes the thing it
  /// controls — without calling its `onChange`.
  set value(double v) {
    input.value = '$v';
    _shown.textContent = _text(double.parse(input.value));
  }
}

/// The one-line status under the canvas.
class Readout {
  final web.Element _el = web.document.getElementById('readout')!;
  String _last = '';

  void set(String text) {
    // Rewriting identical text every frame would still cost a layout.
    if (text == _last) return;
    _el.textContent = _last = text;
  }
}

/// Calls [frame] once per screen refresh with the seconds since the last
/// call, capped so a tab returning from the background doesn't try to
/// catch up on a minute of simulation in one go.
void animate(void Function(double seconds) frame) {
  double? last;
  late JSFunction tick;
  tick = ((double now) {
    final seconds = last == null ? 0.0 : math.min((now - last!) / 1000, 0.1);
    last = now;
    frame(seconds);
    web.window.requestAnimationFrame(tick);
  }).toJS;
  web.window.requestAnimationFrame(tick);
}

/// Keyboard shortcuts, ignored while typing in a field.
void onKey(Map<String, void Function()> keys) {
  web.document.addEventListener('keydown', ((web.KeyboardEvent e) {
    final target = e.target;
    if (target != null &&
        (target.isA<web.HTMLSelectElement>() ||
            (target.isA<web.HTMLInputElement>() && (target as web.HTMLInputElement).type == 'text'))) {
      return;
    }
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    final action = keys[e.key];
    if (action == null) return;
    e.preventDefault();
    action();
  }).toJS);
}

/// `package:web` types `clientX`/`clientY` as `int`, but pointer events carry
/// fractional coordinates on most screens — and compiled Dart checks the type,
/// so reading them through the `int` getter throws. Same properties, honest
/// type.
extension on web.MouseEvent {
  @JS('clientX')
  external double get preciseX;
  @JS('clientY')
  external double get preciseY;
}

/// Reads a CSS colour written as #rgb or #rrggbb, as the site's tokens are.
(int, int, int) rgbOf(String css, [(int, int, int) fallback = (17, 17, 17)]) {
  var hex = css.trim();
  if (!hex.startsWith('#')) return fallback;
  hex = hex.substring(1);
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  final v = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
  if (v == null) return fallback;
  return ((v >> 16) & 255, (v >> 8) & 255, v & 255);
}

/// The colour [t] of the way from [from] to [to], as a CSS string.
String mix(String from, String to, double t) {
  final (r1, g1, b1) = rgbOf(from);
  final (r2, g2, b2) = rgbOf(to);
  int at(int a, int b) => (a + (b - a) * t).round().clamp(0, 255);
  return 'rgb(${at(r1, r2)},${at(g1, g2)},${at(b1, b2)})';
}
