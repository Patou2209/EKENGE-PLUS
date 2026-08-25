import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/ek_state.dart';
import '../services/location_service.dart';
import '../widgets/common.dart';

/// EKENGE PLUS — §12 Journalisation des evenements de securite.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            EkHeader(
              title: 'Journal de securite',
              subtitle: 'Historique des evenements',
              back: false,
              actions: [
                IconButton(
                  tooltip: 'Copier le journal',
                  onPressed: st.journal.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: st.exportJournal()),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Journal copie au format JSON.'),
                            ),
                          );
                        },
                  icon: const Icon(Icons.copy_all_outlined, size: 19),
                  color: Ek.textSecondary,
                ),
                IconButton(
                  tooltip: 'Effacer',
                  onPressed: st.journal.isEmpty
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(
                                'Effacer le journal',
                                style: Ek.title(size: 16),
                              ),
                              content: Text(
                                'L\'historique des evenements de securite sera '
                                'definitivement supprime.',
                                style: Ek.body(size: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(
                                    'Annuler',
                                    style: Ek.body(size: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(
                                    'Effacer',
                                    style: Ek.body(
                                      size: 13,
                                      color: Ek.dangerBright,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) await st.clearJournal();
                        },
                  icon: const Icon(Icons.delete_outline, size: 19),
                  color: Ek.textSecondary,
                ),
              ],
            ),
            Expanded(
              child: st.journal.isEmpty
                  ? const EkEmpty(
                      icon: Icons.receipt_long_outlined,
                      title: 'Journal vide',
                      message:
                          'Chaque activation de Tracking, alerte Danger, '
                          'verification Safe, escalade et confirmation de '
                          'securite est enregistree ici.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: st.journal.length,
                      itemBuilder: (_, i) => _EventTile(
                        event: st.journal[i],
                        first: i == 0,
                        last: i == st.journal.length - 1,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final EkEvent event;
  final bool first;
  final bool last;

  const _EventTile({
    required this.event,
    required this.first,
    required this.last,
  });

  (IconData, Color) get _visual => switch (event.type) {
    EkEventType.accountCreated => (Icons.person_add_alt, Ek.accent),
    EkEventType.otpSent => (Icons.sms_outlined, Ek.textSecondary),
    EkEventType.otpVerified => (Icons.verified_outlined, Ek.safe),
    EkEventType.login => (Icons.login, Ek.textSecondary),
    EkEventType.logout => (Icons.logout, Ek.textSecondary),
    EkEventType.listsConfigured => (Icons.group_add_outlined, Ek.accent),
    EkEventType.contactAdded => (Icons.person_add_alt_1_outlined, Ek.accent),
    EkEventType.contactRemoved => (
      Icons.person_remove_alt_1_outlined,
      Ek.textTertiary,
    ),
    EkEventType.contactLinked => (Icons.link, Ek.safe),
    EkEventType.invitationSent => (Icons.send_outlined, Ek.warn),
    EkEventType.trackingStarted => (Icons.share_location_outlined, Ek.safe),
    EkEventType.trackingStopped => (
      Icons.location_off_outlined,
      Ek.textTertiary,
    ),
    EkEventType.dangerTriggered => (Icons.crisis_alert_outlined, Ek.danger),
    EkEventType.safeCheckScheduled => (Icons.timer_outlined, Ek.textSecondary),
    EkEventType.safeCheckDue => (Icons.notifications_active_outlined, Ek.warn),
    EkEventType.safeConfirmed => (Icons.verified_user_outlined, Ek.safe),
    EkEventType.escalationLevel1 => (Icons.warning_amber_rounded, Ek.warn),
    EkEventType.escalationLevel2 => (
      Icons.report_gmailerrorred_outlined,
      Ek.danger,
    ),
    EkEventType.alertClosed => (Icons.task_alt, Ek.safe),
    EkEventType.notificationSent => (Icons.outbox_outlined, Ek.textTertiary),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visual;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colonne chronologique
          Column(
            children: [
              Container(
                width: 1,
                height: 10,
                color: first ? Colors.transparent : Ek.hairline,
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Ek.surface,
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              Expanded(
                child: Container(
                  width: 1,
                  color: last ? Colors.transparent : Ek.hairline,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: Ek.body(size: 13.5, color: Ek.textPrimary),
                        ),
                      ),
                      Text(ekFormatTime(event.at), style: Ek.over(size: 8.5)),
                    ],
                  ),
                  if (event.detail.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(event.detail, style: Ek.body(size: 12, height: 1.5)),
                  ],
                  if (event.position != null) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: Ek.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            LocationService.formatCoords(event.position!),
                            style: Ek.body(size: 10.5, color: Ek.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
