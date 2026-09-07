import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// EKENGE PLUS — Notifications SYSTÈME (barre de notification + sonnerie).
///
/// Corrige le cas des comptes qui ne recevaient rien dans la barre de
/// notification :
///  1. La permission POST_NOTIFICATIONS (Android 13+) est demandée
///     EXPLICITEMENT — sans elle, aucune notification ne peut apparaître.
///  2. Un canal Android « ekenge_alerts » d'importance MAXIMALE est créé
///     (son + vibration + affichage tête haute).
///  3. Les alertes reçues app OUVERTE sont désormais affichées dans la
///     barre de notification système (avant : seulement la cloche interne).
///  4. Le même canal est déclaré comme canal FCM par défaut dans le
///     manifest : les push reçus app FERMÉE sonnent aussi.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String channelId = 'ekenge_alerts';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _id = 0;

  /// Initialise le plugin, crée le canal haute importance et demande la
  /// permission notifications (Android 13+).
  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      const channel = AndroidNotificationChannel(
        channelId,
        'Alertes EKENGE PLUS',
        description:
            'Alertes de sécurité : danger, tracking, vérifications Safe.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService.init: $e');
    }
  }

  /// Demande EXPLICITE de la permission notifications (Android 13+).
  /// Sans elle, rien n'apparaît dans la barre de notification.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      if (await Permission.notification.isGranted) return true;
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Affiche une notification SYSTÈME (barre de notification + sonnerie).
  Future<void> show(String title, String body) async {
    if (kIsWeb) return;
    if (!_ready) await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        _id++,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Alertes EKENGE PLUS',
            channelDescription:
                'Alertes de sécurité : danger, tracking, vérifications Safe.',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService.show: $e');
    }
  }
}
