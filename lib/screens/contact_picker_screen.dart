import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/ek_state.dart';
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
  final Set<String> _selected = {};
  String _query = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await context.read<EkState>().readPhoneBook();
    if (!mounted) return;
    setState(() {
      _all = entries;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final st = context.read<EkState>();
    for (final e in _all.where((e) => _selected.contains(e.phone))) {
      await st.addContact(e, list: widget.target);
    }
    if (!mounted) return;
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

    final filtered = _all
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
              subtitle: 'Liste ${safetyListLabel(widget.target)}',
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
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: const BoxDecoration(
                color: Ek.bgElevated,
                border: Border(top: BorderSide(color: Ek.hairline)),
              ),
              child: Column(
                children: [
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
                              'Les contacts Tracking sont automatiquement copies '
                              'dans la liste Urgence.',
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
                        ? const Color(0xFF04120F)
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
