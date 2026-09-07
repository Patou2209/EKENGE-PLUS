import 'package:flutter/material.dart';
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
/// publicités (max 5 actives, bannière 1200 × 300 imposée).
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
              Text('Maintenant', style: Ek.over(size: 7.5)),
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
        .where((a) => ((a['expires_at'] as num?)?.toInt() ?? 0) > now)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EkSectionLabel(
          'Publicités ($activeCount/5 actives)',
          trailing: GestureDetector(
            onTap: activeCount >= 5 ? null : _addAdDialog,
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
                  'Dimensions imposées : bannière 1200 × 300 px (ratio 4:1). '
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
    final expires = (a['expires_at'] as num?)?.toInt() ?? 0;
    final active = expires > now;
    final remaining = Duration(milliseconds: (expires - now).abs());
    return EkCard(
      padding: const EdgeInsets.all(12),
      border: active ? Ek.accent.withValues(alpha: 0.25) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aperçu bannière 4:1.
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 4,
              child: Image.network(
                (a['image_url'] as String?) ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Ek.surfaceHigh,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Ek.textTertiary,
                    ),
                  ),
                ),
              ),
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
                    ? 'Expire dans ${remaining.inDays + 1} j'
                    : 'Expirée',
                color: active ? Ek.safe : Ek.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 13,
                color: Ek.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                '${(a['impressions'] as num?)?.toInt() ?? 0} affichages',
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

  Future<void> _addAdDialog() async {
    final title = TextEditingController();
    final image = TextEditingController();
    final target = TextEditingController();
    var days = 7;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Ek.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text('Publier une publicité', style: Ek.body(size: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bannière 1200 × 300 px (ratio 4:1) OBLIGATOIRE.',
                  style: Ek.body(size: 11.5, color: Ek.warn),
                ),
                const SizedBox(height: 12),
                EkField(label: 'Titre', controller: title),
                const SizedBox(height: 10),
                EkField(
                  label: 'URL de l\'image (1200 × 300)',
                  controller: image,
                  keyboard: TextInputType.url,
                ),
                const SizedBox(height: 10),
                EkField(
                  label: 'Lien au clic (facultatif)',
                  controller: target,
                  keyboard: TextInputType.url,
                ),
                const SizedBox(height: 12),
                Text('DURÉE DE DIFFUSION', style: Ek.over(size: 9)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in [1, 3, 7, 14, 30])
                      ChoiceChip(
                        label: Text(
                          '$d j',
                          style: Ek.over(
                            size: 9,
                            color: days == d ? Colors.white : Ek.textSecondary,
                          ),
                        ),
                        selected: days == d,
                        selectedColor: Ek.ink,
                        backgroundColor: Ek.surfaceHigh,
                        onSelected: (_) => setD(() => days = d),
                      ),
                  ],
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
                'PUBLIER',
                style: Ek.over(size: 10, color: Ek.accent),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (title.text.trim().isEmpty || image.text.trim().isEmpty) return;
    final st = context.read<EkState>();
    final err = await FirebaseBackend.instance.createAd(
      title: title.text.trim(),
      imageUrl: image.text.trim(),
      targetUrl: target.text.trim(),
      durationDays: days,
      createdBy: st.user?.phone ?? '',
    );
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
/// Comptabilise 1 affichage au montage et 1 clic au toucher.
class EkAdBanner extends StatefulWidget {
  const EkAdBanner({super.key});

  @override
  State<EkAdBanner> createState() => _EkAdBannerState();
}

class _EkAdBannerState extends State<EkAdBanner> {
  Map<String, dynamic>? _ad;

  @override
  void initState() {
    super.initState();
    _pick();
  }

  Future<void> _pick() async {
    final ads = await FirebaseBackend.instance.fetchActiveAds();
    if (!mounted || ads.isEmpty) return;
    // Rotation : la publicité la moins affichée passe en premier.
    ads.sort(
      (a, b) => ((a['impressions'] as num?)?.toInt() ?? 0).compareTo(
        (b['impressions'] as num?)?.toInt() ?? 0,
      ),
    );
    final ad = ads.first;
    setState(() => _ad = ad);
    // Statistique : affichage comptabilisé.
    await FirebaseBackend.instance.logAdImpression(
      (ad['id'] as String?) ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Padding(
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
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 4,
                child: Image.network(
                  (ad['image_url'] as String?) ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              Positioned(
                top: 6,
                right: 8,
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
            ],
          ),
        ),
      ),
    );
  }
}