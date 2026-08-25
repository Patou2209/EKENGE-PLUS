import 'dart:async';

import 'package:web/web.dart' as web;

/// Implementation web : alarme synthetisee via Web Audio API (§8).
web.AudioContext? _ctx;
Timer? _timer;

web.AudioContext _context() => _ctx ??= web.AudioContext();

void startAlarm() {
  _timer?.cancel();
  _pattern();
  _timer = Timer.periodic(
    const Duration(milliseconds: 1100),
    (_) => _pattern(),
  );
}

void stopAlarm() {
  _timer?.cancel();
  _timer = null;
}

/// Motif d'alarme a deux tons, type sirene de securite.
void _pattern() {
  _tone(freq: 920, start: 0.00, dur: 0.22, gain: 0.16);
  _tone(freq: 680, start: 0.26, dur: 0.22, gain: 0.16);
  _tone(freq: 920, start: 0.52, dur: 0.22, gain: 0.16);
}

void chirp({bool low = false}) {
  _tone(freq: low ? 420 : 1180, start: 0, dur: 0.09, gain: 0.09);
}

void _tone({
  required double freq,
  required double start,
  required double dur,
  required double gain,
}) {
  try {
    final ctx = _context();
    final t0 = ctx.currentTime + start;
    final osc = ctx.createOscillator();
    final g = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.value = freq;
    g.gain.value = 0;
    osc.connect(g);
    g.connect(ctx.destination);
    g.gain.setValueAtTime(0, t0);
    g.gain.linearRampToValueAtTime(gain, t0 + 0.02);
    g.gain.linearRampToValueAtTime(0, t0 + dur);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  } catch (_) {
    // Contexte audio indisponible (interaction utilisateur requise).
  }
}
