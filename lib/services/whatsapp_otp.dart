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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class WhatsAppOtp {
  WhatsAppOtp._();
  static final WhatsAppOtp instance = WhatsAppOtp._();

  // --- Identifiants WhatsApp Cloud API --------------------------------------
  // Numero de TEST Meta par defaut. En production, le champ phone_number_id
  // du document Firestore app_config/whatsapp prend le dessus : la bascule
  // vers le numero officiel EKENGE se fait SANS reinstaller l'application.
  static const String _phoneNumberId = '1202711136269311';
  // Jeton PERMANENT (System User, n'expire jamais) — verifie le 2025-08-31.
  // Peut aussi etre mis a jour a distance via Firestore app_config/whatsapp.
  static const String _accessToken =
      'EAATgUQZB8y1cBSSdz4WeHdAd7jkxL7tnFEEOCBhX1uF4opBDuKtdWJwdHat7r5wM7'
      'FPUo84Lai4oKEeWWZCO0Aut6XeaumhIk4NIA7wLH1KydYoc74ZBLy7ei3ZBUQ6ZC1x'
      'psZCIgz7xBzV0JP5Ml9U9njZCqH6bQNUomoZALw6K2gKa8Nk410h5VdZAZB36vZB6g'
      'ZDZD';

  static const Duration _validity = Duration(minutes: 10);

  // --- Configuration dynamique ----------------------------------------------
  // TOUTE la configuration WhatsApp est lue en priorite dans Firestore
  // (document app_config/whatsapp) : jeton, numero d'expedition et modele
  // OTP peuvent ainsi etre changes SANS reinstaller l'application
  // (indispensable pour la bascule test -> production).
  //   access_token       : jeton d'acces Meta
  //   phone_number_id    : ID du numero expediteur (test ou production)
  //   otp_template_name  : nom du modele OTP approuve
  //   otp_template_lang  : langue du modele (en_US, fr...)
  //   otp_template_type  : 'utility3' (3 parametres texte, mode test actuel)
  //                        ou 'authentication' (vrai modele OTP production)
  Map<String, dynamic>? _cachedConfig;

  Future<Map<String, dynamic>> _config({bool refresh = false}) async {
    if (!refresh && _cachedConfig != null) return _cachedConfig!;
    try {
      final doc = await fs.FirebaseFirestore.instance
          .collection('app_config')
          .doc('whatsapp')
          .get()
          .timeout(const Duration(seconds: 8));
      final d = doc.data();
      if (d != null && (d['access_token'] as String?)?.isNotEmpty == true) {
        _cachedConfig = d;
        return d;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[WhatsApp] lecture config Firestore : $e');
    }
    _cachedConfig = {'access_token': _accessToken};
    return _cachedConfig!;
  }

  Future<String> _token({bool refresh = false}) async =>
      (await _config(refresh: refresh))['access_token'] as String? ??
      _accessToken;

  Future<String> _senderId() async =>
      (await _config())['phone_number_id'] as String? ?? _phoneNumberId;

  /// Envoi brut vers l'API Meta. Retourne (statusCode, corps).
  Future<(int, String)> _post(String token, String jsonBody) async {
    final sender = await _senderId();
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse(
          'https://graph.facebook.com/v25.0/$sender/messages',
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
      // Recharge TOUTE la config (jeton + numero) depuis Firestore.
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

    // ⚠️ LIVRAISON WhatsApp : un message TEXTE LIBRE n'est remis que si le
    // destinataire a ecrit au numero EKENGE dans les dernieres 24 h
    // (fenetre de session Meta). Un MODELE (template) approuve est remis
    // SANS session. Le modele utilise est configurable a distance via
    // Firestore : en production, il suffira d'y renseigner le vrai modele
    // AUTHENTICATION cree sur le WABA officiel EKENGE (otp_template_type =
    // 'authentication') — aucune reinstallation necessaire.
    final cfg = await _config();
    final tplName = cfg['otp_template_name'] as String? ??
        'jaspers_market_order_confirmation_v1';
    final tplLang = cfg['otp_template_lang'] as String? ?? 'en_US';
    final tplType = cfg['otp_template_type'] as String? ?? 'utility3';

    final List<Map<String, dynamic>> components;
    if (tplType == 'authentication') {
      // Vrai modele AUTHENTICATION Meta : corps = {{1}} = code, plus le
      // bouton « copier le code » obligatoire (sub_type url, index 0).
      components = [
        {
          'type': 'body',
          'parameters': [
            {'type': 'text', 'text': code},
          ],
        },
        {
          'type': 'button',
          'sub_type': 'url',
          'index': '0',
          'parameters': [
            {'type': 'text', 'text': code},
          ],
        },
      ];
    } else {
      // Mode test : modele UTILITY 3 parametres transportant le code.
      components = [
        {
          'type': 'body',
          'parameters': [
            {'type': 'text', 'text': 'EKENGE PLUS'},
            {'type': 'text', 'text': 'votre code de verification : $code'},
            {'type': 'text', 'text': 'valable 10 minutes'},
          ],
        },
      ];
    }

    final templateBody = jsonEncode({
      'messaging_product': 'whatsapp',
      'to': to,
      'type': 'template',
      'template': {
        'name': tplName,
        'language': {'code': tplLang},
        'components': components,
      },
    });
    // Message texte clair (remis en plus si une session est ouverte).
    final textBody = jsonEncode({
      'messaging_product': 'whatsapp',
      'to': to,
      'type': 'text',
      'text': {
        'body': 'EKENGE PLUS\n\nVotre code de verification : $code\n\n'
            'Ce code expire dans 10 minutes. Ne le partagez avec personne.',
      },
    });

    try {
      final (status, resBody) = await _postWithRetry(templateBody);
      // Texte libre en bonus (best-effort, ne conditionne pas le succes).
      unawaited(_postWithRetry(textBody).catchError((_) => (0, '')));

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
