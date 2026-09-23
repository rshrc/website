import 'dart:math' as math;

import '../../shared/sound.dart';
import '../model/model.dart';

/// Plays the sound for something that just happened. Each civilization has
/// its own note, so you can hear whose news it is.
void playCue(ChronicleEntry entry, Sound sound) {
  final note = 220 * math.pow(2, ((entry.civilization ?? 0) * 7 % 12) / 12).toDouble();
  switch (entry.kind) {
    case EventKind.founding || EventKind.speciation || EventKind.firstHybrid || EventKind.merger:
      sound.arise(note);
    case EventKind.extinction:
      sound.lose(note);
    case EventKind.civilizationLost:
      sound.fall(note);
    case EventKind.war:
      sound.drum();
    case EventKind.peace || EventKind.plenty:
      sound.bounty();
    case EventKind.meteor:
      sound.impact();
    case EventKind.plague:
      sound.sickness();
    case EventKind.drought:
      sound.wind();
    case EventKind.droughtEnds:
      sound.rain();
    case EventKind.lifeEnds:
      sound.fall(110);
    case EventKind.warming:
      sound.wind();
    case EventKind.cooling || EventKind.flood:
      sound.rain();
    case EventKind.dustBowl:
      sound.wind();
    case EventKind.plentyEnds || EventKind.climateSettles || EventKind.dustSettles:
      break;
  }
}
