import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;

import '../core/design.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import 'common.dart';

/// Marqueur affiche sur la carte.
class MapMarker {
  final GeoPoint point;
  final String initials;
  final String label;
  final Color color;
  final bool self;
  final bool pulsing;

  const MapMarker({
    required this.point,
    required this.initials,
    required this.label,
    required this.color,
    this.self = false,
    this.pulsing = false,
  });
}

/// EKENGE PLUS — Carte interactive REELLE (§6, §12 « Carte interactive »).
///
/// Fond de carte OpenStreetMap CLAIR (tuiles officielles, sans cle API) via
/// flutter_map — le meme rendu blanc et lisible que la carte web de suivi
/// (ekenge-plus.web.app). Zoom, deplacement, trajet parcouru et marqueurs
/// des proches en temps reel.
class EkMap extends StatefulWidget {
  final List<MapMarker> markers;
  final List<GeoPoint> trail;
  final GeoPoint? focus;
  final double height;
  final bool interactive;
  final bool showGrid;
  final Color trailColor;

  const EkMap({
    super.key,
    required this.markers,
    this.trail = const [],
    this.focus,
    this.height = 300,
    this.interactive = true,
    this.showGrid = true,
    this.trailColor = Ek.accent,
  });

  @override
  State<EkMap> createState() => _EkMapState();
}

class _EkMapState extends State<EkMap> with SingleTickerProviderStateMixin {
  final fm.MapController _map = fm.MapController();
  bool _ready = false;
  bool _follow = true; // recentre automatiquement sur la position suivie
  double _zoom = 16;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  ll.LatLng get _center {
    final p = widget.focus ??
        (widget.markers.isNotEmpty ? widget.markers.first.point : null);
    return p != null
        ? ll.LatLng(p.lat, p.lng)
        : const ll.LatLng(-4.3217, 15.3125); // Kinshasa, Gombe
  }

  @override
  void didUpdateWidget(EkMap old) {
    super.didUpdateWidget(old);
    // Suivi temps reel : la camera suit la position focalisee.
    if (_ready && _follow && widget.focus != null) {
      final f = widget.focus!;
      if (old.focus == null ||
          old.focus!.lat != f.lat ||
          old.focus!.lng != f.lng) {
        _map.move(ll.LatLng(f.lat, f.lng), _zoom);
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _map.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    _zoom = (_zoom + delta).clamp(3.0, 19.0);
    _map.move(_map.camera.center, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Ek.r20),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EDF1), // fond clair pendant le chargement
          border: Border.all(color: Ek.hairline),
          borderRadius: BorderRadius.circular(Ek.r20),
        ),
        child: Stack(
          children: [
            fm.FlutterMap(
              mapController: _map,
              options: fm.MapOptions(
                initialCenter: _center,
                initialZoom: _zoom,
                minZoom: 3,
                maxZoom: 19,
                backgroundColor: const Color(0xFFE9EDF1),
                interactionOptions: fm.InteractionOptions(
                  flags: widget.interactive
                      ? fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate
                      : fm.InteractiveFlag.none,
                ),
                onMapReady: () => _ready = true,
                onPositionChanged: (camera, hasGesture) {
                  _zoom = camera.zoom;
                  // L'utilisateur explore la carte : suspendre le suivi auto.
                  if (hasGesture && _follow) {
                    setState(() => _follow = false);
                  }
                },
              ),
              children: [
                // Tuiles officielles OpenStreetMap (gratuites, sans cle API),
                // affichees en clair — identiques a la carte web de suivi.
                fm.TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ekengeplus.app',
                  maxNativeZoom: 19,
                ),
                // Trajet parcouru (§6 : deplacement mis a jour en temps reel).
                if (widget.trail.length > 1)
                  fm.PolylineLayer(
                    polylines: [
                      fm.Polyline(
                        points: widget.trail
                            .map((p) => ll.LatLng(p.lat, p.lng))
                            .toList(),
                        strokeWidth: 7,
                        color: widget.trailColor.withValues(alpha: 0.14),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      fm.Polyline(
                        points: widget.trail
                            .map((p) => ll.LatLng(p.lat, p.lng))
                            .toList(),
                        strokeWidth: 2.6,
                        color: widget.trailColor.withValues(alpha: 0.9),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),
                // Marqueurs des utilisateurs — le point est centre EXACTEMENT
                // sur la position GPS (pas d'etiquette, pas de decalage).
                fm.MarkerLayer(
                  markers: widget.markers
                      .map(
                        (m) => fm.Marker(
                          point: ll.LatLng(m.point.lat, m.point.lng),
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          child: _Marker(marker: m, pulse: _pulse),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            // Attribution OpenStreetMap (obligation de licence).
            Positioned(
              left: 10,
              bottom: 6,
              child: IgnorePointer(
                child: Text(
                  '© OpenStreetMap',
                  style: Ek.over(size: 7.5, color: Color(0xFF5B6470)),
                ),
              ),
            ),
            // Commandes de zoom + recentrage.
            if (widget.interactive)
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  children: [
                    _MapBtn(icon: Icons.add, onTap: () => _zoomBy(1)),
                    const SizedBox(height: 8),
                    _MapBtn(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                    const SizedBox(height: 8),
                    _MapBtn(
                      icon: Icons.my_location,
                      active: _follow,
                      onTap: () {
                        setState(() => _follow = true);
                        _zoom = 16;
                        _map.move(_center, _zoom);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _MapBtn({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ek.surface.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: active ? Ek.accent : Ek.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 17,
            color: active ? Ek.accent : Ek.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  final MapMarker marker;
  final AnimationController pulse;
  const _Marker({required this.marker, required this.pulse});

  @override
  Widget build(BuildContext context) {
    // Uniquement le point de position (aucune etiquette sur la carte) :
    // le centre du point correspond exactement a la position GPS.
    if (marker.pulsing) {
      return AnimatedBuilder(
        animation: pulse,
        builder: (_, __) {
          final t = pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 18 + 34 * t,
                height: 18 + 34 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: marker.color.withValues(alpha: (1 - t) * 0.6),
                    width: 1.4,
                  ),
                ),
              ),
              _dot(),
            ],
          );
        },
      );
    }
    return Center(child: _dot());
  }

  Widget _dot() {
    if (marker.self) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: marker.color,
          border: Border.all(color: Colors.white, width: 2.4),
          boxShadow: Ek.glow(marker.color, o: 0.55, b: 14),
        ),
      );
    }
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Ek.bgElevated,
        border: Border.all(color: marker.color, width: 1.6),
        boxShadow: Ek.glow(marker.color, o: 0.28, b: 12),
      ),
      child: Center(
        child: Text(
          marker.initials,
          style: Ek.over(size: 9.5, color: marker.color),
        ),
      ),
    );
  }
}

/// Bandeau d'information sous la carte : coordonnees, vitesse, mise a jour.
class EkMapReadout extends StatelessWidget {
  final GeoPoint? point;
  final bool live;
  const EkMapReadout({super.key, required this.point, this.live = false});

  @override
  Widget build(BuildContext context) {
    if (point == null) {
      return Text('Position indisponible', style: Ek.body(size: 12));
    }
    return Row(
      children: [
        if (live) ...[
          const EkPulseDot(color: Ek.accent, size: 6),
          const SizedBox(width: 2),
        ] else
          const SizedBox(width: 4),
        Expanded(
          child: Text(
            LocationService.formatCoords(point!),
            style: Ek.body(size: 11.5, color: Ek.textTertiary),
          ),
        ),
        Text(
          '${point!.speedKmh.toStringAsFixed(1)} km/h',
          style: Ek.over(size: 9.5),
        ),
      ],
    );
  }
}
