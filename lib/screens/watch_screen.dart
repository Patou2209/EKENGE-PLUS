import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/ek_state.dart';
import '../services/location_service.dart';
import '../widgets/common.dart';
import '../widgets/ek_map.dart';
import 'follow_screen.dart';

/// EKENGE PLUS — §5 / §6 Suivi des proches.
///
/// Les utilisateurs synchronises apparaissent ici : lorsqu'ils activent leur
/// Tracking, leur localisation est consultable sur la carte interactive et
/// mise a jour en temps reel.
class WatchScreen extends StatelessWidget {
  const WatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final active = st.watched.where((w) => w.trackingActive).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const EkHeader(
              title: 'Suivi des proches',
              subtitle: 'Personnes que vous pouvez suivre',
              back: false,
            ),
            Expanded(
              child: st.watched.isEmpty
                  ? const EkEmpty(
                      icon: Icons.travel_explore_outlined,
                      title: 'Aucun proche synchronise',
                      message:
                          'Les contacts possédant un compte EKENGE PLUS '
                          'apparaissent ici. Vous pourrez suivre leur '
                          'localisation lorsqu\'ils activeront leur Tracking.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        if (active.isNotEmpty) ...[
                          EkSectionLabel(
                            'Carte interactive',
                            trailing: Text(
                              '${active.length} EN DIRECT',
                              style: Ek.over(size: 8.5, color: Ek.accent),
                            ),
                          ),
                          EkMap(
                            height: 240,
                            focus: active.first.position,
                            markers: active
                                .map(
                                  (w) => MapMarker(
                                    point: w.position,
                                    initials: w.initials,
                                    label: w.name
                                        .split(' ')
                                        .first
                                        .toUpperCase(),
                                    color: w.alert == AlertKind.danger
                                        ? Ek.danger
                                        : Ek.accent,
                                    pulsing: true,
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                        EkSectionLabel('${st.watched.length} proche(s)'),
                        ...List.generate(st.watched.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _WatchedCard(index: i),
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchedCard extends StatelessWidget {
  final int index;
  const _WatchedCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final w = st.watched[index];
    final danger = w.alert == AlertKind.danger;
    final color = danger
        ? Ek.danger
        : (w.trackingActive ? Ek.accent : Ek.textTertiary);

    return EkCard(
      padding: const EdgeInsets.all(16),
      border: danger ? Ek.danger.withValues(alpha: 0.42) : null,
      color: danger ? Ek.danger.withValues(alpha: 0.05) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EkMonogram(initials: w.initials, size: 44, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.name,
                      style: Ek.body(size: 14.5, color: Ek.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (danger)
                          EkPill(
                            label: 'Danger',
                            color: Ek.danger,
                            icon: Icons.crisis_alert,
                            solid: true,
                          )
                        else if (w.trackingActive)
                          EkPill(
                            label: 'Tracking actif',
                            color: Ek.accent,
                            icon: Icons.share_location_outlined,
                          )
                        else
                          EkPill(
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
                  ],
                ),
              ),
              if (w.trackingActive) const EkPulseDot(color: Ek.accent, size: 6),
            ],
          ),
          if (w.trackingActive) ...[
            const SizedBox(height: 14),
            EkMap(
              height: 150,
              interactive: false,
              focus: w.position,
              markers: [
                MapMarker(
                  point: w.position,
                  initials: w.initials,
                  label: w.name.split(' ').first.toUpperCase(),
                  color: color,
                  pulsing: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    LocationService.formatCoords(w.position),
                    style: Ek.body(size: 11, color: Ek.textTertiary),
                  ),
                ),
                Text(
                  '${LocationService.distance(st.position ?? LocationService.instance.current, w.position).round()} m',
                  style: Ek.over(size: 9),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              // SUIVRE : carte en gros plan avec la position en direct.
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FollowScreen(phone: w.phone),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.travel_explore_outlined,
                    size: 16,
                    color: Ek.accentDim,
                  ),
                  label: Text(
                    'SUIVRE',
                    style: Ek.over(size: 9.5, color: Ek.accentDim),
                  ),
                ),
              ),
              Container(width: 1, height: 22, color: Ek.hairline),
              // ALERTER : previent ce proche que VOUS etes en danger et
              // partage votre position exacte en direct.
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _confirmAlert(context, st, w.name),
                  icon: const Icon(
                    Icons.crisis_alert_outlined,
                    size: 16,
                    color: Ek.danger,
                  ),
                  label: Text(
                    'ALERTER',
                    style: Ek.over(size: 9.5, color: Ek.danger),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAlert(
    BuildContext context,
    EkState st,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ek.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Alerter $name ?', style: Ek.body(size: 16)),
        content: Text(
          '$name recevra une alerte indiquant que vous êtes en danger et '
          'pourra suivre votre position exacte en direct.',
          style: Ek.body(size: 12.5, color: Ek.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('ANNULER', style: Ek.over(size: 10)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('ALERTER', style: Ek.over(size: 10, color: Ek.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // Verification stricte GPS/permission avant l'envoi.
    final ready = await ekEnsureLocationReady(context);
    if (!ready || !context.mounted) return;
    await st.alertContact(index);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Ek.ink,
        content: Text(
          'Alerte envoyée à $name — il peut maintenant suivre votre position.',
          style: Ek.body(size: 12.5, color: Colors.white),
        ),
      ),
    );
  }
}
