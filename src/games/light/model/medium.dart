/// Something light can pass through, with a refractive index that depends
/// on the wavelength: n(λ) = n_D + B (1/λ² − 1/λ_D²), Cauchy's formula,
/// written so [index] is the index for yellow sodium light, as handbooks
/// give it.
class Medium {
  final String name;
  final double index;

  /// Cauchy's B, in µm². Crown glass is about 0.0042.
  final double dispersion;

  const Medium(this.name, this.index, this.dispersion);

  static const air = Medium('air', 1.0003, 0.00001);
  static const water = Medium('water', 1.333, 0.0031);
  static const acrylic = Medium('acrylic', 1.491, 0.0045);
  static const crown = Medium('crown glass', 1.517, 0.0042);
  static const flint = Medium('flint glass', 1.620, 0.0087);
  static const diamond = Medium('diamond', 2.417, 0.0131);

  /// What a piece of glass (or not glass) can be made of.
  static const materials = [water, acrylic, crown, flint, diamond];

  static Medium? named(String name) => materials.where((m) => m.name == name).firstOrNull;

  /// The wavelength handbook indices are given for, in nm.
  static const sodium = 589.3;

  double at(double nm) {
    final um = nm / 1000, d = sodium / 1000;
    return index + dispersion * (1 / (um * um) - 1 / (d * d));
  }

  /// Blue (486 nm) minus red (656 nm): how far apart the colours spread,
  /// n_F − n_C in a handbook.
  double get spread => at(486.1) - at(656.3);

  Medium copyWith({double? index, double? dispersion}) =>
      Medium('custom', index ?? this.index, dispersion ?? this.dispersion);
}
