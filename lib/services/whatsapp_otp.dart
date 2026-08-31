// =============================================================================
// EKENGE PLUS — Service OTP via WhatsApp Cloud API (Meta Graph API v25.0)
// =============================================================================
// Remplace l'envoi du code par SMS (Firebase Phone Auth) par un envoi via
// WhatsApp. Le code est genere localement, envoye en message texte, puis
// verifie localement (hash SHA-256 + expiration 10 minutes).
//
// ⚠️ JETON TEMPORAIRE : le token ci-dessous est un jeton de test Meta qui
//    expire au bout d'environ 24 h. Pour la production, creer un
//    "System User token" permanent dans Meta Business Suite et remplacer
//    la constante _accessToken.
// ⚠️ NUMERO DE TEST : le numero expediteur est le numero de test Meta
//    (+1 555 655 2459). Seuls les numeros destinataires enregistres dans
//    le tableau de bord Meta peuvent recevoir les messages tant que le
//    compte n'est pas passe en production (Etape 2/3 Meta).
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class WhatsAppOtp {
  WhatsAppOtp._();
  static final WhatsAppOtp instance = WhatsAppOtp._();

  // --- Identifiants WhatsApp Cloud API (compte test Meta) -------------------
  static const String _phoneNumberId = '1202711136269311';
  // TODO(production) : remplacer par un System User token permanent.
  static const String _accessToken =
      'EAATgUQZB8y1cBSVzgutG4CnEcyKgvSioESxZBq9kYqQZAPWgFBJ027vq1TOL4YYpd'
      'NOvhUdrItKL526z8r0wYoSFYkQw0kfL6KFS8suZByqmNgot7YIYgTq2ACvhmZCMyIx'
      'WMTvOyIDkp94dgHZCyKGqWZAQvBON5lXm4VYzXKbp6cNcd6oG8O09QPDfn58hvagoy'
      '8qop2dcMTh8p7wzLoK3fV28lmwr1MOnN2tGG0inSQ3uPyy7xLT01SRQFUvfXcc8Dun'
      'muZC6TPAhZCXVpTmx4ZAAZDZD';

  static const Duration _validity = Duration(minutes: 10);

  // --- Jeton dynamique -------------------------------------------------------
  // Le jeton est lu en priorite dans Firestore (app_config/whatsapp,
  // champ access_token) : il peut ainsi etre renouvele SANS reinstaller
  // l'application. La constante _accessToken sert de secours.
  String? _cachedToken;

  Future<String> _token({bool refresh = false}) async {
    if (!refresh && _cachedToken != null) return _cachedToken!;
    try {
      final doc = await fs.FirebaseFirestore.instance
          .collection('app_config')
          .doc('whatsapp')
          .get()
          .timeout(const Duration(seconds: 8));
      final t = doc.data()?['access_token'] as String?;
      if (t != null && t.isNotEmpty) {
        _cachedToken = t;
        return t;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WhatsApp] lecture jeton Firestore : $e');
    }
    _cachedToken = _accessToken;
    return _accessToken;
  }

  /// Envoi brut vers l'API Meta. Retourne (statusCode, corps).
  Future<(int, String)> _post(String token, String jsonBody) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse(
          'https://graph.facebook.com/v25.0/$_phoneNumberId/messages',
        ),
      );
      req.headers.set('Authorization', 'Bearer $token');
      req.headers.contentType = ContentType.json;
      req.write(jsonBody);
      final res = await req.close().timeout(const Duration(seconds: 30));
      final resBody = await res.transform(utf8.decoder).join();
      return (res.statusCode, resBody);
    } finally {
      client.close();
    }
  }

  /// Envoie [jsonBody] ; si Meta repond « jeton invalide » (190/131005),
  /// recharge le jeton depuis Firestore et retente UNE fois.
  Future<(int, String)> _postWithRetry(String jsonBody) async {
    var token = await _token();
    var (status, body) = await _post(token, jsonBody);
    if (status != 200 && (body.contains('"code":190') ||
        body.contains('"code":131005'))) {
      final fresh = await _token(refresh: true);
      if (fresh != token) {
        (status, body) = await _post(fresh, jsonBody);
      }
    }
    return (status, body);
  }

  // --- Numero de test (identique a l'ancien systeme Firebase) ---------------
  static const String _testPhone = '+243900000001';
  static const String _testCode = '123456';

  // Etat du code en cours : hash SHA-256 + expiration (jamais en clair).
  String? _codeHash;
  DateTime? _expiresAt;
  String? _phoneInProgress;

  String _hash(String code) => sha256.convert(utf8.encode(code)).toString();

  /// Genere un code a 6 chiffres cryptographiquement aleatoire.
  String _generateCode() {
    final rnd = Random.secure();
    return List.generate(6, (_) => rnd.nextInt(10)).join();
  }

  /// Envoie le code OTP par WhatsApp. Callbacks identiques a l'ancien flux
  /// Firebase pour que les ecrans restent inchanges.
  Future<void> sendOtp({
    required String phone,
    required void Function() onCodeSent,
    required void Function(String message) onFailed,
  }) async {
    // Numero de test : aucun message envoye, code fixe 123456.
    if (phone == _testPhone) {
      _phoneInProgress = phone;
      _codeHash = _hash(_testCode);
      _expiresAt = DateTime.now().add(_validity);
      onCodeSent();
      return;
    }

    final code = _generateCode();
    final to = phone.startsWith('+') ? phone.substring(1) : phone;
    final body = jsonEncode({
      'messaging_product': 'whatsapp',
      'to': to,
      'type': 'text',
      'text': {
        'body': 'EKENGE PLUS\n\nVotre code de verification : $code\n\n'
            'Ce code expire dans 10 minutes. Ne le partagez avec personne.',
      },
    });

    try {
      final (status, resBody) = await _postWithRetry(body);

      if (kDebugMode) {
        debugPrint('[WhatsAppOtp] HTTP $status : $resBody');
      }

      if (status == 200) {
        _phoneInProgress = phone;
        _codeHash = _hash(code);
        _expiresAt = DateTime.now().add(_validity);
        onCodeSent();
        return;
      }

      // Analyse de l'erreur Meta pour un message clair en francais.
      String message = 'Envoi WhatsApp impossible (HTTP $status).';
      try {
        final err = jsonDecode(resBody)['error'] as Map<String, dynamic>?;
        final errCode = err?['code'];
        if (errCode == 190 || errCode == 131005) {
          message = 'Jeton WhatsApp expire ou refuse. Contactez le support '
              'EKENGE pour renouveler le jeton d\'acces.';
        } else if (errCode == 131030) {
          message = 'Ce numero n\'est pas encore autorise a recevoir les '
              'messages WhatsApp de test. Ajoutez-le comme destinataire '
              'dans le tableau de bord Meta.';
        } else if (errCode == 131047) {
          message = 'Session WhatsApp expiree. Envoyez d\'abord un message '
              'WhatsApp au numero +1 (555) 655-2459 puis reessayez.';
        } else if (err?['message'] != null) {
          message = 'WhatsApp : ${err!['message']}';
        }
      } catch (_) {}
      onFailed(message);
    } on SocketException {
      onFailed('Pas de connexion internet. Verifiez votre reseau.');
    } catch (e) {
      onFailed('Envoi WhatsApp impossible : $e');
    }
  }

  /// Envoi d'un message WhatsApp libre (alertes Danger/Safe, invitations,
  /// confirmations de securite — §5, §7, §9, §10, §11 du cahier des charges).
  /// Retourne true si Meta a accepte le message. Ne lance jamais d'exception.
  ///
  /// ⚠️ Compte test Meta : seuls les destinataires enregistres dans le
  /// tableau de bord Meta recoivent reellement le message. En production
  /// (numero officiel EKENGE verifie), tous les numeros seront joignables.
  Future<bool> sendText(String phone, String message) async {
    final to = phone.startsWith('+') ? phone.substring(1) : phone;
    try {
      final (status, resBody) = await _postWithRetry(jsonEncode({
        'messaging_product': 'whatsapp',
        'to': to,
        'type': 'text',
        'text': {'body': message},
      }));
      if (kDebugMode) {
        debugPrint('[WhatsApp] sendText $to HTTP $status : $resBody');
      }
      return status == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('[WhatsApp] sendText erreur : $e');
      return false;
    }
  }

  /// Verifie le code saisi par l'utilisateur. Retourne true si le code
  /// correspond et n'a pas expire.
  bool verifyOtp(String phone, String code) {
    if (_codeHash == null || _expiresAt == null) return false;
    if (_phoneInProgress != phone) return false;
    if (DateTime.now().isAfter(_expiresAt!)) {
      _clear();
      return false;
    }
    final ok = _hash(code.trim()) == _codeHash;
    if (ok) _clear();
    return ok;
  }

  void _clear() {
    _codeHash = null;
    _expiresAt = null;
    _phoneInProgress = null;
  }
}
