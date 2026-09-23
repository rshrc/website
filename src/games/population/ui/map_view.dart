import 'dart:js_interop';
import 'dart:math' as math;

import '../../shared/page.dart';
import '../model/model.dart';
import 'creature_art.dart';
import 'palette.dart';

/// A widening ring where a meteor struck.
class _MeteorFlash {
  final double x, y, radius;
  double age = 0;

  _MeteorFlash(this.x, this.y, this.radius);
}

/// The land from above: food as a faint wash, every creature drawn from its
/// genes, a ring round the one being followed, the circle a meteor will
/// clear while one is being aimed, and rings where meteors struck.
class MapView {
  final Stage stage;
  final _flashes = <_MeteorFlash>[];

  MapView(this.stage);

  /// Screen pixels per world pixel.
  double scaleFor(World world) => stage.width / world.width;

  /// Fits the canvas to [world]'s shape.
  void fit(World world) => stage.setHeight(stage.width * world.height / world.width);

  void flashMeteor(double x, double y, double radius) => _flashes.add(_MeteorFlash(x, y, radius));

  void draw(World world, Palette palette,
      {required double seconds,
      Creature? followed,
      (double, double)? aimAt,
      double aimRadius = 80,
      bool plain = false}) {
    final ink = palette.ink, ctx = stage.ctx;
    final scale = scaleFor(world);
    stage.fill(ink.bg);
    _drawFood(world, palette, scale);
    if (world.terrain.isDisturbed) _drawLandCondition(world.terrain, scale);
    _drawCraters(world, palette.ink, scale);
    _drawClimateCast(world.climateNow);

    // Drawn a little larger than life, so the gene-driven details show.
    // At the top speeds the details are a blur anyway; plain bodies leave
    // more of each frame for the simulation.
    final zoom = (scale * 1.6).clamp(0.9, 1.7);
    for (final creature in world.creatures) {
      drawCreature(ctx, creature.genes,
          x: creature.x * scale,
          y: creature.y * scale,
          heading: creature.heading,
          scale: zoom,
          colour: palette.colour(creature.species.civilization, creature.genes.tint),
          growth: creature.growth,
          plain: plain,
          bodyShapes: world.laws.bodyShapes);
    }

    if (followed != null) {
      _ring(followed.x * scale, followed.y * scale, followed.radius * zoom * 2.4 + 5, ink.fg, 1.5);
    }
    if (aimAt != null) _ring(aimAt.$1, aimAt.$2, aimRadius * scale, ink.muted, 1);
    _drawFlashes(seconds, scale, ink);
  }

  /// Food as a faint wash of ink, darker where there's more to eat, in five
  /// shades, each drawn in one pass.
  void _drawFood(World world, Palette palette, double scale) {
    final ctx = stage.ctx, terrain = world.terrain;
    final patch = Terrain.patchSize * scale;
    ctx.fillStyle = palette.ink.fg.toJS;
    for (var shade = 1; shade <= 5; shade++) {
      ctx.globalAlpha = 0.035 * shade;
      for (var row = 0; row < terrain.rows; row++) {
        for (var column = 0; column < terrain.columns; column++) {
          final food = terrain.food[row * terrain.columns + column];
          if (food <= 0.02 || (food * 5).ceil().clamp(1, 5) != shade) continue;
          final left = (column * patch).roundToDouble(), top = (row * patch).roundToDouble();
          ctx.fillRect(
              left, top, ((column + 1) * patch).roundToDouble() - left, ((row + 1) * patch).roundToDouble() - top);
        }
      }
    }
    ctx.globalAlpha = 1;
  }

  /// Soaked land in blue, flooded land deeper blue, dry land in ochre, and
  /// meteor scars in dark brown, each in four strengths drawn in one pass.
  void _drawLandCondition(Terrain terrain, double scale) {
    final ctx = stage.ctx;
    final patch = Terrain.patchSize * scale;
    final passes = <String, List<int>>{};
    for (var i = 0; i < terrain.moisture.length; i++) {
      final moisture = terrain.moisture[i], health = terrain.health[i];
      String? colour;
      if (health < 0.9) {
        colour = 'rgba(90,45,20,${_level(1 - health) * 0.14})';
      } else if (moisture > Terrain.floodAbove) {
        colour = 'rgba(40,110,235,${0.3 + _level((moisture - Terrain.floodAbove) / 1.2) * 0.06})';
      } else if (moisture > 1.05) {
        colour = 'rgba(70,150,255,${_level((moisture - 1) / 0.8) * 0.06})';
      } else if (moisture < 0.95) {
        colour = 'rgba(200,140,60,${_level(1 - moisture) * 0.09})';
      }
      if (colour != null) (passes[colour] ??= []).add(i);
    }
    for (final MapEntry(key: colour, value: patches) in passes.entries) {
      ctx.fillStyle = colour.toJS;
      for (final i in patches) {
        final left = ((i % terrain.columns) * patch).roundToDouble(), top = ((i ~/ terrain.columns) * patch).roundToDouble();
        ctx.fillRect(left, top, patch.ceilToDouble(), patch.ceilToDouble());
      }
    }
  }

  /// [amount], 0 to 1, as one of four steps, 1 to 4.
  static int _level(double amount) => (amount * 4).ceil().clamp(1, 4);

  /// Every meteor strike is remembered on the map: a thin ring where it
  /// fell, the size it was.
  void _drawCraters(World world, Ink ink, double scale) {
    if (world.meteorStrikes.isEmpty) return;
    final ctx = stage.ctx;
    ctx
      ..globalAlpha = 0.35
      ..setLineDash(<JSNumber>[2.toJS, 3.toJS].toJS);
    for (final strike in world.meteorStrikes) {
      _ring(strike.x * scale, strike.y * scale, strike.radius * scale, ink.muted, 1);
    }
    ctx
      ..setLineDash(<JSNumber>[].toJS)
      ..globalAlpha = 1;
  }

  /// A faint orange wash over a warmer world, blue over a colder one,
  /// deeper the further the climate has shifted.
  void _drawClimateCast(double shift) {
    if (shift == 0) return;
    final strength = (shift.abs() / World.maxClimateShift * 0.12).toStringAsFixed(3);
    stage.fill(shift > 0 ? 'rgba(255,120,40,$strength)' : 'rgba(70,150,255,$strength)');
  }

  /// Meteor strikes: a ring that widens and fades over a second.
  void _drawFlashes(double seconds, double scale, Ink ink) {
    _flashes.removeWhere((flash) => (flash.age += seconds) > 1);
    for (final flash in _flashes) {
      stage.ctx.globalAlpha = 1 - flash.age;
      _ring(flash.x * scale, flash.y * scale, flash.radius * (0.3 + 0.9 * flash.age) * scale, ink.fg, 2);
    }
    stage.ctx.globalAlpha = 1;
  }

  void _ring(double x, double y, double radius, String colour, double lineWidth) {
    final ctx = stage.ctx;
    ctx
      ..strokeStyle = colour.toJS
      ..lineWidth = lineWidth;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, math.pi * 2);
    ctx.stroke();
  }
}
