// EKENGE PLUS — Modeles de donnees.
// Structure alignee sur le schema Firestore decrit au cahier des charges (12).

/// Cahier des charges §4 : deux listes de securite.
enum SafetyList { tracking, urgence }

String safetyListLabel(SafetyList l) =>
    l == SafetyList.tracking ? 'Tracking' : 'Urgence';

/// Etat de synchronisation d'un contact (§5).
enum ContactSync {
  /// Le numero possede un compte EKENGE PLUS -> synchronise.
  linked,

  /// Aucun compte : invitation WhatsApp generee.
  invited,
}

/// Utilisateur (§3) — le numero de telephone est l'identifiant unique.
class EkUser {
  final String phone; // identifiant unique
  final String firstName;
  final String lastName;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;

  const EkUser({
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    final i = (a + b).toUpperCase();
    return i.isEmpty ? '?' : i;
  }

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'first_name': firstName,
    'last_name': lastName,
    'password_hash': passwordHash,
    'salt': salt,
    'created_at': createdAt.toIso8601String(),
  };

  static EkUser fromJson(Map<String, dynamic> j) => EkUser(
    phone: j['phone'] as String,
    firstName: (j['first_name'] as String?) ?? '',
    lastName: (j['last_name'] as String?) ?? '',
    passwordHash: (j['password_hash'] as String?) ?? '',
    salt: (j['salt'] as String?) ?? '',
    createdAt:
        DateTime.tryParse((j['created_at'] as String?) ?? '') ?? DateTime.now(),
  );
}

/// Contact de securite appartenant a une liste (§4).
class SafetyContact {
  final String id;
  final String name;
  final String phone;
  final Set<SafetyList> lists;
  final ContactSync sync;
  final DateTime addedAt;

  const SafetyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.lists,
    required this.sync,
    required this.addedAt,
  });

  bool get inTracking => lists.contains(SafetyList.tracking);
  bool get inUrgence => lists.contains(SafetyList.urgence);

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  SafetyContact copyWith({Set<SafetyList>? lists, ContactSync? sync}) =>
      SafetyContact(
        id: id,
        name: name,
        phone: phone,
        lists: lists ?? this.lists,
        sync: sync ?? this.sync,
        addedAt: addedAt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'lists': lists.map((e) => e.name).toList(),
    'sync': sync.name,
    'added_at': addedAt.toIso8601String(),
  };

  static SafetyContact fromJson(Map<String, dynamic> j) => SafetyContact(
    id: j['id'] as String,
    name: (j['name'] as String?) ?? '',
    phone: (j['phone'] as String?) ?? '',
    lists: ((j['lists'] as List?) ?? const [])
        .map(
          (e) => SafetyList.values.firstWhere(
            (v) => v.name == e,
            orElse: () => SafetyList.tracking,
          ),
        )
        .toSet(),
    sync: ContactSync.values.firstWhere(
      (v) => v.name == j['sync'],
      orElse: () => ContactSync.invited,
    ),
    addedAt:
        DateTime.tryParse((j['added_at'] as String?) ?? '') ?? DateTime.now(),
  );
}

/// Position geographique horodatee.
class GeoPoint {
  final double lat;
  final double lng;
  final DateTime at;
  final double speedKmh;

  const GeoPoint({
    required this.lat,
    required this.lng,
    required this.at,
    this.speedKmh = 0,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'at': at.toIso8601String(),
    'speed_kmh': speedKmh,
  };

  static GeoPoint fromJson(Map<String, dynamic> j) => GeoPoint(
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    at: DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
    speedKmh: ((j['speed_kmh'] as num?) ?? 0).toDouble(),
  );
}

/// Canaux de communication (§11).
enum Channel { push, whatsapp }

/// Types d'evenements journalises (§12 « Journalisation des evenements »).
enum EkEventType {
  accountCreated,
  otpSent,
  otpVerified,
  login,
  logout,
  listsConfigured,
  contactAdded,
  contactRemoved,
  contactLinked,
  invitationSent,
  trackingStarted,
  trackingStopped,
  dangerTriggered,
  safeCheckScheduled,
  safeCheckDue,
  safeConfirmed,
  escalationLevel1,
  escalationLevel2,
  alertClosed,
  notificationSent,
}

/// Journal de securite.
class EkEvent {
  final String id;
  final EkEventType type;
  final String title;
  final String detail;
  final DateTime at;
  final GeoPoint? position;

  const EkEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.at,
    this.position,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'detail': detail,
    'at': at.toIso8601String(),
    'position': position?.toJson(),
  };

  static EkEvent fromJson(Map<String, dynamic> j) => EkEvent(
    id: j['id'] as String,
    type: EkEventType.values.firstWhere(
      (v) => v.name == j['type'],
      orElse: () => EkEventType.notificationSent,
    ),
    title: (j['title'] as String?) ?? '',
    detail: (j['detail'] as String?) ?? '',
    at: DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
    position: j['position'] == null
        ? null
        : GeoPoint.fromJson(Map<String, dynamic>.from(j['position'] as Map)),
  );
}

/// Message sortant (Push ou WhatsApp) — trace de la sortie backend (§11, §14).
class OutboundMessage {
  final String id;
  final Channel channel;
  final String recipientName;
  final String recipientPhone;
  final String body;
  final DateTime at;
  final String kind; // invitation | danger | safe_level1 | safe_level2 | ...

  const OutboundMessage({
    required this.id,
    required this.channel,
    required this.recipientName,
    required this.recipientPhone,
    required this.body,
    required this.at,
    required this.kind,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'channel': channel.name,
    'recipient_name': recipientName,
    'recipient_phone': recipientPhone,
    'body': body,
    'at': at.toIso8601String(),
    'kind': kind,
  };

  static OutboundMessage fromJson(Map<String, dynamic> j) => OutboundMessage(
    id: j['id'] as String,
    channel: Channel.values.firstWhere(
      (v) => v.name == j['channel'],
      orElse: () => Channel.push,
    ),
    recipientName: (j['recipient_name'] as String?) ?? '',
    recipientPhone: (j['recipient_phone'] as String?) ?? '',
    body: (j['body'] as String?) ?? '',
    at: DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
    kind: (j['kind'] as String?) ?? 'push',
  );
}

/// Etat de l'alerte active (§7, §9, §10).
enum AlertKind { none, danger, safeLevel1, safeLevel2 }

class ActiveAlert {
  final AlertKind kind;
  final DateTime startedAt;
  final GeoPoint position;

  const ActiveAlert({
    required this.kind,
    required this.startedAt,
    required this.position,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'started_at': startedAt.toIso8601String(),
    'position': position.toJson(),
  };

  static ActiveAlert fromJson(Map<String, dynamic> j) => ActiveAlert(
    kind: AlertKind.values.firstWhere(
      (v) => v.name == j['kind'],
      orElse: () => AlertKind.none,
    ),
    startedAt:
        DateTime.tryParse((j['started_at'] as String?) ?? '') ?? DateTime.now(),
    position: GeoPoint.fromJson(
      Map<String, dynamic>.from(j['position'] as Map),
    ),
  );
}

/// Un proche que l'utilisateur peut suivre (§5 : synchronisation reciproque).
class WatchedUser {
  final String name;
  final String phone;
  final bool trackingActive;
  final AlertKind alert;
  final GeoPoint position;
  final DateTime lastUpdate;

  const WatchedUser({
    required this.name,
    required this.phone,
    required this.trackingActive,
    required this.alert,
    required this.position,
    required this.lastUpdate,
  });

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  WatchedUser copyWith({
    bool? trackingActive,
    AlertKind? alert,
    GeoPoint? position,
    DateTime? lastUpdate,
  }) => WatchedUser(
    name: name,
    phone: phone,
    trackingActive: trackingActive ?? this.trackingActive,
    alert: alert ?? this.alert,
    position: position ?? this.position,
    lastUpdate: lastUpdate ?? this.lastUpdate,
  );
}

/// Contact du repertoire telephonique (§4 : ouverture du repertoire).
class PhoneBookEntry {
  final String name;
  final String phone;

  /// true si le numero correspond a un compte EKENGE PLUS existant (§5).
  final bool hasEkengeAccount;

  const PhoneBookEntry({
    required this.name,
    required this.phone,
    required this.hasEkengeAccount,
  });

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
