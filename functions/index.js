/**
 * EKENGE PLUS — Cloud Functions (§9, §13 du cahier des charges)
 *
 * 1. onMessageCreated : chaque document `messages` (channel == 'push') est
 *    délivré en vraie notification FCM sur le téléphone du destinataire.
 *
 * 2. escalationTick : filet de sécurité serveur (interrupteur homme-mort).
 *    Si l'utilisateur ne confirme pas « Je suis en sécurité » à temps —
 *    même téléphone éteint ou détruit — le serveur déclenche l'escalade :
 *      Niveau 1 : alerte préventive -> liste Tracking
 *      Niveau 2 (15 min plus tard) : alerte critique -> liste Urgence
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: "europe-west1", maxInstances: 5 });

// ---------------------------------------------------------------------------
// Utilitaires
// ---------------------------------------------------------------------------

async function fcmTokenOf(phone) {
  if (!phone) return null;
  const doc = await db.collection("users").doc(phone).get();
  return doc.exists ? doc.get("fcm_token") || null : null;
}

async function sendPush(token, title, body, data = {}) {
  if (!token) return false;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v ?? "")])
      ),
      android: {
        priority: "high",
        notification: {
          sound: "default",
          priority: "max",
        },
      },
    });
    return true;
  } catch (e) {
    console.warn(`FCM refuse pour ${title}: ${e.message}`);
    return false;
  }
}

function titleForKind(kind) {
  switch (kind) {
    case "danger":
      return "ALERTE DANGER";
    case "safe_level1":
      return "Niveau 1 · Alerte préventive";
    case "safe_level2":
      return "Niveau 2 · ALERTE CRITIQUE";
    case "safe_confirmed":
      return "Sécurité confirmée";
    case "tracking_start":
      return "Partage de localisation";
    case "tracking_stop":
      return "Partage terminé";
    default:
      return "EKENGE PLUS";
  }
}

// ---------------------------------------------------------------------------
// 1. Délivrance FCM de tous les messages push écrits par l'application
// ---------------------------------------------------------------------------

exports.onMessageCreated = onDocumentCreated(
  "messages/{id}",
  async (event) => {
    const m = event.data?.data();
    if (!m || m.channel !== "push") return;

    const token = await fcmTokenOf(m.to_phone);
    if (!token) {
      console.log(`Pas de jeton FCM pour ${m.to_phone} — push ignore`);
      return;
    }
    const ok = await sendPush(token, titleForKind(m.kind), m.body || "", {
      kind: m.kind || "",
      from_phone: m.from_phone || "",
    });
    await event.data.ref.set(
      { fcm_delivered: ok, fcm_at: Date.now() },
      { merge: true }
    );
  }
);

// ---------------------------------------------------------------------------
// 2. Escalade N1/N2 côté serveur (§9) — toutes les minutes
// ---------------------------------------------------------------------------

async function contactsOf(phone, list) {
  // list: 'tracking' | 'urgence'
  const snap = await db
    .collection("contacts")
    .where("owner_phone", "==", phone)
    .get();
  return snap.docs
    .map((d) => d.data())
    .filter((c) => (list === "tracking" ? c.in_tracking : c.in_urgence));
}

async function notifyList(user, list, kind, body) {
  const recipients = await contactsOf(user.phone, list);
  const batch = db.batch();
  for (const c of recipients) {
    batch.set(db.collection("messages").doc(), {
      from_phone: user.phone,
      to_phone: c.phone,
      to_name: c.name || "",
      channel: "push",
      kind,
      body,
      at: Date.now(),
      by_server: true,
    });
  }
  await batch.commit();
  return recipients.length;
}

function fullNameOf(u) {
  return [u.first_name, u.last_name].filter(Boolean).join(" ") || u.phone;
}

exports.escalationTick = onSchedule("every 1 minutes", async () => {
  const now = Date.now();
  const snap = await db
    .collection("safety_status")
    .where("tracking_active", "==", true)
    .get();

  for (const doc of snap.docs) {
    const s = doc.data();
    if (!s.safe_enabled || !s.phone) continue;

    const graceMs = s.confirm_grace_ms || 120000; // 2 min par defaut
    const level2Ms = s.level2_delay_ms || 900000; // 15 min par defaut
    const userDoc = await db.collection("users").doc(s.phone).get();
    if (!userDoc.exists) continue;
    const user = userDoc.data();
    const name = fullNameOf(user);
    const trail = `https://ekengeplus.app/suivi/${s.phone}`;

    // ---- Niveau 1 : echeance + delai de grace depasses, pas de reponse ----
    if (
      s.state === "ok" &&
      s.next_check_at &&
      now > s.next_check_at + graceMs
    ) {
      console.log(`ESCALADE N1 (serveur) pour ${s.phone}`);
      const body =
        `ALERTE PREVENTIVE : ${name} n'a pas confirme sa securite. ` +
        `Derniere position connue disponible dans EKENGE PLUS. Suivi : ${trail}`;
      const n = await notifyList(user, "tracking", "safe_level1", body);
      await db.collection("alerts").add({
        phone: s.phone,
        kind: "safe_level1",
        started_at: now,
        resolved_at: null,
        lat: s.last_lat ?? null,
        lng: s.last_lng ?? null,
        by_server: true,
      });
      await doc.ref.set(
        { state: "level1", level1_at: now, next_check_at: null },
        { merge: true }
      );
      console.log(`N1 : ${n} contact(s) Tracking alerte(s)`);
      continue;
    }

    // ---- Niveau 2 : 15 minutes apres N1, toujours pas de reponse ---------
    if (s.state === "level1" && s.level1_at && now > s.level1_at + level2Ms) {
      console.log(`ESCALADE N2 (serveur) pour ${s.phone}`);
      const body =
        `ALERTE CRITIQUE : ${name} demeure sans confirmation de securite. ` +
        `Incident considere comme critique. Geolocalisation temps reel : ${trail}`;
      const n = await notifyList(user, "urgence", "safe_level2", body);
      await db.collection("alerts").add({
        phone: s.phone,
        kind: "safe_level2",
        started_at: now,
        resolved_at: null,
        lat: s.last_lat ?? null,
        lng: s.last_lng ?? null,
        by_server: true,
      });
      await doc.ref.set({ state: "level2" }, { merge: true });
      console.log(`N2 : ${n} contact(s) Urgence alerte(s)`);
    }
  }
});
