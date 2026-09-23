import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/model.dart';
import 'creature_art.dart';
import 'palette.dart';
import 'words.dart';

/// The creature the reader clicked on: drawn large beside the average of
/// its species, so what's unusual about it is plain to see, with a line
/// about it — and when it dies, its epitaph.
class Follower {
  final web.HTMLCanvasElement _portrait;
  final web.HTMLParagraphElement _about;

  int? _followedId;
  Creature? _lastSeen;
  String? _epitaph;

  static const _width = 230.0, _height = 96.0;

  /// Adds the portrait and its line after [anchor].
  Follower(web.Element anchor)
      : _portrait = web.document.createElement('canvas') as web.HTMLCanvasElement..id = 'portrait',
        _about = web.document.createElement('p') as web.HTMLParagraphElement..className = 'meta inspect' {
    final row = web.document.createElement('div') as web.HTMLDivElement..className = 'inspect-row';
    row
      ..append(_portrait)
      ..append(_about);
    anchor.after(row);
  }

  /// Starts following [creature], or stops following anyone.
  void follow(Creature? creature) {
    _followedId = creature?.id;
    _epitaph = null;
  }

  /// The followed creature if it's still alive. Writes its epitaph the
  /// first time it's found dead.
  Creature? find(World world) {
    final id = _followedId;
    if (id == null) return null;
    final followed = world.find(id);
    if (followed != null) {
      _lastSeen = followed;
    } else if (_epitaph == null && _lastSeen?.id == id) {
      final dead = _lastSeen!;
      final how = dead.death == null ? '' : ' ${dead.death!.how}';
      _epitaph = 'One ${dead.species.name}, generation ${dead.generation}, died at ${dead.age.round()} years old$how, '
          'leaving ${childrenWords(dead.children)}.';
    }
    return followed;
  }

  void drawPortrait(Creature? followed, Palette palette, {required bool bodyShapes}) {
    _portrait.style.display = followed == null ? 'none' : 'block';
    if (followed == null) return;
    final ratio = web.window.devicePixelRatio;
    if (_portrait.width != (_width * ratio).round()) {
      _portrait
        ..width = (_width * ratio).round()
        ..height = (_height * ratio).round();
      _portrait.style
        ..width = '${_width}px'
        ..height = '${_height}px';
    }
    final ctx = _portrait.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.setTransform(ratio.toJS, 0, 0, ratio, 0, 0);
    ctx
      ..fillStyle = palette.ink.bg.toJS
      ..fillRect(0, 0, _width, _height);

    final civilization = followed.species.civilization;
    drawCreature(ctx, followed.genes,
        x: 62,
        y: 42,
        heading: 0,
        scale: 3.6,
        colour: palette.colour(civilization, followed.genes.tint),
        growth: followed.growth,
        bodyShapes: bodyShapes);
    final average = followed.species.averageGenes;
    drawCreature(ctx, average,
        x: 172,
        y: 42,
        heading: 0,
        scale: 3.6,
        colour: palette.colour(civilization, average.tint, fade: 0.55),
        bodyShapes: bodyShapes);
    ctx
      ..font = '12px Times, Georgia, serif'
      ..textAlign = 'center'
      ..fillStyle = palette.ink.muted.toJS;
    ctx.fillText('this one', 62, _height - 4);
    ctx.fillText('its species, on average', 172, _height - 4);
    ctx.textAlign = 'start';
  }

  void describe(Creature? followed, {required bool bodyShapes}) {
    if (followed == null) {
      _about.textContent = _epitaph ?? 'Click a creature to follow it.';
      return;
    }
    final genes = followed.genes, species = followed.species;
    _about.textContent = 'Following one ${species.name}: ${followed.age.round()} years old, generation '
        '${followed.generation}, ${childrenWords(followed.children)}. '
        'Against its species: speed ${genes.speed.round()} (${comparedWith(genes.speed, species.averageSpeed)}) · '
        'size ${genes.size.toStringAsFixed(2)} (${comparedWith(genes.size, species.averageSize)}) · '
        'sight ${genes.sight.round()} (${comparedWith(genes.sight, species.averageSight)}) · '
        'aggression ${genes.aggression.toStringAsFixed(2)} '
        '(${comparedWith(genes.aggression, species.averageAggression, asPercent: false)}) · '
        'likes it ${climateWord(genes.idealClimate)} '
        '(${comparedWith(genes.idealClimate, species.averageIdealClimate, asPercent: false)})'
        '${bodyShapes ? ' · body ${bodyWords(genes.body)}' : ''}.';
  }
}
