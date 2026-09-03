import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/backend.dart';
import '../services/ek_state.dart';
import '../services/haptics.dart';
import '../widgets/common.dart';

/// EKENGE PLUS — §4 Ouverture du repertoire telephonique et selection des
/// contacts. §5 Le statut de synchronisation (compte EKENGE PLUS existant ou
/// invitation WhatsApp a envoyer) est indique pour chaque numero.
class ContactPickerScreen extends StatefulWidget {
  final SafetyList target;
  const ContactPickerScreen({super.key, required this.target});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  List<PhoneBookEntry> _all = [];

  /// Contacts saisis a la main, utilises lorsque le repertoire est
  /// inaccessible ou vide. Aucune donnee n'est inventee par l'application.
  final List<PhoneBookEntry> _manual = [];

  final Set<String> _selected = {};
  String _query = '';
  bool _loading = true;
  bool _saving = false;

  /// Etat reel de l'autorisation systeme au moment de la lecture.
  bool _permission = false;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = context.read<EkState>();
    final granted = st.contactsPermission;
    final entries = granted
        ? await st.readPhoneBook()
        : const <PhoneBookEntry>[];
    final permanent = granted ? false : await st.contactsPermanentlyDenied();
    if (!mounted) return;
    setState(() {
      _all = entries;
      _permission = granted;
      _permanentlyDenied = permanent;
      _loading = false;
    });
  }

  /// Nouvelle tentative de demande d'autorisation depuis cet ecran.
  Future<void> _requestPermission() async {
    Haptics.tap();
    setState(() => _loading = true);
    final st = context.read<EkState>();
    final ok = await st.requestContactsPermission();
    if (!mounted) return;
    if (ok) {
      await _load();
      Haptics.confirm();
    } else {
      final permanent = await st.contactsPermanentlyDenied();
      if (!mounted) return;
      setState(() {
        _permission = false;
        _permanentlyDenied = permanent;
        _loading = false;
      });
      Haptics.medium();
    }
  }

  Future<void> _addManual() async {
    Haptics.tap();
    final entry = await showModalBottomSheet<PhoneBookEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ManualEntrySheet(),
    );
    if (entry == null || !mounted) return;
    final phone = Backend.normalizePhone(entry.phone);
    if (_all.any((e) => e.phone == phone) ||
        _manual.any((e) => e.phone == phone)) {
      setState(() => _selected.add(phone));
      return;
    }
    final linked = await context.read<EkState>().isEkengeNumber(phone);
    if (!mounted) return;
    setState(() {
      _manual.insert(
        0,
        PhoneBookEntry(
          name: entry.name,
          phone: phone,
          hasEkengeAccount: linked,
        ),
      );
      _selected.add(phone);
    });
  }

  Future<void> _save() async {
    Haptics.tap();
    setState(() => _saving = true);
    final st = context.read<EkState>();
    final pool = [..._manual, ..._all];
    for (final e in pool.where((e) => _selected.contains(e.phone))) {
      await st.addContact(e, list: widget.target);
    }
    if (!mounted) return;
    Haptics.confirm();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final existing = st.contacts
        .where(
          (c) =>
              widget.target == SafetyList.tracking ? c.inTracking : c.inUrgence,
        )
        .map((c) => c.phone)
        .toSet();

    final filtered = [..._manual, ..._all]
        .where(
          (e) =>
              e.name.toLowerCase().contains(_query.toLowerCase()) ||
              e.phone.contains(_query),
        )
        .toList();

    final accent = widget.target == SafetyList.tracking ? Ek.accent : Ek.danger;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EkHeader(
              title: 'Repertoire telephonique',
              subtitle: _permission
                  ? 'Liste ${safetyListLabel(widget.target)} · '
                        '${_all.length} contact(s)'
                  : 'Liste ${safetyListLabel(widget.target)}',
              actions: [
                if (_selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: EkPill(
                      label: '${_selected.length} choisis',
                      color: accent,
                    ),
                  ),
              ],
            ),
            if (filtered.isNotEmpty || _query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: Ek.body(size: 14, color: Ek.textPrimary),
                  cursorColor: Ek.accent,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un contact',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 19,
                      color: Ek.textTertiary,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Ek.accent),
                        ),
                      ),
                    )
                  : filtered.isEmpty
                  ? _EmptyDirectory(
                      permission: _permission,
                      permanentlyDenied: _permanentlyDenied,
                      searching: _query.isNotEmpty,
                      onRequest: _requestPermission,
                      onOpenSettings: () =>
                          context.read<EkState>().openSystemSettings(),
                      onManual: _addManual,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        final already = existing.contains(e.phone);
                        final sel = _selected.contains(e.phone);
                        return InkWell(
                          onTap: already
                              ? null
                              : () => setState(() {
                                  if (sel) {
                                    _selected.remove(e.phone);
                                  } else {
                                    _selected.add(e.phone);
                                  }
                                }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                EkMonogram(
                                  initials: e.initials,
                                  size: 40,
                                  color: e.hasEkengeAccount
                                      ? Ek.accent
                                      : Ek.textTertiary,
                                  linked: e.hasEkengeAccount,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.name,
                                        style: Ek.body(
                                          size: 14,
                                          color: already
                                              ? Ek.textTertiary
                                              : Ek.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            e.phone,
                                            style: Ek.body(size: 11.5),
                                          ),
                                          const SizedBox(width: 8),
                                          if (e.hasEkengeAccount)
                                            EkPill(
                                              label: 'Compte EKENGE',
                                              color: Ek.safe,
                                              icon: Icons.link,
                                            )
                                          else
                                            EkPill(
                                              label: 'Invitation WhatsApp',
                                              color: Ek.warn,
                                              icon: Icons.send_outlined,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (already)
                                  const Icon(
                                    Icons.check_circle,
                                    size: 20,
                                    color: Ek.textTertiary,
                                  )
                                else
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: sel ? accent : Colors.transparent,
                                      border: Border.all(
                                        color: sel ? accent : Ek.hairline,
                                        width: 1.3,
                                      ),
                                    ),
                                    child: sel
                                        ? const Icon(
                                            Icons.check,
                                            size: 13,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // La barre d'action n'a de sens que si le repertoire propose des
            // contacts : sur un etat vide elle afficherait un bouton inerte.
            if (filtered.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                decoration: const BoxDecoration(
                  color: Ek.bgElevated,
                  border: Border(top: BorderSide(color: Ek.hairline)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addManual,
                          icon: const Icon(
                            Icons.dialpad_outlined,
                            size: 16,
                            color: Ek.textSecondary,
                          ),
                          label: Text(
                            'Saisir un numero manuellement',
                            style: Ek.over(size: 10, color: Ek.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    if (widget.target == SafetyList.tracking)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.content_copy_outlined,
                              size: 14,
                              color: Ek.textTertiary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Les contacts Tracking sont automatiquement '
                                'copies dans la liste Urgence.',
                                style: Ek.body(size: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    EkButton(
                      label:
                          'Ajouter a la liste ${safetyListLabel(widget.target)}',
                      icon: Icons.playlist_add_check,
                      color: accent,
                      textColor: widget.target == SafetyList.tracking
                          ? Colors.white
                          : Colors.white,
                      loading: _saving,
                      onPressed: _selected.isEmpty ? null : _save,
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

/// Etat affiche lorsque le repertoire reel ne fournit aucun contact :
/// autorisation refusee, refusee definitivement, ou carnet d'adresses vide.
/// Aucun contact fictif n'est genere.
class _EmptyDirectory extends StatelessWidget {
  final bool permission;
  final bool permanentlyDenied;
  final bool searching;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;
  final VoidCallback onManual;

  const _EmptyDirectory({
    required this.permission,
    required this.permanentlyDenied,
    required this.searching,
    required this.onRequest,
    required this.onOpenSettings,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String title;
    final String body;

    if (searching) {
      icon = Icons.search_off_outlined;
      title = 'Aucun resultat';
      body =
          'Aucun contact de votre repertoire ne correspond a cette '
          'recherche.';
    } else if (!permission) {
      icon = Icons.no_accounts_outlined;
      title = 'Repertoire non autorise';
      body = permanentlyDenied
          ? 'Le systeme ne peut plus afficher la demande d\'autorisation. '
                'Ouvrez les reglages de l\'application et activez la '
                'permission Contacts pour acceder a votre repertoire reel.'
          : 'EKENGE PLUS a besoin de l\'autorisation systeme pour ouvrir le '
                'repertoire de votre telephone.';
    } else {
      icon = Icons.contacts_outlined;
      title = 'Repertoire vide';
      body =
          'L\'autorisation est accordee mais aucun contact avec numero de '
          'telephone n\'a ete trouve sur cet appareil. Saisissez le numero '
          'de vos proches manuellement.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Ek.surface,
              border: Border.all(color: Ek.hairline),
            ),
            child: Icon(icon, size: 30, color: Ek.textSecondary),
          ),
          const SizedBox(height: 22),
          Text(title, style: Ek.title(size: 17)),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Ek.body(size: 13, height: 1.55),
          ),
          const SizedBox(height: 26),
          if (!permission && !searching)
            permanentlyDenied
                ? EkButton(
                    label: 'Ouvrir les reglages',
                    icon: Icons.settings_outlined,
                    onPressed: onOpenSettings,
                  )
                : EkButton(
                    label: 'Autoriser l\'acces aux contacts',
                    icon: Icons.check,
                    onPressed: onRequest,
                  ),
          if (!searching) ...[
            const SizedBox(height: 10),
            EkButton(
              label: 'Saisir un numero manuellement',
              icon: Icons.dialpad_outlined,
              outlined: true,
              textColor: Ek.textPrimary,
              onPressed: onManual,
            ),
          ],
        ],
      ),
    );
  }
}

/// Saisie manuelle d'un proche lorsque le repertoire est indisponible.
class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet();

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (name.isEmpty) {
      setState(() => _err = 'Indiquez le nom du contact.');
      return;
    }
    if (digits.length < 8) {
      setState(() => _err = 'Numero de telephone invalide.');
      return;
    }
    Navigator.of(
      context,
    ).pop(PhoneBookEntry(name: name, phone: phone, hasEkengeAccount: false));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Ek.bgElevated,
          border: Border(top: BorderSide(color: Ek.hairline)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(Ek.r20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Ek.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Ajouter un proche', style: Ek.title(size: 17)),
            const SizedBox(height: 8),
            Text(
              'Le numero doit etre au format international, indicatif pays '
              'inclus.',
              style: Ek.body(size: 12.5, height: 1.5),
            ),
            const SizedBox(height: 20),
            EkField(
              label: 'Nom complet',
              controller: _name,
              icon: Icons.person_outline,
              caps: TextCapitalization.words,
              autofocus: true,
              onChanged: (_) => setState(() => _err = null),
            ),
            const SizedBox(height: 14),
            EkField(
              label: 'Numero de telephone',
              controller: _phone,
              hint: '+243 000 000 000',
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
              error: _err,
              onChanged: (_) => setState(() => _err = null),
            ),
            const SizedBox(height: 20),
            EkButton(
              label: 'Ajouter',
              icon: Icons.person_add_alt_1_outlined,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
