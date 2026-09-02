# EKENGE PLUS

Application mobile de sécurité personnelle et de partage de localisation en temps réel.
Flutter (Android + aperçu Web) · Firebase (Auth, Firestore, FCM, Hosting) · WhatsApp Cloud API (Meta).

- **Package Android** : `com.ekengeplus.app`
- **Carte web de suivi** : https://ekenge-plus.web.app/suivi/`<numéro ou jeton>`
- **Dépôt** : https://github.com/Patou2209/EKENGE-PLUS

---

## 🔄 Flow complet de l'application

```
Lancement
   │
   ├─ Pas de compte ──► INSCRIPTION (4 étapes)
   │     1. Identité      : nom, prénom, numéro de téléphone (identifiant unique)
   │     2. WhatsApp      : code OTP à 6 chiffres envoyé par WhatsApp (modèle Meta,
   │                        vérification locale SHA-256, validité 10 min)
   │     3. Sécurité      : création du mot de passe
   │     4. Réseaux       : constitution des listes de contacts de sécurité
   │
   ├─ Compte existant ──► CONNEXION (numéro + mot de passe)
   │                      (mot de passe oublié : ré-OTP WhatsApp puis réinitialisation)
   │
   └─ Lien de suivi reçu ──► SUIVI INVITÉ (sans compte, §11)
   
Une fois connecté ──► SHELL (navigation par onglets)
   │
   ├─ ACCUEIL ──► Tracking ▶/■, bouton DANGER, vérification SAFE
   │                │
   │                ├─ Tracking actif ──► GPS réel (geolocator) + service Android
   │                │     de premier plan : notification persistante
   │                │     « EKENGE PLUS vous protège » — le suivi continue
   │                │     écran verrouillé. Position publiée sur Firestore
   │                │     (positions/<téléphone>) → visible dans l'app des
   │                │     proches ET sur la carte web ekenge-plus.web.app.
   │                │
   │                ├─ DANGER ──► alerte immédiate à la liste Urgence :
   │                │     Push FCM (contacts avec compte) + WhatsApp (tous),
   │                │     avec heure, position et lien de suivi temps réel.
   │                │     Tracking activé automatiquement. Bouton de partage
   │                │     du lien de suivi sur WhatsApp.
   │                │
   │                └─ SAFE ──► vérification périodique « êtes-vous en
   │                      sécurité ? » : sans réponse → Niveau 1 (alerte
   │                      préventive) puis Niveau 2 (alerte critique + alarme).
   │
   ├─ SURVEILLANCE ──► carte temps réel des proches qui partagent leur position
   ├─ RÉSEAUX      ──► gestion des 3 listes de contacts de sécurité
   ├─ JOURNAL      ──► historique horodaté de tous les événements de sécurité
   └─ PROFIL       ──► compte, permissions, préférences, déconnexion
```

---

## 📱 Description des pages

### `auth_screens.dart` — Authentification
- **Bienvenue / Connexion** : numéro + mot de passe, lien vers l'inscription et
  la réinitialisation du mot de passe.
- **Inscription — étape 1 (Identité)** : nom, prénom, numéro de téléphone.
- **Inscription — étape 2 (WhatsApp)** : saisie du code OTP à 6 chiffres reçu
  par WhatsApp ; renvoi possible ; vérification automatique à la 6ᵉ frappe.
- **Inscription — étape 3 (Sécurité)** : création et confirmation du mot de passe.
- **Inscription — étape 4 (Réseaux)** : premier remplissage des listes de contacts.
- **Réinitialisation** : même écran OTP en `resetMode`, puis nouveau mot de passe.

### `shell.dart` — Coque de navigation
Barre d'onglets inférieure : Accueil · Surveillance · Réseaux · Journal · Profil.
Cloche de notifications avec compteur de non-lus.

### `home_screen.dart` — Accueil (cœur de l'app)
- Carte interactive OpenStreetMap **claire** (flutter_map) : ma position en
  direct, tracé du trajet, zoom, recentrage.
- **Tracking** : démarrer/arrêter le partage de position avec la liste Tracking.
- **Bouton DANGER** : déclenchement de l'alerte d'urgence (vibration haptique) ;
  bannière d'alerte active avec bouton « Partager le lien de suivi sur WhatsApp ».
- **SAFE** : configuration et état de la vérification périodique de sécurité.
- Bandeau d'état : coordonnées GPS, vitesse, heure de mise à jour.

### `watch_screen.dart` — Surveillance
Carte + liste des proches qui partagent leur position avec moi : positions en
temps réel, distance, vitesse, dernière mise à jour.

### `networks_screen.dart` — Réseaux de sécurité
Gestion des trois listes de contacts (§4/§5) :
- **Urgence** : reçoivent les alertes DANGER.
- **Tracking** : voient ma position quand le partage est actif.
- **Safe** : reçoivent les alertes de la vérification Safe (niveaux 1 et 2).
Ajout depuis le répertoire du téléphone (`contact_picker_screen.dart`) avec
détection des contacts déjà membres EKENGE ; invitation WhatsApp pour les autres.

### `contact_picker_screen.dart` — Sélecteur de contacts
Accès au vrai répertoire Android (permission runtime), recherche, sélection
multiple, indication des contacts déjà inscrits sur EKENGE PLUS.

### `journal_screen.dart` — Journal (§12)
Historique complet et horodaté : alertes déclenchées/levées, débuts/fins de
tracking, notifications envoyées, connexions — avec position quand disponible.

### `notifications_screen.dart` — Notifications
Boîte de réception des alertes reçues (Danger, Safe niveau 1/2, tracking
démarré/arrêté), avec sévérité colorée et marquage lu/non-lu.

### `profile_screen.dart` — Profil
Informations du compte, état des permissions (localisation, contacts,
notifications), préférences, déconnexion.

### `safe_settings_sheet.dart` — Réglages Safe
Feuille de configuration de la vérification périodique : intervalle, activation.

### `guest_tracking_screen.dart` — Suivi invité (§11)
Partage de position **sans compte** : génération d'un jeton de session
(`guest_sessions/<jeton>`), lien web partageable, arrêt à tout moment.

---

## 🌐 Carte web de suivi (`hosting/`)

Page plein écran Leaflet + OpenStreetMap (claire) déployée sur Firebase
Hosting : `https://ekenge-plus.web.app/suivi/<id>`
- `<id>` = numéro de téléphone (`+243...`) → suit `positions/<numéro>` ;
  ou jeton invité → suit `guest_sessions/<jeton>`.
- Mise à jour **en temps réel** (Firestore onSnapshot), marqueur pulsant,
  tracé du parcours, heure et coordonnées, lien Google Maps.
- Boutons **‹ Retour** et **Quitter** uniquement.

---

## 🏗️ Architecture technique (lib/)

| Fichier | Rôle |
|---|---|
| `main.dart` | Bootstrap : Firebase, Hive, Provider, thème |
| `core/design.dart` | Système de design (couleurs, typo, composants Ek) |
| `models/models.dart` | Modèles : utilisateur, contact, alerte, position, événement |
| `services/ek_state.dart` | État global (Provider) : auth, alertes, tracking, envois |
| `services/whatsapp_otp.dart` | WhatsApp Cloud API : OTP par modèle + messages d'alerte. Config 100 % dynamique via Firestore `app_config/whatsapp` (jeton, numéro, modèle) — bascule test→production **sans réinstallation** |
| `services/firebase_backend.dart` | Firestore (users, contacts, positions, alerts, events, messages) + FCM. Ancien OTP Firebase Phone Auth conservé en commentaire |
| `services/location_service.dart` | GPS réel (geolocator) + foreground service Android (notification persistante) ; simulation en secours (web/refus) |
| `services/backend.dart` | Répartition des envois par canal (Push/WhatsApp) |
| `services/contacts_service.dart` | Accès répertoire téléphonique |
| `services/alarm_sound*.dart` | Alarme sonore Safe (implémentations io/web) |
| `services/haptics.dart` | Retour haptique (bouton Danger) |
| `widgets/ek_map.dart` | Carte flutter_map réutilisable (marqueurs, trajet, suivi caméra) |
| `widgets/common.dart` | Composants UI partagés |

### Canaux d'alerte
1. **Push FCM** (canal principal, contacts avec compte) + écoute Firestore en
   secours (l'alerte arrive dans la cloche même sans notification système).
2. **WhatsApp** (API Meta Cloud, numéro officiel) : contacts sans compte et
   doublon des alertes Danger.

### Données Firestore
`users` · `contacts` · `positions/<tél>` (lat, lng, vitesse, horodatage) ·
`alerts` · `events` · `messages` (boîte d'envoi/réception) ·
`guest_sessions/<jeton>` · `app_config/whatsapp` (config WhatsApp dynamique).

---

## 🔧 Build

```bash
flutter pub get
flutter analyze
flutter build apk --release   # APK signé (android/key.properties)
```

Déploiement carte web : `cd hosting && firebase deploy --only hosting`

## 📌 État production WhatsApp
- Numéro officiel **+243 986 826 658** (« EKENGE PLUS ») : enregistré, vérifié.
- Jeton permanent System User : actif, déployé via Firestore.
- Vérification d'entreprise Meta : **en cours** → débloquera le modèle
  AUTHENTICATION (OTP avec bouton copier) et l'envoi vers tous les numéros.
- La bascule finale se fait uniquement dans `app_config/whatsapp` (Firestore),
  sans nouvel APK.
