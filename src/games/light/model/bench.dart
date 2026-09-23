import 'light.dart';
import 'medium.dart';
import 'pieces.dart';
import 'scenes.dart';
import 'tracer.dart';

/// The optical bench: a metre by 62 cm of room, what's on it, and what it's
/// filled with.
class Bench {
  static const width = 1000.0, height = 620.0;

  final pieces = <Piece>[];
  Medium room = Medium.air;

  /// Whether glass surfaces also send back the few percent Fresnel says
  /// they reflect.
  bool faint = true;

  Bench([String scene = 'prism']) {
    load(scene);
  }

  /// Swaps what's on the bench for one of the [scenes]. The room and the
  /// faint reflections stay as they were.
  void load(String scene) {
    pieces
      ..clear()
      ..addAll(scenes[scene]!());
  }

  Trace trace() =>
      traceLight(pieces, Surroundings(room: room, faint: faint), width: width, height: height);
}
