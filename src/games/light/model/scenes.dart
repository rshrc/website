import 'dart:math' as math;

import 'medium.dart';
import 'pieces.dart';

/// Every kind of piece, by the name the page shows, made fresh at a point.
final Map<String, Piece Function(double x, double y)> catalogue = {
  'laser': Laser.new,
  'mirror': Mirror.new,
  'curved mirror': (x, y) => CurvedMirror(x, y, angle: math.pi),
  'prism': Prism.new,
  'block': Block.new,
  'lens': Lens.new,
  'diverging lens': DivergingLens.new,
  'half disc': HalfDisc.new,
  'drop': Drop.new,
  'splitter': Splitter.new,
  'grating': Grating.new,
  'filter': Filter.new,
  'screen': Screen.new,
};

double _deg(double d) => d * math.pi / 180;

/// Ready-made benches, each set up to show one thing, by name. The first
/// is where the page starts.
final Map<String, List<Piece> Function()> scenes = {
  'prism': () => [
        Laser(90, 470, angle: _deg(-24)),
        Prism(420, 330),
        Screen(900, 545, length: 200, angle: _deg(24)),
      ],
  'Snell’s law': () => [
        Laser(200, 110, angle: _deg(40), white: false),
        Block(500, 380, width: 520, height: 200),
      ],
  // The laser points at the middle of the flat face, so it crosses the
  // curved side head on, unbent, and meets the flat face at 36°.
  'critical angle': () {
    final aim = _deg(-36);
    return [
      HalfDisc(520, 330, radius: 200, angle: math.pi),
      Laser(520 - 330 * math.cos(aim), 330 - 330 * math.sin(aim), angle: aim, white: false, nm: 650),
    ];
  },
  'optical fibre': () => [
        Block(520, 320, width: 820, height: 44, medium: Medium.acrylic),
        Laser(40, 300, angle: _deg(16), white: false),
        Screen(970, 320, length: 200),
      ],
  'converging lens': () => [
        Laser(120, 310, white: false, nm: 610, beam: 140),
        Lens(420, 310, height: 200, radius: 260),
      ],
  'diverging lens': () => [
        Laser(120, 310, white: false, nm: 470, beam: 110),
        DivergingLens(420, 310, height: 200, radius: 200),
      ],
  'concave mirror': () => [
        Laser(120, 310, white: false, beam: 160),
        CurvedMirror(820, 310, height: 260, radius: 560, angle: math.pi),
      ],
  'periscope': () => [
        Laser(80, 500, white: false, nm: 650),
        Mirror(380, 500, length: 110, angle: _deg(45)),
        Mirror(380, 130, length: 110, angle: _deg(45)),
        Screen(900, 130, length: 120),
      ],
  // Red, green and blue joined into one beam by two half-silvered mirrors,
  // then pulled apart again by a prism.
  'mixing colours': () => [
        Laser(70, 120, white: false, nm: 640),
        Laser(260, 560, angle: _deg(-90), white: false),
        Laser(400, 560, angle: _deg(-90), white: false, nm: 450),
        Splitter(260, 120, length: 60, angle: _deg(45)),
        Splitter(400, 120, length: 60, angle: _deg(45)),
        Prism(675, 126, side: 150, angle: _deg(24)),
        Screen(960, 380, length: 200, angle: _deg(48)),
      ],
  'diffraction grating': () => [
        Laser(80, 310),
        Grating(360, 310, length: 120, lines: 500),
        Screen(700, 310, length: 580),
      ],
  // Rainbows are light that reflected once inside the drop: the faint
  // reflections are where they come from.
  'rainbow': () => [
        Laser(60, 310, beam: 150),
        Drop(520, 380, radius: 150),
      ],
  'empty': () => [],
};
