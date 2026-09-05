import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/backend.dart';
import '../services/ek_state.dart';
import '../widgets/common.dart';
import 'follow_screen.dart';

/// EKENGE PLUS — §11 Notifications.
///
/// Deux canaux : notifications Push (utilisateurs equipes de l'application)
/// et messages WhatsApp (meilleure visibilite des alertes). Le second onglet
/// presente le registre des messages emis vers les contacts.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EkState>().markAllRead();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const EkHeader(
              title: 'Notifications',
              subtitle: 'Canaux Push et WhatsApp',
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Ek.surface,
                borderRadius: BorderRadius.circular(Ek.r16),
                border: Border.all(color: Ek.hairline),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: Ek.surfaceHigh,
                  borderRadius: BorderRadius.circular(Ek.r12),
                  border: Border.all(color: Ek.hairline),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                dividerColor: Colors.transparent,
                labelColor: Ek.textPrimary,
                unselectedLabelColor: Ek.textTertiary,
                labelStyle: Ek.over(size: 10.5, color: Ek.textPrimary),
                unselectedLabelStyle: Ek.over(size: 10.5),
                tabs: const [
                  Tab(height: 44, text: 'REÇUES'),
                  Tab(height: 44, text: 'ÉMISES'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _Received(items: st.inbox),
                  _Sent(items: st.outbox),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Received extends StatelessWidget {
  final List<PushNotification> items;
  const _Received({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EkEmpty(
        icon: Icons.notifications_none,
        title: 'Aucune notification',
        message:
            'Les notifications Push liées à votre sécurité et à celle de vos '
            'proches apparaissent ici.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final n = items[i];
        final color = switch (n.severity) {
          AlertKind.danger || AlertKind.safeLevel2 => Ek.danger,
          AlertKind.safeLevel1 => Ek.warn,
          AlertKind.none => Ek.accent,
        };
        return EkCard(
          padding: const EdgeInsets.all(15),
          border: n.severity == AlertKind.none
              ? null
              : color.withValues(alpha: 0.32),
          color: n.severity == AlertKind.none
              ? null
              : color.withValues(alpha: 0.05),
          // Toucher une notification liee a un proche ouvre sa carte de
          // suivi en direct (position exacte).
          onTap: n.fromPhone.isEmpty
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FollowScreen(phone: n.fromPhone),
                    ),
                  );
                },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: color.withValues(alpha: 0.10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  switch (n.severity) {
                    AlertKind.danger => Icons.crisis_alert_outlined,
                    AlertKind.safeLevel1 => Icons.warning_amber_rounded,
                    AlertKind.safeLevel2 => Icons.report_gmailerrorred_outlined,
                    AlertKind.none => Icons.notifications_none,
                  },
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: Ek.body(size: 13.5, color: Ek.textPrimary),
                          ),
                        ),
                        Text(ekRelative(n.at), style: Ek.over(size: 8.5)),
                      ],
                    ),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(n.body, style: Ek.body(size: 12, height: 1.5)),
                    ],
                    if (n.fromPhone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.travel_explore_outlined,
                            size: 13,
                            color: color,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'TOUCHER POUR SUIVRE SUR LA CARTE',
                            style: Ek.over(size: 8.5, color: color),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sent extends StatelessWidget {
  final List<OutboundMessage> items;
  const _Sent({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EkEmpty(
        icon: Icons.outbox_outlined,
        title: 'Aucun message émis',
        message:
            'Le registre des notifications Push et des messages WhatsApp '
            'transmis à vos contacts apparaîtra ici.',
      );
    }

    final push = items.where((m) => m.channel == Channel.push).length;
    final wa = items.length - push;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: EkCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          size: 15,
                          color: Ek.accent,
                        ),
                        const SizedBox(width: 8),
                        Text('PUSH', style: Ek.over(size: 9)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('$push', style: Ek.num(size: 20)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EkCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.chat_outlined,
                          size: 15,
                          color: Ek.safe,
                        ),
                        const SizedBox(width: 8),
                        Text('WHATSAPP', style: Ek.over(size: 9)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('$wa', style: Ek.num(size: 20)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        EkCard(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, size: 15, color: Ek.safe),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Messages WhatsApp émis depuis le numéro officiel certifié '
                  'EKENGE PLUS via WhatsApp Business Platform.',
                  style: Ek.body(size: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        EkSectionLabel('${items.length} message(s)'),
        ...items
            .take(120)
            .map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SentCard(message: m),
              ),
            ),
      ],
    );
  }
}

class _SentCard extends StatelessWidget {
  final OutboundMessage message;
  const _SentCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final wa = message.channel == Channel.whatsapp;
    final color = switch (message.kind) {
      'danger' || 'safe_level2' => Ek.danger,
      'safe_level1' => Ek.warn,
      'invitation' => Ek.accent,
      'safe_confirmed' => Ek.safe,
      _ => Ek.textSecondary,
    };
    final kindLabel = switch (message.kind) {
      'danger' => 'ALERTE DANGER',
      'safe_level1' => 'NIVEAU 1 · PRÉVENTIVE',
      'safe_level2' => 'NIVEAU 2 · CRITIQUE',
      'safe_confirmed' => 'CONFIRMATION SÉCURITÉ',
      'invitation' => 'INVITATION',
      'tracking_start' => 'TRACKING ACTIVE',
      'tracking_stop' => 'TRACKING ARRÊTÉ',
      'sync_notice' => 'SYNCHRONISATION',
      _ => 'NOTIFICATION',
    };

    return EkCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (wa ? Ek.safe : Ek.accent).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (wa ? Ek.safe : Ek.accent).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      wa
                          ? Icons.chat_outlined
                          : Icons.notifications_active_outlined,
                      size: 11,
                      color: wa ? Ek.safe : Ek.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      wa ? 'WHATSAPP' : 'PUSH',
                      style: Ek.over(size: 8, color: wa ? Ek.safe : Ek.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(kindLabel, style: Ek.over(size: 8.5, color: color)),
              ),
              Text(ekFormatTime(message.at), style: Ek.over(size: 8.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              EkMonogram(
                initials: _initials(message.recipientName),
                size: 28,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.recipientName,
                      style: Ek.body(size: 12.5, color: Ek.textPrimary),
                    ),
                    Text(message.recipientPhone, style: Ek.body(size: 10.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Ek.bg,
              borderRadius: BorderRadius.circular(10),
              border: const Border(
                left: BorderSide(color: Ek.hairline, width: 2),
              ),
            ),
            child: Text(message.body, style: Ek.body(size: 11.5, height: 1.55)),
          ),
          if (wa) ...[
            const SizedBox(height: 8),
            Text(
              'Émis depuis ${Backend.officialWhatsAppNumber}',
              style: Ek.over(size: 8),
            ),
          ],
        ],
      ),
    );
  }

  static String _initials(String n) {
    final p = n
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first[0].toUpperCase();
    return (p.first[0] + p.last[0]).toUpperCase();
  }
}
