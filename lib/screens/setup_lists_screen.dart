import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/ek_state.dart';
import '../widgets/common.dart';
import 'contact_picker_screen.dart';

/// EKENGE PLUS — §4 Creation obligatoire des listes de securite.
///
/// A la premiere connexion, l'utilisateur doit obligatoirement configurer ses
/// reseaux de securite. L'application affiche d'abord une demande
/// d'autorisation d'acces aux contacts du telephone.
class SetupListsScreen extends StatefulWidget {
  const SetupListsScreen({super.key});

  @override
  State<SetupListsScreen> createState() => _SetupListsScreenState();
}

class _SetupListsScreenState extends State<SetupListsScreen> {
  /// 0 = autorisation contacts, 1 = liste Tracking, 2 = liste Urgence
  int _stage = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final st = context.read<EkState>();
    if (st.contactsPermission) {
      _stage = st.trackingList.isEmpty ? 1 : 2;
    }
  }

  Future<void> _askPermission() async {
    setState(() => _busy = true);
    final ok = await context.read<EkState>().requestContactsPermission();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _stage = 1;
    });
  }

  Future<void> _pick(SafetyList list) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ContactPickerScreen(target: list)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const EkHeader(
              title: 'Reseaux de securite',
              subtitle: 'Etape 4 sur 4 · Configuration obligatoire',
              back: false,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_stage == 0)
                      _PermissionStage(busy: _busy, onGrant: _askPermission)
                    else ...[
                      // ---- Liste Tracking (§4.1) ----
                      _ListBlock(
                        index: 1,
                        title: 'Liste Tracking',
                        description:
                            'Les personnes autorisees a suivre votre localisation '
                            'lorsque vous activez le partage de position.',
                        count: st.trackingList.length,
                        contacts: st.trackingList,
                        accent: Ek.accent,
                        onAdd: () => _pick(SafetyList.tracking),
                        onRemove: (c) =>
                            st.removeFromList(c, SafetyList.tracking),
                      ),
                      const SizedBox(height: 18),
                      // ---- Liste Urgence (§4.2) ----
                      if (st.trackingList.isNotEmpty) ...[
                        _ListBlock(
                          index: 2,
                          title: 'Liste Urgence',
                          description:
                              'Tous les contacts Tracking y sont automatiquement '
                              'copies. Vous pouvez ajouter des contacts '
                              'supplementaires qui recevront les alertes critiques.',
                          count: st.urgenceList.length,
                          contacts: st.urgenceList,
                          accent: Ek.danger,
                          onAdd: () => _pick(SafetyList.urgence),
                          onRemove: (c) =>
                              st.removeFromList(c, SafetyList.urgence),
                        ),
                        const SizedBox(height: 22),
                        EkButton(
                          label: 'Terminer la configuration',
                          icon: Icons.verified_outlined,
                          onPressed: st.trackingList.isEmpty
                              ? null
                              : () => st.confirmListsConfigured(),
                        ),
                      ] else
                        EkCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 17,
                                color: Ek.warn,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Selectionnez au moins un contact Tracking pour '
                                  'poursuivre. La liste Urgence sera creee '
                                  'automatiquement.',
                                  style: Ek.body(size: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionStage extends StatelessWidget {
  final bool busy;
  final VoidCallback onGrant;
  const _PermissionStage({required this.busy, required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Ek.surface,
              border: Border.all(color: Ek.hairline),
            ),
            child: const Icon(
              Icons.contacts_outlined,
              size: 32,
              color: Ek.accent,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text('Acces au repertoire', style: Ek.title(size: 19)),
        const SizedBox(height: 10),
        Text(
          'EKENGE PLUS demande l\'autorisation d\'acceder aux contacts de votre '
          'telephone afin de faciliter la selection de vos proches lors de la '
          'creation de vos listes de securite.',
          style: Ek.body(size: 13.5, height: 1.55),
        ),
        const SizedBox(height: 22),
        EkCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _Bullet(
                icon: Icons.lock_outline,
                text: 'Vos contacts ne sont jamais transmis a des tiers.',
              ),
              const Divider(height: 22),
              _Bullet(
                icon: Icons.person_search_outlined,
                text:
                    'Seuls les numeros que vous selectionnez sont enregistres.',
              ),
              const Divider(height: 22),
              _Bullet(
                icon: Icons.settings_outlined,
                text: 'L\'autorisation est revocable a tout moment.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        EkButton(
          label: 'Autoriser l\'acces',
          icon: Icons.check,
          loading: busy,
          onPressed: onGrant,
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Bullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Ek.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: Ek.body(size: 12.5))),
      ],
    );
  }
}

class _ListBlock extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final int count;
  final List<SafetyContact> contacts;
  final Color accent;
  final VoidCallback onAdd;
  final ValueChanged<SafetyContact> onRemove;

  const _ListBlock({
    required this.index,
    required this.title,
    required this.description,
    required this.count,
    required this.contacts,
    required this.accent,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return EkCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: Ek.over(size: 10, color: accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: Ek.title(size: 16))),
              EkPill(label: '$count', color: accent),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: Ek.body(size: 12.5, height: 1.5)),
          const SizedBox(height: 16),
          if (contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Aucun contact selectionne',
                style: Ek.body(size: 12, color: Ek.textTertiary),
              ),
            )
          else
            ...contacts.map(
              (c) => _ContactRow(
                contact: c,
                accent: accent,
                onRemove: () => onRemove(c),
              ),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onAdd,
            icon: Icon(
              Icons.person_add_alt_1_outlined,
              size: 17,
              color: accent,
            ),
            label: Text(
              'Ouvrir le repertoire',
              style: Ek.over(size: 10.5, color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final SafetyContact contact;
  final Color accent;
  final VoidCallback onRemove;

  const _ContactRow({
    required this.contact,
    required this.accent,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          EkMonogram(
            initials: contact.initials,
            size: 36,
            color: accent,
            linked: contact.sync == ContactSync.linked,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: Ek.body(size: 13.5, color: Ek.textPrimary),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(contact.phone, style: Ek.body(size: 11.5)),
                    const SizedBox(width: 8),
                    Icon(
                      contact.sync == ContactSync.linked
                          ? Icons.link
                          : Icons.schedule_send_outlined,
                      size: 11,
                      color: contact.sync == ContactSync.linked
                          ? Ek.safe
                          : Ek.warn,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      contact.sync == ContactSync.linked
                          ? 'Synchronise'
                          : 'Invitation envoyee',
                      style: Ek.over(
                        size: 8.5,
                        color: contact.sync == ContactSync.linked
                            ? Ek.safe
                            : Ek.warn,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 18,
              color: Ek.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
