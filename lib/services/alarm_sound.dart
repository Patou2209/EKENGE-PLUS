import 'alarm_sound_io.dart'
    if (dart.library.js_interop) 'alarm_sound_web.dart'
    as impl;

/// EKENGE PLUS — Alarme sonore de la verification Safe (§8).
class AlarmSound {
  AlarmSound._();
  static final AlarmSound instance = AlarmSound._();

  bool _on = false;
  bool get isRinging => _on;

  void start() {
    if (_on) return;
    _on = true;
    impl.startAlarm();
  }

  void stop() {
    if (!_on) return;
    _on = false;
    impl.stopAlarm();
  }

  /// Signal court : confirmation, ouverture d'alerte.
  void chirp({bool low = false}) => impl.chirp(low: low);
}
