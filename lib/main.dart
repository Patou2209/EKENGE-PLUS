import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/design.dart';
import 'screens/auth_screens.dart';
import 'screens/setup_lists_screen.dart';
import 'screens/shell.dart';
import 'services/ek_state.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Ek.bgElevated,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const EkengePlusApp());
}

class EkengePlusApp extends StatelessWidget {
  const EkengePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EkState()..bootstrap(),
      child: MaterialApp(
        title: 'EKENGE PLUS',
        debugShowCheckedModeBanner: false,
        theme: Ek.theme(),
        home: const _Router(),
      ),
    );
  }
}

/// Routeur racine.
/// 1. Amorcage
/// 2. Non connecte -> accueil / authentification (§3)
/// 3. Connecte sans listes -> configuration obligatoire (§4)
/// 4. Connecte et configure -> application
class _Router extends StatelessWidget {
  const _Router();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();

    if (!st.bootstrapped) return const _Splash();
    if (!st.isLoggedIn) return const WelcomeScreen();
    if (!st.listsConfigured) return const SetupListsScreen();
    return const AppShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EkMark(size: 76),
            SizedBox(height: 26),
            EkWordmark(size: 19, showSub: true),
            SizedBox(height: 40),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Ek.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
