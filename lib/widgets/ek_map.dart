import 'dart:math';

import 'package:flutter/material.dart';

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

/// EKENGE PLUS — Carte interactive (§6 : consultation de la localisation sur
/// une carte, mise a jour en temps reel).
///
/// Rendu vectoriel du tissu urbain dans le style sombre de l'application :
/// aucune dependance externe, aucune cle API requise pour la preview. La
/// substitution par Google Maps SDK ou Mapbox (§13) se limite a ce widget.
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
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  Offset _panStart = Offset.zero;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Echelle : metres par pixel a zoom 1.
  static const double _mppBase = 1.6;

  Offset _project(GeoPoint p, GeoPoint center, Size size) {
    final mpp = _mppBase / _zoom;
    final dx =
        LocationService.distance(
          GeoPoint(lat: center.lat, lng: center.lng, at: p.at),
          GeoPoint(lat: center.lat, lng: p.lng, at: p.at),
        ) *
        (p.lng >= center.lng ? 1 : -1);
    final dy =
        LocationService.distance(
          GeoPoint(lat: center.lat, lng: center.lng, at: p.at),
          GeoPoint(lat: p.lat, lng: center.lng, at: p.at),
        ) *
        (p.lat >= center.lat ? -1 : 1);
    return Offset(
      size.width / 2 + dx / mpp + _pan.dx,
      size.height / 2 + dy / mpp + _pan.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final center =
        widget.focus ??
        (widget.markers.isNotEmpty
            ? widget.markers.first.point
            : GeoPoint(lat: -4.3217, lng: 15.3125, at: DateTime.now()));

    return ClipRRect(
      borderRadius: BorderRadius.circular(Ek.r20),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E13),
          border: Border.all(color: Ek.hairline),
          borderRadius: BorderRadius.circular(Ek.r20),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return GestureDetector(
              onScaleStart: widget.interactive
                  ? (d) => _panStart = d.localFocalPoint - _pan
                  : null,
              onScaleUpdate: widget.interactive
                  ? (d) {
                      setState(() {
                        if (d.scale != 1.0) {
                          _zoom = (_zoom * (1 + (d.scale - 1) * 0.06)).clamp(
                            0.45,
                            3.2,
                          );
                        }
                        _pan = d.localFocalPoint - _panStart;
                      });
                    }
                  : null,
              child: Stack(
                children: [
                  // Tissu urbain
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CityPainter(
                        zoom: _zoom,
                        pan: _pan,
                        grid: widget.showGrid,
                      ),
                    ),
                  ),
                  // Trajet parcouru
                  if (widget.trail.length > 1)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TrailPainter(
                          points: widget.trail
                              .map((e) => _project(e, center, size))
                              .toList(),
                          color: widget.trailColor,
                        ),
                      ),
                    ),
                  // Marqueurs
                  ...widget.markers.map((m) {
                    final o = _project(m.point, center, size);
                    if (o.dx < -60 ||
                        o.dy < -60 ||
                        o.dx > size.width + 60 ||
                        o.dy > size.height + 60) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      left: o.dx - 58,
                      top: o.dy - 46,
                      width: 116,
                      child: _Marker(marker: m, pulse: _pulse),
                    );
                  }),
                  // Vignette
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 1.0,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.42),
                            ],
                            stops: const [0.55, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Echelle
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: _ScaleBar(zoom: _zoom, mppBase: _mppBase),
                  ),
                  // Commandes de zoom
                  if (widget.interactive)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(
                        children: [
                          _MapBtn(
                            icon: Icons.add,
                            onTap: () => setState(
                              () => _zoom = (_zoom * 1.35).clamp(0.45, 3.2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MapBtn(
                            icon: Icons.remove,
                            onTap: () => setState(
                              () => _zoom = (_zoom / 1.35).clamp(0.45, 3.2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MapBtn(
                            icon: Icons.my_location,
                            onTap: () => setState(() {
                              _pan = Offset.zero;
                              _zoom = 1.0;
                            }),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ek.surface.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Ek.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 17, color: Ek.textSecondary),
        ),
      ),
    );
  }
}

class _ScaleBar extends StatelessWidget {
  final double zoom;
  final double mppBase;
  const _ScaleBar({required this.zoom, required this.mppBase});

  @override
  Widget build(BuildContext context) {
    final mpp = mppBase / zoom;
    final metres = (60 * mpp).round();
    final label = metres >= 1000
        ? '${(metres / 1000).toStringAsFixed(1)} km'
        : '$metres m';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 60, height: 1.4, color: Ek.textTertiary),
        const SizedBox(height: 4),
        Text(label, style: Ek.over(size: 9)),
      ],
    );
  }
}

class _Marker extends StatelessWidget {
  final MapMarker marker;
  final AnimationController pulse;
  const _Marker({required this.marker, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (marker.pulsing)
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) {
              final t = pulse.value;
              return SizedBox(
                width: 54,
                height: 54,
                child: Stack(
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
                ),
              );
            },
          )
        else
          SizedBox(width: 54, height: 54, child: Center(child: _dot())),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Ek.bgElevated.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: marker.color.withValues(alpha: 0.35)),
          ),
          child: Text(
            marker.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ek.over(size: 8.5, color: Ek.textPrimary),
          ),
        ),
      ],
    );
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

/// Rendu du tissu urbain : blocs, avenues, fleuve.
class _CityPainter extends CustomPainter {
  final double zoom;
  final Offset pan;
  final bool grid;
  _CityPainter({required this.zoom, required this.pan, required this.grid});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0B0E13);
    canvas.drawRect(Offset.zero & size, bg);

    if (!grid) return;

    final rnd = Random(7);
    final step = 78 * zoom;

    // Ilots urbains
    final block = Paint()..color = const Color(0xFF10141B);
    for (double x = -step; x < size.width + step; x += step) {
      for (double y = -step; y < size.height + step; y += step) {
        final ox = (x + pan.dx % step) - step / 2;
        final oy = (y + pan.dy % step) - step / 2;
        final inset = 6.0 + rnd.nextDouble() * 8;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              ox + inset,
              oy + inset,
              step - inset * 2,
              step - inset * 2,
            ),
            const Radius.circular(3),
          ),
          block,
        );
      }
    }

    // Voies secondaires
    final minor = Paint()
      ..color = const Color(0xFF171C24)
      ..strokeWidth = 1.2 * zoom.clamp(0.6, 2.0);
    for (double x = 0; x < size.width + step; x += step) {
      final ox = x + pan.dx % step;
      canvas.drawLine(Offset(ox, 0), Offset(ox, size.height), minor);
    }
    for (double y = 0; y < size.height + step; y += step) {
      final oy = y + pan.dy % step;
      canvas.drawLine(Offset(0, oy), Offset(size.width, oy), minor);
    }

    // Avenues principales
    final major = Paint()
      ..color = const Color(0xFF1F2733)
      ..strokeWidth = 3.4 * zoom.clamp(0.6, 2.0);
    final bigStep = step * 3;
    for (double x = 0; x < size.width + bigStep; x += bigStep) {
      final ox = x + pan.dx % bigStep;
      canvas.drawLine(Offset(ox, 0), Offset(ox, size.height), major);
    }
    for (double y = 0; y < size.height + bigStep; y += bigStep) {
      final oy = y + pan.dy % bigStep;
      canvas.drawLine(Offset(0, oy), Offset(size.width, oy), major);
    }

    // Fleuve en diagonale
    final river = Paint()
      ..color = const Color(0xFF0D2830)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26 * zoom.clamp(0.5, 2.0)
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final base = size.height * 0.82 + pan.dy * 0.35;
    path.moveTo(-40, base);
    path.quadraticBezierTo(
      size.width * 0.35 + pan.dx * 0.3,
      base - 70 * zoom,
      size.width + 40,
      base - 20 * zoom,
    );
    canvas.drawPath(path, river);
  }

  @override
  bool shouldRepaint(_CityPainter o) => o.zoom != zoom || o.pan != pan;
}

/// Trace du deplacement.
class _TrailPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  _TrailPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.14),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_TrailPainter o) => true;
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
