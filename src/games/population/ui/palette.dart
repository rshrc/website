import 'dart:math' as math;

import '../../shared/page.dart';

/// Colours for any number of civilizations, in the page's current theme.
///
/// Base hues step around the colour wheel by the golden angle, so
/// neighbours in the list always differ a lot; each creature's tint gene
/// then shifts its own hue by up to 40°, so drift shows as colour.
class Palette {
  final Ink ink;
  final bool isLightTheme;
  final _cache = <int, String>{};

  Palette(this.ink) : isLightTheme = _brightness(ink.bg) > 0.5;

  static double _brightness(String css) {
    final (r, g, b) = rgbOf(css, (255, 255, 255));
    return (r + g + b) / 765;
  }

  /// The hue for [civilization], shifted by [tint] through a tanh so the
  /// shift levels off at ±40°.
  static double hueOf(int civilization, double tint) {
    final shift = 40 * (math.exp(tint / 2) - math.exp(-tint / 2)) / (math.exp(tint / 2) + math.exp(-tint / 2));
    return (205 + civilization * 137.508 + shift) % 360;
  }

  /// A CSS colour for [civilization] with [tint]; [fade] below 1 washes it
  /// out, for the dead and the average.
  String colour(int civilization, double tint, {double fade = 1}) {
    final hue = hueOf(civilization, tint).round();
    final key = hue * 100 + (fade * 99).round();
    return _cache[key] ??= isLightTheme
        ? 'hsl($hue ${(62 * fade).round()}% ${(44 + (1 - fade) * 40).round()}%)'
        : 'hsl($hue ${(58 * fade).round()}% ${(63 - (1 - fade) * 38).round()}%)';
  }
}
