import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../core/design.dart';
import '../services/backend.dart';
import '../services/ek_state.dart';
import '../widgets/common.dart';
import 'guest_tracking_screen.dart';

// =========================================================================
// Ecran d'accueil : connexion ou creation de compte
// =========================================================================
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 18),
                // Logo complet EKENGE+
                Image.asset(
                  'assets/brand/logo.png',
                  width: 130,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const EkMark(size: 90),
                ),
                const SizedBox(height: 8),
                Container(width: 46, height: 2.4, color: Ek.accent),
                const SizedBox(height: 18),
                // Slogan principal
                Text(
                  'EN SECURITE,',
                  textAlign: TextAlign.center,
                  style: Ek.title(size: 30),
                ),
                Text(
                  'ENSEMBLE.',
                  textAlign: TextAlign.center,
                  style: Ek.title(size: 30, color: Ek.accent),
                ),
                const SizedBox(height: 12),
                Text(
                  'Parce que votre securite et celle\nde vos proches comptent plus que tout.',
                  textAlign: TextAlign.center,
                  style: Ek.body(size: 14, color: Ek.textSecondary),
                ),
                const SizedBox(height: 26),
                // Emblème central : bouclier dans un medaillon
                const _WelcomeEmblem(),
                const SizedBox(height: 26),
                // Carte des trois fonctions cles
                EkCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  shadow: Ek.lift,
                  child: Row(
                    children: [
                      const Expanded(
                        child: _WelcomeFeature(
                          icon: Icons.location_on_outlined,
                          color: Ek.accent,
                          title: 'Suivi',
                          sub: 'en temps reel',
                        ),
                      ),
                      Container(width: 1, height: 52, color: Ek.hairline),
                      const Expanded(
                        child: _WelcomeFeature(
                          icon: Icons.notifications_active_outlined,
                          color: Ek.danger,
                          title: 'Alerte',
                          sub: 'immediate',
                        ),
                      ),
                      Container(width: 1, height: 52, color: Ek.hairline),
                      const Expanded(
                        child: _WelcomeFeature(
                          icon: Icons.verified_user_outlined,
                          color: Ek.safe,
                          title: 'SAFE',
                          sub: 'periodique',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                EkButton(
                  label: 'Creer un compte',
                  icon: Icons.person_add_alt,
                  color: Ek.accentDim,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PhoneStepScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                EkButton(
                  label: 'J\'ai deja un compte',
                  icon: Icons.person_outline,
                  outlined: true,
                  color: Ek.textPrimary,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                // §11 : fonction Tracking sans creation de compte (visiteur).
                EkButton(
                  label: 'Partager ma localisation sans compte',
                  icon: Icons.visibility_outlined,
                  outlined: true,
                  color: Ek.accentDim,
                  height: 48,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GuestTrackingScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Emblème central de l'ecran d'accueil : bouclier du logo dans un
/// medaillon circulaire avec anneaux decoratifs.
class _WelcomeEmblem extends StatelessWidget {
  const _WelcomeEmblem();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anneaux decoratifs
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Ek.accent.withValues(alpha: 0.25),
                width: 1.4,
              ),
            ),
          ),
          Container(
            width: 186,
            height: 186,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Ek.accent.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
          ),
          // Medaillon
          Container(
            width: 164,
            height: 164,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22101828),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/brand/shield.png',
                width: 96,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shield_outlined,
                  size: 70,
                  color: Ek.accent,
                ),
              ),
            ),
          ),
          // Points decoratifs sur les anneaux
          const Positioned(top: 24, right: 34, child: _EmblemDot()),
          const Positioned(bottom: 30, left: 26, child: _EmblemDot()),
          const Positioned(top: 96, left: 4, child: _EmblemDot(small: true)),
        ],
      ),
    );
  }
}

class _EmblemDot extends StatelessWidget {
  final bool small;
  const _EmblemDot({this.small = false});

  @override
  Widget build(BuildContext context) {
    final s = small ? 6.0 : 9.0;
    return Container(
      width: s,
      height: s,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Ek.accentDim,
      ),
    );
  }
}

/// Colonne « fonction cle » de la carte d'accueil.
class _WelcomeFeature extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;

  const _WelcomeFeature({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Ek.body(
            size: 13,
            color: Ek.textPrimary,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(sub, style: Ek.body(size: 11, color: Ek.textSecondary)),
      ],
    );
  }
}


// =========================================================================
// §3 Etape 1 — saisie du numero de telephone
// =========================================================================
class PhoneStepScreen extends StatefulWidget {
  const PhoneStepScreen({super.key});

  @override
  State<PhoneStepScreen> createState() => _PhoneStepScreenState();
}

class _PhoneStepScreenState extends State<PhoneStepScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController(text: '+243 ');
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final st = context.read<EkState>();
    final phone = Backend.normalizePhone(_phone.text);

    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _err = 'Prenom et nom obligatoires');
      return;
    }
    if (phone.length < 9) {
      setState(() => _err = 'Numero de telephone invalide');
      return;
    }
    if (await st.accountExists(phone)) {
      setState(() => _err = 'Un compte existe deja avec ce numero');
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });
    // Garde-fou : si aucun callback Firebase ne repond en 150 s, on
    // affiche un diagnostic clair au lieu d'un spinner infini.
    var answered = false;
    Future<void>.delayed(const Duration(seconds: 150), () {
      if (!answered && mounted && _busy) {
        setState(() {
          _busy = false;
          _err =
              'Firebase ne repond pas (aucun callback en 150 s). '
              'Verifiez la connexion internet et les services Google Play '
              'de l\'appareil, puis reessayez.';
        });
      }
    });
    // Flux ImmoZone : on navigue vers l'ecran OTP UNIQUEMENT quand
    // Firebase confirme l'envoi du SMS (codeSent). Le spinner tourne
    // pendant l'attestation Play Integrity (jusqu'a ~2 min au 1er envoi).
    await st.startOtp(
      phone: phone,
      onCodeSent: () {
        answered = true;
        if (!mounted) return;
        setState(() => _busy = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpStepScreen(
              phone: phone,
              firstName: _first.text.trim(),
              lastName: _last.text.trim(),
            ),
          ),
        );
      },
      onAutoVerified: () {
        // Android a valide le SMS automatiquement : saisie inutile,
        // on passe directement au mot de passe.
        answered = true;
        if (!mounted) return;
        setState(() => _busy = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PasswordStepScreen(
              phone: phone,
              firstName: _first.text.trim(),
              lastName: _last.text.trim(),
              resetMode: false,
            ),
          ),
        );
      },
      onFailed: (message) {
        answered = true;
        if (!mounted) return;
        setState(() {
          _busy = false;
          _err = message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const EkHeader(
              title: 'Creation de compte',
              subtitle: 'Etape 1 sur 4 · Identite et numero',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Steps(current: 0),
                    const SizedBox(height: 26),
                    EkField(
                      label: 'Prenom',
                      controller: _first,
                      hint: 'Jean',
                      icon: Icons.badge_outlined,
                      caps: TextCapitalization.words,
                    ),
                    const SizedBox(height: 18),
                    EkField(
                      label: 'Nom',
                      controller: _last,
                      hint: 'Mukendi',
                      icon: Icons.badge_outlined,
                      caps: TextCapitalization.words,
                    ),
                    const SizedBox(height: 18),
                    EkField(
                      label: 'Numero de telephone',
                      controller: _phone,
                      hint: '+243 810 000 000',
                      icon: Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                      error: _err,
                    ),
                    const SizedBox(height: 14),
                    _Note(
                      icon: Icons.info_outline,
                      text:
                          'Le numero de telephone constitue l\'identifiant '
                          'unique de votre compte. Un code de verification vous '
                          'sera envoye par WhatsApp.',
                    ),
                    const SizedBox(height: 28),
                    EkButton(
                      label: 'Recevoir le code WhatsApp',
                      icon: Icons.chat_outlined,
                      loading: _busy,
                      onPressed: _next,
                    ),
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

// =========================================================================
// §3 Etape 2 — verification du code OTP recu par SMS
// =========================================================================
class OtpStepScreen extends StatefulWidget {
  final String phone;
  final String firstName;
  final String lastName;

  /// Mode reinitialisation du mot de passe.
  final bool resetMode;

  const OtpStepScreen({
    super.key,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.resetMode = false,
  });

  @override
  State<OtpStepScreen> createState() => _OtpStepScreenState();
}

class _OtpStepScreenState extends State<OtpStepScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _err;
  String? _resendErr;
  int _resend = 45;

  /// Canal de secours : le code a ete (re)envoye par SMS Firebase.
  bool _viaSms = false;

  @override
  void initState() {
    super.initState();
    _countdown();
  }

  Future<void> _countdown() async {
    while (_resend > 0 && mounted) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resend--);
    }
  }

  /// Renvoi du code sur le canal actif (WhatsApp par defaut, SMS si le
  /// canal de secours a ete choisi).
  Future<void> _resendCode() async {
    setState(() {
      _resendErr = null;
      _resend = 45;
    });
    _countdown();
    final st = context.read<EkState>();
    final send = _viaSms ? st.startOtpSms : st.startOtp;
    await send(
      phone: widget.phone,
      isResend: true,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _resendErr = null);
      },
      onAutoVerified: _goNext,
      onFailed: (message) {
        if (!mounted) return;
        setState(() => _resendErr = message);
      },
    );
  }

  /// CANAL DE SECOURS : l'utilisateur n'a pas WhatsApp — envoi par SMS
  /// via Firebase Phone Auth.
  Future<void> _switchToSms() async {
    setState(() {
      _viaSms = true;
      _err = null;
      _resendErr = null;
      _resend = 45;
    });
    _countdown();
    await context.read<EkState>().startOtpSms(
      phone: widget.phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _resendErr = null);
      },
      onAutoVerified: _goNext,
      onFailed: (message) {
        if (!mounted) return;
        setState(() => _resendErr = message);
      },
    );
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PasswordStepScreen(
          phone: widget.phone,
          firstName: widget.firstName,
          lastName: widget.lastName,
          resetMode: widget.resetMode,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    // La saisie automatique a 6 chiffres et le bouton peuvent declencher
    // deux verifications simultanees : on ignore les appels concurrents.
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    // La verification attend Firebase si la confirmation d'envoi tarde
    // (SMS arrive avant codeSent) : le vrai code n'est jamais rejete
    // pour cause de lenteur.
    final ok = await context.read<EkState>().verifyOtp(
      widget.phone,
      _code.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _err = 'Code incorrect ou expire');
      return;
    }
    _goNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EkHeader(
              title: 'Verification du numero',
              subtitle: widget.resetMode
                  ? (_viaSms ? 'Code envoye par SMS' : 'Code envoye par WhatsApp')
                  : (_viaSms
                        ? 'Etape 2 sur 4 · Code SMS'
                        : 'Etape 2 sur 4 · Code WhatsApp'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.resetMode) const _Steps(current: 1),
                    const SizedBox(height: 26),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Ek.surface,
                              border: Border.all(color: Ek.hairline),
                            ),
                            child: const Icon(
                              Icons.mark_email_read_outlined,
                              size: 23,
                              color: Ek.accent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Code envoye au', style: Ek.body(size: 12.5)),
                          const SizedBox(height: 4),
                          Text(widget.phone, style: Ek.title(size: 17)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    EkField(
                      label: 'Code de verification',
                      controller: _code,
                      hint: '000000',
                      icon: Icons.pin_outlined,
                      keyboard: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      error: _err,
                      onChanged: (v) {
                        if (v.length == 6) _verify();
                      },
                    ),
                    const SizedBox(height: 12),
                    // Confirmation d'envoi (WhatsApp Cloud API ou SMS Firebase).
                    EkCard(
                      color: Ek.safe.withValues(alpha: 0.06),
                      border: Ek.safe.withValues(alpha: 0.28),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            _viaSms ? Icons.sms_outlined : Icons.chat_outlined,
                            size: 17,
                            color: Ek.safe,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _viaSms ? 'SMS ENVOYE' : 'WHATSAPP ENVOYE',
                                  style: Ek.over(size: 9, color: Ek.safe),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _viaSms
                                      ? 'Un code de verification a ete envoye '
                                            'par SMS a ${widget.phone}. La '
                                            'reception peut prendre jusqu\'a '
                                            '2 minutes.'
                                      : 'Un code de verification a ete envoye '
                                            'par WhatsApp a ${widget.phone}. La '
                                            'reception peut prendre jusqu\'a '
                                            '2 minutes.',
                                  style: Ek.body(
                                    size: 13,
                                    color: Ek.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_resendErr != null) ...[
                      const SizedBox(height: 10),
                      EkCard(
                        color: Ek.warn.withValues(alpha: 0.06),
                        border: Ek.warn.withValues(alpha: 0.28),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 15,
                              color: Ek.warn,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _resendErr!,
                                style: Ek.body(
                                  size: 11,
                                  color: Ek.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    EkButton(
                      label: 'Verifier le code',
                      icon: Icons.check,
                      loading: _busy,
                      onPressed: _code.text.length >= 6 ? _verify : _verify,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _resend > 0 ? null : _resendCode,
                        child: Text(
                          _resend > 0
                              ? 'Renvoyer le code dans $_resend s'
                              : 'Renvoyer le code',
                          style: Ek.body(
                            size: 12.5,
                            color: _resend > 0 ? Ek.textTertiary : Ek.accent,
                          ),
                        ),
                      ),
                    ),
                    if (!_viaSms)
                      Center(
                        child: TextButton.icon(
                          onPressed: _switchToSms,
                          icon: const Icon(
                            Icons.sms_outlined,
                            size: 15,
                            color: Ek.textSecondary,
                          ),
                          label: Text(
                            'Vous n\'avez pas WhatsApp ? '
                            'Recevoir le code par SMS',
                            style: Ek.body(
                              size: 12.5,
                              color: Ek.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
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

// =========================================================================
// §3 Etape 3 — definition du mot de passe
// =========================================================================
class PasswordStepScreen extends StatefulWidget {
  final String phone;
  final String firstName;
  final String lastName;
  final bool resetMode;

  const PasswordStepScreen({
    super.key,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.resetMode = false,
  });

  @override
  State<PasswordStepScreen> createState() => _PasswordStepScreenState();
}

class _PasswordStepScreenState extends State<PasswordStepScreen> {
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final v = Backend.validatePassword(_pwd.text);
    if (v != null) {
      setState(() => _err = v);
      return;
    }
    if (_pwd.text != _confirm.text) {
      setState(() => _err = 'Les mots de passe ne correspondent pas');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });

    final st = context.read<EkState>();
    if (widget.resetMode) {
      await st.resetPassword(widget.phone, _pwd.text);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mot de passe reinitialise. Vous pouvez vous connecter.',
          ),
        ),
      );
      return;
    }

    try {
      await st.completeRegistration(
        phone: widget.phone,
        firstName: widget.firstName,
        lastName: widget.lastName,
        password: _pwd.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = 'Creation du compte impossible. Reessayez.';
      });
      return;
    }

    if (!mounted) return;
    // Le routeur racine affiche desormais la configuration obligatoire des
    // listes (§4). Les ecrans d'inscription doivent etre retires de la pile,
    // sinon ils resteraient empiles par-dessus et masqueraient l'etape 4.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final rules = <(String, bool)>[
      ('8 caracteres minimum', _pwd.text.length >= 8),
      ('Une majuscule', _pwd.text.contains(RegExp(r'[A-Z]'))),
      ('Une minuscule', _pwd.text.contains(RegExp(r'[a-z]'))),
      ('Un chiffre', _pwd.text.contains(RegExp(r'[0-9]'))),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EkHeader(
              title: widget.resetMode
                  ? 'Nouveau mot de passe'
                  : 'Mot de passe securise',
              subtitle: widget.resetMode
                  ? 'Definissez un nouveau mot de passe'
                  : 'Etape 3 sur 4 · Securite du compte',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.resetMode) const _Steps(current: 2),
                    const SizedBox(height: 26),
                    EkField(
                      label: 'Mot de passe',
                      controller: _pwd,
                      obscure: _hide,
                      icon: Icons.lock_outline,
                      onChanged: (_) => setState(() {}),
                      suffix: IconButton(
                        onPressed: () => setState(() => _hide = !_hide),
                        icon: Icon(
                          _hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                          color: Ek.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    EkField(
                      label: 'Confirmation',
                      controller: _confirm,
                      obscure: _hide,
                      icon: Icons.lock_outline,
                      error: _err,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    EkCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: rules
                            .map(
                              (r) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      r.$2
                                          ? Icons.check_circle_outline
                                          : Icons.radio_button_unchecked,
                                      size: 15,
                                      color: r.$2 ? Ek.safe : Ek.textTertiary,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      r.$1,
                                      style: Ek.body(
                                        size: 12.5,
                                        color: r.$2
                                            ? Ek.textPrimary
                                            : Ek.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    EkButton(
                      label: widget.resetMode
                          ? 'Reinitialiser'
                          : 'Valider et continuer',
                      icon: Icons.shield_outlined,
                      loading: _busy,
                      onPressed: _submit,
                    ),
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

// =========================================================================
// §3 Connexion : numero de telephone + mot de passe
// =========================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(text: '+243 ');
  final _pwd = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _phone.dispose();
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final err = await context.read<EkState>().signIn(
      Backend.normalizePhone(_phone.text),
      _pwd.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _err = err;
    });
    // Connexion reussie : on retire l'ecran de connexion de la pile pour
    // laisser le routeur racine afficher l'application.
    if (err == null) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _forgot() async {
    final phone = Backend.normalizePhone(_phone.text);
    final st = context.read<EkState>();
    if (!await st.accountExists(phone)) {
      if (!mounted) return;
      setState(() => _err = 'Aucun compte associe a ce numero');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    // Flux ImmoZone : navigation vers la saisie du code DANS onCodeSent.
    await st.startOtp(
      phone: phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _busy = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpStepScreen(
              phone: phone,
              firstName: '',
              lastName: '',
              resetMode: true,
            ),
          ),
        );
      },
      onAutoVerified: () {
        if (!mounted) return;
        setState(() => _busy = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PasswordStepScreen(
              phone: phone,
              firstName: '',
              lastName: '',
              resetMode: true,
            ),
          ),
        );
      },
      onFailed: (message) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _err = message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const EkHeader(
              title: 'Connexion',
              subtitle: 'Numero de telephone et mot de passe',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Center(child: EkMark(size: 62)),
                    const SizedBox(height: 18),
                    const Center(child: EkWordmark(size: 17, showSub: true)),
                    const SizedBox(height: 34),
                    EkField(
                      label: 'Numero de telephone',
                      controller: _phone,
                      icon: Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 18),
                    EkField(
                      label: 'Mot de passe',
                      controller: _pwd,
                      obscure: _hide,
                      icon: Icons.lock_outline,
                      error: _err,
                      suffix: IconButton(
                        onPressed: () => setState(() => _hide = !_hide),
                        icon: Icon(
                          _hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                          color: Ek.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgot,
                        child: Text(
                          'Mot de passe oublie ?',
                          style: Ek.body(size: 12.5, color: Ek.accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    EkButton(
                      label: 'Se connecter',
                      icon: Icons.login,
                      loading: _busy,
                      onPressed: _login,
                    ),
                    const SizedBox(height: 20),
                    // Separateur « OU »
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('OU', style: Ek.over(size: 10)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    EkButton(
                      label: 'Creer un nouveau compte',
                      icon: Icons.person_add_alt,
                      outlined: true,
                      color: Ek.accentDim,
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const PhoneStepScreen(),
                        ),
                      ),
                    ),
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

// =========================================================================
// Indicateur d'etapes
// =========================================================================
class _Steps extends StatelessWidget {
  final int current;
  const _Steps({required this.current});

  // Libelles courts : ils doivent tenir sur une seule ligne sous la puce.
  static const _labels = ['Identite', 'WhatsApp', 'Securite', 'Reseaux'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i - 1) ~/ 2 < current;
          return Expanded(
            child: Container(
              height: 1.4,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: done ? Ek.accent.withValues(alpha: 0.6) : Ek.hairline,
            ),
          );
        }
        final idx = i ~/ 2;
        final done = idx < current;
        final active = idx == current;
        return Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? Ek.accent : Ek.surface,
                border: Border.all(
                  color: done || active ? Ek.accent : Ek.hairline,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, size: 12, color: Ek.accent)
                    : Text(
                        '${idx + 1}',
                        style: Ek.over(
                          size: 9.5,
                          color: active
                              ? Colors.white
                              : Ek.textTertiary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 58,
              child: Text(
                _labels[idx],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: Ek.over(
                  size: 8,
                  color: active ? Ek.accent : Ek.textTertiary,
                ).copyWith(letterSpacing: 0.5),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Ek.textTertiary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Ek.body(size: 12, height: 1.5))),
      ],
    );
  }
}
