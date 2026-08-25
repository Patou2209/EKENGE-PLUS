import 'dart:async';
import 'dart:math';

import '../models/models.dart';

/// EKENGE PLUS — Geolocalisation temps reel (§12 « Geolocalisation temps reel »,
/// §13 Geolocator + Background Location Services).
///
/// En environnement de preview web, le materiel GPS n'est pas disponible : ce
/// service produit un flux de positions realiste (marche/deplacement urbain)
/// avec la meme API qu'un `Geolocator.getPositionStream`. Le remplacement par
/// Geolocator se fait dans cette seule classe.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Point de depart : Kinshasa, commune de la Gombe.
  static const double _originLat = -4.3217;
  static const double _originLng = 15.3125;

  final Random _rnd = Random();
  final StreamController<GeoPoint> _ctrl =
      StreamController<GeoPoint>.broadcast();
  Timer? _timer;

  double _lat = _originLat;
  double _lng = _originLng;
  double _heading = 0.9;
  bool _permissionGranted = false;
  bool _running = false;

  Stream<GeoPoint> get stream => _ctrl.stream;
  bool get isRunning => _running;
  bool get permissionGranted => _permissionGranted;

  GeoPoint get current =>
      GeoPoint(lat: _lat, lng: _lng, at: DateTime.now(), speedKmh: _lastSpeed);

  double _lastSpeed = 0;

  /// §15 Gestion stricte des permissions mobiles.
  Future<bool> requestPermission() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _permissionGranted = true;
    return true;
  }

  /// Demarre la transmission continue de la localisation.
  void start({Duration interval = const Duration(seconds: 3)}) {
    if (_running) return;
    _running = true;
    _timer?.cancel();
    _emit();
    _timer = Timer.periodic(interval, (_) => _emit());
  }

  /// Arrete la transmission (arret du Tracking).
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _lastSpeed = 0;
  }

  void _emit() {
    // Deplacement pedestre : ~4 a 6 km/h avec legere derive de cap.
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
      lat: _originLat + cos(a) * d / 111320,
      lng: _originLng + sin(a) * d / (111320 * cos(_originLat * pi / 180)),
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
