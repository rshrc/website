import 'dart:js_interop';

import '../../shared/page.dart';
import '../model/model.dart';
import 'creature_art.dart';
import 'palette.dart';

/// The key under the map: each gene drawn low and high, side by side, and
/// when body shapes are on, a second row with every shape and a hybrid.
class GeneKey {
  final Stage stage;

  GeneKey(this.stage);

  static const _plain = Genes(speed: 32, size: 0.9, sight: 50, aggression: 0.02, idealClimate: 0.6);

  static Genes _with({double? speed, double? size, double? sight, double? aggression, double? idealClimate}) => Genes(
        speed: speed ?? _plain.speed,
        size: size ?? _plain.size,
        sight: sight ?? _plain.sight,
        aggression: aggression ?? _plain.aggression,
        idealClimate: idealClimate ?? _plain.idealClimate,
      );

  /// Each gene: its name, what low and high look like, and a creature of
  /// each.
  static final _genes = [
    ('size', 'small', 'big', _with(size: 0.6), _with(size: 1.6)),
    ('speed', 'slow', 'fast', _with(speed: 15), _with(speed: 70)),
    ('sight', 'short', 'far', _with(sight: 12), _with(sight: 150)),
    ('aggression', 'gentle', 'fierce', _plain, _with(aggression: 0.6)),
    ('climate', 'warm', 'cold', _with(idealClimate: 0.9), _with(idealClimate: 0.05)),
  ];

  void draw(Palette palette, {required bool bodyShapes}) {
    stage.setHeight(bodyShapes ? 170 : 80);
    final ink = palette.ink, ctx = stage.ctx;
    stage.fill(ink.bg);
    ctx
      ..font = '12px Times, Georgia, serif'
      ..textBaseline = 'alphabetic'
      ..textAlign = 'center';

    final geneWidth = stage.width / _genes.length;
    for (final (i, (name, low, high, lowGenes, highGenes)) in _genes.indexed) {
      final centre = geneWidth * (i + 0.5), lowX = centre - geneWidth * 0.2, highX = centre + geneWidth * 0.2;
      ctx.fillStyle = ink.fg.toJS;
      ctx.fillText(name, centre, 13);
      drawCreature(ctx, lowGenes, x: lowX, y: 42, heading: 0, scale: 2.2, colour: ink.muted);
      drawCreature(ctx, highGenes, x: highX, y: 42, heading: 0, scale: 2.2, colour: ink.muted);
      ctx.fillStyle = ink.muted.toJS;
      ctx.fillText(low, lowX, 76);
      ctx.fillText(high, highX, 76);
    }

    if (bodyShapes) _drawShapes(palette);
    ctx.textAlign = 'start';
  }

  /// The five body shapes and what each is good for, and a hybrid, whose
  /// body is halfway between its parents' shapes.
  void _drawShapes(Palette palette) {
    final ink = palette.ink, ctx = stage.ctx;
    const top = 86.0;
    Genes shaped(Shape a, Shape b) =>
        Genes(speed: 32, size: 1.1, sight: 40, aggression: 0.02, idealClimate: 0.6, firstShape: a, secondShape: b);
    final bodies = [
      for (final shape in Shape.values) (shape.label, shape.advantage, shaped(shape, shape)),
      ('hybrid', 'half of each', shaped(Shape.round, Shape.square)),
    ];
    final bodyWidth = stage.width / bodies.length;
    for (final (i, (name, advantage, genes)) in bodies.indexed) {
      final centre = bodyWidth * (i + 0.5);
      ctx.fillStyle = ink.fg.toJS;
      ctx.fillText(name, centre, top + 12);
      drawCreature(ctx, genes, x: centre, y: top + 42, heading: 0, scale: 2.6, colour: ink.muted);
      ctx.fillStyle = ink.muted.toJS;
      ctx.fillText(advantage, centre, top + 76);
    }
  }
}
