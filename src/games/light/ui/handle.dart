import '../model/model.dart';

/// The ring a selected piece is turned by, in its own frame: just ahead of
/// a laser's aperture, so turning it aims the beam; above anything else.
(double, double) handleLocal(Piece p) => p is Laser ? (38.0, 0.0) : (0.0, -p.top - 26);

/// [handleLocal], on the bench.
(double, double) handleOf(Piece p) {
  final (x, y) = handleLocal(p);
  return p.toWorld(x, y);
}
