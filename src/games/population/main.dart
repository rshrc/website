import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../shared/page.dart';
import '../shared/sound.dart';
import 'model/model.dart';
import 'ui/chart_view.dart';
import 'ui/chronicle_list.dart';
import 'ui/clock.dart';
import 'ui/control_panel.dart';
import 'ui/family_tree_view.dart';
import 'ui/follower.dart';
import 'ui/gene_key.dart';
import 'ui/map_view.dart';
import 'ui/meteor_list.dart';
import 'ui/palette.dart';
import 'ui/sound_cues.dart';
import 'ui/species_list.dart';

/// Civilizations on one land: competing, fighting, evolving, splitting into
/// species, and weathering whatever nature (or you) throws at them.
///
/// The simulation lives in model/, with no web imports; ui/ puts it on the
/// page. This file builds the page and runs the frame loop.
void main() {
  web.document.getElementById('stage')!.parentElement!.classList.add('wide');
  final settings = NewWorldSettings();
  final world = World(
      seed: DateTime.now().millisecondsSinceEpoch,
      civilizations: settings.civilizations,
      perCivilization: settings.perCivilization);

  // The page, top to bottom.
  final map = MapView(Stage.find(aspect: world.height / world.width));
  final geneKey = GeneKey(Stage.after(map.stage.canvas, 'key', aspect: 0.08));
  final follower = Follower(geneKey.stage.canvas);
  final chart = ChartView(Stage.below('chart', aspect: 0.2));
  final familyTree = FamilyTreeView(Stage.below('tree', aspect: 0.1));
  final readout = Readout();
  final sound = Sound();
  final clock = Clock();
  final mapTool = MapTool();

  void startNewWorld() {
    world.reset(
        seed: world.seed + 1,
        civilizations: settings.civilizations,
        landSize: settings.landSize,
        perCivilization: settings.perCivilization);
    map.fit(world);
    follower.follow(null);
    clock.rates.clear();
  }

  ControlPanel(
      world: world,
      clock: clock,
      mapTool: mapTool,
      map: map.stage.canvas,
      settings: settings,
      chart: chart,
      sound: sound,
      startNewWorld: startNewWorld);
  final speciesList = SpeciesList(web.document.getElementById('controls')!);
  final chronicleList = ChronicleList(web.document.getElementById('readout')!);
  final meteorList = MeteorList(web.document.querySelector('.chronicle')!);

  // A click follows a creature or drops a meteor; pressing and holding
  // rains, or dries, the land under the pointer.
  map.stage.canvas.addEventListener('pointerdown', ((web.PointerEvent e) {
    final (x, y) = map.stage.locate(e);
    final scale = map.scaleFor(world);
    mapTool.pointer = (x, y);
    switch (mapTool.tool) {
      case Tool.follow:
        follower.follow(world.nearestCreature(x / scale, y / scale, within: 14 / scale));
      case Tool.meteor:
        world.meteor(x / scale, y / scale, radius: mapTool.radius);
      case Tool.rain || Tool.dry:
        mapTool.isPressed = true;
        map.stage.canvas.setPointerCapture(e.pointerId);
    }
  }).toJS);
  void release(web.Event _) => mapTool.isPressed = false;
  map.stage.canvas
    ..addEventListener('pointermove', ((web.PointerEvent e) {
      mapTool.pointer = map.stage.locate(e);
    }).toJS)
    ..addEventListener('pointerup', release.toJS)
    ..addEventListener('pointercancel', release.toJS)
    ..addEventListener('pointerleave', ((web.Event _) {
      mapTool.pointer = null;
      mapTool.isPressed = false;
    }).toJS);

  // The lists are text, and rebuilding text every frame is wasted work.
  var secondsSinceTextUpdate = 1.0;
  animate((seconds) {
    clock.advance(world, seconds);
    if (mapTool.isPainting && mapTool.pointer != null) {
      // A second held rains (or dries) a full unit of moisture at the middle:
      // well past the flood line, or to dust, in about a second.
      final scale = map.scaleFor(world);
      final (x, y) = mapTool.pointer!;
      final amount = 1.2 * seconds;
      mapTool.tool == Tool.rain
          ? world.rainOn(x / scale, y / scale, radius: mapTool.radius, amount: amount)
          : world.dryOut(x / scale, y / scale, radius: mapTool.radius, amount: amount);
    }
    for (final entry in world.chronicle.news()) {
      playCue(entry, sound);
      if (entry.kind == EventKind.meteor && entry.x != null) map.flashMeteor(entry.x!, entry.y!, entry.radius ?? 80);
      chronicleList.isStale = true;
    }

    final palette = Palette(Ink.read());
    final bodyShapes = world.laws.bodyShapes;
    final followed = follower.find(world);
    geneKey.draw(palette, bodyShapes: bodyShapes);
    follower.drawPortrait(followed, palette, bodyShapes: bodyShapes);
    map.draw(world, palette,
        seconds: seconds,
        followed: followed,
        aimAt: mapTool.showsReach ? mapTool.pointer : null,
        aimRadius: mapTool.radius,
        plain: clock.isBlurring);
    chart.draw(world, palette);
    familyTree.draw(world, palette);

    secondsSinceTextUpdate += seconds;
    if (secondsSinceTextUpdate > 0.25) {
      secondsSinceTextUpdate = 0;
      speciesList.show(world, palette);
      chronicleList.show(world);
      meteorList.show(world);
      follower.describe(followed, bodyShapes: bodyShapes);
    }
    readout.set(_status(world, clock));
  });
}

String _status(World world, Clock clock) {
  final weather = world.isDrought ? ' · drought' : (world.isPlenty ? ' · age of plenty' : '');
  final degrees = (world.climateNow * Terrain.degreesPerUnit).round();
  final changing = world.climateShift < world.climateShiftTarget
      ? ', warming'
      : (world.climateShift > world.climateShiftTarget ? ', cooling' : '');
  final dust = world.dust > 0.02 ? ' · dust darkens the sky' : '';
  final climate = degrees == 0 && changing.isEmpty
      ? ''
      : ' · ${degrees == 0 ? 'climate as at the start' : '${degrees.abs()}° ${degrees > 0 ? 'warmer' : 'colder'}'}$changing';
  final pace = clock.isRunning ? '${withCommas(clock.achievedYearsPerSecond.round())} years a second' : 'paused';
  final causes = clock.rates.diedPerYearOf.take(3).map((entry) => '${entry.$2} ${entry.$1.noun}').join(', ');
  final limit = world.isAtCreatureLimit
      ? ' · at the ${withCommas(world.creatureLimit)}-creature limit, so births are held back'
      : '';
  return 'year ${withCommas(world.time.floor())} · ${withCommas(world.creatures.length)} alive$limit · '
      '${world.livingSpecies.length} species · about ${world.meanGeneration.round()} generations · '
      '${clock.rates.bornPerYear} born and ${clock.rates.diedPerYear} died a year'
      '${causes.isEmpty ? '' : ' ($causes)'}$weather$climate$dust · $pace';
}
