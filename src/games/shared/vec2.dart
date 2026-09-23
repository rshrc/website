import 'dart:math' as math;

/// An immutable 2D vector, used at the edges of the simulations — spawning a
/// body, reading a position back out, describing a force.
///
/// The hot loops inside the physics and ecology steps deliberately do *not*
/// use this type: they work on raw `double` fields, because a pair loop over a
/// few hundred bodies would otherwise allocate tens of thousands of short-lived
/// objects per frame. Clarity at the boundary, plain numbers in the middle.
class Vec2 {
  final double x, y;

  const Vec2(this.x, this.y);

  static const zero = Vec2(0, 0);

  factory Vec2.polar(double angle, double length) =>
      Vec2(math.cos(angle) * length, math.sin(angle) * length);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double factor) => Vec2(x * factor, y * factor);
  Vec2 operator /(double divisor) => Vec2(x / divisor, y / divisor);
  Vec2 operator -() => Vec2(-x, -y);

  double get length => math.sqrt(x * x + y * y);
  double get lengthSquared => x * x + y * y;
  double get angle => math.atan2(y, x);

  Vec2 get normalized {
    final len = length;
    return len == 0 ? zero : Vec2(x / len, y / len);
  }

  double dot(Vec2 other) => x * other.x + y * other.y;

  /// The z component of the cross product — the only part of it that means
  /// anything in two dimensions.
  double cross(Vec2 other) => x * other.y - y * other.x;

  double distanceTo(Vec2 other) => (this - other).length;

  @override
  String toString() => '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) => other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
