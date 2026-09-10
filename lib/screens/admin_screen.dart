import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design.dart';
import '../services/backend.dart';
import '../services/ek_state.dart';
import '../services/firebase_backend.dart';
import '../widgets/common.dart';

/// EKENGE PLUS — Tableau de bord ADMINISTRATEUR.
///
/// Réservé aux comptes de la collection Firestore « admins ».
/// KPI, graphiques d'évolution, gestion des administrateurs et des
/// publicités (max 5 actives, petite bannière discrète de 100 px,
/// image chargée depuis le stockage local, durée d'affichage en secondes).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

/// Périodes d'analyse disponibles.
enum _Period { day, week, month, quarter }

extension _PeriodX on _Period {
  String get label => switch (this) {
    _Period.day => '24 H',
    _Period.week => '7 JOURS',
    _Period.month => '1 MOIS',
    _Period.quarter => '3 MOIS',
  };

  Duration get duration => switch (this) {
    _Period.day => const Duration(hours: 24),
    _Period.week => const Duration(days: 7),
    _Period.month => const Duration(days: 30),
    _Period.quarter => const Duration(days: 90),
  };

  int get buckets => switch (this) {
    _Period.day => 12,
    _Period.week => 7,
    _Period.month => 15,
    _Period.quarter => 12,
  };
}

class _AdminScreenState extends State<AdminScreen> {
  AdminData? _data;
  List<Map<String, dynamic>> _ads = const [];
  List<Map<String, dynamic>> _admins = const [];
  bool _loading = true;
  _Period _period = _Period.week;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fb = FirebaseBackend.instance;
    final data = await fb.fetchAdminData();
    final ads = await fb.fetchAllAds();
    final admins = await fb.listAdmins();
    if (!mounted) return;
    setState(() {
      _data = data;
      _ads = ads;
      _admins = admins;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EkHeader(
              title: 'Administration',
              subtitle: 'Tableau de bord EKENGE PLUS',
              actions: [
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 20),
                  color: Ek.textSecondary,
                ),
              ],
            ),
            Expanded(
              child: _loading || d == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        children: [
                          _periodSelector(),
                          const SizedBox(height: 16),
                          _kpiGrid(d),
                          const SizedBox(height: 22),
                          EkSectionLabel('Évolution du total de comptes'),
                          _chart(
                            d.accountsTotalSeries(
                              _period.duration,
                              _period.buckets,
                            ),
                            color: Ek.accent,
                          ),
                          const SizedBox(height: 18),
                          EkSectionLabel('Nouveaux comptes (non cumulés)'),
                          _chart(
                            d.newAccountsSeries(
                              _period.duration,
                              _period.buckets,
                            ),
                            color: Ek.safe,
                          ),
                          const SizedBox(height: 18),
                          EkSectionLabel('Sessions de tracking'),
                          _chart(
                            d.trackingSeries(
                              _period.duration,
                              _period.buckets,
                            ),
                            color: Ek.accentDim,
                          ),
                          const SizedBox(height: 18),
                          EkSectionLabel('Utilisation du bouton Urgence'),
                          _chart(
                            d.panicSeries(_period.duration, _period.buckets),
                            color: Ek.danger,
                          ),
                          const SizedBox(height: 24),
                          _adminsSection(),
                          const SizedBox(height: 24),
                          _adsSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sélecteur de période
  // -------------------------------------------------------------------------
  Widget _periodSelector() {
    return Row(
      children: [
        for (final p in _Period.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _period = p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _period == p ? Ek.ink : Ek.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _period == p ? Ek.ink : Ek.hairline,
                  ),
                ),
                child: Center(
                  child: Text(
                    p.label,
                    style: Ek.over(
                      size: 9,
                      color: _period == p ? Colors.white : Ek.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (p != _Period.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // KPI 1-6
  // -------------------------------------------------------------------------
  Widget _kpiGrid(AdminData d) {
    final avg = Duration(seconds: d.avgTrackingSeconds);
    final kpis = [
      ('COMPTES AU TOTAL', '${d.totalAccounts}', Icons.people_outline),
      ('EN LIGNE MAINTENANT', '${d.onlineNow}', Icons.wifi_tethering),
      (
        'CONNECTÉS · ${_period.label}',
        '${d.activeWithin(_period.duration)}',
        Icons.login,
      ),
      (
        'NOUVEAUX · ${_period.label}',
        '${d.newWithin(_period.duration)}',
        Icons.person_add_alt,
      ),
      ('DURÉE MOY. TRACKING', ekFormatDuration(avg), Icons.timer_outlined),
      (
        'URGENCE · ${_period.label}',
        '${d.panicWithin(_period.duration)}',
        Icons.crisis_alert_outlined,
      ),
    ];
    return Column(
      children: [
        for (var row = 0; row < 3; row++) ...[
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                Expanded(child: _kpiCard(kpis[row * 2 + col])),
                if (col == 0) const SizedBox(width: 10),
              ],
            ],
          ),
          if (row < 2) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _kpiCard((String, String, IconData) k) {
    return EkCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(k.$3, size: 14, color: Ek.accentDim),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(k.$1, maxLines: 1, style: Ek.over(size: 8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(k.$2, style: Ek.num(size: 22)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Graphique à barres
  // -------------------------------------------------------------------------
  Widget _chart(List<int> values, {required Color color}) {
    final maxV = values.isEmpty
        ? 1
        : values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    return EkCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (values[i] > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${values[i]}',
                              style: Ek.over(size: 7.5, color: color),
                            ),
                          ),
                        const SizedBox(height: 3),
                        Container(
                          height: (90 * values[i] / maxV).clamp(2.0, 90.0),
                          decoration: BoxDecoration(
                            color: values[i] == 0
                                ? color.withValues(alpha: 0.12)
                                : color.withValues(alpha: 0.75),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < values.length - 1) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Il y a ${_period.label.toLowerCase()}',
                style: Ek.over(size: 7.5),
              ),
              Text('Aujourd\'hui', style: Ek.over(size: 7.5)),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Gestion des administrateurs
  // -------------------------------------------------------------------------
  Widget _adminsSection() {
    final st = context.read<EkState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EkSectionLabel(
          'Administrateurs (${_admins.length})',
          trailing: GestureDetector(
            onTap: _addAdminDialog,
            child: Row(
              children: [
                const Icon(Icons.add, size: 13, color: Ek.accentDim),
                const SizedBox(width: 3),
                Text('AJOUTER', style: Ek.over(size: 8.5, color: Ek.accentDim)),
              ],
            ),
          ),
        ),
        for (final a in _admins)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: EkCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 17,
                    color: Ek.accentDim,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      (a['phone'] as String?) ?? '',
                      style: Ek.body(size: 13, color: Ek.textPrimary),
                    ),
                  ),
                  if ((a['phone'] as String?) != st.user?.phone)
                    GestureDetector(
                      onTap: () => _removeAdmin((a['phone'] as String?) ?? ''),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 17,
                        color: Ek.textTertiary,
                      ),
                    )
                  else
                    Text('VOUS', style: Ek.over(size: 8, color: Ek.accent)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addAdminDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ek.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Nouvel administrateur', style: Ek.body(size: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ce compte aura les mêmes droits que vous '
              '(KPI, publicités, création d\'administrateurs).',
              style: Ek.body(size: 12, color: Ek.textSecondary),
            ),
            const SizedBox(height: 14),
            EkPhoneField(controller: ctrl, label: 'Numéro de téléphone'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('ANNULER', style: Ek.over(size: 10)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('CRÉER', style: Ek.over(size: 10, color: Ek.accent)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final phone = Backend.normalizePhone(ctrl.text);
    if (phone.length < 10) return;
    final st = context.read<EkState>();
    await FirebaseBackend.instance.addAdmin(phone, st.user?.phone ?? '');
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Ek.ink,
        content: Text(
          'Administrateur $phone créé.',
          style: Ek.body(size: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _removeAdmin(String phone) async {
    await FirebaseBackend.instance.removeAdmin(phone);
    await _load();
  }

  // -------------------------------------------------------------------------
  // Publicités
  // -------------------------------------------------------------------------
  Widget _adsSection() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final activeCount = _ads
        .where((a) => FirebaseBackend.adIsActive(a, now))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EkSectionLabel(
          'Publicités ($activeCount/5 actives)',
          trailing: GestureDetector(
            onTap: activeCount >= 5 ? null : () => _adDialog(),
            child: Row(
              children: [
                Icon(
                  Icons.add,
                  size: 13,
                  color: activeCount >= 5 ? Ek.textTertiary : Ek.accentDim,
                ),
                const SizedBox(width: 3),
                Text(
                  'PUBLIER',
                  style: Ek.over(
                    size: 8.5,
                    color: activeCount >= 5 ? Ek.textTertiary : Ek.accentDim,
                  ),
                ),
              ],
            ),
          ),
        ),
        EkCard(
          padding: const EdgeInsets.all(12),
          color: Ek.surfaceHigh,
          child: Row(
            children: [
              const Icon(Icons.straighten, size: 14, color: Ek.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Petite bannière discrète : 100 px de hauteur, pleine '
                  'largeur. Image choisie depuis le stockage local. '
                  'Maximum 5 publicités actives simultanément.',
                  style: Ek.body(size: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_ads.isEmpty)
          EkCard(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text('Aucune publicité publiée', style: Ek.body(size: 12)),
            ),
          ),
        for (final a in _ads)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _adCard(a, now),
          ),
      ],
    );
  }

  Widget _adCard(Map<String, dynamic> a, int now) {
    final active = FirebaseBackend.adIsActive(a, now);
    final createdAt = (a['created_at'] as num?)?.toInt() ?? 0;
    final created = createdAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(createdAt)
        : null;
    final mode = (a['expiry_mode'] as String?) ?? 'days';
    final value = (a['expiry_value'] as num?)?.toInt() ?? 0;
    final expiryLabel = switch (mode) {
      'views' => 'Expire à $value vues',
      'clicks' => 'Expire à $value clics',
      _ => value > 0
          ? 'Expire après $value jour(s)'
          : 'Expire le ${_fmtDate(DateTime.fromMillisecondsSinceEpoch((a['expires_at'] as num?)?.toInt() ?? 0))}',
    };
    return EkCard(
      padding: const EdgeInsets.all(12),
      border: active ? Ek.accent.withValues(alpha: 0.25) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aperçu bannière : hauteur 100 px, pleine largeur.
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: _adImage(a),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  (a['title'] as String?) ?? '',
                  style: Ek.body(size: 13, color: Ek.textPrimary),
                ),
              ),
              EkPill(
                label: active
                    ? '${(a['display_seconds'] as num?)?.toInt() ?? 10} s à l\'écran'
                    : 'Expirée',
                color: active ? Ek.safe : Ek.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Date de création + critère d'expiration de l'annonce.
          Row(
            children: [
              const Icon(
                Icons.event_outlined,
                size: 13,
                color: Ek.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                created != null
                    ? 'Créée le ${_fmtDate(created)}'
                    : 'Date inconnue',
                style: Ek.over(size: 8.5),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.hourglass_bottom_outlined,
                size: 13,
                color: Ek.textTertiary,
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(expiryLabel, style: Ek.over(size: 8.5))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 13,
                color: Ek.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                '${(a['impressions'] as num?)?.toInt() ?? 0} vues',
                style: Ek.over(size: 8.5),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.touch_app_outlined, size: 13, color: Ek.accent),
              const SizedBox(width: 4),
              Text(
                '${(a['clicks'] as num?)?.toInt() ?? 0} clics',
                style: Ek.over(size: 8.5, color: Ek.accent),
              ),
              const Spacer(),
              // Modifier la publicité.
              GestureDetector(
                onTap: () => _adDialog(existing: a),
                child: const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Icon(Icons.edit_outlined, size: 17, color: Ek.accent),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await FirebaseBackend.instance.deleteAd(
                    (a['id'] as String?) ?? '',
                  );
                  await _load();
                },
                child: const Icon(
                  Icons.delete_outline,
                  size: 17,
                  color: Ek.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Affiche l'image d'une publicité (base64 local ou ancienne URL).
  Widget _adImage(Map<String, dynamic> a) {
    final b64 = (a['image_b64'] as String?) ?? '';
    if (b64.isNotEmpty) {
      try {
        return Image.memory(base64Decode(b64), fit: BoxFit.cover);
      } catch (_) {}
    }
    final url = (a['image_url'] as String?) ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Ek.surfaceHigh,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Ek.textTertiary),
          ),
        ),
      );
    }
    return Container(
      color: Ek.surfaceHigh,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Ek.textTertiary),
      ),
    );
  }

  /// Création OU modification d'une publicité ([existing] non nul = édition).
  Future<void> _adDialog({Map<String, dynamic>? existing}) async {
    final editing = existing != null;
    final title = TextEditingController(
      text: (existing?['title'] as String?) ?? '',
    );
    final target = TextEditingController(
      text: (existing?['target_url'] as String?) ?? '',
    );
    var seconds = (existing?['display_seconds'] as num?)?.toInt() ?? 10;
    if (![5, 10, 15, 20, 30, 60].contains(seconds)) seconds = 10;
    // Critère d'expiration : jours de diffusion, nombre de vues ou de clics.
    var expiryMode = (existing?['expiry_mode'] as String?) ?? 'days';
    final expiryValue = TextEditingController(
      text:
          ((existing?['expiry_value'] as num?)?.toInt() ?? 30).toString(),
    );
    Uint8List? imageBytes;
    // En édition, l'image actuelle sert d'aperçu tant qu'aucune nouvelle
    // image n'est choisie.
    Uint8List? currentImage;
    final b64 = (existing?['image_b64'] as String?) ?? '';
    if (b64.isNotEmpty) {
      try {
        currentImage = base64Decode(b64);
      } catch (_) {}
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Ek.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            editing ? 'Modifier la publicité' : 'Publier une publicité',
            style: Ek.body(size: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Petite bannière discrète : 100 px de hauteur, pleine '
                  'largeur. Elle disparaît après la durée choisie.',
                  style: Ek.body(size: 11.5, color: Ek.textSecondary),
                ),
                const SizedBox(height: 12),
                // Choix de l'image DEPUIS LE STOCKAGE LOCAL du téléphone.
                GestureDetector(
                  onTap: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      // Compression : la bannière ne fait que 100 px de
                      // haut, inutile de stocker une image lourde.
                      maxWidth: 1200,
                      maxHeight: 400,
                      imageQuality: 70,
                    );
                    if (picked == null) return;
                    final bytes = await picked.readAsBytes();
                    // Firestore limite un document à ~1 Mo.
                    if (bytes.lengthInBytes > 700 * 1024) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            backgroundColor: Ek.warn,
                            content: Text(
                              'Image trop lourde (max 700 Ko). '
                              'Choisissez une image plus légère.',
                              style: Ek.body(size: 12, color: Colors.white),
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    setD(() => imageBytes = bytes);
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Ek.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: imageBytes != null ? Ek.accent : Ek.hairline,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (imageBytes ?? currentImage) != null
                        ? Image.memory(
                            (imageBytes ?? currentImage)!,
                            fit: BoxFit.cover,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 26,
                                color: Ek.accentDim,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'CHOISIR UNE IMAGE (STOCKAGE LOCAL)',
                                style: Ek.over(size: 8, color: Ek.accentDim),
                              ),
                            ],
                          ),
                  ),
                ),
                if (editing) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Touchez l\'image pour la remplacer (facultatif).',
                    style: Ek.body(size: 10, color: Ek.textTertiary),
                  ),
                ],
                const SizedBox(height: 12),
                EkField(label: 'Titre', controller: title),
                const SizedBox(height: 10),
                EkField(
                  label: 'Lien au clic (facultatif)',
                  controller: target,
                  keyboard: TextInputType.url,
                ),
                const SizedBox(height: 12),
                Text('DURÉE D\'AFFICHAGE À L\'ÉCRAN', style: Ek.over(size: 9)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final s in [5, 10, 15, 20, 30, 60])
                      ChoiceChip(
                        label: Text(
                          '$s s',
                          style: Ek.over(
                            size: 9,
                            color: seconds == s
                                ? Colors.white
                                : Ek.textSecondary,
                          ),
                        ),
                        selected: seconds == s,
                        selectedColor: Ek.ink,
                        backgroundColor: Ek.surfaceHigh,
                        onSelected: (_) => setD(() => seconds = s),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Critère d'expiration de l'annonce, au choix de l'admin.
                Text('CRITÈRE D\'EXPIRATION', style: Ek.over(size: 9)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final m in const [
                      ('days', 'Jours de diffusion'),
                      ('views', 'Nombre de vues'),
                      ('clicks', 'Nombre de clics'),
                    ])
                      ChoiceChip(
                        label: Text(
                          m.$2,
                          style: Ek.over(
                            size: 9,
                            color: expiryMode == m.$1
                                ? Colors.white
                                : Ek.textSecondary,
                          ),
                        ),
                        selected: expiryMode == m.$1,
                        selectedColor: Ek.ink,
                        backgroundColor: Ek.surfaceHigh,
                        onSelected: (_) => setD(() => expiryMode = m.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                EkField(
                  label: switch (expiryMode) {
                    'views' => 'Nombre de vues (ex : 1000)',
                    'clicks' => 'Nombre de clics (ex : 1000)',
                    _ => 'Nombre de jours (ex : 30)',
                  },
                  controller: expiryValue,
                  keyboard: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('ANNULER', style: Ek.over(size: 10)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                editing ? 'ENREGISTRER' : 'PUBLIER',
                style: Ek.over(size: 10, color: Ek.accent),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final value = int.tryParse(expiryValue.text.trim()) ?? 0;
    if (title.text.trim().isEmpty ||
        (!editing && imageBytes == null) ||
        value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Ek.warn,
          content: Text(
            'Titre, image (stockage local) et valeur d\'expiration '
            'obligatoires.',
            style: Ek.body(size: 12.5, color: Colors.white),
          ),
        ),
      );
      return;
    }
    final String? err;
    if (editing) {
      err = await FirebaseBackend.instance.updateAd(
        id: (existing['id'] as String?) ?? '',
        title: title.text.trim(),
        targetUrl: target.text.trim(),
        displaySeconds: seconds,
        expiryMode: expiryMode,
        expiryValue: value,
        imageB64: imageBytes != null ? base64Encode(imageBytes!) : null,
      );
    } else {
      final st = context.read<EkState>();
      err = await FirebaseBackend.instance.createAd(
        title: title.text.trim(),
        imageB64: base64Encode(imageBytes!),
        targetUrl: target.text.trim(),
        displaySeconds: seconds,
        createdBy: st.user?.phone ?? '',
        expiryMode: expiryMode,
        expiryValue: value,
      );
    }
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Ek.warn,
          content: Text(err, style: Ek.body(size: 12.5, color: Colors.white)),
        ),
      );
      return;
    }
    await _load();
  }
}

/// Bannière publicitaire côté UTILISATEUR (affichée sur l'accueil).
///
/// Format DISCRET : 100 px de hauteur, pleine largeur — elle ne gêne pas
/// la vue de l'utilisateur. Elle disparaît automatiquement après la durée
/// d'affichage définie par l'admin (5 s, 10 s, etc.) et peut aussi être
/// fermée manuellement (croix). Comptabilise 1 affichage au montage et
/// 1 clic au toucher.
class EkAdBanner extends StatefulWidget {
  const EkAdBanner({super.key});

  @override
  State<EkAdBanner> createState() => _EkAdBannerState();
}

class _EkAdBannerState extends State<EkAdBanner> {
  /// Pause entre deux affichages : la bannière disparaît puis RÉAPPARAÎT
  /// au bout d'un moment — comportement identique sur toutes les pages
  /// (Sécurité, Proches…).
  static const _pause = Duration(seconds: 45);

  Map<String, dynamic>? _ad;
  bool _visible = false;
  Timer? _hideTimer;
  Timer? _nextTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _nextTimer?.cancel();
    super.dispose();
  }

  /// Cache la bannière puis programme sa réapparition (cycle permanent).
  void _hideThenReschedule() {
    if (!mounted) return;
    setState(() => _visible = false);
    _nextTimer?.cancel();
    _nextTimer = Timer(_pause, _pick);
  }

  Future<void> _pick() async {
    if (!mounted) return;
    // Les publicités ne sont PAS diffusées sur les comptes administrateurs.
    if (context.read<EkState>().isAdmin) return;
    final ads = await FirebaseBackend.instance.fetchActiveAds();
    if (!mounted) return;
    if (ads.isEmpty) {
      // Aucune annonce active pour l'instant : on réessaie plus tard.
      _nextTimer?.cancel();
      _nextTimer = Timer(_pause, _pick);
      return;
    }
    // Rotation : la publicité la moins affichée passe en premier.
    ads.sort(
      (a, b) => ((a['impressions'] as num?)?.toInt() ?? 0).compareTo(
        (b['impressions'] as num?)?.toInt() ?? 0,
      ),
    );
    final ad = ads.first;
    setState(() {
      _ad = ad;
      _visible = true;
    });
    // La bannière disparaît d'elle-même après la durée définie par
    // l'admin, puis REVIENT après la pause (rotation des annonces).
    final secs = (ad['display_seconds'] as num?)?.toInt() ?? 10;
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: secs), _hideThenReschedule);
    // Statistique : affichage comptabilisé.
    await FirebaseBackend.instance.logAdImpression(
      (ad['id'] as String?) ?? '',
    );
  }

  Widget _image(Map<String, dynamic> ad) {
    final b64 = (ad['image_b64'] as String?) ?? '';
    if (b64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      } catch (_) {}
    }
    final url = (ad['image_url'] as String?) ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    // Aucune publicité pour les comptes administrateurs.
    if (context.watch<EkState>().isAdmin) return const SizedBox.shrink();
    // AnimatedSize : la bannière se replie en douceur quand elle expire.
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: (ad == null || !_visible)
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () async {
                  // Statistique : clic comptabilisé.
                  await FirebaseBackend.instance.logAdClick(
                    (ad['id'] as String?) ?? '',
                  );
                  final url = (ad['target_url'] as String?) ?? '';
                  if (url.isNotEmpty) {
                    final uri = Uri.tryParse(url);
                    if (uri != null) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Petite bannière discrète : 100 px, pleine largeur.
                      SizedBox(
                        height: 100,
                        width: double.infinity,
                        child: _image(ad),
                      ),
                      Positioned(
                        top: 6,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PUB',
                            style: Ek.over(size: 7, color: Colors.white),
                          ),
                        ),
                      ),
                      // Fermeture manuelle : l'utilisateur garde le contrôle
                      // (la bannière reviendra après la pause, comme partout).
                      Positioned(
                        top: 4,
                        right: 6,
                        child: GestureDetector(
                          onTap: () {
                            _hideTimer?.cancel();
                            _hideThenReschedule();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}