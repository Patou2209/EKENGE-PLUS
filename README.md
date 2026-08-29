# EKENGE PLUS

Application Flutter de securite personnelle (Android). OTP par SMS via
Firebase Phone Auth, donnees Cloud Firestore, notifications FCM.

---

## SECRETS ET CLES DU PROJET

> AVERTISSEMENT : ce depot doit rester PRIVE. Ces cles donnent un acces
> complet au projet Firebase et permettent de signer des APK au nom de
> l'application. Si le depot devient public, revoquer immediatement toutes
> les cles (console Firebase + regenerer le keystore).

### 1. Projet Firebase / Google Cloud

| Element | Valeur |
|---|---|
| Project ID | `ekenge-plus` |
| Project Number | `677245357032` |
| Storage bucket | `ekenge-plus.firebasestorage.app` |
| Auth domain | `ekenge-plus.firebaseapp.com` |

### 2. Cles API Firebase

| Plateforme | Cle API | App ID |
|---|---|---|
| Android | `AIzaSyA-ehkmWb0936Iz43zfxJS6PuEHyzqY7DM` | `1:677245357032:android:d50062fb4ecd031d70f25d` |
| Web | `AIzaSyA0uXpLyjJ3sCScJwn0fVQ4-nu32ZzoIAc` | `1:677245357032:web:96eeba9fddacdc6670f25d` |

### 3. Clients OAuth (google-services.json)

| Type | Client ID |
|---|---|
| Android (type 1) | `677245357032-e8isq79o151b6q4qh5bhecd3pfvsvmg4.apps.googleusercontent.com` |
| Web (type 3) | `677245357032-0k3g1dbatkcn6e6bl5hvl3k6qti77rkh.apps.googleusercontent.com` |

Fichier complet : `android/app/google-services.json` (inclus dans le depot).

### 4. Signature des APK/AAB (keystore release)

| Element | Valeur |
|---|---|
| Fichier keystore | `android/release-key.jks` (inclus dans le depot) |
| Alias | `release` |
| Mot de passe store | `IdgIw*s07khrIm1oFNYV` |
| Mot de passe cle | `IdgIw*s07khrIm1oFNYV` |
| SHA-1 | `82:D3:F9:3B:3A:B0:DB:9A:20:B6:C4:33:59:FE:60:28:42:4A:34:EA` |
| SHA-256 | `CF:ED:A0:45:4C:0A:FC:66:90:43:EE:B5:34:61:D7:7B:54:94:E7:BE:3E:95:C8:90:83:9D:68:37:11:44:5B:72` |

Configuration : `android/key.properties` (inclus dans le depot).
Les empreintes SHA-1 et SHA-256 sont enregistrees dans la console Firebase
(Parametres du projet → Applications Android).

### 5. App Check (APK sideload, hors Play Store)

| Element | Valeur |
|---|---|
| Provider actif | `AndroidProvider.debug` |
| Debug token | `894BFB29-E3BD-429A-8745-3A3D87E6EE9C` |
| Enregistre dans | Console Firebase → App Check → Debug tokens ("EKENGE PLUS APK sideload") |
| Injection | `MainActivity.kt` ecrit le token dans les SharedPreferences du SDK |
| Enforcement Authentication | `ENFORCED` |

Mise en production Play Store : passer a `AndroidProvider.playIntegrity`
dans `lib/services/firebase_backend.dart`, supprimer le debug token de la
console et de `MainActivity.kt`.

### 6. Authentification par telephone

| Element | Valeur |
|---|---|
| Numero de test | `+243900000001` |
| Code OTP du numero test | `123456` |
| Region SMS | allowByDefault |

### 7. Firebase Admin SDK (operations serveur)

Cle de compte de service : NON incluse dans le depot — GitHub bloque
automatiquement le push des cles privees Google Cloud (secret scanning),
meme sur un depot prive. Elle se retelecharge en 30 secondes :
Console Firebase → Parametres du projet → Comptes de service →
"Generer une nouvelle cle privee" (langage Python). Elle donne un acces
administrateur total au projet (Firestore, Auth, configuration) et sert
aux scripts de maintenance (nettoyage des comptes, diagnostic).

---

## Build

```bash
flutter pub get
flutter build apk --release   # APK signe avec android/release-key.jks
```

## Structure

- `lib/services/firebase_backend.dart` — Firebase (Auth OTP, Firestore, FCM, App Check)
- `lib/services/ek_state.dart` — etat global de l'application
- `lib/screens/auth_screens.dart` — inscription 4 etapes + connexion
- `android/app/src/main/kotlin/com/ekengeplus/app/MainActivity.kt` — injection du debug token App Check
