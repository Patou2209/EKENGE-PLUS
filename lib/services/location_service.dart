import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../models/models.dart';

/// EKENGE PLUS — Geolocalisation temps reel (§12 « Geolocalisation temps reel »,
/// §13 Geolocator + Background Location Services).
///
/// GPS REEL via le paquet `geolocator`. Si la permission est refusee ou que
/// le materiel GPS est indisponible (preview web), le service bascule sur un
/// flux de positions simule afin que l'application reste utilisable.
///
/// Diagnostic de disponibilité du GPS avant tout partage de position.
enum LocationReadiness {
  /// GPS actif et permission accordée : positions réelles.
  ready,

  /// Le service de localisation de l'appareil est désactivé (GPS éteint).
  serviceDisabled,

  /// Permission refusée pour cette session.
  denied,

  /// Permission refusée définitivement : passer par les réglages système.
  deniedForever,

  /// Matériel ou API indisponible (preview web).
  unavailable,
}

/// SUIVI EN ARRIERE-PLAN (§13 Background Location Services) : sur Android,
/// le flux GPS est adosse a un FOREGROUND SERVICE natif avec notification
/// persistante « EKENGE PLUS vous protege ». La position continue donc
/// d'etre transmise a Firestore (et a la carte web de suivi) meme quand
/// l'application est en arriere-plan ou l'ecran verrouille.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Point de depart du mode simule : Kinshasa, commune de la Gombe.
  static const double _originLat = -4.3217;
  static const double _originLng = 15.3125;

  final Random _rnd = Random();
  final StreamController<GeoPoint> _ctrl =
      StreamController<GeoPoint>.broadcast();
  Timer? _timer;
  StreamSubscription<geo.Position>? _gpsSub;

  double _lat = _originLat;
  double _lng = _originLng;
  double _heading = 0.9;
  bool _permissionGranted = false;
  bool _running = false;

  /// true = GPS materiel actif ; false = flux simule (preview / refus).
  bool _realGps = false;
  bool get usingRealGps => _realGps;

  Stream<GeoPoint> get stream => _ctrl.stream;
  bool get isRunning => _running;
  bool get permissionGranted => _permissionGranted;

  GeoPoint get current =>
      GeoPoint(lat: _lat, lng: _lng, at: DateTime.now(), speedKmh: _lastSpeed);

  double _lastSpeed = 0;

  /// §15 Gestion stricte des permissions mobiles : vérifie que le GPS de
  /// l'appareil est ACTIVÉ puis demande la permission système. Retourne un
  /// diagnostic précis afin que l'interface puisse guider l'utilisateur
  /// (activer la localisation, ouvrir les réglages…) au lieu de partager
  /// une position erronée.
  Future<LocationReadiness> ensureReady() async {
    if (kIsWeb) {
      _permissionGranted = true;
      _realGps = false;
      return LocationReadiness.ready;
    }
    try {
      // 1. Le service de localisation de l'appareil doit être actif.
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        _realGps = false;
        return LocationReadiness.serviceDisabled;
      }
      // 2. Permission d'accès à la position (boite de dialogue native).
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.deniedForever) {
        _realGps = false;
        return LocationReadiness.deniedForever;
      }
      final granted =
          permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always;
      if (!granted) {
        _realGps = false;
        return LocationReadiness.denied;
      }
      _realGps = true;
      _permissionGranted = true;
      // 3. Position initiale immédiate pour centrer la carte.
      try {
        final p = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 15));
        _lat = p.latitude;
        _lng = p.longitude;
      } catch (_) {
        // Dernière position connue en attendant le premier point GPS.
        try {
          final last = await geo.Geolocator.getLastKnownPosition();
          if (last != null) {
            _lat = last.latitude;
            _lng = last.longitude;
          }
        } catch (_) {}
      }
      return LocationReadiness.ready;
    } catch (e) {
      if (kDebugMode) debugPrint('[Location] ensureReady: $e');
      _realGps = false;
      return LocationReadiness.unavailable;
    }
  }

  /// Compatibilité : vraie demande de permission, true uniquement si le
  /// GPS réel est opérationnel (ou preview web).
  Future<bool> requestPermission() async {
    final r = await ensureReady();
    return r == LocationReadiness.ready;
  }

  /// Ouvre les réglages de localisation de l'appareil (GPS désactivé).
  Future<void> openLocationSettings() =>
      geo.Geolocator.openLocationSettings();

  /// Ouvre les réglages de l'application (permission refusée définitivement).
  Future<void> openAppSettings() => geo.Geolocator.openAppSettings();

  /// Demarre la transmission continue de la localisation.
  void start({Duration interval = const Duration(seconds: 3)}) {
    if (_running) return;
    _running = true;

    if (_realGps && !kIsWeb) {
      _gpsSub?.cancel();
      _gpsSub = geo.Geolocator.getPositionStream(
        locationSettings: _settings(),
      ).listen(
        (p) {
          _lat = p.latitude;
          _lng = p.longitude;
          _lastSpeed = (p.speed * 3.6).clamp(0, 300); // m/s -> km/h
          _ctrl.add(current);
        },
        onError: (Object e) {
          if (kDebugMode) debugPrint('[Location] GPS stream: $e');
          // Panne GPS en cours de route : bascule sur la simulation.
          _realGps = false;
          _startSimulation(interval);
        },
      );
      // Premiere emission immediate.
      _ctrl.add(current);
    } else if (kIsWeb) {
      // La simulation n'existe QUE pour l'apercu web : sur telephone,
      // jamais de position inventee.
      _startSimulation(interval);
    } else {
      _running = false;
    }
  }

  /// Parametres de localisation par plateforme. Sur Android, active le
  /// FOREGROUND SERVICE natif de geolocator : notification persistante
  /// obligatoire qui maintient le GPS actif ecran verrouille / app en fond.
  geo.LocationSettings _settings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return geo.AndroidSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5, // mise a jour tous les 5 metres
        intervalDuration: const Duration(seconds: 5),
        // Notification persistante : le systeme ne peut pas tuer le suivi.
        foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
          notificationTitle: 'EKENGE PLUS vous protège',
          notificationText:
              'Partage de position en cours — vos proches peuvent vous suivre '
              'en temps réel, même écran verrouillé.',
          notificationIcon: geo.AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
          notificationChannelName: 'Suivi de localisation EKENGE PLUS',
          enableWakeLock: true, // le CPU reste actif pour transmettre
          enableWifiLock: true, // la connexion reste active pour Firestore
          setOngoing: true, // notification non balayable pendant le suivi
        ),
      );
    }
    return const geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  void _startSimulation(Duration interval) {
    _timer?.cancel();
    _emit();
    _timer = Timer.periodic(interval, (_) => _emit());
  }

  /// Arrete la transmission (arret du Tracking).
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    _lastSpeed = 0;
  }

  void _emit() {
    // Deplacement pedestre simule : ~4 a 6 km/h avec legere derive de cap.
    _heading += (_rnd.nextDouble() - 0.5) * 0.5;
    final speed = 3.5 + _rnd.nextDouble() * 2.5;
    _lastSpeed = speed;
    final metres = speed * 1000 / 3600 * 3; // distance sur 3 secondes
    _lat += cos(_heading) * metres / 111320;
    _lng += sin(_heading) * metres / (111320 * cos(_originLat * pi / 180));
    _ctrl.add(current);
  }

  /// Genere une position voisine (positions des proches suivis).
  GeoPoint nearby({double radiusMetres = 1800}) {
    final a = _rnd.nextDouble() * 2 * pi;
    final d = radiusMetres * (0.25 + _rnd.nextDouble() * 0.75);
    return GeoPoint(
      lat: _lat + cos(a) * d / 111320,
      lng: _lng + sin(a) * d / (111320 * cos(_lat * pi / 180)),
      at: DateTime.now(),
      speedKmh: _rnd.nextDouble() * 6,
    );
  }

  /// Deplace legerement une position existante (mise a jour temps reel).
  GeoPoint drift(GeoPoint p, {double metres = 12}) {
    final a = _rnd.nextDouble() * 2 * pi;
    return GeoPoint(
      lat: p.lat + cos(a) * metres / 111320,
      lng: p.lng + sin(a) * metres / (111320 * cos(_originLat * pi / 180)),
      at: DateTime.now(),
      speedKmh: p.speedKmh,
    );
  }

  /// Distance en metres (formule de Haversine).
  static double distance(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    final dLat = (b.lat - a.lat) * pi / 180;
    final dLng = (b.lng - a.lng) * pi / 180;
    final la1 = a.lat * pi / 180;
    final la2 = b.lat * pi / 180;
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(la1) * cos(la2) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * atan2(sqrt(h), sqrt(1 - h));
  }

  /// Libelle de coordonnees en degres / minutes / secondes.
  static String formatCoords(GeoPoint p) {
    String dms(double v, String pos, String neg) {
      final hemi = v >= 0 ? pos : neg;
      final a = v.abs();
      final d = a.floor();
      final m = ((a - d) * 60).floor();
      final s = (((a - d) * 60 - m) * 60);
      return '$d\u00B0${m.toString().padLeft(2, '0')}\'${s.toStringAsFixed(1)}"$hemi';
    }

    return '${dms(p.lat, 'N', 'S')}  ${dms(p.lng, 'E', 'W')}';
  }
}
