import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../model/model.dart';
import 'handle.dart';

/// Draws the bench's pieces and light onto a canvas already scaled to bench
/// millimetres.
///
/// The board stays dark whatever the page's theme: light only shows up
/// against the dark, the way an optics lab turns its lights off.
class Painter {
  final web.CanvasRenderingContext2D ctx;

  /// One screen pixel, in bench millimetres. Line widths and sizes are
  /// written in pixels and multiplied by this, so they stay the same at
  /// any zoom.
  final double px;

  Painter(this.ctx, this.px);

  static const background = '#0c0c0f';

  /// Glass is drawn as a faint blue tint, under the light.
  void glass(Glass g) {
    outline(g);
    ctx.fillStyle = 'rgba(160,195,255,0.09)'.toJS;
    ctx.fill();
  }

  /// Every ray, added together as light adds: red, green and blue lasers
  /// crossing make white where they meet. Grouped by colour so each colour
  /// is one path, and drawn twice: a soft glow, then the ray.
  void rays(List<RaySegment> segments) {
    final byColour = <String, List<RaySegment>>{};
    for (final s in segments) {
      byColour.putIfAbsent(css(shade(s.colour, s.intensity)), () => []).add(s);
    }
    _adding(() {
      ctx.lineCap = 'round';
      for (final (width, alpha) in [(5.0, 0.16), (1.5, 1.0)]) {
        ctx.lineWidth = width * px;
        ctx.globalAlpha = alpha;
        for (final MapEntry(key: colour, value: segs) in byColour.entries) {
          ctx.strokeStyle = colour.toJS;
          ctx.beginPath();
          for (final s in segs) {
            ctx.moveTo(s.x1, s.y1);
            ctx.lineTo(s.x2, s.y2);
          }
          ctx.stroke();
        }
      }
      ctx.globalAlpha = 1;
    });
  }

  /// A soft patch of colour wherever light lands on a screen.
  void spots(Iterable<Hit> landings) => _adding(() {
        for (final h in landings) {
          ctx.fillStyle = css(shade(h.colour, h.intensity), 0.55).toJS;
          dot(h.x, h.y, 4);
        }
      });

  void piece(Piece p, {required bool selected}) {
    final lift = selected ? 1.0 : 0.0;
    outline(p);
    switch (p) {
      case Laser():
        ctx.fillStyle = '#26262b'.toJS;
        ctx.fill();
        _stroke(selected ? '#eeeeee' : '#77777f', 1);
        // The aperture glows the colour it shines.
        final (x, y) = p.toWorld(-3, 0);
        ctx.fillStyle = css(p.white ? Rgb.white : laserRgb(p.nm)).toJS;
        dot(x, y, 2.5);
      case Mirror() || CurvedMirror():
        _stroke(selected ? '#ffffff' : '#c9ccd2', 3 + lift);
      case Splitter():
        _stroke(selected ? 'rgba(235,240,255,0.95)' : 'rgba(200,210,230,0.6)', 2 + lift);
      case Grating():
        dashed([1.2, 1.8], () => _stroke(selected ? '#dddddd' : '#9a9aa2', 3 + lift));
      case Filter():
        _stroke(css(laserRgb(p.nm), selected ? 0.95 : 0.6), 4 + lift);
      case Screen():
        _stroke(selected ? '#bbbbbb' : '#55555c', 5 + lift);
      case Glass():
        _stroke(selected ? 'rgba(225,238,255,0.95)' : 'rgba(170,200,255,0.5)', 1 + lift);
    }
    if (selected) _handle(p);
  }

  /// Traces the outline of [p] as the current path, edge after edge.
  void outline(Piece p) {
    ctx.beginPath();
    for (final e in p.edges()) {
      switch (e) {
        case LineEdge():
          ctx.lineTo(e.ax, e.ay);
          ctx.lineTo(e.bx, e.by);
        case ArcEdge():
          ctx.arc(e.cx, e.cy, e.r, e.from, e.from + e.sweep);
      }
    }
    if (p is Glass || p is Laser) ctx.closePath();
  }

  /// A line from the piece's pivot to a ring, for turning it by.
  void _handle(Piece p) {
    final (hx, hy) = handleOf(p);
    final (ax, ay) = p is Laser ? p.toWorld(0, 0) : (p.x, p.y);
    ctx.beginPath();
    ctx.moveTo(ax, ay);
    ctx.lineTo(hx, hy);
    _stroke('rgba(255,255,255,0.35)', 1);
    ring(hx, hy, 5, filled: true);
  }

  /// A white ring of [radius] pixels, hollow or [filled] with the board.
  void ring(double x, double y, double radius, {bool filled = false}) {
    ctx.beginPath();
    ctx.arc(x, y, radius * px, 0, 2 * math.pi);
    if (filled) {
      ctx.fillStyle = background.toJS;
      ctx.fill();
    }
    _stroke('rgba(255,255,255,0.9)', 1);
  }

  /// A filled dot of [radius] pixels, in the current fill.
  void dot(double x, double y, double radius) {
    ctx.beginPath();
    ctx.arc(x, y, radius * px, 0, 2 * math.pi);
    ctx.fill();
  }

  /// Runs [draw] with dashes of the given pixel lengths.
  void dashed(List<double> pattern, void Function() draw) {
    ctx.setLineDash(pattern.map((d) => (d * px).toJS).toList().toJS);
    draw();
    ctx.setLineDash(<JSNumber>[].toJS);
  }

  void _stroke(String colour, double width) {
    ctx.strokeStyle = colour.toJS;
    ctx.lineWidth = width * px;
    ctx.stroke();
  }

  /// Runs [draw] with colours adding up, the way light does.
  void _adding(void Function() draw) {
    ctx.globalCompositeOperation = 'lighter';
    draw();
    ctx.globalCompositeOperation = 'source-over';
  }
}

/// How bright light of [intensity] looks. Eyes see brightness roughly as a
/// power of intensity, so a 4% reflection still shows, dimly.
Rgb shade(Rgb colour, double intensity) => colour * math.pow(intensity, 0.72).toDouble();

/// [c] as a CSS colour, clipped to what a screen can show.
String css(Rgb c, [double alpha = 1]) {
  int channel(double v) => (v.clamp(0, 1) * 255).round();
  final rgb = '${channel(c.r)},${channel(c.g)},${channel(c.b)}';
  return alpha >= 1 ? 'rgb($rgb)' : 'rgba($rgb,$alpha)';
}
