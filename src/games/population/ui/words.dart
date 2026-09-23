import '../model/model.dart';

/// Genes put into words for the page.

/// "cold", "cool", "mild", "warm" or "hot".
String climateWord(double idealClimate) => switch (idealClimate) {
      < 0.2 => 'cold',
      < 0.4 => 'cool',
      < 0.6 => 'mild',
      < 0.8 => 'warm',
      _ => 'hot',
    };

/// "round", or for a hybrid, "round-square hybrid".
String bodyWords(Body body) => body.isHybrid ? '${body.first.label}-${body.second.label} hybrid' : body.first.label;

const _shapeGlyphs = {Shape.round: '●', Shape.pointed: '▲', Shape.square: '■', Shape.spiky: '✶', Shape.crescent: '☾'};

/// "●" for a pure round body, "●■" for a round-square hybrid.
String bodyGlyphs(Body body) =>
    body.isHybrid ? '${_shapeGlyphs[body.first]}${_shapeGlyphs[body.second]}' : _shapeGlyphs[body.first]!;

/// How far [mine] is from [average], as a person reads it: a percentage for
/// the body genes, a plain difference for the 0-to-1 ones.
String comparedWith(double mine, double average, {bool asPercent = true}) {
  if (asPercent) {
    final percent = ((mine / average - 1) * 100).round();
    return percent == 0 ? 'average' : '${percent > 0 ? '+' : '−'}${percent.abs()}%';
  }
  final difference = mine - average;
  return difference.abs() < 0.005 ? 'average' : '${difference > 0 ? '+' : '−'}${difference.abs().toStringAsFixed(2)}';
}

String childrenWords(int children) => '$children ${children == 1 ? 'child' : 'children'}';
