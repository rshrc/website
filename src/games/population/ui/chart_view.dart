import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../../shared/page.dart';
import '../model/model.dart';
import 'headings.dart';
import 'palette.dart';

/// One line per civilization, from year 0 to now: its headcount, or the
/// average of one of its genes, which is where you watch evolution happen.
/// Behind the lines, when the droughts, good ages and meteors happened, so
/// the booms and crashes explain themselves.
class ChartView {
  final Stage stage;
  final web.HTMLParagraphElement _explanation;

  /// What the chart shows.
  Measure measure = Measure.population;

  static const _top = 6.0, _bottom = 16.0, _labelsWidth = 70.0;

  ChartView(this.stage) : _explanation = addExplainedHeading(stage.canvas, 'Civilizations over time');

  static const _explanations = {
    Measure.population: 'How many of each civilization were alive, from year 0 to now. Shaded stretches are '
        'droughts (solid) and ages of plenty (striped); ticks along the bottom are meteors, taller the more of all '
        'life they took.',
    Measure.speed: "Each civilization's average speed gene, from year 0 to now. A line that climbs means its "
        'creatures are evolving to be faster.',
    Measure.size: "Each civilization's average size gene, from year 0 to now.",
    Measure.sight: "Each civilization's average sight gene, from year 0 to now.",
    Measure.aggression: "Each civilization's average aggression gene, from year 0 to now. Wars tend to push it "
        'up; peace lets it fall, because a temper costs energy.',
    Measure.climate: 'The climate each civilization is built for, on average: 0 is cold, 1 is hot. A line that '
        'moves means a civilization adapting to new valleys, or to a changing climate. The dashed line is the '
        "land's own average climate, which moves when the climate warms or cools.",
  };

  double get _plotWidth => stage.width - _labelsWidth;
  double get _plotHeight => stage.height - _top - _bottom;

  void draw(World world, Palette palette) {
    _explanation.textContent = _explanations[measure]!;
    stage.fill(palette.ink.bg);
    final lines = world.traits.of(measure);
    if (lines.first.length < 2) return;
    final now = math.max(world.time, 1);
    double xOfYear(double year) => year / now * _plotWidth;

    _drawWeatherAndMeteors(world, palette.ink, xOfYear);
    final landClimate = measure == Measure.climate
        ? [for (final shift in world.traits.climateShifts) world.terrain.meanClimate + shift]
        : const <double>[];
    final (low, high) = _range(world, [...lines.take(world.civilizations), landClimate]);
    double yOf(double value) => _top + _plotHeight - (value - low) / (high - low) * _plotHeight;
    _drawGridlines(palette.ink, low, high, yOf);
    if (landClimate.isNotEmpty) _drawLandClimate(landClimate, palette.ink, yOf);
    final lineEnds = _drawLines(world, palette, lines, yOf);
    _drawLabels(world, palette.ink, lineEnds);
  }

  /// Droughts as solid bands, ages of plenty as hatched ones, so the two
  /// read differently even as narrow stripes; meteors as ticks.
  void _drawWeatherAndMeteors(World world, Ink ink, double Function(double) xOfYear) {
    final ctx = stage.ctx;
    void band(double from, double to, {required bool hatched}) {
      final left = xOfYear(from), right = math.max(xOfYear(to), left + 1);
      ctx.fillStyle = ink.fg.toJS;
      if (!hatched) {
        ctx.globalAlpha = 0.13;
        ctx.fillRect(left, _top, right - left, _plotHeight);
      } else {
        ctx.globalAlpha = 0.3;
        for (var x = left.floorToDouble(); x < right; x += 3) {
          ctx.fillRect(x, _top, 1, _plotHeight);
        }
      }
      ctx.globalAlpha = 1;
    }

    double? droughtFrom, plentyFrom;
    for (final entry in world.chronicle.entries) {
      switch (entry.kind) {
        case EventKind.drought:
          droughtFrom = entry.year;
        case EventKind.droughtEnds when droughtFrom != null:
          band(droughtFrom, entry.year, hatched: false);
          droughtFrom = null;
        case EventKind.plenty:
          plentyFrom = entry.year;
        case EventKind.plentyEnds when plentyFrom != null:
          band(plentyFrom, entry.year, hatched: true);
          plentyFrom = null;
        default:
          break;
      }
    }
    if (droughtFrom != null) band(droughtFrom, world.time, hatched: false);
    if (plentyFrom != null) band(plentyFrom, world.time, hatched: true);

    // Meteors, as ticks rising from the bottom, taller the more of all life
    // they took.
    ctx.fillStyle = ink.muted.toJS;
    for (final strike in world.meteorStrikes) {
      final tick = 6 + math.min(1.0, strike.shareOfAllLife * 3) * (_plotHeight - 6);
      ctx.fillRect(xOfYear(strike.year), _top + _plotHeight - tick, 1, tick);
    }
  }

  /// The values the chart spans: from zero for headcounts, otherwise the
  /// data's own range with a little room.
  (double, double) _range(World world, List<List<double>> lines) {
    var low = double.infinity, high = -double.infinity;
    for (final line in lines) {
      for (final value in line) {
        if (value.isNaN) continue;
        low = math.min(low, value);
        high = math.max(high, value);
      }
    }
    if (!low.isFinite) low = 0;
    if (!high.isFinite || high <= low) high = low + 1;
    if (measure == Measure.population) return (0, high);
    final room = (high - low) * 0.1;
    return (math.max(0, low - room), high + room);
  }

  /// Gridlines at tidy values, labelled at the left.
  void _drawGridlines(Ink ink, double low, double high, double Function(double) yOf) {
    final ctx = stage.ctx;
    final step = _tidyStep((high - low) / 3);
    String label(double value) =>
        step >= 1 ? withCommas(value.round()) : value.toStringAsFixed(step >= 0.1 ? 1 : 2);
    ctx
      ..font = '11px Times, Georgia, serif'
      ..textBaseline = 'bottom';
    for (var value = (low / step).ceil() * step; value <= high; value += step) {
      ctx.fillStyle = ink.rule.toJS;
      ctx.fillRect(0, yOf(value).roundToDouble(), _plotWidth, 1);
      ctx.fillStyle = ink.muted.toJS;
      ctx.fillText(label(value), 2, yOf(value) - 1);
    }
  }

  /// The land's average climate over time, dashed, behind the
  /// civilizations' lines.
  void _drawLandClimate(List<double> values, Ink ink, double Function(double) yOf) {
    final ctx = stage.ctx;
    ctx
      ..strokeStyle = ink.muted.toJS
      ..lineWidth = 1.5
      ..setLineDash(<JSNumber>[5.toJS, 4.toJS].toJS)
      ..beginPath();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * _plotWidth;
      i == 0 ? ctx.moveTo(x, yOf(values[i])) : ctx.lineTo(x, yOf(values[i]));
    }
    ctx
      ..stroke()
      ..setLineDash(<JSNumber>[].toJS);
  }

  /// A line per civilization, with gaps where it had died out. Returns
  /// where each living one's line ends, for labelling.
  List<(double, int)> _drawLines(World world, Palette palette, List<List<double>> lines, double Function(double) yOf) {
    final ctx = stage.ctx;
    final samples = lines.first.length;
    double xOfSample(int i) => i / (samples - 1) * _plotWidth;
    ctx
      ..lineWidth = 2
      ..lineJoin = 'round';
    final lineEnds = <(double, int)>[];
    for (var civilization = 0; civilization < world.civilizations; civilization++) {
      final values = lines[civilization];
      ctx.strokeStyle = palette.colour(civilization, 0).toJS;
      ctx.beginPath();
      var penDown = false;
      for (var i = 0; i < samples; i++) {
        final value = values[i];
        final stillExtinct = measure == Measure.population && value == 0 && i > 0 && values[i - 1] == 0;
        if (value.isNaN || stillExtinct) {
          penDown = false;
          continue;
        }
        penDown ? ctx.lineTo(xOfSample(i), yOf(value)) : ctx.moveTo(xOfSample(i), yOf(value));
        penDown = true;
      }
      ctx.stroke();
      final last = values.last;
      if (!last.isNaN && (measure != Measure.population || last > 0)) lineEnds.add((yOf(last), civilization));
    }
    return lineEnds;
  }

  /// Each living civilization's name by the end of its line, nudged apart
  /// so none overlap, and the years along the bottom.
  void _drawLabels(World world, Ink ink, List<(double, int)> lineEnds) {
    final ctx = stage.ctx;
    ctx
      ..font = '12px Times, Georgia, serif'
      ..fillStyle = ink.muted.toJS
      ..textBaseline = 'middle';
    lineEnds.sort((a, b) => a.$1.compareTo(b.$1));
    var lowestTaken = -double.infinity;
    for (final (y, civilization) in lineEnds) {
      final placed = math.max(y, lowestTaken + 13);
      if (placed > stage.height - 4) break;
      lowestTaken = placed;
      ctx.fillText(civilizationNames[civilization], _plotWidth + 6, placed);
    }
    ctx.textBaseline = 'alphabetic';
    ctx.fillText('year 0', 0, stage.height - 1);
    final now = 'year ${withCommas(world.time.floor())}';
    ctx.fillText(now, _plotWidth - ctx.measureText(now).width, stage.height - 1);
  }
}

/// A round number near [rough]: 1, 2 or 5 times a power of ten.
double _tidyStep(double rough) {
  if (rough <= 0) return 1;
  final power = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  final multiple = rough / power;
  return (multiple < 1.5 ? 1 : (multiple < 3.5 ? 2 : 5)) * power;
}
