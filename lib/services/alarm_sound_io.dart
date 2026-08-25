import 'dart:async';

import 'package:flutter/services.dart';

/// Implementation mobile (Android) : sonnerie systeme + retour haptique
/// soutenu, conformement a l'alarme sonore de la verification Safe (§8).
Timer? _timer;

void startAlarm() {
  _timer?.cancel();
  _beep();
  _timer = Timer.periodic(const Duration(milliseconds: 850), (_) => _beep());
}

void stopAlarm() {
  _timer?.cancel();
  _timer = null;
}

void _beep() {
  SystemSound.play(SystemSoundType.alert);
  HapticFeedback.heavyImpact();
}

void chirp({bool low = false}) {
  SystemSound.play(SystemSoundType.click);
  if (low) {
    HapticFeedback.lightImpact();
  } else {
    HapticFeedback.mediumImpact();
  }
}
