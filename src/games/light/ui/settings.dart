import 'dart:math' as math;

import '../model/model.dart';

/// What can be changed about each kind of piece, described plainly enough
/// for the panel to build a control for each without knowing what it's
/// for. No web imports.

sealed class Setting {
  final String label;

  const Setting(this.label);
}

/// A number between [min] and [max].
final class Range extends Setting {
  final double min, max, step;
  final double Function() read;
  final void Function(double) write;
  final String Function(double) format;

  const Range(super.label, this.min, this.max, this.read, this.write, {this.step = 1, required this.format});
}

/// One of a few [options].
final class Options extends Setting {
  final List<String> options;
  final String Function() read;
  final void Function(String) write;

  const Options(super.label, this.options, this.read, this.write);
}

/// Everything that can be changed about [piece], its angle first.
List<Setting> settingsFor(Piece piece) => [
      _turned(piece),
      ...switch (piece) {
        Laser l => _laser(l),
        Splitter s => [
            _length(s, 400),
            Range('reflects', 0, 1, () => s.reflect, (v) => s.reflect = v, step: 0.05, format: _percent),
          ],
        Grating g => [
            _length(g, 400),
            Range('lines', 50, 1200, () => g.lines, (v) => g.lines = v,
                step: 10, format: (v) => '${v.round()} per mm'),
          ],
        Filter f => [
            _length(f, 400),
            Range('passes', 380, 700, () => f.nm, (v) => f.nm = v, format: _wavelength),
            Range('band', 10, 320, () => f.band, (v) => f.band = v, step: 5, format: (v) => '${v.round()} nm'),
          ],
        Thin t => [_length(t, 600)],
        CurvedMirror m => [
            _mm('height', 20, 600, () => m.height, (v) => m.height = v),
            Range('radius', 60, 1600, () => m.radius, (v) => m.radius = v,
                step: 10, format: (v) => '${v.round()} mm, focus at ${(v / 2).round()}'),
          ],
        Glass g => [..._shape(g), ..._material(g)],
      },
    ];

Setting _turned(Piece p) => Range('turned', -180, 180, () => turnedDegrees(p), (v) => p.angle = -v * math.pi / 180,
    step: 0.5, format: (v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}°');

/// A piece's angle as people count them: degrees anticlockwise, −180 to
/// 180, to the half degree.
double turnedDegrees(Piece p) {
  var d = (-p.angle * 180 / math.pi) % 360;
  if (d > 180) d -= 360;
  return (d * 2).round() / 2;
}

List<Setting> _laser(Laser l) => [
      Options('light', ['white', 'one colour'], () => l.white ? 'white' : 'one colour', (v) => l.white = v == 'white'),
      Range('wavelength', 380, 700, () => l.nm, (v) {
        l
          ..nm = v
          ..white = false;
      }, format: _wavelength),
      Range('beam', 0, 200, () => l.beam, (v) => l.beam = v, step: 5, format: (v) => v == 0 ? 'one ray' : _mmText(v)),
    ];

List<Setting> _shape(Glass g) => switch (g) {
      Prism p => [
          _mm('side', 40, 450, () => p.side, (v) => p.side = v),
          Range('apex', 10, 120, () => p.apex, (v) => p.apex = v, format: (v) => '${v.round()}°'),
        ],
      Block b => [
          _mm('width', 20, 900, () => b.width, (v) => b.width = v),
          _mm('height', 10, 600, () => b.height, (v) => b.height = v),
        ],
      Lens l => _lens(() => l.height, (v) => l.height = v, () => l.radius, (v) => l.radius = v),
      DivergingLens l => _lens(() => l.height, (v) => l.height = v, () => l.radius, (v) => l.radius = v),
      HalfDisc h => [_mm('radius', 20, 300, () => h.radius, (v) => h.radius = v)],
      Drop d => [_mm('radius', 20, 300, () => d.radius, (v) => d.radius = v)],
    };

List<Setting> _lens(double Function() height, void Function(double) setHeight, double Function() radius,
        void Function(double) setRadius) =>
    [
      _mm('height', 20, 500, height, setHeight),
      Range('radius', 40, 1600, radius, setRadius, step: 5, format: _mmText),
    ];

/// What it's made of, as a named material or its two numbers; changing
/// either number makes it a custom material.
List<Setting> _material(Glass g) => [
      Options('material', [...Medium.materials.map((m) => m.name), 'custom'],
          () => Medium.named(g.medium.name)?.name ?? 'custom', (name) {
        final m = Medium.named(name);
        if (m != null) g.medium = m;
      }),
      Range('n', 1, 3, () => g.medium.index, (v) => g.medium = g.medium.copyWith(index: v),
          step: 0.001, format: (v) => v.toStringAsFixed(3)),
      // Shown as n_F − n_C, the number handbooks give.
      Range('dispersion', 0, 0.04, () => g.medium.dispersion, (v) => g.medium = g.medium.copyWith(dispersion: v),
          step: 0.0005, format: (v) => Medium('', 1, v).spread.toStringAsFixed(4)),
    ];

Setting _length(Thin t, double max) => _mm('length', 20, max, () => t.length, (v) => t.length = v);

Setting _mm(String label, double min, double max, double Function() read, void Function(double) write) =>
    Range(label, min, max, read, write, format: _mmText);

String _mmText(double v) => '${v.round()} mm';
String _percent(double v) => '${(v * 100).round()}%';
String _wavelength(double v) => '${v.round()} nm, ${colourName(v)}';
