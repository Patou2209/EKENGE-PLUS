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

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class WhatsAppOtp {
  WhatsAppOtp._();
  static final WhatsAppOtp instance = WhatsAppOtp._();

  // --- Identifiants WhatsApp Cloud API (compte test Meta) -------------------
  static const String _phoneNumberId = '1202711136269311';
  // TODO(production) : remplacer par un System User token permanent.
  static const String _accessToken =
      'EAATgUQZB8y1cBSa6ZCno3j8o8NRAJ7IRiloJETUUm1UkJ7ZClbsIM2WckWZCYrO4aF'
      'JZAF5ZASFF87nJZAedh6LzZCYQLWBRcD8geGTTq2UMUcnYbMkM9gfEW5Kpbm7vHCJPz'
      'CSAo07TrAzUqlSrI5AKx7I1z6WyZAilGuZBRa32Eed0LEVsZAD3xMHD9lFic7WtVnh8'
      'tv7OCgZCIPAi5UKI23D97nZBpdeukL2EwnPmKaatjpy9dkQ0LaHCW5IeAPjNxBSKtPZ'
      'BpTGsGeifJmkE818xZB5';

  static const Duration _validity = Duration(minutes: 10);

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
      final client = HttpClient();
      final req = await client.postUrl(
        Uri.parse(
          'https://graph.facebook.com/v25.0/$_phoneNumberId/messages',
        ),
      );
      req.headers.set('Authorization', 'Bearer $_accessToken');
      req.headers.contentType = ContentType.json;
      req.write(body);
      final res = await req.close().timeout(const Duration(seconds: 30));
      final resBody = await res.transform(utf8.decoder).join();
      client.close();

      if (kDebugMode) {
        debugPrint('[WhatsAppOtp] HTTP ${res.statusCode} : $resBody');
      }

      if (res.statusCode == 200) {
        _phoneInProgress = phone;
        _codeHash = _hash(code);
        _expiresAt = DateTime.now().add(_validity);
        onCodeSent();
        return;
      }

      // Analyse de l'erreur Meta pour un message clair en francais.
      String message =
          'Envoi WhatsApp impossible (HTTP ${res.statusCode}).';
      try {
        final err = jsonDecode(resBody)['error'] as Map<String, dynamic>?;
        final errCode = err?['code'];
        if (errCode == 190) {
          message = 'Jeton WhatsApp expire. Contactez le support EKENGE '
              'pour renouveler le jeton d\'acces.';
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
