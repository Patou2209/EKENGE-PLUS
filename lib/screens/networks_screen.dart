import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/backend.dart';
import '../services/ek_state.dart';
import '../widgets/common.dart';
import 'contact_picker_screen.dart';

/// EKENGE PLUS — §4 Gestion des listes Tracking et Urgence,
/// §5 Etat de synchronisation et invitations WhatsApp.
class NetworksScreen extends StatefulWidget {
  const NetworksScreen({super.key});

  @override
  State<NetworksScreen> createState() => _NetworksScreenState();
}

class _NetworksScreenState extends State<NetworksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

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
        bottom: false,
        child: Column(
          children: [
            EkHeader(
              title: 'Reseaux de securite',
              subtitle: 'Listes Tracking et Urgence',
              back: false,
              actions: [
                IconButton(
                  onPressed: () => _add(
                    context,
                    _tabs.index == 0 ? SafetyList.tracking : SafetyList.urgence,
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                  color: Ek.accent,
                ),
              ],
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
                onTap: (_) => setState(() {}),
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
                tabs: [
                  Tab(
                    height: 46,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.share_location_outlined, size: 15),
                        const SizedBox(width: 8),
                        Text('TRACKING · ${st.trackingList.length}'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 46,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emergency_outlined, size: 15),
                        const SizedBox(width: 8),
                        Text('URGENCE · ${st.urgenceList.length}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ListView(
                    list: SafetyList.tracking,
                    contacts: st.trackingList,
                    accent: Ek.accent,
                    note:
                        'Ces contacts peuvent consulter votre localisation en '
                        'temps reel lorsque vous activez le Tracking.',
                  ),
                  _ListView(
                    list: SafetyList.urgence,
                    contacts: st.urgenceList,
                    accent: Ek.danger,
                    note:
                        'Ces contacts recoivent les alertes critiques et les '
                        'messages de detresse. Tous les contacts Tracking y '
                        'figurent automatiquement.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _add(BuildContext context, SafetyList l) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => ContactPickerScreen(target: l)));
}

class _ListView extends StatelessWidget {
  final SafetyList list;
  final List<SafetyContact> contacts;
  final Color accent;
  final String note;

  const _ListView({
    required this.list,
    required this.contacts,
    required this.accent,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final st = context.read<EkState>();

    if (contacts.isEmpty) {
      return EkEmpty(
        icon: Icons.group_outlined,
        title: 'Liste ${safetyListLabel(list)} vide',
        message: note,
        action: EkButton(
          label: 'Ouvrir le repertoire',
          icon: Icons.contacts_outlined,
          color: accent,
          textColor: list == SafetyList.tracking
              ? Colors.white
              : Colors.white,
          onPressed: () => _NetworksScreenState._add(context, list),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        EkCard(
          padding: const EdgeInsets.all(14),
          color: accent.withValues(alpha: 0.05),
          border: accent.withValues(alpha: 0.25),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(note, style: Ek.body(size: 12, height: 1.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        EkSectionLabel('${contacts.length} contact(s)'),
        ...contacts.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ContactCard(
              contact: c,
              accent: accent,
              onRemove: () => _confirmRemove(context, st, c),
              onInvite: c.sync == ContactSync.invited
                  ? () async {
                      await st.resendInvitation(c);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Invitation WhatsApp renvoyee a ${c.name}.',
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        EkButton(
          label: 'Ajouter des contacts',
          icon: Icons.person_add_alt_1_outlined,
          outlined: true,
          color: accent,
          onPressed: () => _NetworksScreenState._add(context, list),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    EkState st,
    SafetyContact c,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer ${c.name}', style: Ek.title(size: 16)),
        content: Text(
          list == SafetyList.tracking
              ? 'Ce contact ne pourra plus suivre votre localisation. Il restera '
                    'dans votre liste Urgence.'
              : 'Ce contact ne recevra plus vos alertes de detresse et sera '
                    'retire des deux listes.',
          style: Ek.body(size: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler', style: Ek.body(size: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Retirer',
              style: Ek.body(size: 13, color: Ek.dangerBright),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await st.removeFromList(c, list);
  }
}

class _ContactCard extends StatelessWidget {
  final SafetyContact contact;
  final Color accent;
  final VoidCallback onRemove;
  final VoidCallback? onInvite;

  const _ContactCard({
    required this.contact,
    required this.accent,
    required this.onRemove,
    this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final linked = contact.sync == ContactSync.linked;
    return EkCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          EkMonogram(
            initials: contact.initials,
            size: 44,
            color: accent,
            linked: linked,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: Ek.body(size: 14.5, color: Ek.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(contact.phone, style: Ek.body(size: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (contact.inTracking)
                      EkPill(
                        label: 'Tracking',
                        color: Ek.accent,
                        icon: Icons.share_location_outlined,
                      ),
                    if (contact.inTracking) const SizedBox(width: 6),
                    if (contact.inUrgence)
                      EkPill(
                        label: 'Urgence',
                        color: Ek.danger,
                        icon: Icons.emergency_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      linked ? Icons.link : Icons.schedule_send_outlined,
                      size: 12,
                      color: linked ? Ek.safe : Ek.warn,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        linked
                            ? 'Compte EKENGE PLUS synchronise'
                            : 'Invitation WhatsApp envoyee · en attente',
                        style: Ek.body(
                          size: 11,
                          color: linked ? Ek.safe : Ek.warn,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (onInvite != null)
                IconButton(
                  onPressed: onInvite,
                  tooltip: 'Renvoyer l\'invitation WhatsApp',
                  icon: const Icon(
                    Icons.send_outlined,
                    size: 17,
                    color: Ek.warn,
                  ),
                ),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Retirer',
                icon: const Icon(
                  Icons.remove_circle_outline,
                  size: 18,
                  color: Ek.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'information sur le numero officiel WhatsApp (§14).
class WhatsAppNotice extends StatelessWidget {
  const WhatsAppNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return EkCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, size: 17, color: Ek.safe),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les messages WhatsApp sont emis depuis le numero officiel '
              'certifie EKENGE PLUS (${Backend.officialWhatsAppNumber}).',
              style: Ek.body(size: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
