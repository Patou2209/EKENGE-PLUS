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
  // Utilise par le canal de secours OTP SMS (Firebase Phone Auth).
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
        // App Check — RECETTE IMMOZONE pour APK sideloade (hors Play Store) :
        // provider debug + token force dans AndroidManifest.xml
        // (com.google.firebase.appcheck.debug.force_debug_token), token
        // enregistre dans Firebase Console → App Check → Debug tokens.
        // Ainsi l'app est attestee sans Play Store et le SMS OTP part.
        // MISE EN PRODUCTION (Play Store) : passer a
        // AndroidProvider.playIntegrity et retirer le meta-data du manifest.
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.debug,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('AppCheck: $e');
        }
        // Flux Phone Auth silencieux (pas de page reCAPTCHA) — l'attestation
        // passe par le debug token App Check ci-dessus (recette ImmoZone).
        try {
          await fa.FirebaseAuth.instance.setSettings(
            forceRecaptchaFlow: false,
            appVerificationDisabledForTesting: false,
          );
        } catch (_) {}
      }
      _initialized = true;
      if (kDebugMode) debugPrint('Firebase initialisé (ekenge-plus)');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase indisponible : $e');
      _initialized = false;
      return false;
    }
  }

  // =========================================================================
  // §3 Authentification — OTP par VRAI SMS (Firebase Phone Auth)
  //
  // REACTIVE comme CANAL DE SECOURS : WhatsApp reste le canal principal ;
  // le SMS Firebase est propose quand l'utilisateur n'a pas WhatsApp
  // (bouton « Recevoir par SMS » sur l'ecran OTP) ou quand l'envoi
  // WhatsApp echoue. Flux FONCTIONNEL (App Check debug token via
  // MainActivity.kt + Enforcement ENFORCED sur Authentication).
  // =========================================================================

  String? _verificationId;
  int? _resendToken;

  /// true après un basculement automatique vers le flux reCAPTCHA (un seul
  /// re-essai par session pour éviter les boucles).
  bool _recaptchaRetried = false;

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
        'Firebase non initialisé sur cet appareil. '
        'Vérifiez votre connexion internet puis relancez l\'application.',
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
        verificationFailed: (fa.FirebaseAuthException e) async {
          if (kDebugMode) {
            debugPrint('[PhoneAuth] verificationFailed: ${e.code}');
          }
          // SECOURS AUTOMATIQUE : l'attestation App Check / Play Integrity
          // a échoué sur CE téléphone (APK hors Play Store, appareil sans
          // Play Services à jour...). On relance UNE fois la vérification
          // en forçant le flux reCAPTCHA (page web de vérification) qui
          // fonctionne sur n'importe quel appareil.
          if ((e.code == 'missing-client-identifier' ||
                  e.code == 'invalid-app-credential' ||
                  e.code == 'app-not-authorized') &&
              !_recaptchaRetried) {
            _recaptchaRetried = true;
            if (kDebugMode) {
              debugPrint('[PhoneAuth] retry avec flux reCAPTCHA');
            }
            try {
              await _auth.setSettings(forceRecaptchaFlow: true);
              await startPhoneVerification(
                phone: phone,
                onCodeSent: onCodeSent,
                onAutoVerified: onAutoVerified,
                onFailed: onFailed,
                isResend: false,
              );
              return;
            } catch (_) {}
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
        return 'Numéro de téléphone invalide. Format attendu : +243...';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'quota-exceeded':
        return 'Quota SMS du jour dépassé. Réessayez demain.';
      case 'app-not-authorized':
        return 'Application non autorisée (empreinte SHA non reconnue). '
            'Code : app-not-authorized';
      case 'missing-client-identifier':
        return 'Vérification d\'application impossible '
            '(Play Integrity/reCAPTCHA). Code : missing-client-identifier';
      case 'network-request-failed':
        return 'Pas de connexion internet. Vérifiez votre réseau.';
      case 'invalid-app-credential':
        return 'Jeton de vérification refusé. Code : invalid-app-credential';
      default:
        return 'Erreur [${e.code}] : ${e.message ?? ''}';
    }
  }
  // ===================== FIN OTP SMS (canal de secours) ====================

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

  /// Contacts SORTANTS enregistrés dans le cloud : les listes Tracking /
  /// Urgence de [ownerPhone]. Permet de restaurer les listes après une
  /// réinstallation ou si le stockage local a été vidé.
  Future<List<Map<String, dynamic>>> fetchOwnedContacts(
    String ownerPhone,
  ) async {
    if (!_initialized) return const [];
    try {
      final snap = await _db
          .collection('contacts')
          .where('owner_phone', isEqualTo: ownerPhone)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('fetchOwnedContacts: $e');
      return const [];
    }
  }

  /// Liens ENTRANTS : les personnes qui M'ONT ajouté à leurs contacts de
  /// sécurité (réciprocité §5 — j'apparais dans leur liste, elles doivent
  /// apparaître dans ma page Proches pour que je puisse les suivre).
  Future<List<Map<String, dynamic>>> fetchInboundLinks(String phone) async {
    if (!_initialized) return const [];
    try {
      final snap = await _db
          .collection('contacts')
          .where('phone', isEqualTo: phone)
          .get();
      final out = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final owner = (d['owner_phone'] as String?) ?? '';
        if (owner.isEmpty || owner == phone) continue;
        // Nom réel du propriétaire depuis son compte.
        String name = owner;
        final u = await fetchUser(owner);
        if (u != null) {
          final fn = (u['first_name'] as String?) ?? '';
          final ln = (u['last_name'] as String?) ?? '';
          final full = '$fn $ln'.trim();
          if (full.isNotEmpty) name = full;
        }
        out.add({'phone': owner, 'name': name});
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('fetchInboundLinks: $e');
      return const [];
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

  /// Flux TEMPS RÉEL de la position publiée par [phone] (doc positions/…).
  /// Émet null tant qu'aucune position n'a été publiée.
  Stream<GeoPoint?> positionStream(String phone) {
    if (!_initialized) return const Stream.empty();
    return _db.collection('positions').doc(phone).snapshots().map((doc) {
      final d = doc.data();
      if (d == null) return null;
      final lat = (d['lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return GeoPoint(
        lat: lat,
        lng: lng,
        at: DateTime.fromMillisecondsSinceEpoch(
          (d['at'] as num?)?.toInt() ?? 0,
        ),
        speedKmh: (d['speed_kmh'] as num?)?.toDouble() ?? 0,
      );
    });
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

  // =========================================================================
  // ADMINISTRATION — comptes admin, KPI, publicités
  // =========================================================================

  /// Le numéro est-il administrateur ?
  Future<bool> isAdmin(String phone) async {
    if (!_initialized) return false;
    try {
      final d = await _db.collection('admins').doc(phone).get();
      return d.exists;
    } catch (_) {
      return false;
    }
  }

  /// Crée un nouvel administrateur (au même titre que le créateur).
  Future<void> addAdmin(String phone, String createdBy) async {
    if (!_initialized) return;
    await _db.collection('admins').doc(phone).set({
      'phone': phone,
      'role': 'admin',
      'created_by': createdBy,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, fs.SetOptions(merge: true));
  }

  Future<void> removeAdmin(String phone) async {
    if (!_initialized) return;
    await _db.collection('admins').doc(phone).delete();
  }

  Future<List<Map<String, dynamic>>> listAdmins() async {
    if (!_initialized) return const [];
    try {
      final snap = await _db.collection('admins').get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Présence : horodatage « vu en ligne » rafraîchi périodiquement.
  Future<void> heartbeat(String phone) async {
    if (!_initialized) return;
    try {
      await _db.collection('users').doc(phone).set({
        'last_seen': DateTime.now().millisecondsSinceEpoch,
      }, fs.SetOptions(merge: true));
    } catch (_) {}
  }

  /// Garantit que le document utilisateur possède un `created_at` : les
  /// anciens documents (créés uniquement par heartbeat/FCM) en étaient
  /// dépourvus, ce qui faussait les statistiques admin. Appelé une seule
  /// fois par session au démarrage.
  Future<void> ensureCreatedAt(String phone, {int? fallbackMs}) async {
    if (!_initialized) return;
    try {
      final ref = _db.collection('users').doc(phone);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null) return;
      final existing = (data['created_at'] as num?)?.toInt() ?? 0;
      if (existing > 0) return;
      await ref.set({
        'created_at': fallbackMs ?? DateTime.now().millisecondsSinceEpoch,
      }, fs.SetOptions(merge: true));
    } catch (_) {}
  }

  /// Session de tracking terminée : durée enregistrée pour les KPI.
  Future<void> logTrackingSession(
    String phone,
    DateTime start,
    DateTime end,
  ) async {
    if (!_initialized) return;
    try {
      await _db.collection('tracking_sessions').add({
        'phone': phone,
        'started_at': start.millisecondsSinceEpoch,
        'ended_at': end.millisecondsSinceEpoch,
        'duration_s': end.difference(start).inSeconds,
      });
    } catch (_) {}
  }

  /// Appui sur le bouton Urgence (KPI 6 et graphique 10).
  Future<void> logPanicPress(String phone) async {
    if (!_initialized) return;
    try {
      await _db.collection('panic_events').add({
        'phone': phone,
        'at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// Charge toutes les données nécessaires au tableau de bord admin.
  Future<AdminData> fetchAdminData() async {
    if (!_initialized) return AdminData.empty();
    try {
      final users = await _db.collection('users').get();
      final sessions = await _db.collection('tracking_sessions').get();
      final panics = await _db.collection('panic_events').get();
      final now = DateTime.now().millisecondsSinceEpoch;

      final accounts = <({int createdAt, int lastSeen})>[];
      for (final d in users.docs) {
        final m = d.data();
        accounts.add((
          createdAt: (m['created_at'] as num?)?.toInt() ?? 0,
          lastSeen: (m['last_seen'] as num?)?.toInt() ?? 0,
        ));
      }
      final trackingList = <({int startedAt, int durationS})>[];
      for (final d in sessions.docs) {
        final m = d.data();
        trackingList.add((
          startedAt: (m['started_at'] as num?)?.toInt() ?? 0,
          durationS: (m['duration_s'] as num?)?.toInt() ?? 0,
        ));
      }
      final panicTimes = <int>[
        for (final d in panics.docs) (d.data()['at'] as num?)?.toInt() ?? 0,
      ];
      return AdminData(
        now: now,
        accounts: accounts,
        sessions: trackingList,
        panicTimes: panicTimes,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('fetchAdminData: $e');
      return AdminData.empty();
    }
  }

  // ---- Publicités ---------------------------------------------------------

  /// Publicités actives (max 5, non expirées) pour l'affichage utilisateur.
  Future<List<Map<String, dynamic>>> fetchActiveAds() async {
    if (!_initialized) return const [];
    try {
      final snap = await _db.collection('ads').get();
      final now = DateTime.now().millisecondsSinceEpoch;
      final list = snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .where((a) => ((a['expires_at'] as num?)?.toInt() ?? 0) > now)
          .toList();
      list.sort(
        (a, b) => ((b['created_at'] as num?)?.toInt() ?? 0).compareTo(
          (a['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
      return list.take(5).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Toutes les publicités (admin), y compris expirées.
  Future<List<Map<String, dynamic>>> fetchAllAds() async {
    if (!_initialized) return const [];
    try {
      final snap = await _db.collection('ads').get();
      final list = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      list.sort(
        (a, b) => ((b['created_at'] as num?)?.toInt() ?? 0).compareTo(
          (a['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Publie une publicité. L'image est choisie depuis le STOCKAGE LOCAL
  /// du téléphone (encodée en base64). Format imposé : petite bannière
  /// discrète de 100 px de hauteur, pleine largeur. [displaySeconds]
  /// définit la durée d'affichage à l'écran (5 s, 10 s, etc.) après quoi
  /// la bannière disparaît pour ne pas gêner la vue de l'utilisateur.
  Future<String?> createAd({
    required String title,
    required String imageB64,
    required String targetUrl,
    required int displaySeconds,
    required String createdBy,
  }) async {
    if (!_initialized) return 'Backend indisponible';
    final active = await fetchActiveAds();
    if (active.length >= 5) {
      return 'Limite atteinte : 5 publicités actives maximum.';
    }
    final now = DateTime.now();
    await _db.collection('ads').add({
      'title': title,
      'image_b64': imageB64,
      'target_url': targetUrl,
      'display_seconds': displaySeconds,
      'created_by': createdBy,
      'created_at': now.millisecondsSinceEpoch,
      // Campagne active 30 jours ; supprimable à tout moment par l'admin.
      'expires_at': now.add(const Duration(days: 30)).millisecondsSinceEpoch,
      'impressions': 0,
      'clicks': 0,
    });
    return null;
  }

  Future<void> deleteAd(String id) async {
    if (!_initialized) return;
    try {
      await _db.collection('ads').doc(id).delete();
    } catch (_) {}
  }

  /// Statistique : la publicité a été affichée.
  Future<void> logAdImpression(String id) async {
    if (!_initialized) return;
    try {
      await _db.collection('ads').doc(id).update({
        'impressions': fs.FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Statistique : la publicité a été touchée.
  Future<void> logAdClick(String id) async {
    if (!_initialized) return;
    try {
      await _db.collection('ads').doc(id).update({
        'clicks': fs.FieldValue.increment(1),
      });
    } catch (_) {}
  }
}

/// Données brutes du tableau de bord admin (calculs côté application pour
/// éviter tout index composite Firestore).
class AdminData {
  final int now;
  final List<({int createdAt, int lastSeen})> accounts;
  final List<({int startedAt, int durationS})> sessions;
  final List<int> panicTimes;

  const AdminData({
    required this.now,
    required this.accounts,
    required this.sessions,
    required this.panicTimes,
  });

  factory AdminData.empty() => const AdminData(
    now: 0,
    accounts: [],
    sessions: [],
    panicTimes: [],
  );

  /// KPI 1 : nombre total de comptes.
  int get totalAccounts => accounts.length;

  /// KPI 2 : comptes en ligne à l'instant (vu < 5 min).
  int get onlineNow =>
      accounts.where((a) => now - a.lastSeen < 5 * 60 * 1000).length;

  /// KPI 3 : comptes connectés sur la période (last_seen dans la fenêtre).
  int activeWithin(Duration d) =>
      accounts.where((a) => now - a.lastSeen < d.inMilliseconds).length;

  /// KPI 4 : nouveaux comptes sur la période.
  int newWithin(Duration d) =>
      accounts.where((a) => now - a.createdAt < d.inMilliseconds).length;

  /// KPI 5 : durée moyenne de tracking (secondes).
  int get avgTrackingSeconds {
    if (sessions.isEmpty) return 0;
    final total = sessions.fold<int>(0, (s, e) => s + e.durationS);
    return total ~/ sessions.length;
  }

  /// KPI 6 : appuis Urgence sur la période.
  int panicWithin(Duration d) =>
      panicTimes.where((t) => now - t < d.inMilliseconds).length;

  /// Série par intervalle pour les graphiques : [buckets] valeurs.
  List<int> _series(
    List<int> times,
    Duration period,
    int buckets, {
    bool cumulative = false,
    int baseline = 0,
  }) {
    final start = now - period.inMilliseconds;
    final step = period.inMilliseconds / buckets;
    final out = List<int>.filled(buckets, 0);
    for (final t in times) {
      if (t < start || t > now) continue;
      final i = ((t - start) / step).floor().clamp(0, buckets - 1);
      out[i]++;
    }
    if (cumulative) {
      var run = baseline;
      for (var i = 0; i < buckets; i++) {
        run += out[i];
        out[i] = run;
      }
    }
    return out;
  }

  /// Graphique 7 : évolution du TOTAL de comptes (cumulé).
  ///
  /// Les comptes sans `created_at` (anciens documents) sont comptés dans la
  /// base de départ : ils existaient déjà avant la fenêtre affichée. Ainsi le
  /// dernier point du graphique correspond toujours au total réel de comptes.
  List<int> accountsTotalSeries(Duration p, int buckets) {
    final start = now - p.inMilliseconds;
    // createdAt == 0 (champ manquant) => compte antérieur à la fenêtre.
    final before = accounts.where((a) => a.createdAt < start).length;
    return _series(
      accounts.map((a) => a.createdAt).toList(),
      p,
      buckets,
      cumulative: true,
      baseline: before,
    );
  }

  /// Graphique 8 : nouveaux comptes (non cumulés).
  List<int> newAccountsSeries(Duration p, int buckets) =>
      _series(accounts.map((a) => a.createdAt).toList(), p, buckets);

  /// Graphique 9 : sessions de tracking démarrées.
  List<int> trackingSeries(Duration p, int buckets) =>
      _series(sessions.map((s) => s.startedAt).toList(), p, buckets);

  /// Graphique 10 : utilisation du bouton Urgence.
  List<int> panicSeries(Duration p, int buckets) =>
      _series(panicTimes, p, buckets);
}
