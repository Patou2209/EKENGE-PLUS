import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import 'backend.dart';

/// §4 Acces au repertoire reel du telephone.
///
/// Le systeme d'exploitation affiche la boite de dialogue d'autorisation
/// natice. Une fois accordee, on lit les vrais contacts de l'appareil :
/// aucune donnee n'est simulee.
class ContactsService {
  ContactsService._();
  static final ContactsService instance = ContactsService._();

  /// Etat courant de l'autorisation, sans declencher de demande.
  Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    return Permission.contacts.isGranted;
  }

  /// L'utilisateur a refuse definitivement : seul le passage par les
  /// reglages systeme permet de reactiver l'acces.
  Future<bool> isPermanentlyDenied() async {
    if (kIsWeb) return false;
    return Permission.contacts.isPermanentlyDenied;
  }

  Future<void> openSettings() => openAppSettings();

  /// Declenche la demande d'autorisation systeme (§4).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (await Permission.contacts.isGranted) return true;
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Lecture du repertoire reel de l'appareil.
  ///
  /// Retourne une entree par numero de telephone distinct. Les doublons de
  /// numero (meme contact enregistre plusieurs fois) sont fusionnes sur la
  /// forme normalisee du numero.
  Future<List<PhoneBookEntry>> readDeviceContacts() async {
    if (kIsWeb) return const [];
    if (!await Permission.contacts.isGranted) return const [];

    final raw = await fc.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
      withThumbnail: false,
      deduplicateProperties: true,
    );

    // Cle = numero normalise, afin d'eviter les doublons.
    final byPhone = <String, PhoneBookEntry>{};

    for (final c in raw) {
      final name = c.displayName.trim();
      for (final p in c.phones) {
        final normalized = Backend.normalizePhone(p.number);
        // Un numero exploitable comporte au moins 6 chiffres.
        final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 6) continue;
        if (byPhone.containsKey(normalized)) continue;

        byPhone[normalized] = PhoneBookEntry(
          name: name.isEmpty ? normalized : name,
          phone: normalized,
          // §5 : renseigne ensuite par le backend (compte EKENGE existant).
          hasEkengeAccount: false,
        );
      }
    }

    final out = byPhone.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }
}
