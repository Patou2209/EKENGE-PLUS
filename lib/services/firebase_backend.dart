import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/models.dart';

/// EKENGE PLUS — Backend Firebase reel (§13 du cahier des charges).
///
/// - Firebase Authentication : OTP par vrai SMS (verifyPhoneNumber)
/// - Cloud Firestore : users, contacts, positions, alerts, events, messages
/// - Firebase Cloud Messaging : jeton d'appareil pour notifications push
///
/// En cas d'indisponibilite (preview web sans reseau, quota SMS...), les
/// appelants retombent sur le backend local — l'app reste utilisable.
class FirebaseBackend {
  FirebaseBackend._();
  static final FirebaseBackend instance = FirebaseBackend._();

  bool _initialized = false;
  bool get isReady => _initialized;

  fs.FirebaseFirestore get _db => fs.FirebaseFirestore.instance;
  fa.FirebaseAuth get _auth => fa.FirebaseAuth.instance;

  /// Initialisation au demarrage. Ne lance jamais d'exception : en cas
  /// d'echec l'app fonctionne en mode local.
  Future<bool> init() async {
    if (_initialized) return true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      if (kDebugMode) debugPrint('Firebase initialise (ekenge-plus)');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase indisponible : $e');
      _initialized = false;
      return false;
    }
  }

  // =========================================================================
  // §3 Authentification — OTP par VRAI SMS (Firebase Phone Auth)
  // =========================================================================

  String? _verificationId;
  int? _resendToken;

  /// Envoie un vrai SMS OTP au numero fourni (format E.164 : +243...).
  /// Retourne true si l'envoi est engage, false si Firebase indisponible.
  Future<bool> sendRealOtp(
    String phone, {
    required void Function(String error) onError,
    void Function()? onCodeSent,
    void Function()? onAutoVerified,
  }) async {
    if (!_initialized) return false;
    try {
      final completer = Completer<bool>();
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (fa.PhoneAuthCredential cred) async {
          // Android peut valider automatiquement le SMS recu.
          try {
            await _auth.signInWithCredential(cred);
            onAutoVerified?.call();
          } catch (_) {}
        },
        verificationFailed: (fa.FirebaseAuthException e) {
          onError(_frenchAuthError(e));
          if (!completer.isCompleted) completer.complete(false);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent?.call();
          if (!completer.isCompleted) completer.complete(true);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (!completer.isCompleted) completer.complete(true);
        },
      );
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => _verificationId != null,
      );
    } catch (e) {
      onError('Envoi du SMS impossible : $e');
      return false;
    }
  }

  /// Verifie le code OTP recu par SMS.
  Future<bool> verifyRealOtp(String code) async {
    if (!_initialized || _verificationId == null) return false;
    try {
      final cred = fa.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code.trim(),
      );
      await _auth.signInWithCredential(cred);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _frenchAuthError(fa.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Numero de telephone invalide. Format attendu : +243...';
      case 'too-many-requests':
        return 'Trop de tentatives. Reessayez plus tard.';
      case 'quota-exceeded':
        return 'Quota SMS du jour depasse (plan gratuit). Reessayez demain.';
      default:
        return 'Erreur d\'authentification : ${e.message ?? e.code}';
    }
  }

  // =========================================================================
  // Firestore — Utilisateurs (§3)
  // =========================================================================

  Future<bool> userExists(String phone) async {
    if (!_initialized) return false;
    try {
      final d = await _db.collection('users').doc(phone).get();
      return d.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveUser(EkUser u) async {
    if (!_initialized) return;
    try {
      await _db.collection('users').doc(u.phone).set({
        'phone': u.phone,
        'first_name': u.firstName,
        'last_name': u.lastName,
        'password_hash': u.passwordHash,
        'salt': u.salt,
        'created_at': u.createdAt.millisecondsSinceEpoch,
        'fcm_token': await fcmToken(),
      }, fs.SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('saveUser: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchUser(String phone) async {
    if (!_initialized) return null;
    try {
      final d = await _db.collection('users').doc(phone).get();
      return d.data();
    } catch (_) {
      return null;
    }
  }

  // =========================================================================
  // Firestore — Contacts des listes (§4)
  // =========================================================================

  Future<void> saveContact(String ownerPhone, SafetyContact c) async {
    if (!_initialized) return;
    try {
      await _db.collection('contacts').doc('${ownerPhone}_${c.phone}').set({
        'owner_phone': ownerPhone,
        'name': c.name,
        'phone': c.phone,
        'in_tracking': c.inTracking,
        'in_urgence': c.inUrgence,
        'sync_status': c.sync.name,
        'added_at': fs.FieldValue.serverTimestamp(),
      }, fs.SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('saveContact: $e');
    }
  }

  Future<void> deleteContact(String ownerPhone, String contactPhone) async {
    if (!_initialized) return;
    try {
      await _db
          .collection('contacts')
          .doc('${ownerPhone}_$contactPhone')
          .delete();
    } catch (_) {}
  }

  // =========================================================================
  // Firestore — Geolocalisation temps reel (§6, §12)
  // =========================================================================

  Future<void> pushPosition(String phone, GeoPoint p) async {
    if (!_initialized) return;
    try {
      await _db.collection('positions').doc(phone).set({
        'phone': phone,
        'lat': p.lat,
        'lng': p.lng,
        'speed_kmh': p.speedKmh,
        'at': p.at.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // =========================================================================
  // Firestore — Alertes (§7, §9) et journal (§12)
  // =========================================================================

  Future<void> pushAlert({
    required String phone,
    required String kind,
    required DateTime startedAt,
    GeoPoint? position,
  }) async {
    if (!_initialized) return;
    try {
      await _db.collection('alerts').add({
        'phone': phone,
        'kind': kind,
        'started_at': startedAt.millisecondsSinceEpoch,
        'resolved_at': null,
        'lat': position?.lat,
        'lng': position?.lng,
      });
    } catch (_) {}
  }

  Future<void> pushEvent({
    required String phone,
    required String type,
    required String title,
    required String detail,
  }) async {
    if (!_initialized) return;
    try {
      await _db.collection('events').add({
        'phone': phone,
        'type': type,
        'title': title,
        'detail': detail,
        'at': fs.FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> pushMessage(OutboundMessage m, String fromPhone) async {
    if (!_initialized) return;
    try {
      await _db.collection('messages').add({
        'from_phone': fromPhone,
        'to_phone': m.recipientPhone,
        'to_name': m.recipientName,
        'channel': m.channel.name,
        'kind': m.kind,
        'body': m.body,
        'at': m.at.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // =========================================================================
  // §11 Sessions visiteur
  // =========================================================================

  Future<void> saveGuestSession({
    required String token,
    required String guestName,
    required bool sharing,
    required List<Map<String, String>> followers,
    DateTime? startedAt,
  }) async {
    if (!_initialized) return;
    try {
      await _db.collection('guest_sessions').doc(token).set({
        'token': token,
        'guest_name': guestName,
        'sharing': sharing,
        'started_at': startedAt?.millisecondsSinceEpoch,
        'followers': followers,
        'updated_at': fs.FieldValue.serverTimestamp(),
      }, fs.SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> pushGuestPosition(String token, GeoPoint p) async {
    if (!_initialized) return;
    try {
      await _db.collection('guest_sessions').doc(token).set({
        'last_lat': p.lat,
        'last_lng': p.lng,
        'last_at': p.at.millisecondsSinceEpoch,
      }, fs.SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> endGuestSession(String token) async {
    if (!_initialized) return;
    try {
      await _db.collection('guest_sessions').doc(token).delete();
    } catch (_) {}
  }

  // =========================================================================
  // §9 Escalade serveur — etat de securite (interrupteur homme-mort)
  // =========================================================================

  /// Publie l'etat Safe de l'utilisateur : le serveur (Cloud Function
  /// escalationTick) surveille ce document et declenche N1/N2 meme si le
  /// telephone est eteint ou detruit.
  Future<void> saveSafetyStatus({
    required String phone,
    required bool trackingActive,
    required bool safeEnabled,
    DateTime? nextCheckAt,
    required String state, // ok | level1 | level2
    DateTime? level1At,
    GeoPoint? lastPosition,
  }) async {
    if (!_initialized) return;
    try {
      await _db.collection('safety_status').doc(phone).set({
        'phone': phone,
        'tracking_active': trackingActive,
        'safe_enabled': safeEnabled,
        'next_check_at': nextCheckAt?.millisecondsSinceEpoch,
        'state': state,
        'level1_at': level1At?.millisecondsSinceEpoch,
        'last_lat': lastPosition?.lat,
        'last_lng': lastPosition?.lng,
        'confirm_grace_ms': 120000,
        'level2_delay_ms': 900000,
        'updated_at': fs.FieldValue.serverTimestamp(),
      }, fs.SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('saveSafetyStatus: $e');
    }
  }

  // =========================================================================
  // FCM — jeton et reception des notifications push (§13)
  // =========================================================================

  Future<String?> fcmToken() async {
    if (!_initialized || kIsWeb) return null;
    try {
      await FirebaseMessaging.instance.requestPermission();
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Rafraichit le jeton FCM de l'utilisateur dans Firestore (au demarrage).
  Future<void> refreshFcmToken(String phone) async {
    if (!_initialized || kIsWeb) return;
    try {
      final t = await fcmToken();
      if (t == null) return;
      await _db.collection('users').doc(phone).set({
        'fcm_token': t,
      }, fs.SetOptions(merge: true));
      FirebaseMessaging.instance.onTokenRefresh.listen((nt) {
        _db.collection('users').doc(phone).set({
          'fcm_token': nt,
        }, fs.SetOptions(merge: true));
      });
    } catch (_) {}
  }

  /// Ecoute les notifications FCM recues app ouverte (premier plan).
  void onForegroundMessage(void Function(String title, String body) handler) {
    if (!_initialized || kIsWeb) return;
    try {
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) {
          handler(n.title ?? 'EKENGE PLUS', n.body ?? '');
        }
      });
    } catch (_) {}
  }
}
