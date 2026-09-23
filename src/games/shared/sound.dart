import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

/// Small synthesized sounds: soft tones and filtered noise, made on the fly
/// with Web Audio, so the page still loads nothing.
///
/// Browsers only allow audio after the visitor has interacted with the page,
/// so nothing plays until the first click or key press, and the context is
/// created then.
class Sound {
  web.AudioContext? _ctx;
  web.AudioBuffer? _noise;
  bool on;
  double _lastAt = -1;

  Sound({this.on = true}) {
    void wake(web.Event _) {
      if (!on) return;
      _context();
    }

    for (final type in ['pointerdown', 'keydown']) {
      web.document.addEventListener(type, wake.toJS);
    }
  }

  web.AudioContext? _context() {
    if (_ctx == null) {
      try {
        _ctx = web.AudioContext();
      } catch (_) {
        return null; // no audio here; stay silent
      }
    }
    if (_ctx!.state == 'suspended') _ctx!.resume();
    return _ctx;
  }

  /// Plays nothing if the last sound was under [gap] seconds ago, so a burst
  /// of events at high speed doesn't become a racket.
  web.AudioContext? _ready({double gap = 0.12}) {
    if (!on || _ctx == null) return null;
    final ctx = _context()!;
    if (ctx.currentTime - _lastAt < gap) return null;
    _lastAt = ctx.currentTime;
    return ctx;
  }

  /// A soft plucked tone at [hz], starting [delay] seconds from now.
  void _tone(web.AudioContext ctx, double hz,
      {double delay = 0, double length = 0.6, double volume = 0.07, String wave = 'sine'}) {
    final t = ctx.currentTime + delay;
    final osc = ctx.createOscillator()
      ..type = wave
      ..frequency.value = hz;
    final gain = ctx.createGain();
    gain.gain
      ..setValueAtTime(0.0001, t)
      ..exponentialRampToValueAtTime(volume, t + 0.015)
      ..exponentialRampToValueAtTime(0.0001, t + length);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc
      ..start(t)
      ..stop(t + length + 0.05);
  }

  /// A burst of noise through a low-pass filter whose cutoff slides from
  /// [fromHz] to [toHz] — a thud, a gust, a hiss, depending on the numbers.
  void _whoosh(web.AudioContext ctx,
      {double length = 0.8, double fromHz = 2000, double toHz = 200, double volume = 0.12, double attack = 0.01}) {
    _noise ??= () {
      final buffer = ctx.createBuffer(1, ctx.sampleRate.round() * 2, ctx.sampleRate);
      final data = buffer.getChannelData(0).toDart;
      final rng = math.Random(7);
      for (var i = 0; i < data.length; i++) {
        data[i] = rng.nextDouble() * 2 - 1;
      }
      return buffer;
    }();
    final t = ctx.currentTime;
    final source = ctx.createBufferSource()..buffer = _noise;
    final filter = ctx.createBiquadFilter()..type = 'lowpass';
    filter.frequency
      ..setValueAtTime(fromHz, t)
      ..exponentialRampToValueAtTime(toHz, t + length);
    final gain = ctx.createGain();
    gain.gain
      ..setValueAtTime(0.0001, t)
      ..exponentialRampToValueAtTime(volume, t + attack)
      ..exponentialRampToValueAtTime(0.0001, t + length);
    source.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);
    source
      ..start(t)
      ..stop(t + length + 0.05);
  }

  // ---- the vocabulary ---------------------------------------------------------

  /// Something new: a rising fifth.
  void arise(double root) {
    final ctx = _ready();
    if (ctx == null) return;
    _tone(ctx, root, length: 0.7);
    _tone(ctx, root * 1.5, delay: 0.12, length: 0.9);
  }

  /// Something lost: a falling minor third, darker.
  void lose(double root) {
    final ctx = _ready();
    if (ctx == null) return;
    _tone(ctx, root, length: 0.8, wave: 'triangle', volume: 0.05);
    _tone(ctx, root / 1.2, delay: 0.18, length: 1.1, wave: 'triangle', volume: 0.05);
  }

  /// A whole line gone: three slow falling notes.
  void fall(double root) {
    final ctx = _ready(gap: 0.3);
    if (ctx == null) return;
    for (final (i, ratio) in [1.0, 0.84, 0.67].indexed) {
      _tone(ctx, root * ratio, delay: i * 0.28, length: 1.2, wave: 'triangle', volume: 0.06);
    }
  }

  void impact() {
    final ctx = _ready(gap: 0.05);
    if (ctx == null) return;
    _whoosh(ctx, length: 1.4, fromHz: 1800, toHz: 60, volume: 0.25, attack: 0.005);
    _tone(ctx, 55, length: 1.0, volume: 0.18);
  }

  /// Two low tones just out of tune with each other.
  void sickness() {
    final ctx = _ready();
    if (ctx == null) return;
    _tone(ctx, 110, length: 1.6, wave: 'triangle', volume: 0.06);
    _tone(ctx, 116.5, length: 1.6, wave: 'triangle', volume: 0.06);
  }

  void wind() {
    final ctx = _ready();
    if (ctx == null) return;
    _whoosh(ctx, length: 2.2, fromHz: 700, toHz: 250, volume: 0.07, attack: 0.8);
  }

  void rain() {
    final ctx = _ready();
    if (ctx == null) return;
    _whoosh(ctx, length: 1.8, fromHz: 6000, toHz: 2500, volume: 0.04, attack: 0.3);
  }

  /// A low drum: two hits.
  void drum() {
    final ctx = _ready(gap: 0.2);
    if (ctx == null) return;
    for (final delay in [0.0, 0.22]) {
      _tone(ctx, 80, delay: delay, length: 0.35, volume: 0.16);
    }
    _whoosh(ctx, length: 0.3, fromHz: 900, toHz: 120, volume: 0.08, attack: 0.005);
  }

  /// A major arpeggio.
  void bounty() {
    final ctx = _ready();
    if (ctx == null) return;
    for (final (i, hz) in [523.3, 659.3, 784.0, 1046.5].indexed) {
      _tone(ctx, hz, delay: i * 0.09, length: 0.8, volume: 0.05);
    }
  }
}
