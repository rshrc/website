import 'dart:math' as math;

/// A colour of light, 0–1 per channel. Light adds, so a sum of colours can
/// run past 1; whoever draws it clips.
class Rgb {
  final double r, g, b;

  const Rgb(this.r, this.g, this.b);

  static const white = Rgb(1, 1, 1);

  Rgb operator *(double k) => Rgb(r * k, g * k, b * k);
  Rgb operator +(Rgb o) => Rgb(r + o.r, g + o.g, b + o.b);

  double get peak => math.max(r, math.max(g, b));
}

/// The colour of light of wavelength [nm]. Dan Bruton's piecewise fit,
/// dimmed at the ends of what eyes can see.
Rgb wavelengthRgb(double nm) {
  final (r, g, b) = switch (nm) {
    < 440 => ((440 - nm) / 60, 0.0, 1.0),
    < 490 => (0.0, (nm - 440) / 50, 1.0),
    < 510 => (0.0, 1.0, (510 - nm) / 20),
    < 580 => ((nm - 510) / 70, 1.0, 0.0),
    < 645 => (1.0, (645 - nm) / 65, 0.0),
    _ => (1.0, 0.0, 0.0),
  };
  final fade = switch (nm) {
    < 420 => 0.3 + 0.7 * (nm - 380) / 40,
    > 680 => 0.3 + 0.7 * (720 - nm) / 40,
    _ => 1.0,
  };
  double gamma(double v) => math.pow((v * fade).clamp(0, 1), 0.8).toDouble();
  return Rgb(gamma(r), gamma(g), gamma(b));
}

/// A laser's colour: [wavelengthRgb] at full strength.
Rgb laserRgb(double nm) {
  final c = wavelengthRgb(nm);
  return c * (1 / c.peak);
}

/// A plain name for the colour of [nm].
String colourName(double nm) => switch (nm) {
      < 450 => 'violet',
      < 490 => 'blue',
      < 520 => 'cyan',
      < 565 => 'green',
      < 590 => 'yellow',
      < 625 => 'orange',
      _ => 'red',
    };

/// One of the wavelengths white light is made of here.
typedef Wavelength = ({double nm, Rgb colour});

/// White light, as [whiteSamples] wavelengths from 400 to 700 nm whose
/// colours add up to white — somewhat more than white, so each colour on
/// its own still shows once a prism pulls them apart.
const whiteSamples = 24;

final List<Wavelength> whiteLight = () {
  final raw = [
    for (var i = 0; i < whiteSamples; i++) 400 + (i + 0.5) * 300 / whiteSamples,
  ].map((nm) => (nm: nm, colour: wavelengthRgb(nm))).toList();
  final sum = raw.map((w) => w.colour).reduce((a, b) => a + b);
  const gain = 4.0;
  return [
    for (final w in raw)
      (nm: w.nm, colour: Rgb(w.colour.r / sum.r * gain, w.colour.g / sum.g * gain, w.colour.b / sum.b * gain)),
  ];
}();

/// The wavelength of white light whose path is annotated: the one nearest
/// 550 nm, the middle of the spectrum to an eye.
final double whiteMarkedNm =
    whiteLight.map((w) => w.nm).reduce((a, b) => (a - 550).abs() < (b - 550).abs() ? a : b);
