import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/ek_state.dart';
import '../services/location_service.dart';
import '../widgets/common.dart';
import '../widgets/ek_map.dart';

/// EKENGE PLUS — Suivi en direct d'un proche sur carte plein écran.
///
/// Même expérience que la page web de suivi (ekenge-plus.web.app) : la carte
/// occupe tout l'écran, la position du proche est mise à jour en temps réel
/// (flux Firestore), avec un bouton retour pour revenir à la page Proches.
class FollowScreen extends StatelessWidget {
  final String phone;
  const FollowScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final i = st.watched.indexWhere((w) => w.phone == phone);
    final w = i >= 0 ? st.watched[i] : null;
    final danger = w != null && w.alert == AlertKind.danger;
    final online = w != null && w.trackingActive;
    final color = danger ? Ek.danger : Ek.accent;

    return Scaffold(
      backgroundColor: Ek.bg,
      body: SafeArea(
        child: Column(
          children: [
            EkHeader(
              title: w?.name ?? 'Suivi en direct',
              subtitle: danger
                  ? 'ALERTE DANGER — position en direct'
                  : (online ? 'Suivi en direct' : 'Hors ligne'),
            ),
            if (w == null)
              const Expanded(
                child: EkEmpty(
                  icon: Icons.location_off_outlined,
                  title: 'Position indisponible',
                  message:
                      'Ce proche ne partage pas sa localisation pour le '
                      'moment. Sa position apparaîtra ici dès qu\'il activera '
                      'son Tracking.',
                ),
              )
            else ...[
              // Bandeau d'état.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: EkCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  color: danger
                      ? Ek.danger.withValues(alpha: 0.06)
                      : (online ? Ek.accent.withValues(alpha: 0.06) : null),
                  border: danger
                      ? Ek.danger.withValues(alpha: 0.35)
                      : (online ? Ek.accent.withValues(alpha: 0.22) : null),
                  child: Row(
                    children: [
                      EkMonogram(
                        initials: w.initials,
                        size: 36,
                        color: online ? color : Ek.textTertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (danger)
                                  const EkPill(
                                    label: 'Danger',
                                    color: Ek.danger,
                                    icon: Icons.crisis_alert,
                                    solid: true,
                                  )
                                else if (online)
                                  const EkPill(
                                    label: 'En ligne',
                                    color: Ek.accent,
                                    icon: Icons.share_location_outlined,
                                  )
                                else
                                  const EkPill(
                                    label: 'Hors ligne',
                                    color: Ek.textTertiary,
                                    icon: Icons.location_off_outlined,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  ekRelative(w.lastUpdate),
                                  style: Ek.over(size: 8.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            EkMapReadout(point: w.position, live: online),
                          ],
                        ),
                      ),
                      if (online) EkPulseDot(color: color, size: 7),
                    ],
                  ),
                ),
              ),
              // Carte plein écran, suivie en temps réel.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: LayoutBuilder(
                    builder: (context, box) => EkMap(
                      height: box.maxHeight,
                      focus: w.position,
                      trailColor: color,
                      markers: [
                        MapMarker(
                          point: w.position,
                          initials: w.initials,
                          label: w.name.split(' ').first.toUpperCase(),
                          color: online ? color : Ek.textTertiary,
                          pulsing: online,
                        ),
                        if (st.position != null)
                          MapMarker(
                            point: st.position!,
                            initials: 'MOI',
                            label: 'MOI',
                            color: Ek.ink,
                            self: true,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Distance + retour.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.straighten,
                          size: 14,
                          color: Ek.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Distance : '
                          '${LocationService.distance(st.position ?? LocationService.instance.current, w.position).round()} m',
                          style: Ek.body(size: 11.5, color: Ek.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    EkButton(
                      label: 'RETOUR',
                      icon: Icons.arrow_back,
                      height: 48,
                      outlined: true,
                      color: Ek.ink,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
