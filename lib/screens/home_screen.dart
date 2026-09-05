import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/ek_state.dart';
import '../services/haptics.dart';
import '../services/location_service.dart';
import '../widgets/common.dart';
import '../widgets/ek_map.dart';
import 'notifications_screen.dart';
import 'safe_settings_sheet.dart';

/// EKENGE PLUS — Ecran principal.
/// Regroupe §6 Tracking, §7 Danger, §8 Safe, §10 Je suis en securite.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final alert = st.activeAlert;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  // ---- Bandeau d'alerte active (§7 / §9) ----
                  if (alert != null) ...[
                    _AlertBanner(alert: alert),
                    const SizedBox(height: 16),
                  ],

                  // ---- Verification Safe en cours (§8) ----
                  if (st.safeCheckPending && alert == null) ...[
                    const _SafeCheckBanner(),
                    const SizedBox(height: 16),
                  ],

                  // ---- Carte interactive (§6) ----
                  _MapSection(),
                  const SizedBox(height: 16),

                  // ---- Bouton Danger (§7) ----
                  const _DangerSection(),
                  const SizedBox(height: 18),

                  // ---- Tracking (§6) ----
                  const _TrackingCard(),
                  const SizedBox(height: 12),

                  // ---- Safe (§8) ----
                  const _SafeCard(),
                  const SizedBox(height: 18),

                  // ---- Reseaux de securite ----
                  const _NetworkSummary(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// Barre supérieure
// =========================================================================
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 14),
      child: Row(
        children: [
          const EkWordmark(size: 21, align: CrossAxisAlignment.start),
          const Spacer(),
          if (st.trackingActive)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  const EkPulseDot(color: Ek.safe, size: 6),
                  Text('EN DIRECT', style: Ek.over(size: 9, color: Ek.safe)),
                ],
              ),
            ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            icon: Badge(
              isLabelVisible: st.unreadCount > 0,
              label: Text('${st.unreadCount}'),
              backgroundColor: Ek.danger,
              textColor: Colors.white,
              child: const Icon(Icons.notifications_none, size: 22),
            ),
            color: Ek.textSecondary,
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// §7 / §9 Bandeau d'alerte active
// =========================================================================
class _AlertBanner extends StatelessWidget {
  final ActiveAlert alert;
  const _AlertBanner({required this.alert});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final (label, color, desc) = switch (alert.kind) {
      AlertKind.danger => (
        'ALERTE DANGER ACTIVE',
        Ek.danger,
        'Vos ${st.urgenceList.length} contacts d\'urgence ont été alertes '
            'par notification Push et par WhatsApp.',
      ),
      AlertKind.safeLevel1 => (
        'NIVEAU 1 · ALERTE PRÉVENTIVE',
        Ek.warn,
        'Aucune confirmation reçue. Votre liste Tracking a été alertée.',
      ),
      AlertKind.safeLevel2 => (
        'NIVEAU 2 · ALERTE CRITIQUE',
        Ek.danger,
        'Incident critique. Votre liste Urgence a été alertée et la '
            'géolocalisation temps réel est partagée.',
      ),
      AlertKind.none => ('', Ek.accent, ''),
    };

    final l2 = st.level2Countdown;

    return EkCard(
      color: color.withValues(alpha: 0.07),
      border: color.withValues(alpha: 0.4),
      shadow: Ek.glow(color, o: 0.12, b: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 19, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: Ek.over(size: 10.5, color: color)),
              ),
              Text(
                'depuis ${ekRelative(alert.startedAt)}',
                style: Ek.over(size: 8.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(desc, style: Ek.body(size: 12.5, height: 1.5)),
          if (l2 != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Ek.warn),
                const SizedBox(width: 8),
                Text(
                  'Escalade Niveau 2 dans ${ekFormatDuration(l2)}',
                  style: Ek.body(size: 12, color: Ek.warn),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _SafeConfirmButton(),
          if (alert.kind == AlertKind.danger) ...[
            const SizedBox(height: 10),
            // §7 : lien partageable sur WhatsApp pour permettre a des
            // personnes hors liste Tracking de suivre le deplacement,
            // meme sans compte EKENGE.
            EkButton(
              label: 'Partager le lien de suivi sur WhatsApp',
              icon: Icons.share_outlined,
              outlined: true,
              color: color,
              onPressed: () => _shareTrackingLink(context, st),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _shareTrackingLink(BuildContext context, EkState st) async {
    final link = 'https://ekenge-plus.web.app/suivi/${st.user!.phone}';
    final text = Uri.encodeComponent(
      'ALERTE : ${st.user!.fullName} se sent en danger. '
      'Suivez sa position en temps réel (aucun compte requis) : $link',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lien de suivi : $link')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lien de suivi : $link')),
        );
      }
    }
  }
}

// =========================================================================
// §8 Bandeau de verification Safe
// =========================================================================
class _SafeCheckBanner extends StatelessWidget {
  const _SafeCheckBanner();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final left = st.confirmCountdown ?? Duration.zero;
    final total = EkState.confirmWindowSeconds;

    return EkCard(
      color: Ek.warn.withValues(alpha: 0.07),
      border: Ek.warn.withValues(alpha: 0.42),
      shadow: Ek.glow(Ek.warn, o: 0.12, b: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: 19,
                color: Ek.warn,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'VÉRIFICATION DE SÉCURITÉ',
                  style: Ek.over(size: 10.5, color: Ek.warn),
                ),
              ),
              EkRing(
                progress: left.inSeconds / total,
                size: 40,
                color: Ek.warn,
                stroke: 2.5,
                center: Text(
                  ekFormatClock(left),
                  style: Ek.over(size: 8, color: Ek.warn),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'L\'alarme sonore est déclenchée. Confirmez votre sécurité avant '
            'la fin du compte à rebours, sans quoi une alerte préventive sera '
            'transmise à votre liste Tracking.',
            style: Ek.body(size: 12.5, height: 1.5),
          ),
          const SizedBox(height: 16),
          _SafeConfirmButton(),
        ],
      ),
    );
  }
}

// =========================================================================
// §10 Bouton « Je suis en securite »
// =========================================================================
class _SafeConfirmButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EkButton(
      label: 'Je suis en sécurité',
      icon: Icons.verified_user_outlined,
      color: Ek.safe,
      textColor: Colors.white,
      onPressed: () => _confirm(context),
    );
  }

  static Future<void> _confirm(BuildContext context) async {
    final st = context.read<EkState>();
    final keep = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Ek.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Ek.r28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Ek.hairline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Ek.safe.withValues(alpha: 0.12),
                      border: Border.all(color: Ek.safe.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      size: 19,
                      color: Ek.safe,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Confirmation de sécurité',
                      style: Ek.title(size: 17),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Cette action clôt immédiatement l\'alerte active et arrêté le '
                'processus d\'escalade. Vos contacts Tracking et Urgence seront '
                'informés que vous êtes en sécurité.',
                style: Ek.body(size: 13, height: 1.55),
              ),
              const SizedBox(height: 20),
              Text('MAINTENIR LE TRACKING ?', style: Ek.over()),
              const SizedBox(height: 12),
              EkButton(
                label: 'Confirmer et maintenir le Tracking',
                icon: Icons.share_location_outlined,
                color: Ek.safe,
                textColor: Colors.white,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 10),
              EkButton(
                label: 'Confirmer et arrêter le Tracking',
                icon: Icons.location_off_outlined,
                outlined: true,
                color: Ek.textSecondary,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (keep == null) return;
    await st.confirmSafe(keepTracking: keep);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          keep
              ? 'Sécurité confirmée. Tracking maintenu.'
              : 'Sécurité confirmée. Tracking désactivé.',
        ),
      ),
    );
  }
}

// =========================================================================
// §6 Carte interactive
// =========================================================================
class _MapSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final me = st.position ?? LocationService.instance.current;
    final alertKind = st.activeAlert?.kind;
    final selfColor = switch (alertKind) {
      AlertKind.danger || AlertKind.safeLevel2 => Ek.danger,
      AlertKind.safeLevel1 => Ek.warn,
      _ => st.trackingActive ? Ek.accent : Ek.textSecondary,
    };

    final markers = <MapMarker>[
      MapMarker(
        point: me,
        initials: st.user?.initials ?? '?',
        label: 'VOUS',
        color: selfColor,
        self: true,
        pulsing: st.trackingActive,
      ),
      ...st.watched
          .where((w) => w.trackingActive)
          .map(
            (w) => MapMarker(
              point: w.position,
              initials: w.initials,
              label: w.name.split(' ').first.toUpperCase(),
              color: w.alert == AlertKind.danger ? Ek.danger : Ek.accent,
              pulsing: w.alert == AlertKind.danger,
            ),
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tete de la carte (cf. maquette) : icone + double libelle.
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 2, right: 2),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Ek.accentDim,
                ),
                child: const Icon(
                  Icons.map_outlined,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CARTE INTERACTIVE',
                    style: Ek.over(size: 10, color: Ek.accentDim),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    st.trackingActive
                        ? 'Vue en temps réel'
                        : 'Vue de la position',
                    style: Ek.body(size: 11, color: Ek.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    st.trackingActive ? 'TEMPS RÉEL' : 'POSITION LOCALE',
                    style: Ek.over(size: 10, color: Ek.accentDim),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Précision élevée',
                    style: Ek.body(size: 11, color: Ek.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.place_outlined, size: 18, color: Ek.accentDim),
            ],
          ),
        ),
        EkMap(
          markers: markers,
          trail: st.trackingActive ? st.trail : const [],
          focus: me,
          height: 268,
          trailColor: selfColor,
        ),
        const SizedBox(height: 10),
        // Bandeau coordonnees dans une carte blanche (cf. maquette).
        EkCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: EkMapReadout(point: me, live: st.trackingActive),
        ),
      ],
    );
  }
}

// =========================================================================
// §7 Bouton Danger
// =========================================================================
class _DangerSection extends StatelessWidget {
  const _DangerSection();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final active = st.activeAlert?.kind == AlertKind.danger;

    if (active) {
      return Center(
        child: Column(
          children: [
            _DangerButton(active: active),
            const SizedBox(height: 14),
            Text(
              'Alerte transmise à la liste Urgence',
              textAlign: TextAlign.center,
              style: Ek.body(size: 12, color: Ek.danger),
            ),
          ],
        ),
      );
    }

    // Libelles lateraux de part et d'autre du bouton (cf. maquette).
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'APPUYEZ',
                textAlign: TextAlign.right,
                style: Ek.over(size: 9.5, color: Ek.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                'LONGUEMENT',
                textAlign: TextAlign.right,
                style: Ek.over(size: 9.5, color: Ek.textSecondary),
              ),
              const SizedBox(height: 6),
              const Icon(
                Icons.arrow_forward,
                size: 13,
                color: Ek.danger,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _DangerButton(active: active),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POUR SIGNALER',
                style: Ek.over(size: 9.5, color: Ek.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                'UNE SITUATION CRITIQUE',
                style: Ek.over(size: 9.5, color: Ek.danger),
              ),
              const SizedBox(height: 6),
              const Icon(Icons.arrow_back, size: 13, color: Ek.danger),
            ],
          ),
        ),
      ],
    );
  }
}

class _DangerButton extends StatefulWidget {
  final bool active;
  const _DangerButton({required this.active});

  @override
  State<_DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<_DangerButton>
    with TickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  /// Eclat blanc joue au moment exact du declenchement : preuve visuelle
  /// immediate que l'appui a ete pris en compte.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  // Paliers de vibration franchis pendant le maintien : l'utilisateur sent
  // la progression au lieu d'attendre sans aucun retour.
  int _lastStep = 0;

  @override
  void initState() {
    super.initState();
    _hold.addStatusListener((s) {
      if (s == AnimationStatus.completed) _fire();
    });
    _hold.addListener(_onHoldProgress);
  }

  void _onHoldProgress() {
    // 3 paliers pendant la montee : 33 %, 66 %, 100 %.
    final step = (_hold.value * 3).floor();
    if (step > _lastStep && step < 3) {
      Haptics.tap();
    }
    _lastStep = step;
  }

  @override
  void dispose() {
    _hold.removeListener(_onHoldProgress);
    _hold.dispose();
    _breathe.dispose();
    _flash.dispose();
    super.dispose();
  }

  Future<void> _fire() async {
    _hold.reset();
    _lastStep = 0;
    final st = context.read<EkState>();

    if (st.urgenceList.isEmpty) {
      await Haptics.medium();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Ek.warn,
          content: Text(
            'Aucun contact dans la liste Urgence. Ajoutez vos proches '
            'dans l\'onglet Réseaux.',
            style: Ek.body(size: 13, color: Colors.white),
          ),
        ),
      );
      return;
    }

    // §7 Vibration d'alerte : confirmation physique du declenchement.
    Haptics.danger();
    // Confirmation visuelle immediate.
    _flash.forward(from: 0);

    await st.triggerDanger();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Ek.danger,
        duration: const Duration(seconds: 4),
        content: Text(
          'ALERTE TRANSMISE · ${st.urgenceList.length} contact(s) de la liste '
          'Urgence notifiés par Push et WhatsApp.',
          style: Ek.body(size: 13, color: Colors.white),
        ),
      ),
    );
  }

  void _onDown() {
    // Retour immediat des l'appui : l'utilisateur sait que le maintien
    // est pris en compte.
    Haptics.tap();
    _hold.forward();
  }

  void _onUp() {
    // Relachement avant la fin : on annule et on le signale.
    if (_hold.isAnimating && _hold.value > 0.08) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1600),
          backgroundColor: Ek.surfaceHigh,
          content: Text(
            'Maintenez le bouton jusqu\'au bout pour déclencher l\'alerte.',
            style: Ek.body(size: 12.5, color: Ek.textPrimary),
          ),
        ),
      );
    }
    _lastStep = 0;
    _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onDown(),
      onTapUp: (_) => _onUp(),
      onTapCancel: _onUp,
      child: AnimatedBuilder(
        animation: Listenable.merge([_hold, _breathe, _flash]),
        builder: (_, __) {
          final p = _hold.value;
          final breathe = widget.active ? 0.5 + _breathe.value * 0.5 : 0.0;
          // Le flash s'ouvre vite puis retombe.
          final f = _flash.value == 0
              ? 0.0
              : (1 - (_flash.value - 0.18).abs() / 0.82).clamp(0.0, 1.0);
          final scale = 1 - p * 0.04 + f * 0.05;
          final holding = p > 0.02;
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 196,
              height: 196,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Anneau exterieur
                  Container(
                    width: 196,
                    height: 196,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Ek.danger.withValues(
                          alpha: 0.14 + breathe * 0.22 + p * 0.3,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Ek.danger.withValues(
                          alpha: 0.20 + breathe * 0.26 + p * 0.3,
                        ),
                      ),
                    ),
                  ),
                  // Progression du maintien
                  EkRing(
                    progress: p,
                    size: 152,
                    color: Colors.white,
                    stroke: 2.2,
                  ),
                  // Noyau
                  Container(
                    width: 138,
                    height: 138,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE8213C), Ek.danger],
                      ),
                      boxShadow: Ek.glow(
                        Ek.danger,
                        o: 0.30 + breathe * 0.22 + p * 0.25,
                        b: 42,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.active
                              ? Icons.crisis_alert
                              : holding
                              ? Icons.touch_app
                              : Icons.shield_outlined,
                          size: 34,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        // Pendant le maintien, la progression est chiffree :
                        // le geste n'est plus silencieux.
                        Text(
                          holding
                              ? '${(p * 100).round()} %'
                              : widget.active
                              ? 'ACTIVE'
                              : 'DANGER',
                          style: Ek.over(size: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Eclat de confirmation au declenchement
                  if (f > 0.01)
                    IgnorePointer(
                      child: Container(
                        width: 196,
                        height: 196,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: f * 0.30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: f * 0.75),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =========================================================================
// §6 Carte Tracking
// =========================================================================
class _TrackingCard extends StatelessWidget {
  const _TrackingCard();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final on = st.trackingActive;
    final elapsed = st.trackingElapsed;

    return EkCard(
      color: Ek.accent.withValues(alpha: 0.06),
      border: Ek.accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: on
                      ? Ek.accentDim
                      : Ek.accent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: on
                        ? Ek.accentDim
                        : Ek.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.share_location_outlined,
                  size: 19,
                  color: on ? Colors.white : Ek.accentDim,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARTAGE DE LOCALISATION',
                      style: Ek.over(size: 10, color: Ek.accentDim),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      on
                          ? 'Actif · ${st.trackingList.length} contact(s)'
                          : 'Inactif',
                      style: Ek.body(size: 13.5, color: Ek.textPrimary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                onChanged: (v) async {
                  if (v) {
                    if (st.trackingList.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Aucun contact dans la liste Tracking.',
                          ),
                        ),
                      );
                      return;
                    }
                    // Verification stricte : GPS active + permission,
                    // sinon guide l'utilisateur (aucune position simulee).
                    final ok = await ekEnsureLocationReady(context);
                    if (!ok || !context.mounted) return;
                    await st.startTracking();
                  } else {
                    await st.stopTracking();
                  }
                },
              ),
            ],
          ),
          if (on) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Durée',
                    value: elapsed == null ? '--' : ekFormatDuration(elapsed),
                  ),
                ),
                Container(width: 1, height: 30, color: Ek.hairline),
                Expanded(
                  child: _Metric(label: 'Points', value: '${st.trail.length}'),
                ),
                Container(width: 1, height: 30, color: Ek.hairline),
                Expanded(
                  child: _Metric(
                    label: 'Vitesse',
                    value:
                        '${(st.position?.speedKmh ?? 0).toStringAsFixed(1)} km/h',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Ek.num(size: 15)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: Ek.over(size: 8.5)),
      ],
    );
  }
}

// =========================================================================
// §8 Carte Safe
// =========================================================================
class _SafeCard extends StatelessWidget {
  const _SafeCard();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final cd = st.safeCountdown;
    final totalSec = st.safeIntervalMinutes * 60;
    final progress = cd == null
        ? 0.0
        : 1 - (cd.inSeconds / totalSec).clamp(0.0, 1.0);

    return EkCard(
      color: Ek.accent.withValues(alpha: 0.06),
      border: Ek.accent.withValues(alpha: 0.22),
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Ek.bgElevated,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Ek.r28)),
        ),
        builder: (_) => const SafeSettingsSheet(),
      ),
      child: Row(
        children: [
          EkRing(
            progress: progress,
            size: 46,
            color: st.safeEnabled ? Ek.accent : Ek.textTertiary,
            stroke: 2.6,
            center: Icon(
              Icons.verified_user_outlined,
              size: 17,
              color: st.safeEnabled ? Ek.accent : Ek.textTertiary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VÉRIFICATION SAFE',
                  style: Ek.over(size: 10, color: Ek.accentDim),
                ),
                const SizedBox(height: 4),
                Text(
                  !st.safeEnabled
                      ? 'Désactivée'
                      : !st.trackingActive
                      ? 'Activée dès le démarrage du Tracking'
                      : cd == null
                      ? 'En attente'
                      : 'Prochaine vérification dans ${ekFormatDuration(cd)}',
                  style: Ek.body(size: 13.5, color: Ek.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  'Fréquence : ${st.safeIntervalMinutes} minutes',
                  style: Ek.body(size: 11.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: Ek.accentDim),
        ],
      ),
    );
  }
}

// =========================================================================
// Recapitulatif des reseaux
// =========================================================================
class _NetworkSummary extends StatelessWidget {
  const _NetworkSummary();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    return Row(
      children: [
        Expanded(
          child: EkCard(
            padding: const EdgeInsets.all(16),
            color: Ek.accent.withValues(alpha: 0.05),
            border: Ek.accent.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.group_outlined,
                      size: 16,
                      color: Ek.accentDim,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TRACKING',
                      style: Ek.over(size: 9, color: Ek.accentDim),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('${st.trackingList.length}', style: Ek.num(size: 22)),
                const SizedBox(height: 2),
                Text('contact(s) autorisé(s)', style: Ek.body(size: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: EkCard(
            padding: const EdgeInsets.all(16),
            color: Ek.danger.withValues(alpha: 0.04),
            border: Ek.danger.withValues(alpha: 0.18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.emergency_outlined,
                      size: 16,
                      color: Ek.danger,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'URGENCE',
                      style: Ek.over(size: 9, color: Ek.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('${st.urgenceList.length}', style: Ek.num(size: 22)),
                const SizedBox(height: 2),
                Text('contact(s) d\'urgence', style: Ek.body(size: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
