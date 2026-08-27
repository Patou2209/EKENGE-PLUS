import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/backend.dart';
import '../services/contacts_service.dart';
import '../services/haptics.dart';
import '../services/location_service.dart';
import '../widgets/common.dart';
import '../widgets/ek_map.dart';
import 'auth_screens.dart';

/// EKENGE PLUS — §11 Fonction Tracking SANS creation de compte (visiteur).
///
/// Parcours exige par le cahier des charges :
/// 1. Avertissement : en partageant sa localisation en tant que visiteur,
///    l'utilisateur n'aura PAS acces aux alertes (Danger / Safe).
///    « Voulez-vous continuer ? Soit connectez-vous. »
/// 2. S'il accepte : saisie du nom sous lequel ses contacts le connaissent.
/// 3. Ouverture du repertoire reel du telephone et selection des contacts
///    avec qui il souhaite partager sa localisation.
/// 4. Envoi via WhatsApp, a chacun des contacts selectionnes, du lien de
///    suivi et de son nom complet, suivi du message :
///    « Vous avez ete choisi par X pour suivre sa localisation en temps
///    reel sur EKENGE PLUS. »
class GuestTrackingScreen extends StatefulWidget {
  const GuestTrackingScreen({super.key});

  @override
  State<GuestTrackingScreen> createState() => _GuestTrackingScreenState();
}

enum _GuestStep { warning, name, contacts, share, live }

class _GuestTrackingScreenState extends State<GuestTrackingScreen> {
  _GuestStep _step = _GuestStep.warning;

  // --- Etape 2 : nom du visiteur -----------------------------------------
  final TextEditingController _nameCtrl = TextEditingController();
  String get _guestName => _nameCtrl.text.trim();

  // --- Etape 3 : repertoire reel ------------------------------------------
  List<PhoneBookEntry> _all = [];
  final List<PhoneBookEntry> _manual = [];
  final Set<String> _selected = {};
  String _query = '';
  bool _loadingContacts = false;
  bool _permission = false;
  bool _permanentlyDenied = false;

  // --- Etape 4 : envoi WhatsApp -------------------------------------------
  final Set<String> _sent = {};

  // --- Etape 5 : suivi en direct -------------------------------------------
  late final String _trackingToken;
  StreamSubscription<GeoPoint>? _sub;
  GeoPoint? _position;
  final List<GeoPoint> _trail = [];
  DateTime? _startedAt;

  String get _trackingLink => 'https://ekengeplus.app/suivi/$_trackingToken';

  @override
  void initState() {
    super.initState();
    final rnd = Random.secure();
    _trackingToken = List.generate(
      10,
      (_) => 'abcdefghjkmnpqrstuvwxyz23456789'[rnd.nextInt(31)],
    ).join();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ==========================================================================
  // Etape 3 : ouverture du repertoire reel (permission systeme + lecture)
  // ==========================================================================
  Future<void> _openDirectory() async {
    Haptics.tap();
    setState(() => _loadingContacts = true);
    final svc = ContactsService.instance;
    var granted = await svc.hasPermission();
    if (!granted) granted = await svc.requestPermission();
    final entries = granted
        ? await svc.readDeviceContacts()
        : const <PhoneBookEntry>[];
    final permanent = granted ? false : await svc.isPermanentlyDenied();
    if (!mounted) return;
    setState(() {
      _permission = granted;
      _permanentlyDenied = permanent;
      _all = entries;
      _loadingContacts = false;
    });
    if (granted) Haptics.confirm();
  }

  Future<void> _addManual() async {
    Haptics.tap();
    final res = await showModalBottomSheet<PhoneBookEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GuestManualSheet(),
    );
    if (res == null || !mounted) return;
    final phone = Backend.normalizePhone(res.phone);
    if (_all.any((e) => e.phone == phone) ||
        _manual.any((e) => e.phone == phone)) {
      setState(() => _selected.add(phone));
      return;
    }
    setState(() {
      _manual.insert(
        0,
        PhoneBookEntry(name: res.name, phone: phone, hasEkengeAccount: false),
      );
      _selected.add(phone);
    });
  }

  // ==========================================================================
  // Etape 4 : message WhatsApp exige par le §11 du cahier des charges
  // ==========================================================================
  String _whatsappBody() =>
      'Vous avez ete choisi par $_guestName pour suivre sa localisation '
      'en temps reel sur EKENGE PLUS.\n\n'
      'Lien de suivi : $_trackingLink';

  /// Ouvre reellement WhatsApp (wa.me) avec le message pre-rempli pour ce
  /// contact. Sur telephone, l'application WhatsApp s'ouvre directement.
  Future<void> _sendWhatsApp(PhoneBookEntry c) async {
    Haptics.tap();
    final digits = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(_whatsappBody())}',
    );
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _sent.add(c.phone));
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'WhatsApp indisponible sur cet appareil — message prepare '
            'pour ${c.name}.',
            style: Ek.body(size: 13),
          ),
        ),
      );
    }
  }

  // ==========================================================================
  // Etape 5 : demarrage du partage en direct
  // ==========================================================================
  Future<void> _startLive() async {
    Haptics.confirm();
    final loc = LocationService.instance;
    await loc.requestPermission();
    loc.start();
    _sub = loc.stream.listen((p) {
      if (!mounted) return;
      setState(() {
        _position = p;
        _trail.add(p);
        if (_trail.length > 240) _trail.removeAt(0);
      });
    });
    setState(() {
      _startedAt = DateTime.now();
      _step = _GuestStep.live;
    });
  }

  void _stopLive() {
    Haptics.medium();
    _sub?.cancel();
    LocationService.instance.stop();
    Navigator.of(context).pop();
  }

  // ==========================================================================
  // UI
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          _GuestStep.warning => _buildWarning(),
          _GuestStep.name => _buildName(),
          _GuestStep.contacts => _buildContacts(),
          _GuestStep.share => _buildShare(),
          _GuestStep.live => _buildLive(),
        },
      ),
    );
  }

  Widget _header(String title, String sub, {VoidCallback? onBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack ?? () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Ek.textSecondary),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Ek.title(size: 17)),
                const SizedBox(height: 2),
                Text(sub, style: Ek.body(size: 12, color: Ek.textTertiary)),
              ],
            ),
          ),
          const EkMark(size: 30),
        ],
      ),
    );
  }

  // --- Etape 1 : avertissement §11 -----------------------------------------
  Widget _buildWarning() {
    return Column(
      children: [
        _header('Mode visiteur', 'Tracking sans creation de compte'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Ek.warn.withValues(alpha: 0.12),
                    border: Border.all(color: Ek.warn.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(
                    Icons.warning_amber,
                    color: Ek.warn,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 26),
                Text('Avertissement', style: Ek.title(size: 20)),
                const SizedBox(height: 14),
                Text(
                  'En partageant votre localisation en tant que visiteur, '
                  'vous n\'aurez pas acces aux alertes.',
                  textAlign: TextAlign.center,
                  style: Ek.body(size: 14.5, color: Ek.textSecondary),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Ek.surface,
                    borderRadius: BorderRadius.circular(Ek.r16),
                    border: Border.all(color: Ek.hairline),
                  ),
                  child: Column(
                    children: [
                      _lockedRow(
                        Icons.crisis_alert_outlined,
                        'Bouton Danger',
                        'Signalement d\'une situation critique',
                      ),
                      const SizedBox(height: 10),
                      _lockedRow(
                        Icons.verified_user_outlined,
                        'Fonction Safe',
                        'Verification periodique de votre securite',
                      ),
                      const SizedBox(height: 10),
                      _lockedRow(
                        Icons.notifications_active_outlined,
                        'Alertes automatiques',
                        'Escalade Niveau 1 / 2',
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                Text(
                  'Voulez-vous continuer ?',
                  style: Ek.body(size: 14, color: Ek.textPrimary),
                ),
                const SizedBox(height: 14),
                EkButton(
                  label: 'Continuer en visiteur',
                  icon: Icons.arrow_forward,
                  onPressed: () {
                    Haptics.tap();
                    setState(() => _step = _GuestStep.name);
                  },
                ),
                const SizedBox(height: 12),
                EkButton(
                  label: 'Me connecter',
                  icon: Icons.login,
                  outlined: true,
                  color: Ek.accent,
                  onPressed: () {
                    Haptics.tap();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _lockedRow(IconData icon, String title, String sub) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Ek.textTertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Ek.body(size: 13, color: Ek.textSecondary)),
              Text(sub, style: Ek.body(size: 11, color: Ek.textTertiary)),
            ],
          ),
        ),
        const Icon(Icons.lock_outline, size: 16, color: Ek.textTertiary),
      ],
    );
  }

  // --- Etape 2 : nom connu par les contacts --------------------------------
  Widget _buildName() {
    return Column(
      children: [
        _header(
          'Votre nom',
          'Etape 1 sur 3 · Identification',
          onBack: () => setState(() => _step = _GuestStep.warning),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 26),
                Text(
                  'Sous quel nom vos contacts\nvous connaissent-ils ?',
                  style: Ek.title(size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ce nom apparaitra dans le message WhatsApp envoye a vos '
                  'contacts, accompagne du lien de suivi.',
                  style: Ek.body(size: 13, color: Ek.textSecondary),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: Ek.body(size: 16, color: Ek.textPrimary),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Ex. : Jean K. Mbala',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: Ek.textTertiary,
                    ),
                  ),
                ),
                const Spacer(),
                EkButton(
                  label: 'Continuer',
                  icon: Icons.arrow_forward,
                  onPressed: _guestName.length >= 2
                      ? () {
                          Haptics.tap();
                          setState(() => _step = _GuestStep.contacts);
                          _openDirectory();
                        }
                      : null,
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Etape 3 : repertoire + selection -------------------------------------
  Widget _buildContacts() {
    final pool = [..._manual, ..._all]
        .where(
          (e) =>
              e.name.toLowerCase().contains(_query.toLowerCase()) ||
              e.phone.contains(_query),
        )
        .toList();

    return Column(
      children: [
        _header(
          'Choisir vos contacts',
          'Etape 2 sur 3 · Repertoire du telephone',
          onBack: () => setState(() => _step = _GuestStep.name),
        ),
        if (_loadingContacts)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Ek.accent),
              ),
            ),
          )
        else if (!_permission)
          Expanded(child: _buildNoPermission())
        else
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: Ek.body(size: 14, color: Ek.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un contact…',
                      prefixIcon: Icon(Icons.search, color: Ek.textTertiary),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      EkSectionLabel(
                        '${pool.length} contact(s) · '
                        '${_selected.length} selectionne(s)',
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addManual,
                        icon: const Icon(Icons.add, size: 16, color: Ek.accent),
                        label: Text(
                          'Saisie manuelle',
                          style: Ek.body(size: 12, color: Ek.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: pool.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun contact trouve',
                            style: Ek.body(color: Ek.textTertiary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                          itemCount: pool.length,
                          itemBuilder: (_, i) {
                            final e = pool[i];
                            final on = _selected.contains(e.phone);
                            return _contactTile(e, on);
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
                  child: EkButton(
                    label: _selected.isEmpty
                        ? 'Selectionnez au moins un contact'
                        : 'Continuer (${_selected.length})',
                    icon: Icons.arrow_forward,
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            Haptics.tap();
                            setState(() => _step = _GuestStep.share);
                          },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNoPermission() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(),
          const Icon(Icons.contacts_outlined, size: 52, color: Ek.textTertiary),
          const SizedBox(height: 18),
          Text('Acces au repertoire requis', style: Ek.title(size: 17)),
          const SizedBox(height: 10),
          Text(
            _permanentlyDenied
                ? 'L\'autorisation a ete refusee definitivement. Activez '
                      '« Contacts » dans les reglages systeme de l\'appareil.'
                : 'EKENGE PLUS a besoin d\'ouvrir votre repertoire pour '
                      'selectionner les contacts avec qui partager votre '
                      'localisation.',
            textAlign: TextAlign.center,
            style: Ek.body(size: 13, color: Ek.textSecondary),
          ),
          const SizedBox(height: 22),
          EkButton(
            label: _permanentlyDenied
                ? 'Ouvrir les reglages'
                : 'Autoriser l\'acces au repertoire',
            icon: _permanentlyDenied ? Icons.settings : Icons.contacts,
            onPressed: _permanentlyDenied
                ? () => ContactsService.instance.openSettings()
                : _openDirectory,
          ),
          const SizedBox(height: 12),
          EkButton(
            label: 'Saisir un contact manuellement',
            outlined: true,
            color: Ek.textSecondary,
            onPressed: () async {
              await _addManual();
              if (mounted && _manual.isNotEmpty) {
                setState(() => _permission = true);
              }
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _contactTile(PhoneBookEntry e, bool on) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(Ek.r16),
        onTap: () {
          Haptics.tap();
          setState(
            () => on ? _selected.remove(e.phone) : _selected.add(e.phone),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: on ? Ek.accent.withValues(alpha: 0.08) : Ek.surface,
            borderRadius: BorderRadius.circular(Ek.r16),
            border: Border.all(color: on ? Ek.accentDim : Ek.hairlineSoft),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: on ? Ek.accentDim : Ek.surfaceHigh,
                child: Text(
                  e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                  style: Ek.body(size: 14, color: Ek.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: Ek.body(size: 14, color: Ek.textPrimary),
                    ),
                    Text(
                      e.phone,
                      style: Ek.body(size: 12, color: Ek.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(
                on ? Icons.check_circle : Icons.circle_outlined,
                size: 22,
                color: on ? Ek.accent : Ek.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Etape 4 : envoi WhatsApp ---------------------------------------------
  Widget _buildShare() {
    final chosen = [
      ..._manual,
      ..._all,
    ].where((e) => _selected.contains(e.phone)).toList();
    final allSent = chosen.every((c) => _sent.contains(c.phone));

    return Column(
      children: [
        _header(
          'Envoi WhatsApp',
          'Etape 3 sur 3 · Lien de suivi',
          onBack: () => setState(() => _step = _GuestStep.contacts),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Ek.surface,
                  borderRadius: BorderRadius.circular(Ek.r16),
                  border: Border.all(color: Ek.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link, size: 16, color: Ek.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Message qui sera envoye',
                          style: Ek.over(size: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _whatsappBody(),
                      style: Ek.body(size: 13, color: Ek.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              EkSectionLabel('${chosen.length} destinataire(s)'),
              const SizedBox(height: 8),
              ...chosen.map((c) {
                final sent = _sent.contains(c.phone);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Ek.surface,
                      borderRadius: BorderRadius.circular(Ek.r16),
                      border: Border.all(
                        color: sent ? Ek.safe : Ek.hairlineSoft,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Ek.body(size: 14, color: Ek.textPrimary),
                              ),
                              Text(
                                c.phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Ek.body(
                                  size: 12,
                                  color: Ek.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Bouton compact a largeur FIXE : EkButton occupe
                        // toute la largeur disponible et ecrasait la colonne
                        // du nom dans la Row (affichage vertical du texte).
                        _SendChip(sent: sent, onTap: () => _sendWhatsApp(c)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            children: [
              if (!allSent) ...[
                EkButton(
                  label: _sent.isEmpty
                      ? 'Envoyer a tous via WhatsApp'
                      : 'Envoyer au suivant '
                            '(${_sent.length}/${chosen.length})',
                  icon: Icons.send,
                  onPressed: () => _sendNext(chosen),
                ),
                const SizedBox(height: 10),
              ],
              EkButton(
                label: 'Demarrer le partage en direct',
                icon: Icons.share_location,
                outlined: !allSent,
                color: allSent ? Ek.accent : Ek.textSecondary,
                // Le partage peut demarrer meme si tous les envois ne sont
                // pas encore faits : l'utilisateur reste maitre du flux.
                onPressed: _startLive,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Envoie le message WhatsApp au prochain contact non encore servi.
  /// WhatsApp ne permet qu'une conversation a la fois : on enchaîne donc
  /// contact par contact a chaque pression.
  Future<void> _sendNext(List<PhoneBookEntry> chosen) async {
    final next = chosen.where((c) => !_sent.contains(c.phone)).toList();
    if (next.isEmpty) return;
    await _sendWhatsApp(next.first);
  }

  // --- Etape 5 : partage en direct -------------------------------------------
  Widget _buildLive() {
    final markers = _position == null
        ? const <MapMarker>[]
        : [
            MapMarker(
              point: _position!,
              initials: _guestName.isNotEmpty
                  ? _guestName[0].toUpperCase()
                  : 'V',
              label: _guestName,
              color: Ek.accent,
              self: true,
              pulsing: true,
            ),
          ];

    return Column(
      children: [
        _header(
          'Partage en direct',
          'Mode visiteur · ${_selected.length} contact(s) informes',
          onBack: _stopLive,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Ek.r20),
                child: EkMap(
                  markers: markers,
                  trail: _trail,
                  focus: _position,
                  height: 320,
                ),
              ),
              const SizedBox(height: 12),
              EkMapReadout(point: _position, live: true),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Ek.surface,
                  borderRadius: BorderRadius.circular(Ek.r16),
                  border: Border.all(color: Ek.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Ek.safe,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Partage actif', style: Ek.over(size: 11)),
                        const Spacer(),
                        if (_startedAt != null)
                          Text(
                            'Depuis '
                            '${_startedAt!.hour.toString().padLeft(2, '0')}:'
                            '${_startedAt!.minute.toString().padLeft(2, '0')}',
                            style: Ek.body(size: 12, color: Ek.textTertiary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Lien de suivi : $_trackingLink',
                      style: Ek.body(size: 12, color: Ek.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Ek.warn.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(Ek.r16),
                  border: Border.all(color: Ek.warn.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 18, color: Ek.warn),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mode visiteur : les fonctions Danger, Safe et les '
                        'alertes automatiques ne sont pas disponibles. '
                        'Creez un compte pour une protection complete.',
                        style: Ek.body(size: 12, color: Ek.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              EkButton(
                label: 'Creer un compte pour etre protege',
                icon: Icons.person_add_alt,
                outlined: true,
                color: Ek.accent,
                onPressed: () {
                  Haptics.tap();
                  _sub?.cancel();
                  LocationService.instance.stop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PhoneStepScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: EkButton(
            label: 'Arreter le partage',
            icon: Icons.stop_circle_outlined,
            color: Ek.danger,
            textColor: Colors.white,
            onPressed: _stopLive,
          ),
        ),
      ],
    );
  }
}

/// Bouton compact a LARGEUR FIXE pour l'envoi WhatsApp d'une ligne contact.
/// (EkButton s'etend sur toute la largeur : inutilisable dans une Row.)
class _SendChip extends StatelessWidget {
  final bool sent;
  final VoidCallback onTap;
  const _SendChip({required this.sent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (sent) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Ek.safe),
          const SizedBox(width: 6),
          Text('Envoye', style: Ek.body(size: 12, color: Ek.safe)),
        ],
      );
    }
    return Material(
      color: Ek.accent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.send, size: 14, color: Color(0xFF04120F)),
              const SizedBox(width: 6),
              Text(
                'WHATSAPP',
                style: Ek.over(size: 10.5, color: const Color(0xFF04120F)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saisie manuelle d'un contact (secours lorsque le repertoire est
/// inaccessible — notamment en preview web).
class _GuestManualSheet extends StatefulWidget {
  const _GuestManualSheet();

  @override
  State<_GuestManualSheet> createState() => _GuestManualSheetState();
}

class _GuestManualSheetState extends State<_GuestManualSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().length >= 2 &&
      _phone.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 6;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
        decoration: const BoxDecoration(
          color: Ek.bgElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Ek.r28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Ek.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Ajouter un contact', style: Ek.title(size: 17)),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: Ek.body(size: 15, color: Ek.textPrimary),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Nom du contact',
                prefixIcon: Icon(Icons.person_outline, color: Ek.textTertiary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: Ek.body(size: 15, color: Ek.textPrimary),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Numero de telephone (+243…)',
                prefixIcon: Icon(Icons.phone_outlined, color: Ek.textTertiary),
              ),
            ),
            const SizedBox(height: 18),
            EkButton(
              label: 'Ajouter',
              icon: Icons.check,
              onPressed: _valid
                  ? () => Navigator.of(context).pop(
                      PhoneBookEntry(
                        name: _name.text.trim(),
                        phone: _phone.text.trim(),
                        hasEkengeAccount: false,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
