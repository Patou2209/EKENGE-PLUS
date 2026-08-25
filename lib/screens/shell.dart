import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../models/models.dart';
import '../services/ek_state.dart';

import 'home_screen.dart';
import 'journal_screen.dart';
import 'networks_screen.dart';
import 'profile_screen.dart';
import 'watch_screen.dart';

/// EKENGE PLUS — Navigation principale.
/// Icones vectorielles natives (Material) uniquement, aucun emoji.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _items = <(IconData, IconData, String)>[
    (Icons.shield_outlined, Icons.shield, 'Securite'),
    (Icons.travel_explore_outlined, Icons.travel_explore, 'Proches'),
    (Icons.groups_outlined, Icons.groups, 'Reseaux'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Journal'),
    (Icons.person_outline, Icons.person, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();
    final alertKind = st.activeAlert?.kind;
    final alertColor = switch (alertKind) {
      AlertKind.danger || AlertKind.safeLevel2 => Ek.danger,
      AlertKind.safeLevel1 => Ek.warn,
      _ => null,
    };

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              HomeScreen(),
              WatchScreen(),
              NetworksScreen(),
              JournalScreen(),
              ProfileScreen(),
            ],
          ),
          // Liseré d'alerte en haut de l'ecran
          if (alertColor != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: alertColor,
                  boxShadow: Ek.glow(alertColor, o: 0.6, b: 12),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Ek.bgElevated,
          border: Border(top: BorderSide(color: Ek.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: List.generate(_items.length, (i) {
                final (out, fill, label) = _items[i];
                final active = i == _index;
                final badge = switch (i) {
                  2 =>
                    st.contacts
                        .where((c) => c.sync == ContactSync.invited)
                        .length,
                  _ => 0,
                };
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _index = i),
                    borderRadius: BorderRadius.circular(Ek.r12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                active ? fill : out,
                                size: 21,
                                color: active ? Ek.accent : Ek.textTertiary,
                              ),
                              if (badge > 0)
                                Positioned(
                                  right: -5,
                                  top: -3,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Ek.warn,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label.toUpperCase(),
                            style: Ek.over(
                              size: 7.5,
                              color: active ? Ek.accent : Ek.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: active ? 14 : 0,
                            height: 1.6,
                            decoration: BoxDecoration(
                              color: Ek.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
