import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Retour haptique de l'application.
///
/// On privilegie le moteur de vibration de l'appareil (motifs precis). Si
/// l'appareil n'en dispose pas, on retombe sur le retour haptique standard
/// de Flutter afin de toujours produire une reaction perceptible.
class Haptics {
  Haptics._();

  static bool? _hasVibrator;

  static Future<bool> _available() async {
    if (kIsWeb) return false;
    _hasVibrator ??= await Vibration.hasVibrator();
    return _hasVibrator ?? false;
  }

  /// Impulsion courte : appui sur un bouton, selection.
  static Future<void> tap() async {
    if (await _available()) {
      await Vibration.vibrate(duration: 20, amplitude: 128);
    } else {
      await HapticFeedback.selectionClick();
    }
  }

  /// Impulsion moyenne : progression, etape franchie.
  static Future<void> medium() async {
    if (await _available()) {
      await Vibration.vibrate(duration: 45, amplitude: 180);
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Vibration d'alerte du bouton Danger (§7) : motif long et marque,
  /// nettement distinct d'un simple appui.
  static Future<void> danger() async {
    if (await _available()) {
      await Vibration.vibrate(
        pattern: const [0, 300, 120, 300, 120, 500],
        intensities: const [0, 255, 0, 255, 0, 255],
      );
    } else {
      for (var i = 0; i < 3; i++) {
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 140));
      }
    }
  }

  /// Confirmation de securite (§10) : deux impulsions douces.
  static Future<void> confirm() async {
    if (await _available()) {
      await Vibration.vibrate(pattern: const [0, 60, 90, 60]);
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  static Future<void> cancel() => Vibration.cancel();
}
