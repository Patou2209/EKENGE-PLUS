import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_app_check/firebase_app_check.dart';
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
/// L'OTP passe EXCLUSIVEMENT par Firebase Phone Auth (vrai SMS) : aucun
/// mode simule. Les donnees (Firestore) gardent un cache local en secours.
class FirebaseBackend {
  FirebaseBackend._();
  static final FirebaseBackend instance = FirebaseBackend._();

  bool _initialized = false;
  bool get isReady => _initialized;

  fs.FirebaseFirestore get _db => fs.FirebaseFirestore.instance;
  fa.FirebaseAuth get _auth => fa.FirebaseAuth.instance;

  /// Initialisation au demarrage. Ne lance jamais d'exception : en cas
  /// d'echec l'app fonctionne en mode local.
  ///
  /// Meme configuration que le projet ImmoZone (OTP verifie et fonctionnel) :
  /// App Check active puis forceRecaptchaFlow desactive une fois pour toutes.
  Future<bool> init() async {
    if (_initialized) return true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (!kIsWeb) {
        // App Check : atteste l'application aupres de Firebase. Sans cette
        // activation, Play Integrity peut bloquer silencieusement l'envoi
        // du SMS OTP (observe : « aucune reponse de Firebase Auth »).
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.debug,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('AppCheck: $e');
        }
        // Flux Phone Auth silencieux (pas de page reCAPTCHA).
        try {
          await fa.FirebaseAuth.instance.setSettings(
            forceRecaptchaFlow: false,
            appVerificationDisabledForTesting: false,
          );
        } catch (_) {}
      }
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

  /// true si Android a valide automatiquement le SMS (connexion deja faite).
  bool autoVerified = false;

  /// Lance la verification du numero — COPIE EXACTE du flux ImmoZone
  /// (PhoneAuthService.verifyPhoneNumber, OTP verifie et fonctionnel) :
  /// - purement pilote par callbacks, AUCUNE attente ni timeout artificiel ;
  /// - l'appelant navigue vers l'ecran OTP DANS onCodeSent (le SMS est
  ///   alors reellement parti) ;
  /// - forceResendingToken uniquement pour les renvois (isResend).
  Future<void> startPhoneVerification({
    required String phone,
    required void Function() onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String message) onFailed,
    bool isResend = false,
  }) async {
    if (!_initialized) {
      onFailed(
        'Firebase non initialise sur cet appareil. '
        'Verifiez votre connexion internet puis relancez l\'application.',
      );
      return;
    }
    autoVerified = false;
    if (kDebugMode) {
      debugPrint('[PhoneAuth] verifyPhoneNumber: $phone isResend=$isResend');
    }
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        // 120 s : laisse le temps a Play Integrity de repondre (ImmoZone).
        timeout: const Duration(seconds: 120),
        // ImmoZone : jeton de renvoi UNIQUEMENT pour les renvois.
        forceResendingToken: isResend ? _resendToken : null,
        verificationCompleted: (fa.PhoneAuthCredential cred) async {
          // Android auto-retrieval : Firebase valide le SMS automatiquement.
          if (kDebugMode) debugPrint('[PhoneAuth] verificationCompleted');
          try {
            await _auth.signInWithCredential(cred);
            autoVerified = true;
            onAutoVerified();
          } on fa.FirebaseAuthException catch (e) {
            onFailed(_frenchAuthError(e));
          }
        },
        verificationFailed: (fa.FirebaseAuthException e) {
          if (kDebugMode) {
            debugPrint('[PhoneAuth] verificationFailed: ${e.code}');
          }
          onFailed(_frenchAuthError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (kDebugMode) debugPrint('[PhoneAuth] codeSent');
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (kDebugMode) debugPrint('[PhoneAuth] codeAutoRetrievalTimeout');
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      onFailed('Envoi du SMS impossible : $e');
    }
  }

  /// Verifie le code OTP saisi — identique a ImmoZone (signInWithCredential
  /// avec le verificationId recu dans codeSent).
  Future<bool> verifyRealOtp(String code) async {
    if (!_initialized) return false;
    // Android a deja valide le SMS automatiquement : l'utilisateur est
    // connecte, le code saisi n'a plus besoin d'etre verifie.
    if (autoVerified && _auth.currentUser != null) return true;
    if (_verificationId == null) return false;
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
        return 'Quota SMS du jour depasse. Reessayez demain.';
      case 'app-not-authorized':
        return 'Application non autorisee (empreinte SHA non reconnue). '
            'Code : app-not-authorized';
      case 'missing-client-identifier':
        return 'Verification d\'application impossible '
            '(Play Integrity/reCAPTCHA). Code : missing-client-identifier';
      case 'network-request-failed':
        return 'Pas de connexion internet. Verifiez votre reseau.';
      case 'invalid-app-credential':
        return 'Jeton de verification refuse. Code : invalid-app-credential';
      default:
        return 'Erreur [${e.code}] : ${e.message ?? ''}';
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

  // =========================================================================
  // §13 Boite de reception temps reel (Firestore)
  // =========================================================================

  StreamSubscription<fs.QuerySnapshot<Map<String, dynamic>>>? _inboxSub;
  final Set<String> _seenInbox = {};

  /// Ecoute en temps reel les messages push adresses a [phone] : toute
  /// nouvelle alerte apparait immediatement dans l'application (cloche),
  /// meme si la notification FCM systeme n'est pas delivree.
  void watchInbox(
    String phone,
    void Function(String kind, String body, String fromPhone) handler,
  ) {
    if (!_initialized) return;
    _inboxSub?.cancel();
    final startAt = DateTime.now().millisecondsSinceEpoch;
    try {
      _inboxSub = _db
          .collection('messages')
          .where('to_phone', isEqualTo: phone)
          .snapshots()
          .listen((snap) {
            for (final change in snap.docChanges) {
              if (change.type != fs.DocumentChangeType.added) continue;
              final id = change.doc.id;
              if (_seenInbox.contains(id)) continue;
              _seenInbox.add(id);
              final m = change.doc.data();
              if (m == null || m['channel'] != 'push') continue;
              // Ignore l'historique : seuls les messages recents sonnent.
              final at = (m['at'] as num?)?.toInt() ?? 0;
              if (at < startAt - 60000) continue;
              handler(
                (m['kind'] as String?) ?? '',
                (m['body'] as String?) ?? '',
                (m['from_phone'] as String?) ?? '',
              );
            }
          });
    } catch (e) {
      if (kDebugMode) debugPrint('watchInbox: $e');
    }
  }

  void stopWatchingInbox() {
    _inboxSub?.cancel();
    _inboxSub = null;
    _seenInbox.clear();
  }
}
