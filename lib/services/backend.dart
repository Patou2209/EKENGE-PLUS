import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// EKENGE PLUS — Couche backend.
///
/// Reproduit les services decrits au cahier des charges §12 / §13 :
/// Authentification, gestion des utilisateurs, listes Tracking / Urgence,
/// gestion des alertes, geolocalisation temps reel, notifications Push,
/// messages WhatsApp, journalisation des evenements de securite.
///
/// L'implementation est locale et persistante (SharedPreferences) afin que
/// l'application soit pleinement fonctionnelle en preview. Les signatures
/// correspondent 1:1 aux appels Firebase (Auth / Firestore / Cloud Functions /
/// FCM / WhatsApp Business API) et sont remplacables sans toucher a l'UI.
class Backend {
  Backend._();
  static final Backend instance = Backend._();

  SharedPreferences? _prefs;
  final Random _rnd = Random();

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  // =======================================================================
  // §15 Securite — hachage du mot de passe (SHA-256 + sel aleatoire)
  // =======================================================================
  String newSalt() {
    final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
    return base64Url.encode(b);
  }

  String hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password::ekenge_plus')).toString();

  /// §3 Regles de robustesse du mot de passe.
  static String? validatePassword(String p) {
    if (p.length < 8) return 'Minimum 8 caracteres';
    if (!p.contains(RegExp(r'[A-Z]'))) return 'Au moins une majuscule requise';
    if (!p.contains(RegExp(r'[a-z]'))) return 'Au moins une minuscule requise';
    if (!p.contains(RegExp(r'[0-9]'))) return 'Au moins un chiffre requis';
    return null;
  }

  static String normalizePhone(String raw) {
    var s = raw.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    return s;
  }

  // =======================================================================
  // §3 Authentification : OTP SMS puis mot de passe
  // =======================================================================

  /// Envoi du code OTP par SMS (Firebase Auth / verifyPhoneNumber).
  /// Le code est retourne pour la demonstration en preview.
  Future<String> sendOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final code = (100000 + _rnd.nextInt(900000)).toString();
    final p = await _p;
    await p.setString('otp_$phone', code);
    await p.setInt('otp_at_$phone', DateTime.now().millisecondsSinceEpoch);
    return code;
  }

  /// Verification du code recu par SMS. Validite : 5 minutes.
  Future<bool> verifyOtp(String phone, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    final p = await _p;
    final expected = p.getString('otp_$phone');
    final at = p.getInt('otp_at_$phone') ?? 0;
    final fresh = DateTime.now().millisecondsSinceEpoch - at < 5 * 60 * 1000;
    return expected != null && expected == code.trim() && fresh;
  }

  Future<bool> accountExists(String phone) async {
    final p = await _p;
    return p.containsKey('user_$phone');
  }

  /// Creation du compte : prenom, nom, numero, mot de passe (§3).
  Future<EkUser> createAccount({
    required String phone,
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    final salt = newSalt();
    final user = EkUser(
      phone: phone,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      passwordHash: hashPassword(password, salt),
      salt: salt,
      createdAt: DateTime.now(),
    );
    final p = await _p;
    await p.setString('user_$phone', jsonEncode(user.toJson()));
    return user;
  }

  /// Connexion : numero de telephone + mot de passe (§3).
  Future<EkUser?> login(String phone, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final p = await _p;
    final raw = p.getString('user_$phone');
    if (raw == null) return null;
    final user = EkUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    if (hashPassword(password, user.salt) != user.passwordHash) return null;
    return user;
  }

  Future<EkUser?> loadUser(String phone) async {
    final p = await _p;
    final raw = p.getString('user_$phone');
    if (raw == null) return null;
    return EkUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Reinitialisation du mot de passe apres verification OTP.
  Future<void> updatePassword(String phone, String password) async {
    final u = await loadUser(phone);
    if (u == null) return;
    final salt = newSalt();
    final updated = EkUser(
      phone: u.phone,
      firstName: u.firstName,
      lastName: u.lastName,
      passwordHash: hashPassword(password, salt),
      salt: salt,
      createdAt: u.createdAt,
    );
    final p = await _p;
    await p.setString('user_$phone', jsonEncode(updated.toJson()));
  }

  // ---- Session ----------------------------------------------------------
  Future<void> setSession(String phone) async =>
      (await _p).setString('session_phone', phone);

  Future<String?> session() async => (await _p).getString('session_phone');

  Future<void> clearSession() async => (await _p).remove('session_phone');

  // =======================================================================
  // Persistance par utilisateur (equivalent document Firestore)
  // =======================================================================
  Future<Map<String, dynamic>> readDoc(String phone) async {
    final p = await _p;
    final raw = p.getString('doc_$phone');
    if (raw == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> writeDoc(String phone, Map<String, dynamic> doc) async {
    final p = await _p;
    await p.setString('doc_$phone', jsonEncode(doc));
  }

  // =======================================================================
  // §5 Synchronisation avec les contacts
  // =======================================================================

  /// Verifie si un numero est associe a un compte EKENGE PLUS.
  /// §5 true si le numero possede deja un compte EKENGE PLUS.
  Future<bool> isEkengeNumber(String phone) => accountExists(phone);

  // =======================================================================
  // §11 / §14 Sortie des notifications
  // Push : Firebase Cloud Messaging.
  // WhatsApp : Cloud Functions -> WhatsApp Business Platform (API Meta),
  // envoi depuis le numero officiel certifie EKENGE PLUS.
  // =======================================================================
  static const String officialWhatsAppNumber = '+243 000 000 000';

  Future<OutboundMessage> dispatch({
    required Channel channel,
    required SafetyContact to,
    required String body,
    required String kind,
  }) async {
    return OutboundMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_rnd.nextInt(9999)}',
      channel: channel,
      recipientName: to.name,
      recipientPhone: to.phone,
      body: body,
      at: DateTime.now(),
      kind: kind,
    );
  }
}
