import 'dart:math' as math;

import '../model/model.dart';
import 'session.dart';

/// The line under the board, in words: what happened where the pointer is,
/// or what the selected piece is, or what's on the bench. No web imports.
String status(Session session) {
  if (session.hovered case final hit?) return describe(hit, session.bench.room);
  if (session.selected case final piece?) return summary(piece, session.bench.room);
  final trace = session.trace;
  final lasers = session.bench.pieces.whereType<Laser>().length;
  return '${_count(lasers, 'laser')} · ${_count(session.bench.pieces.length - lasers, 'other piece')} · '
      '${_count(trace.rays, 'ray')} traced${trace.cut ? ', and more cut short' : ''} · '
      'point at a place where light meets a surface to read its angles';
}

/// What happened at [h], with the numbers.
String describe(Hit h, Medium room) {
  final i = h.incidence, o = h.outgoing;
  final light = _light(h);
  return switch ((h.event, h.piece)) {
    (Event.reflection, final piece) => 'reflection off the ${piece.name} · $light · '
        'in at ${_deg(i)} to the normal, out at ${_deg(o!)}: the same, as it always is',
    (Event.refraction, final piece) => 'refraction ${h.entering ? 'into' : 'out of'} ${_material(piece)} · $light · '
        'n ${_n(h.n1)} → ${_n(h.n2)} · in ${_deg(i)}, out ${_deg(o!)} · '
        'Snell: ${_n(h.n1)} × sin ${_deg(i)} = ${_n(h.n2)} × sin ${_deg(o)} = ${(h.n1 * math.sin(i)).toStringAsFixed(3)} · '
        '${(h.reflected * 100).toStringAsFixed(1)}% reflected'
        '${h.critical == null ? '' : ' · critical angle ${_deg(h.critical!)}'}',
    (Event.totalInternal, final piece) => 'total internal reflection inside ${_material(piece)} · $light · '
        'in at ${_deg(i)}, past the critical angle ${_deg(h.critical!)} '
        '(sin θc = ${_n(h.n2)} / ${_n(h.n1)}), so none of it gets out',
    (Event.split, _) => 'splitter · $light · ${(h.reflected * 100).round()}% reflected at ${_deg(i)}, '
        '${100 - (h.reflected * 100).round()}% passes straight through',
    (Event.diffraction, Grating g) => 'diffraction grating, ${g.lines.round()} lines per mm '
        '(d = ${g.spacing.round()} nm) · $light · d sin θ = m λ: ${_orders(g, h)}; longer waves bend more',
    (Event.filtered, Filter f) => 'filter passes ${_band(f)} · $light gets through',
    (Event.absorbed, Filter f) => 'filter stops $light: it only passes ${_band(f)}',
    (Event.absorbed, final piece) => '$light lands on the ${piece.name} at ${_deg(i)} to its normal',
    (_, final piece) => '${piece.name} · $light',
  };
}

/// What the selected piece is.
String summary(Piece p, Medium room) {
  final what = switch (p) {
    Laser l => l.white ? 'white light, 400–700 nm' : '${l.nm.round()} nm, ${colourName(l.nm)}',
    CurvedMirror m => 'concave on the focus side, convex on the back · '
        'focal length ${m.focal(room).round()} mm (R / 2)',
    Glass g && Focusing lens => '${_material(g)}, n ${_n(g.medium.index)} · focal length ${_focal(lens, room)}',
    Glass g =>'${_material(g)}, n ${_n(g.medium.index)} · critical angle ${_deg(g.critical(room))}',
    Splitter s => '${(s.reflect * 100).round()}% reflected',
    Grating g => '${g.lines.round()} lines per mm',
    Filter f => 'passes ${_band(f)}',
    Thin t => '${t.length.round()} mm',
  };
  return '${p.name} · $what · drag to move, drag the ring to turn, scroll to nudge';
}

String _orders(Grating g, Hit h) {
  final orders = [
    for (var m = 1; m <= 3; m++)
      if ((math.sin(h.incidence) + m * h.nm / g.spacing).abs() <= 1)
        'order $m at ${_deg(math.asin(math.sin(h.incidence) + m * h.nm / g.spacing))}',
  ];
  return orders.isEmpty ? 'only order 0 fits' : orders.join(', ');
}

/// A lens's focal length, which differs by colour: chromatic aberration.
String _focal(Focusing lens, Medium room) => '${lens.focal(room).round()} mm for yellow light, '
    '${lens.focal(room, 450).round()} for blue, ${lens.focal(room, 650).round()} for red';

String _material(Piece p) => p is Glass ? p.medium.name : p.name;

String _band(Filter f) => '${f.lowest.round()}–${f.highest.round()} nm';

String _light(Hit h) => '${h.nm.round()} nm ${colourName(h.nm)}${h.white ? ' (part of white light)' : ''}';

String _count(int n, String thing) => '$n $thing${n == 1 ? '' : 's'}';

String _deg(double radians) => '${(radians * 180 / math.pi).toStringAsFixed(1)}°';

String _n(double n) => n.toStringAsFixed(3);
