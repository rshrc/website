import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../model/model.dart';

/// Draws a creature from its genes, exaggerated so that differences show:
///
/// * size — how big the body is;
/// * speed — how long and streamlined (slow ones are round);
/// * sight — how long the antennae are;
/// * aggression — how big the horn is;
/// * climate — a fringe of fur, longer the colder it's built for;
///   warm-built creatures are smooth;
/// * shape — the outline, halfway between its two shape alleles.
///
/// [growth] shrinks the young; [plain] skips the details, for top speed.
void drawCreature(web.CanvasRenderingContext2D ctx, Genes genes,
    {required double x,
    required double y,
    required double heading,
    required double scale,
    required String colour,
    double growth = 1,
    bool plain = false,
    bool bodyShapes = true}) {
  final radius = (1.2 + 3.3 * genes.size) * growth * scale;
  final stretch = ((genes.speed - 15) / 50).clamp(0.0, 1.1);
  final length = radius * (1 + stretch), width = radius * (1 - stretch * 0.3);
  final cos = math.cos(heading), sin = math.sin(heading);
  ctx
    ..fillStyle = colour.toJS
    ..strokeStyle = colour.toJS;

  ctx.beginPath();
  if (plain || radius < 2 || !bodyShapes) {
    ctx.ellipse(x, y, length, width, heading, 0, math.pi * 2);
  } else {
    final outline = _outlineOf(genes.firstShape, genes.secondShape);
    for (var k = 0; k < _outlinePoints; k++) {
      final along = outline[2 * k] * length, across = outline[2 * k + 1] * width;
      final px = x + cos * along - sin * across, py = y + sin * along + cos * across;
      k == 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
    }
    ctx.closePath();
  }
  ctx.fill();
  if (plain || radius < 1.8) return; // too small, or too fast, to show the details

  ctx
    ..lineWidth = math.max(1, radius * 0.13)
    ..beginPath();
  _fur(ctx, genes, x, y, cos, sin, radius, length, width);
  _antennae(ctx, genes, x, y, heading, cos, sin, radius, length);
  ctx.stroke();
  if (genes.aggression > 0.02) _horn(ctx, genes, x, y, cos, sin, radius, length, width);
}

/// Fourteen tufts standing out from the edge, longer the colder it's built
/// for.
void _fur(web.CanvasRenderingContext2D ctx, Genes genes, double x, double y, double cos, double sin, double radius,
    double length, double width) {
  final furriness = (0.5 - genes.idealClimate) * 2;
  if (furriness <= 0.05) return;
  final tuft = radius * 0.75 * furriness;
  for (var k = 0; k < 14; k++) {
    final angle = k * math.pi / 7;
    // A point on the edge, and the outward normal there.
    final edgeX = math.cos(angle) * length, edgeY = math.sin(angle) * width;
    final normalX = math.cos(angle) * width, normalY = math.sin(angle) * length;
    final normalLength = math.sqrt(normalX * normalX + normalY * normalY);
    final baseX = x + cos * edgeX - sin * edgeY, baseY = y + sin * edgeX + cos * edgeY;
    final outX = (cos * normalX - sin * normalY) / normalLength, outY = (sin * normalX + cos * normalY) / normalLength;
    ctx.moveTo(baseX, baseY);
    ctx.lineTo(baseX + outX * tuft, baseY + outY * tuft);
  }
}

/// Two feelers from the front, longer the farther it sees.
void _antennae(web.CanvasRenderingContext2D ctx, Genes genes, double x, double y, double heading, double cos,
    double sin, double radius, double length) {
  final feeler = radius * (0.3 + genes.sight / 200 * 2.8);
  final frontX = x + cos * length * 0.8, frontY = y + sin * length * 0.8;
  for (final side in [-0.55, 0.55]) {
    final angle = heading + side;
    ctx.moveTo(frontX, frontY);
    ctx.lineTo(frontX + math.cos(angle) * feeler, frontY + math.sin(angle) * feeler);
  }
}

/// A horn at the front, bigger the fiercer it is.
void _horn(web.CanvasRenderingContext2D ctx, Genes genes, double x, double y, double cos, double sin, double radius,
    double length, double width) {
  final horn = radius * (0.15 + genes.aggression * 2.6), halfBase = width * 0.45;
  ctx.beginPath();
  ctx.moveTo(x + cos * (length + horn), y + sin * (length + horn));
  ctx.lineTo(x + cos * length * 0.75 - sin * halfBase, y + sin * length * 0.75 + cos * halfBase);
  ctx.lineTo(x + cos * length * 0.75 + sin * halfBase, y + sin * length * 0.75 - cos * halfBase);
  ctx.closePath();
  ctx.fill();
}

/// Points around a body outline.
const _outlinePoints = 36;

/// How far a shape's edge is from its centre in direction [angle] (0 is the
/// front), for a body of unit size.
double _edge(Shape shape, double angle) {
  switch (shape) {
    case Shape.round:
      return 1;
    case Shape.pointed:
      // A triangle with one corner at the front.
      const third = 2 * math.pi / 3;
      final fromCorner = (angle % third + third) % third - third / 2;
      return 1.3 * 0.5 / math.cos(fromCorner);
    case Shape.square:
      return 0.9 / math.max(math.cos(angle).abs(), math.sin(angle).abs());
    case Shape.spiky:
      return 0.78 + 0.55 * math.pow(math.max(0, math.cos(7 * angle)), 3);
    case Shape.crescent:
      // A round body with a deep bite out of the back.
      var fromBack = (angle - math.pi) % (2 * math.pi);
      if (fromBack > math.pi) fromBack -= 2 * math.pi;
      return 1.05 - 0.85 * math.exp(-(fromBack / 0.6) * (fromBack / 0.6));
  }
}

final _outlines = <(Shape, Shape), List<double>>{};

/// The outline of a body with shape alleles [a] and [b]: at every angle,
/// halfway between the two shapes' edges, as x, y pairs. Cached; there are
/// only 25.
List<double> _outlineOf(Shape a, Shape b) => _outlines[(a, b)] ??= [
      for (var k = 0; k < _outlinePoints; k++)
        for (final component in [math.cos, math.sin])
          component(2 * math.pi * k / _outlinePoints) *
              (_edge(a, 2 * math.pi * k / _outlinePoints) + _edge(b, 2 * math.pi * k / _outlinePoints)) /
              2,
    ];
