import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'alarm_sound.dart';
import 'backend.dart';
import 'contacts_service.dart';
import 'firebase_backend.dart';
import 'location_service.dart';
import 'whatsapp_otp.dart';

/// Notification Push recue par l'utilisateur (§11).
class PushNotification {
  final String id;
  final String title;
  final String body;
  final DateTime at;
  final AlertKind severity;
  bool read;

  PushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.severity,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'at': at.toIso8601String(),
    'severity': severity.name,
    'read': read,
  };

  static PushNotification fromJson(Map<String, dynamic> j) => PushNotification(
    id: j['id'] as String,
    title: (j['title'] as String?) ?? '',
    body: (j['body'] as String?) ?? '',
    at: DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
    severity: AlertKind.values.firstWhere(
      (v) => v.name == j['severity'],
      orElse: () => AlertKind.none,
    ),
    read: (j['read'] as bool?) ?? false,
  );
}

/// EKENGE PLUS — Moteur d'etat central.
///
/// Implemente les mecanismes du cahier des charges :
/// §6 Tracking, §7 Danger, §8 Safe, §9 Escalade, §10 Je suis en securite,
/// §11 Notifications, §12 Journalisation.
class EkState extends ChangeNotifier {
  EkState() {
    _locSub = LocationService.instance.stream.listen(_onPosition);
  }

  final Backend _be = Backend.instance;
  final FirebaseBackend _fb = FirebaseBackend.instance;
  StreamSubscription<GeoPoint>? _locSub;

  /// true lorsque le backend Firebase (Auth/Firestore/FCM) est operationnel.
  bool get firebaseReady => _fb.isReady;

  // ---- Session ----------------------------------------------------------
  EkUser? user;
  bool bootstrapped = false;
  bool get isLoggedIn => user != null;

  /// §4 : configuration obligatoire des listes a la premiere connexion.
  bool listsConfigured = false;

  /// §15 : autorisations mobiles.
  bool contactsPermission = false;
  bool locationPermission = false;

  // ---- Listes de securite (§4) -----------------------------------------
  final List<SafetyContact> contacts = [];

  List<SafetyContact> get trackingList =>
      contacts.where((c) => c.inTracking).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<SafetyContact> get urgenceList =>
      contacts.where((c) => c.inUrgence).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  // ---- Tracking (§6) ----------------------------------------------------
  bool trackingActive = false;
  DateTime? trackingStartedAt;
  final List<GeoPoint> trail = [];
  GeoPoint? position;

  // ---- Safe (§8) --------------------------------------------------------
  /// Frequence de verification en minutes (15, 30, 60 ou personnalisee).
  int safeIntervalMinutes = 30;
  bool safeEnabled = true;

  /// Echeance de la prochaine verification.
  DateTime? nextSafeCheck;

  /// Une verification est en cours : l'alarme sonne, l'utilisateur doit
  /// cliquer sur « Je suis en securite ».
  bool safeCheckPending = false;
  DateTime? safeCheckRaisedAt;

  /// Delai laisse a l'utilisateur pour confirmer avant l'escalade Niveau 1.
  static const int confirmWindowSeconds = 120;

  /// §9 Niveau 2 : 15 minutes apres l'alerte preventive.
  static const int level2DelayMinutes = 15;

  // ---- Alerte active (§7, §9, §10) -------------------------------------
  ActiveAlert? activeAlert;
  DateTime? level1At;

  // ---- Journal et sorties ----------------------------------------------
  final List<EkEvent> journal = [];
  final List<OutboundMessage> outbox = [];
  final List<PushNotification> inbox = [];

  int get unreadCount => inbox.where((n) => !n.read).length;

  // ---- Proches suivis (§5) ---------------------------------------------
  final List<WatchedUser> watched = [];

  // ---- Horloge interne --------------------------------------------------
  Timer? _tick;

  /// Mode demonstration : compresse le temps (1 minute = 1 seconde) afin de
  /// pouvoir observer les cycles Safe et l'escalade Niveau 1 / Niveau 2.
  bool demoTimeScale = true;
  int get _scale => demoTimeScale ? 60 : 1;

  // =======================================================================
  // Amorcage
  // =======================================================================
  Future<void> bootstrap() async {
    // Initialisation Firebase (Auth / Firestore / FCM). Non bloquant :
    // en cas d'echec l'application fonctionne en mode local.
    await _fb.init();
    final phone = await _be.session();
    if (phone != null) {
      user = await _be.loadUser(phone);
      if (user != null) await _restore();
    }
    if (user != null) {
      _wireInbound(user!.phone);
    }
    bootstrapped = true;
    notifyListeners();
  }

  /// §13 : branche la reception des alertes pour cet utilisateur.
  /// Non bloquant : le demarrage de l'app n'attend jamais ces operations
  /// (la demande de permission notifications peut prendre plusieurs
  /// secondes sur Android 13+).
  void _wireInbound(String phone) {
    // Jeton FCM a jour pour recevoir les notifications push.
    unawaited(_fb.refreshFcmToken(phone));
    // Notifications FCM recues quand l'app est au premier plan.
    _fb.onForegroundMessage((title, body) {
      _pushToSelf(title, body, _severityFromTitle(title));
      AlarmSound.instance.chirp();
      notifyListeners();
    });
    // Ecoute Firestore temps reel : toute alerte qui m'est adressee
    // apparait dans la cloche de l'application, meme sans FCM.
    _fb.watchInbox(phone, (kind, body, fromPhone) {
      final title = switch (kind) {
        'danger' => 'ALERTE DANGER',
        'safe_level1' => 'Niveau 1 · Alerte preventive',
        'safe_level2' => 'Niveau 2 · ALERTE CRITIQUE',
        'safe_confirmed' => 'Securite confirmee',
        'tracking_start' => 'Partage de localisation',
        'tracking_stop' => 'Partage termine',
        _ => 'EKENGE PLUS',
      };
      _pushToSelf(title, body, _severityFromTitle(title));
      if (kind == 'danger' || kind == 'safe_level2') {
        AlarmSound.instance.chirp();
      }
      notifyListeners();
    });
  }

  static AlertKind _severityFromTitle(String title) {
    final t = title.toUpperCase();
    if (t.contains('CRITIQUE') || t.contains('DANGER')) {
      return AlertKind.danger;
    }
    if (t.contains('NIVEAU 1') || t.contains('PREVENTIVE')) {
      return AlertKind.safeLevel1;
    }
    return AlertKind.none;
  }

  Future<void> _restore() async {
    final doc = await _be.readDoc(user!.phone);
    listsConfigured = (doc['lists_configured'] as bool?) ?? false;
    contactsPermission = (doc['contacts_permission'] as bool?) ?? false;
    locationPermission = (doc['location_permission'] as bool?) ?? false;
    safeIntervalMinutes = (doc['safe_interval'] as int?) ?? 30;
    safeEnabled = (doc['safe_enabled'] as bool?) ?? true;
    demoTimeScale = (doc['demo_scale'] as bool?) ?? true;

    contacts
      ..clear()
      ..addAll(
        ((doc['contacts'] as List?) ?? const []).map(
          (e) => SafetyContact.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    journal
      ..clear()
      ..addAll(
        ((doc['journal'] as List?) ?? const []).map(
          (e) => EkEvent.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    outbox
      ..clear()
      ..addAll(
        ((doc['outbox'] as List?) ?? const []).map(
          (e) => OutboundMessage.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    inbox
      ..clear()
      ..addAll(
        ((doc['inbox'] as List?) ?? const []).map(
          (e) => PushNotification.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    _seedWatched();
  }

  Future<void> _persist() async {
    if (user == null) return;
    await _be.writeDoc(user!.phone, {
      'lists_configured': listsConfigured,
      'contacts_permission': contactsPermission,
      'location_permission': locationPermission,
      'safe_interval': safeIntervalMinutes,
      'safe_enabled': safeEnabled,
      'demo_scale': demoTimeScale,
      'contacts': contacts.map((e) => e.toJson()).toList(),
      'journal': journal.take(300).map((e) => e.toJson()).toList(),
      'outbox': outbox.take(300).map((e) => e.toJson()).toList(),
      'inbox': inbox.take(200).map((e) => e.toJson()).toList(),
    });
    _syncSafetyStatus();
  }

  /// §9 : publie l'etat Safe vers Firestore. La Cloud Function
  /// `escalationTick` surveille ce document et declenche l'escalade
  /// N1/N2 cote serveur — meme si le telephone est eteint ou detruit.
  void _syncSafetyStatus() {
    if (user == null) return;
    final String state = switch (activeAlert?.kind) {
      AlertKind.safeLevel1 => 'level1',
      AlertKind.safeLevel2 => 'level2',
      _ => level1At != null ? 'level1' : 'ok',
    };
    _fb.saveSafetyStatus(
      phone: user!.phone,
      trackingActive: trackingActive,
      safeEnabled: safeEnabled,
      nextCheckAt: safeCheckPending ? safeCheckRaisedAt : nextSafeCheck,
      state: state,
      level1At: level1At,
      lastPosition: position,
    );
  }

  // =======================================================================
  // §3 Authentification
  // =======================================================================

  /// Lance l'envoi du code OTP par WHATSAPP (Meta Cloud API).
  /// Callbacks identiques a l'ancien flux : l'ecran appelant navigue vers
  /// la saisie du code DANS [onCodeSent]. [onAutoVerified] n'est jamais
  /// appele (pas d'auto-validation avec WhatsApp) mais est conserve pour
  /// ne pas modifier les ecrans.
  Future<void> startOtp({
    required String phone,
    required void Function() onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String message) onFailed,
    bool isResend = false,
  }) {
    _log(
      EkEventType.otpSent,
      'Envoi du code WhatsApp',
      'Demande de code OTP par WhatsApp pour $phone',
    );
    return WhatsAppOtp.instance.sendOtp(
      phone: phone,
      onCodeSent: () {
        _log(
          EkEventType.otpSent,
          'Code envoye',
          'Code OTP envoye par WhatsApp a $phone',
        );
        onCodeSent();
      },
      onFailed: onFailed,
    );

    // -----------------------------------------------------------------------
    // ANCIEN SYSTEME OTP — Firebase Phone Auth (SMS) — CONSERVE POUR PLUS TARD
    // Fonctionnel (App Check debug token + Enforcement), desactive au profit
    // de WhatsApp. Pour le reactiver : decommenter ci-dessous et supprimer
    // l'appel WhatsAppOtp ci-dessus.
    // -----------------------------------------------------------------------
    // return _fb.startPhoneVerification(
    //   phone: phone,
    //   isResend: isResend,
    //   onCodeSent: () {
    //     _log(
    //       EkEventType.otpSent,
    //       'SMS envoye',
    //       'Code OTP envoye par SMS a $phone (Firebase Auth)',
    //     );
    //     onCodeSent();
    //   },
    //   onAutoVerified: onAutoVerified,
    //   onFailed: onFailed,
    // );
  }

  /// Verifie le code OTP saisi — verification locale WhatsApp
  /// (hash SHA-256 + expiration 10 minutes).
  Future<bool> verifyOtp(String phone, String code) async {
    final ok = WhatsAppOtp.instance.verifyOtp(phone, code);
    if (ok) {
      _log(
        EkEventType.otpVerified,
        'Numero verifie',
        'Code OTP valide pour $phone (WhatsApp)',
      );
    }
    return ok;

    // -----------------------------------------------------------------------
    // ANCIEN SYSTEME OTP — Firebase Phone Auth (SMS) — CONSERVE POUR PLUS TARD
    // -----------------------------------------------------------------------
    // final ok = await _fb.verifyRealOtp(code);
    // if (ok) {
    //   _log(
    //     EkEventType.otpVerified,
    //     'Numero verifie',
    //     'Code OTP valide pour $phone (SMS Firebase)',
    //   );
    // }
    // return ok;
  }

  Future<void> completeRegistration({
    required String phone,
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    user = await _be.createAccount(
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      password: password,
    );
    // Synchronisation Firestore : le compte est visible par les proches.
    await _fb.saveUser(user!);
    await _fb.refreshFcmToken(phone);
    await _be.setSession(phone);
    listsConfigured = false;
    contacts.clear();
    journal.clear();
    outbox.clear();
    inbox.clear();
    _log(
      EkEventType.accountCreated,
      'Compte cree',
      '${user!.fullName} · $phone',
    );
    _seedWatched();
    await _persist();
    notifyListeners();
  }

  Future<String?> signIn(String phone, String password) async {
    final u = await _be.login(phone, password);
    if (u == null) return 'Numero ou mot de passe incorrect';
    user = u;
    await _be.setSession(phone);
    await _restore();
    // §13 : jeton FCM a jour pour recevoir les alertes des proches.
    await _fb.refreshFcmToken(phone);
    _log(EkEventType.login, 'Connexion', 'Session ouverte · $phone');
    await _persist();
    notifyListeners();
    return null;
  }

  Future<bool> accountExists(String phone) => _be.accountExists(phone);

  Future<void> resetPassword(String phone, String password) =>
      _be.updatePassword(phone, password);

  Future<void> signOut() async {
    stopTracking(silent: true);
    _stopClock();
    AlarmSound.instance.stop();
    _log(EkEventType.logout, 'Deconnexion', 'Session fermee');
    await _persist();
    await _be.clearSession();
    user = null;
    contacts.clear();
    journal.clear();
    outbox.clear();
    inbox.clear();
    watched.clear();
    trail.clear();
    activeAlert = null;
    safeCheckPending = false;
    listsConfigured = false;
    notifyListeners();
  }

  // =======================================================================
  // §4 / §15 Autorisations
  // =======================================================================
  /// §4 Demande l'autorisation systeme d'acceder au repertoire du telephone.
  /// La boite de dialogue native est affichee par le systeme d'exploitation.
  Future<bool> requestContactsPermission() async {
    final ok = await ContactsService.instance.requestPermission();
    contactsPermission = ok;
    await _persist();
    notifyListeners();
    return ok;
  }

  /// true si l'utilisateur a refuse definitivement : il faut alors passer
  /// par les reglages systeme de l'appareil.
  Future<bool> contactsPermanentlyDenied() =>
      ContactsService.instance.isPermanentlyDenied();

  Future<void> openSystemSettings() => ContactsService.instance.openSettings();

  Future<bool> requestLocationPermission() async {
    final ok = await LocationService.instance.requestPermission();
    locationPermission = ok;
    await _persist();
    notifyListeners();
    return ok;
  }

  /// §4 Lecture du repertoire reel de l'appareil, puis §5 detection des
  /// numeros possedant deja un compte EKENGE PLUS.
  ///
  /// Aucun contact n'est simule : sur le web (ou l'API Contacts native n'est
  /// pas disponible) la liste est simplement vide.
  Future<List<PhoneBookEntry>> readPhoneBook() async {
    final device = await ContactsService.instance.readDeviceContacts();

    final out = <PhoneBookEntry>[];
    for (final e in device) {
      out.add(
        PhoneBookEntry(
          name: e.name,
          phone: e.phone,
          hasEkengeAccount: await _be.isEkengeNumber(e.phone),
        ),
      );
    }
    return out;
  }

  /// §5 Verifie si un numero possede deja un compte EKENGE PLUS.
  /// §5 : verifie si un numero possede un compte EKENGE PLUS.
  /// Interroge d'abord Firestore (comptes reels de tous les utilisateurs),
  /// puis le stockage local.
  Future<bool> isEkengeNumber(String phone) async {
    final n = Backend.normalizePhone(phone);
    if (await _fb.userExists(n)) return true;
    return _be.isEkengeNumber(n);
  }

  // =======================================================================
  // §4 Listes de securite + §5 Synchronisation
  // =======================================================================

  /// Ajout d'un contact dans une liste. Regle §4.2 : tout contact Tracking
  /// est automatiquement copie dans la liste Urgence.
  Future<void> addContact(
    PhoneBookEntry entry, {
    required SafetyList list,
  }) async {
    final phone = Backend.normalizePhone(entry.phone);
    final lists = <SafetyList>{
      list,
      if (list == SafetyList.tracking) SafetyList.urgence,
    };

    final idx = contacts.indexWhere((c) => c.phone == phone);
    if (idx >= 0) {
      contacts[idx] = contacts[idx].copyWith(
        lists: {...contacts[idx].lists, ...lists},
      );
    } else {
      final linked = await isEkengeNumber(phone);
      final c = SafetyContact(
        id: 'c_${DateTime.now().microsecondsSinceEpoch}',
        name: entry.name,
        phone: phone,
        lists: lists,
        sync: linked ? ContactSync.linked : ContactSync.invited,
        addedAt: DateTime.now(),
      );
      contacts.add(c);
      // Synchronisation Firestore de la liste (§4).
      if (user != null) await _fb.saveContact(user!.phone, c);

      // §5 Synchronisation
      if (linked) {
        _log(
          EkEventType.contactLinked,
          'Contact synchronise',
          '${c.name} possede un compte EKENGE PLUS',
        );
        // Y est notifie qu'il a ete ajoute aux contacts de securite de X.
        await _send(
          c,
          Channel.push,
          '${user!.fullName} vous a ajoute a ses contacts de securite EKENGE PLUS.',
          'sync_notice',
        );
        // X apparait dans la liste des personnes que Y pourra suivre.
        watched.add(
          WatchedUser(
            name: c.name,
            phone: c.phone,
            trackingActive: false,
            alert: AlertKind.none,
            position: LocationService.instance.nearby(),
            lastUpdate: DateTime.now(),
          ),
        );
      } else {
        // Invitation WhatsApp contenant le lien de telechargement.
        await _send(
          c,
          Channel.whatsapp,
          'Bonjour ${c.name}, ${user!.fullName} vous invite a rejoindre EKENGE PLUS, '
              'application de securite et de partage de localisation en temps reel. '
              'Telechargez l\'application : https://ekengeplus.app/telecharger',
          'invitation',
        );
        _log(
          EkEventType.invitationSent,
          'Invitation WhatsApp envoyee',
          '${c.name} · ${c.phone}',
        );
      }
    }

    _log(
      EkEventType.contactAdded,
      'Contact ajoute',
      '${entry.name} · liste ${safetyListLabel(list)}',
    );
    await _persist();
    notifyListeners();
  }

  Future<void> removeFromList(SafetyContact c, SafetyList list) async {
    final idx = contacts.indexWhere((e) => e.id == c.id);
    if (idx < 0) return;
    final next = {...contacts[idx].lists}..remove(list);
    // Retirer du Tracking retire aussi l'acces au suivi ; la presence en
    // Urgence reste libre (§4.2 : ajouts supplementaires autorises).
    if (list == SafetyList.urgence) next.remove(SafetyList.tracking);
    if (next.isEmpty) {
      contacts.removeAt(idx);
      watched.removeWhere((w) => w.phone == c.phone);
    } else {
      contacts[idx] = contacts[idx].copyWith(lists: next);
    }
    _log(
      EkEventType.contactRemoved,
      'Contact retire',
      '${c.name} · liste ${safetyListLabel(list)}',
    );
    await _persist();
    notifyListeners();
  }

  /// Validation de la configuration initiale des listes (§4).
  Future<void> confirmListsConfigured() async {
    listsConfigured = true;
    _log(
      EkEventType.listsConfigured,
      'Reseaux de securite configures',
      'Tracking : ${trackingList.length} contact(s) · Urgence : ${urgenceList.length} contact(s)',
    );
    await _persist();
    notifyListeners();
  }

  /// Relance manuelle d'une invitation WhatsApp (§5).
  Future<void> resendInvitation(SafetyContact c) async {
    await _send(
      c,
      Channel.whatsapp,
      'Rappel : ${user!.fullName} vous invite a rejoindre EKENGE PLUS. '
          'Telechargez l\'application : https://ekengeplus.app/telecharger',
      'invitation',
    );
    _log(EkEventType.invitationSent, 'Invitation relancee', c.name);
    await _persist();
    notifyListeners();
  }

  // =======================================================================
  // §6 Fonction Tracking
  // =======================================================================
  Future<void> startTracking({bool notify = true, String? reason}) async {
    if (!locationPermission) {
      final ok = await requestLocationPermission();
      if (!ok) return;
    }
    if (trackingActive) return;

    trackingActive = true;
    trackingStartedAt = DateTime.now();
    trail.clear();
    LocationService.instance.start();
    position = LocationService.instance.current;
    trail.add(position!);

    _scheduleSafeCheck();
    _startClock();

    if (notify) {
      // Les membres de la liste Tracking recoivent une notification.
      for (final c in trackingList) {
        await _send(
          c,
          Channel.push,
          '${user!.fullName} partage sa localisation en temps reel. '
              'Consultez sa position sur la carte dans EKENGE PLUS.',
          'tracking_start',
        );
      }
    }
    _log(
      EkEventType.trackingStarted,
      'Tracking active',
      reason ??
          'Partage de localisation avec ${trackingList.length} contact(s)',
      pos: position,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> stopTracking({bool silent = false}) async {
    if (!trackingActive) return;
    trackingActive = false;
    LocationService.instance.stop();
    nextSafeCheck = null;
    safeCheckPending = false;
    AlarmSound.instance.stop();
    _stopClock();

    if (!silent) {
      for (final c in trackingList) {
        await _send(
          c,
          Channel.push,
          '${user!.fullName} a arrete le partage de sa localisation.',
          'tracking_stop',
        );
      }
      _log(
        EkEventType.trackingStopped,
        'Tracking arrete',
        'Partage de localisation interrompu',
        pos: position,
      );
      await _persist();
    }
    notifyListeners();
  }

  void _onPosition(GeoPoint p) {
    position = p;
    trail.add(p);
    if (trail.length > 240) trail.removeAt(0);
    // §6 : position temps reel publiee sur Firestore pour les proches.
    if (trackingActive && user != null) {
      _fb.pushPosition(user!.phone, p);
    }
    // Mise a jour temps reel des proches suivis.
    for (var i = 0; i < watched.length; i++) {
      if (watched[i].trackingActive) {
        watched[i] = watched[i].copyWith(
          position: LocationService.instance.drift(watched[i].position),
          lastUpdate: DateTime.now(),
        );
      }
    }
    notifyListeners();
  }

  // =======================================================================
  // §7 Fonction Danger
  // =======================================================================
  Future<void> triggerDanger() async {
    final now = DateTime.now();
    if (!locationPermission) await requestLocationPermission();

    // Le suivi en temps reel est automatiquement active.
    if (!trackingActive) {
      await startTracking(notify: false, reason: 'Active par l\'alerte Danger');
    }
    position ??= LocationService.instance.current;

    // §7 : alerte critique publiee sur Firestore.
    _fb.pushAlert(
      phone: user!.phone,
      kind: 'danger',
      startedAt: now,
      position: position,
    );

    activeAlert = ActiveAlert(
      kind: AlertKind.danger,
      startedAt: now,
      position: position!,
    );
    level1At = null;
    AlarmSound.instance.chirp();

    final msg =
        'ALERTE : ${user!.fullName} se sent en danger. '
        'Consultez sa position actuelle dans EKENGE PLUS.';
    final detail =
        '$msg\n'
        'Heure du declenchement : ${_hhmm(now)}\n'
        'Position : ${LocationService.formatCoords(position!)}\n'
        'Suivi en temps reel : https://ekengeplus.app/suivi/${user!.phone}';

    // Notification Push a tous les membres de la liste Urgence.
    for (final c in urgenceList) {
      await _send(c, Channel.push, msg, 'danger');
    }
    // Message WhatsApp a tous les membres de la liste Urgence, envoye
    // depuis le numero officiel EKENGE PLUS.
    for (final c in urgenceList) {
      await _send(c, Channel.whatsapp, detail, 'danger');
    }

    _log(
      EkEventType.dangerTriggered,
      'Alerte Danger declenchee',
      'Liste Urgence alertee · ${urgenceList.length} contact(s)',
      pos: position,
    );
    _pushToSelf(
      'Alerte Danger active',
      'Vos ${urgenceList.length} contacts d\'urgence ont ete alertes. '
          'Le suivi en temps reel est actif.',
      AlertKind.danger,
    );
    _startClock();
    await _persist();
    notifyListeners();
  }

  // =======================================================================
  // §8 Fonction Safe (confirmation de securite)
  // =======================================================================
  Future<void> setSafeInterval(int minutes) async {
    safeIntervalMinutes = minutes;
    if (trackingActive && safeEnabled) _scheduleSafeCheck();
    _log(
      EkEventType.safeCheckScheduled,
      'Frequence Safe definie',
      'Verification toutes les $minutes minutes',
    );
    await _persist();
    notifyListeners();
  }

  Future<void> setSafeEnabled(bool v) async {
    safeEnabled = v;
    if (v && trackingActive) {
      _scheduleSafeCheck();
    } else {
      nextSafeCheck = null;
      safeCheckPending = false;
      AlarmSound.instance.stop();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setDemoTimeScale(bool v) async {
    demoTimeScale = v;
    if (trackingActive && safeEnabled) _scheduleSafeCheck();
    await _persist();
    notifyListeners();
  }

  void _scheduleSafeCheck() {
    if (!safeEnabled) {
      nextSafeCheck = null;
      return;
    }
    nextSafeCheck = DateTime.now().add(
      Duration(seconds: safeIntervalMinutes * 60 ~/ _scale),
    );
    safeCheckPending = false;
  }

  /// Declenchement de la verification periodique : alarme sonore, l'utilisateur
  /// doit deverrouiller son telephone, ouvrir l'application et confirmer.
  void _raiseSafeCheck() {
    safeCheckPending = true;
    safeCheckRaisedAt = DateTime.now();
    nextSafeCheck = null;
    AlarmSound.instance.start();
    _log(
      EkEventType.safeCheckDue,
      'Verification de securite requise',
      'Confirmation attendue dans les 2 minutes',
      pos: position,
    );
    _pushToSelf(
      'Verification de securite',
      'Confirmez votre securite en appuyant sur « Je suis en securite ».',
      AlertKind.none,
    );
    notifyListeners();
  }

  // =======================================================================
  // §9 Gestion des absences de confirmation
  // =======================================================================
  Future<void> _escalateLevel1() async {
    level1At = DateTime.now();
    activeAlert = ActiveAlert(
      kind: AlertKind.safeLevel1,
      startedAt: level1At!,
      position: position ?? LocationService.instance.current,
    );
    if (!trackingActive) {
      await startTracking(
        notify: false,
        reason: 'Active par l\'escalade Niveau 1',
      );
    }

    final msg =
        'ALERTE PREVENTIVE : ${user!.fullName} n\'a pas confirme sa securite. '
        'Derniere position connue disponible dans EKENGE PLUS.';
    final detail =
        '$msg\n'
        'Heure : ${_hhmm(level1At!)}\n'
        'Derniere position : ${LocationService.formatCoords(activeAlert!.position)}\n'
        'Suivi en temps reel : https://ekengeplus.app/suivi/${user!.phone}';

    // Notification Push et message WhatsApp aux membres de la liste Tracking.
    for (final c in trackingList) {
      await _send(c, Channel.push, msg, 'safe_level1');
    }
    for (final c in trackingList) {
      await _send(c, Channel.whatsapp, detail, 'safe_level1');
    }

    _log(
      EkEventType.escalationLevel1,
      'Niveau 1 · Alerte preventive',
      'Liste Tracking alertee · ${trackingList.length} contact(s)',
      pos: activeAlert!.position,
    );
    _pushToSelf(
      'Niveau 1 · Alerte preventive',
      'Aucune confirmation recue. Votre liste Tracking a ete alertee. '
          'Niveau 2 dans $level2DelayMinutes minutes sans confirmation.',
      AlertKind.safeLevel1,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> _escalateLevel2() async {
    final now = DateTime.now();
    activeAlert = ActiveAlert(
      kind: AlertKind.safeLevel2,
      startedAt: now,
      position: position ?? LocationService.instance.current,
    );

    final msg =
        'ALERTE CRITIQUE : ${user!.fullName} demeure sans confirmation de securite. '
        'Incident considere comme critique.';
    final detail =
        '$msg\n'
        'Heure : ${_hhmm(now)}\n'
        'Geolocalisation temps reel : ${LocationService.formatCoords(activeAlert!.position)}\n'
        'Suivi : https://ekengeplus.app/suivi/${user!.phone}';

    for (final c in urgenceList) {
      await _send(c, Channel.push, msg, 'safe_level2');
    }
    for (final c in urgenceList) {
      await _send(c, Channel.whatsapp, detail, 'safe_level2');
    }

    _log(
      EkEventType.escalationLevel2,
      'Niveau 2 · Alerte critique',
      'Liste Urgence alertee · ${urgenceList.length} contact(s)',
      pos: activeAlert!.position,
    );
    _pushToSelf(
      'Niveau 2 · Alerte critique',
      'Aucune confirmation apres $level2DelayMinutes minutes. '
          'Votre liste Urgence a ete alertee.',
      AlertKind.safeLevel2,
    );
    await _persist();
    notifyListeners();
  }

  // =======================================================================
  // §10 Fonction « Je suis en securite »
  // =======================================================================
  /// Clot l'alerte active, arrete l'escalade, puis maintient ou desactive
  /// le Tracking selon le choix de l'utilisateur.
  Future<void> confirmSafe({required bool keepTracking}) async {
    final had = activeAlert != null || safeCheckPending;
    AlarmSound.instance.stop();
    AlarmSound.instance.chirp(low: true);

    safeCheckPending = false;
    safeCheckRaisedAt = null;
    activeAlert = null;
    level1At = null;

    if (had) {
      final msg = '${user!.fullName} a confirme etre en securite.';
      // Les membres des listes Tracking et Urgence sont informes.
      final recipients = <String, SafetyContact>{};
      for (final c in [...trackingList, ...urgenceList]) {
        recipients[c.phone] = c;
      }
      for (final c in recipients.values) {
        await _send(c, Channel.push, msg, 'safe_confirmed');
      }
      for (final c in recipients.values) {
        await _send(c, Channel.whatsapp, msg, 'safe_confirmed');
      }
      _log(
        EkEventType.safeConfirmed,
        'Securite confirmee',
        'Alerte cloturee · escalade interrompue',
        pos: position,
      );
      _log(
        EkEventType.alertClosed,
        'Alerte cloturee',
        keepTracking ? 'Tracking maintenu' : 'Tracking desactive',
      );
    } else {
      _log(
        EkEventType.safeConfirmed,
        'Securite confirmee',
        'Confirmation volontaire',
        pos: position,
      );
    }

    if (keepTracking) {
      if (!trackingActive) {
        await startTracking(
          notify: false,
          reason: 'Maintenu apres confirmation',
        );
      } else {
        _scheduleSafeCheck();
      }
    } else {
      await stopTracking();
    }
    await _persist();
    notifyListeners();
  }

  // =======================================================================
  // §11 Notifications — sortie Push / WhatsApp
  // =======================================================================
  Future<void> _send(
    SafetyContact to,
    Channel channel,
    String body,
    String kind,
  ) async {
    // Un contact sans compte EKENGE PLUS ne peut pas recevoir de Push :
    // le canal WhatsApp prend le relais (§11).
    if (channel == Channel.push && to.sync != ContactSync.linked) {
      final m = await _be.dispatch(
        channel: Channel.whatsapp,
        to: to,
        body: body,
        kind: kind,
      );
      outbox.insert(0, m);
      if (user != null) await _fb.pushMessage(m, user!.phone);
      // Envoi WhatsApp reel (best-effort).
      unawaited(WhatsAppOtp.instance.sendText(to.phone, body));
      return;
    }
    final m = await _be.dispatch(
      channel: channel,
      to: to,
      body: body,
      kind: kind,
    );
    outbox.insert(0, m);
    // Trace cloud : base de travail des Cloud Functions (FCM / WhatsApp).
    if (user != null) await _fb.pushMessage(m, user!.phone);
    // §11/§14 : envoi REEL du message WhatsApp via l'API Meta Cloud
    // (numero officiel EKENGE). Best-effort : un echec (destinataire non
    // enregistre sur le compte test) n'interrompt jamais l'alerte.
    if (channel == Channel.whatsapp) {
      unawaited(WhatsAppOtp.instance.sendText(to.phone, body));
    }
    _log(
      EkEventType.notificationSent,
      channel == Channel.push
          ? 'Notification Push envoyee'
          : 'Message WhatsApp envoye',
      '${to.name} · ${to.phone}',
    );
  }

  void _pushToSelf(String title, String body, AlertKind severity) {
    inbox.insert(
      0,
      PushNotification(
        id: 'n_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        body: body,
        at: DateTime.now(),
        severity: severity,
      ),
    );
  }

  Future<void> markAllRead() async {
    for (final n in inbox) {
      n.read = true;
    }
    await _persist();
    notifyListeners();
  }

  // =======================================================================
  // §12 Journalisation des evenements de securite
  // =======================================================================
  void _log(EkEventType t, String title, String detail, {GeoPoint? pos}) {
    journal.insert(
      0,
      EkEvent(
        id: 'e_${DateTime.now().microsecondsSinceEpoch}_${journal.length}',
        type: t,
        title: title,
        detail: detail,
        at: DateTime.now(),
        position: pos,
      ),
    );
    // §12 : journalisation cloud des evenements de securite.
    if (user != null) {
      _fb.pushEvent(
        phone: user!.phone,
        type: t.name,
        title: title,
        detail: detail,
      );
    }
  }

  Future<void> clearJournal() async {
    journal.clear();
    await _persist();
    notifyListeners();
  }

  /// Export du journal (JSON) — tracabilite des evenements de securite.
  String exportJournal() => const JsonEncoder.withIndent('  ').convert({
    'application': 'EKENGE PLUS',
    'utilisateur': user?.fullName,
    'numero': user?.phone,
    'genere_le': DateTime.now().toIso8601String(),
    'evenements': journal.map((e) => e.toJson()).toList(),
    'messages_sortants': outbox.map((e) => e.toJson()).toList(),
  });

  // =======================================================================
  // Horloge : cycles Safe et escalade
  // =======================================================================
  void _startClock() {
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _stopClock() {
    _tick?.cancel();
    _tick = null;
  }

  void _onTick() {
    final now = DateTime.now();

    // Declenchement de la verification periodique.
    if (trackingActive &&
        safeEnabled &&
        !safeCheckPending &&
        activeAlert == null &&
        nextSafeCheck != null &&
        now.isAfter(nextSafeCheck!)) {
      _raiseSafeCheck();
      return;
    }

    // Niveau 1 : absence de confirmation dans la fenetre imparties.
    if (safeCheckPending &&
        activeAlert == null &&
        safeCheckRaisedAt != null &&
        now.difference(safeCheckRaisedAt!).inSeconds >= confirmWindowSeconds) {
      _escalateLevel1();
      return;
    }

    // Niveau 2 : 15 minutes apres l'alerte preventive.
    if (activeAlert?.kind == AlertKind.safeLevel1 &&
        level1At != null &&
        now.difference(level1At!).inSeconds >=
            level2DelayMinutes * 60 ~/ _scale) {
      _escalateLevel2();
      return;
    }

    notifyListeners();
  }

  /// Compte a rebours restant avant la prochaine verification Safe.
  Duration? get safeCountdown {
    if (nextSafeCheck == null) return null;
    final d = nextSafeCheck!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d * _scale;
  }

  /// Temps restant pour confirmer avant l'escalade Niveau 1.
  Duration? get confirmCountdown {
    if (!safeCheckPending || safeCheckRaisedAt == null) return null;
    final d =
        Duration(seconds: confirmWindowSeconds) -
        DateTime.now().difference(safeCheckRaisedAt!);
    return d.isNegative ? Duration.zero : d;
  }

  /// Temps restant avant l'escalade Niveau 2.
  Duration? get level2Countdown {
    if (activeAlert?.kind != AlertKind.safeLevel1 || level1At == null) {
      return null;
    }
    final d =
        Duration(seconds: level2DelayMinutes * 60 ~/ _scale) -
        DateTime.now().difference(level1At!);
    return (d.isNegative ? Duration.zero : d) * _scale;
  }

  Duration? get trackingElapsed => trackingStartedAt == null
      ? null
      : DateTime.now().difference(trackingStartedAt!);

  // =======================================================================
  // §5 Proches suivis
  // =======================================================================
  void _seedWatched() {
    watched.clear();
    for (final c in contacts.where((e) => e.sync == ContactSync.linked)) {
      watched.add(
        WatchedUser(
          name: c.name,
          phone: c.phone,
          trackingActive: false,
          alert: AlertKind.none,
          position: LocationService.instance.nearby(),
          lastUpdate: DateTime.now(),
        ),
      );
    }
  }

  /// Simulation reciproque : un proche active son Tracking / declenche Danger.
  void toggleWatchedTracking(int i) {
    final w = watched[i];
    watched[i] = w.copyWith(
      trackingActive: !w.trackingActive,
      lastUpdate: DateTime.now(),
    );
    if (!w.trackingActive) {
      _pushToSelf(
        '${w.name} partage sa localisation',
        'Vous pouvez consulter sa position sur la carte.',
        AlertKind.none,
      );
      _startClock();
    } else {
      watched[i] = watched[i].copyWith(alert: AlertKind.none);
    }
    notifyListeners();
  }

  void simulateWatchedDanger(int i) {
    final w = watched[i];
    watched[i] = w.copyWith(
      alert: AlertKind.danger,
      trackingActive: true,
      lastUpdate: DateTime.now(),
    );
    AlarmSound.instance.chirp();
    _pushToSelf(
      'ALERTE : ${w.name} se sent en danger',
      'Consultez sa position actuelle dans EKENGE PLUS.',
      AlertKind.danger,
    );
    _log(
      EkEventType.dangerTriggered,
      'Alerte recue',
      '${w.name} a declenche une alerte Danger',
    );
    _startClock();
    notifyListeners();
  }

  void clearWatchedAlert(int i) {
    watched[i] = watched[i].copyWith(alert: AlertKind.none);
    _pushToSelf(
      '${watched[i].name} a confirme etre en securite.',
      '',
      AlertKind.none,
    );
    notifyListeners();
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _locSub?.cancel();
    _stopClock();
    super.dispose();
  }
}
