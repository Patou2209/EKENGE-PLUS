import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../services/ek_state.dart';
import '../widgets/common.dart';
import 'safe_settings_sheet.dart';

/// EKENGE PLUS — Profil, autorisations et securite des donnees (§15).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// §4 Demande d'autorisation contacts. Si le systeme a definitivement
  /// refuse, la seule issue est la page des reglages de l'application.
  Future<void> _askContacts(BuildContext context) async {
    final st = context.read<EkState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await st.requestContactsPermission();
    if (ok) return;
    final permanent = await st.contactsPermanentlyDenied();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Ek.surfaceHigh,
        duration: const Duration(seconds: 5),
        content: Text(
          permanent
              ? 'Autorisation refusee definitivement. Activez la permission '
                    'Contacts dans les reglages du systeme.'
              : 'Autorisation refusee. Le repertoire du telephone reste '
                    'inaccessible.',
          style: Ek.body(size: 12.5, color: Ek.textPrimary),
        ),
        action: permanent
            ? SnackBarAction(
                label: 'REGLAGES',
                textColor: Ek.accent,
                onPressed: st.openSystemSettings,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final u = st.user;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const EkHeader(
              title: 'Profil',
              subtitle: 'Compte et parametres de securite',
              back: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  // ---- Identite ----
                  EkCard(
                    child: Row(
                      children: [
                        EkMonogram(initials: u?.initials ?? '?', size: 56),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u?.fullName ?? '',
                                style: Ek.title(size: 17),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 13,
                                    color: Ek.textTertiary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    u?.phone ?? '',
                                    style: Ek.body(size: 12.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Compte cree le ${u == null ? '' : ekFormatDateTime(u.createdAt)}',
                                style: Ek.over(size: 8.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ---- Parametres de securite ----
                  const EkSectionLabel('Parametres de securite'),
                  EkCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        EkRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Verification Safe',
                          value: '${st.safeIntervalMinutes} min',
                          onTap: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Ek.bgElevated,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(Ek.r28),
                              ),
                            ),
                            builder: (_) => const SafeSettingsSheet(),
                          ),
                        ),
                        const Divider(height: 1),
                        EkRow(
                          icon: Icons.share_location_outlined,
                          label: 'Tracking',
                          trailing: Switch(
                            value: st.trackingActive,
                            onChanged: (v) =>
                                v ? st.startTracking() : st.stopTracking(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ---- §15 Autorisations mobiles ----
                  const EkSectionLabel('Autorisations de l\'appareil'),
                  EkCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        EkRow(
                          icon: Icons.contacts_outlined,
                          label: 'Acces aux contacts',
                          iconColor: st.contactsPermission
                              ? Ek.safe
                              : Ek.textSecondary,
                          trailing: st.contactsPermission
                              ? EkPill(
                                  label: 'Accorde',
                                  color: Ek.safe,
                                  icon: Icons.check,
                                )
                              : TextButton(
                                  onPressed: () => _askContacts(context),
                                  child: Text(
                                    'Autoriser',
                                    style: Ek.over(size: 9.5, color: Ek.accent),
                                  ),
                                ),
                        ),
                        const Divider(height: 1),
                        EkRow(
                          icon: Icons.my_location_outlined,
                          label: 'Localisation en arriere-plan',
                          iconColor: st.locationPermission
                              ? Ek.safe
                              : Ek.textSecondary,
                          trailing: st.locationPermission
                              ? EkPill(
                                  label: 'Accorde',
                                  color: Ek.safe,
                                  icon: Icons.check,
                                )
                              : TextButton(
                                  onPressed: () =>
                                      st.requestLocationPermission(),
                                  child: Text(
                                    'Autoriser',
                                    style: Ek.over(size: 9.5, color: Ek.accent),
                                  ),
                                ),
                        ),
                        const Divider(height: 1),
                        EkRow(
                          icon: Icons.notifications_none,
                          label: 'Notifications Push',
                          iconColor: Ek.safe,
                          trailing: EkPill(
                            label: 'Accorde',
                            color: Ek.safe,
                            icon: Icons.check,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ---- §15 Securite des donnees ----
                  const EkSectionLabel('Securite des donnees'),
                  EkCard(
                    child: Column(
                      children: [
                        _Secure(
                          icon: Icons.lock_outline,
                          text:
                              'Authentification securisee par numero de '
                              'telephone verifie et mot de passe hache.',
                        ),
                        const Divider(height: 20),
                        _Secure(
                          icon: Icons.https_outlined,
                          text: 'Chiffrement des communications HTTPS.',
                        ),
                        const Divider(height: 20),
                        _Secure(
                          icon: Icons.admin_panel_settings_outlined,
                          text:
                              'Controle des acces : seuls vos contacts '
                              'autorises consultent votre position.',
                        ),
                        const Divider(height: 20),
                        _Secure(
                          icon: Icons.place_outlined,
                          text:
                              'Protection des donnees de localisation : '
                              'transmission uniquement lorsque le Tracking '
                              'est actif ou lors d\'une alerte.',
                        ),
                        const Divider(height: 20),
                        _Secure(
                          icon: Icons.privacy_tip_outlined,
                          text:
                              'Respect de la confidentialite : aucune '
                              'donnee transmise a des tiers.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  EkButton(
                    label: 'Se deconnecter',
                    icon: Icons.logout,
                    outlined: true,
                    color: Ek.dangerBright,
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Deconnexion', style: Ek.title(size: 16)),
                          content: Text(
                            'Le Tracking actif sera interrompu. Vos contacts '
                            'ne recevront plus votre localisation.',
                            style: Ek.body(size: 13),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text('Annuler', style: Ek.body(size: 13)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(
                                'Se deconnecter',
                                style: Ek.body(
                                  size: 13,
                                  color: Ek.dangerBright,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await st.signOut();
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        const EkWordmark(size: 12),
                        const SizedBox(height: 8),
                        Text('VERSION 1.0.0', style: Ek.over(size: 8)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Secure extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Secure({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Ek.safe),
        const SizedBox(width: 13),
        Expanded(child: Text(text, style: Ek.body(size: 12, height: 1.5))),
      ],
    );
  }
}


