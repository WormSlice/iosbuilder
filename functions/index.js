/**
 * Firebase Cloud Function para CONNECT APP.
 * Dispara automáticamente notificaciones push en segundo plano / pantalla bloqueada
 * para Android e iOS cada vez que se crea una notificación en Firestore.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendPushNotificationOnNewDoc = functions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = context.params.userId;

    if (!notification) return null;
    // Los mensajes de chat se manejan automáticamente por sendPushOnNewChatMessage para evitar duplicados
    if (notification.type === "chat_message") return null;

    try {
      // 1. Obtener el token FCM del usuario destinatario
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken || typeof fcmToken !== "string" || fcmToken.trim() === "") {
        console.log(`[Push] Usuario ${userId} no tiene fcmToken registrado.`);
        return null;
      }

      const title = notification.title || "CONNECT";
      const body = notification.body || notification.message || "Tienes un nuevo mensaje";
      const chatId = notification.chatId || "";
      const senderId = notification.senderId || "";
      const type = notification.type || "chat_message";
      const collectionPath = notification.collectionPath || "chats";

      // 2. Construir payload optimizado para Android (FCM) e iOS (APNs)
      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          chatId: String(chatId),
          senderId: String(senderId),
          type: String(type),
          collectionPath: String(collectionPath),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            visibility: "public",
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      console.log(`[Push] Notificación enviada con éxito a ${userId}:`, response);
      return response;
    } catch (error) {
      console.error(`[Push] Error enviando notificación a ${userId}:`, error);

      // Si el token es inválido o expiró, removerlo de la base de datos
      if (
        error.code === "messaging/registration-token-not-registered" ||
        error.code === "messaging/invalid-registration-token"
      ) {
        await admin.firestore().collection("users").doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
          apnsToken: admin.firestore.FieldValue.delete(),
        });
      }
      return null;
    }
  });

/**
 * Endpoint HTTP opcional para llamadas directas desde clientes o servidores
 */
exports.sendDirectPush = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { token, title, body, data } = req.body || {};
  if (!token) {
    return res.status(400).json({ error: "Missing token" });
  }

  try {
    const message = {
      token: token,
      notification: {
        title: title || "CONNECT",
        body: body || "",
      },
      data: data ? Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])) : {},
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          sound: "default",
          priority: "high",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title: title || "CONNECT",
              body: body || "",
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    return res.status(200).json({ success: true, response });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * Trigger directo en chats/{chatId}/messages/{messageId}
 * Garantiza que CUALQUIER mensaje enviado (incluso por usuarios con versiones viejas de la app)
 * dispare automáticamente una notificación push al destinatario.
 */
exports.sendPushOnNewChatMessage = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const chatId = context.params.chatId;
    if (!message) return null;

    try {
      const senderId = message.senderId;
      const chatDoc = await admin.firestore().collection("chats").doc(chatId).get();
      if (!chatDoc.exists) return null;

      const participants = chatDoc.data()?.participants || [];
      const recipientId = participants.find((p) => p !== senderId);
      if (!recipientId) return null;

      // 1. Obtener token FCM del destinatario
      const recipientDoc = await admin.firestore().collection("users").doc(recipientId).get();
      const fcmToken = recipientDoc.data()?.fcmToken;
      if (!fcmToken || typeof fcmToken !== "string" || fcmToken.trim() === "") {
        return null;
      }

      // 2. Obtener nombre del remitente
      let senderName = "CONNECT";
      if (senderId) {
        const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
        const sData = senderDoc.data();
        senderName = sData?.displayName || sData?.name || sData?.username || "CONNECT";
      }

      // 3. Formatear texto según tipo
      let bodyText = message.text || "Nuevo mensaje";
      const type = message.type || "text";
      if (type === "image") bodyText = "📷 Foto";
      else if (type === "voice") bodyText = "🎤 Mensaje de voz";
      else if (type === "file") bodyText = "📎 Archivo";
      else if (type === "location") bodyText = "📍 Ubicación";
      else if (type === "socials") bodyText = "🔗 Redes sociales";

      const pushPayload = {
        token: fcmToken,
        notification: {
          title: senderName,
          body: bodyText,
        },
        data: {
          chatId: String(chatId),
          senderId: String(senderId || ""),
          type: "chat_message",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            visibility: "public",
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
          payload: {
            aps: {
              alert: {
                title: senderName,
                body: bodyText,
              },
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const resp = await admin.messaging().send(pushPayload);
      console.log(`[Push Chat] Notificación enviada a ${recipientId} por mensaje de ${senderName}:`, resp);
      return resp;
    } catch (err) {
      console.error("[Push Chat] Error:", err);
      return null;
    }
  });

