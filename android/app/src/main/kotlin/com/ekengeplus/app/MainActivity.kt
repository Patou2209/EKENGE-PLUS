package com.ekengeplus.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // App Check (APK sideload) : le SDK natif ne lit PAS le meta-data
        // "force_debug_token" du manifest. DebugAppCheckProvider lit son secret
        // dans ces SharedPreferences, sinon il genere un UUID aleatoire (=> 403
        // ExchangeDebugToken). On injecte donc le token enregistre dans la
        // console Firebase AVANT l'activation d'App Check cote Dart.
        //
        // Nom du fichier prefs = "com.google.firebase.appcheck.debug.store." +
        // FirebaseApp.persistenceKey, ou persistenceKey =
        // b64UrlNoPad("[DEFAULT]") + "+" + b64UrlNoPad(mobilesdk_app_id).
        // Precalcule pour app_id 1:677245357032:android:d50062fb4ecd031d70f25d.
        getSharedPreferences(
            "com.google.firebase.appcheck.debug.store." +
                "W0RFRkFVTFRd+MTo2NzcyNDUzNTcwMzI6YW5kcm9pZDpkNTAwNjJmYjRlY2QwMzFkNzBmMjVk",
            MODE_PRIVATE
        ).edit()
            .putString(
                "com.google.firebase.appcheck.debug.DEBUG_SECRET",
                "894BFB29-E3BD-429A-8745-3A3D87E6EE9C"
            )
            .commit()
        super.onCreate(savedInstanceState)
    }
}
