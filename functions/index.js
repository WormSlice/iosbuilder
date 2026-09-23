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
            "apns-topic": "com.connectapp.co",
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
          "apns-topic": "com.connectapp.co",
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
          collapseKey: String(chatId),
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
            "apns-topic": "com.connectapp.co",
            "apns-collapse-id": String(chatId),
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

      // Guardar registro idempotente en el buzón in-app del usuario sin provocar duplicados
      const msgId = context.params.messageId;
      if (msgId) {
        await admin
          .firestore()
          .collection("users")
          .doc(recipientId)
          .collection("notifications")
          .doc(`msg_${msgId}`)
          .set({
            title: senderName,
            body: bodyText,
            chatId: String(chatId),
            senderId: String(senderId || ""),
            type: "chat_message",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
          }, { merge: true });
      }

      return resp;
    } catch (err) {
      console.error("[Push Chat] Error:", err);
      return null;
    }
  });

/**
 * Trigger en broadcasts/{broadcastId}
 * Envía notificación push global a todos los dispositivos registrados cuando se emite un broadcast desde el Admin
 */
exports.sendPushOnBroadcast = functions.firestore
  .document("broadcasts/{broadcastId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const title = data.title || "CONNECT • Oficial";
    const body = data.body || data.message || "Nueva notificación del sistema";

    try {
      // 1. Obtener tokens FCM de usuarios registrados
      const usersSnap = await admin
        .firestore()
        .collection("users")
        .where("fcmToken", "!=", null)
        .limit(500)
        .get();

      const tokens = [];
      usersSnap.forEach((doc) => {
        const tok = doc.data()?.fcmToken;
        if (tok && typeof tok === "string" && tok.trim().length > 10) {
          tokens.push(tok.trim());
        }
      });

      if (tokens.length === 0) {
        console.log("[Broadcast Push] No hay tokens FCM registrados.");
        return null;
      }

      // 2. Enviar a todos los dispositivos con sendEachForMulticast
      const multicastPayload = {
        tokens: tokens,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: "broadcast",
          isBroadcast: "true",
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
            "apns-topic": "com.connectapp.co",
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

      const resp = await admin.messaging().sendEachForMulticast(multicastPayload);
      console.log(`[Broadcast Push] Enviado con éxito a ${resp.successCount} de ${tokens.length} dispositivos.`);
      return resp;
    } catch (err) {
      console.error("[Broadcast Push] Error enviando push global:", err);
      return null;
    }
  });

const nodemailer = require("nodemailer");

/**
 * Obtiene el transportador de correo SMTP configurado en Firestore o en variables de entorno
 */
async function getEmailTransporter() {
  try {
    const configSnap = await admin.firestore().collection("system_settings").doc("email_config").get();
    if (configSnap.exists) {
      const c = configSnap.data();
      if (c && c.user && c.pass) {
        const host = (c.host || "smtp.gmail.com").trim();
        const port = Number(c.port) || (host.includes("gmail") ? 465 : 587);
        const secure = port === 465;
        return {
          transporter: nodemailer.createTransport({
            host,
            port,
            secure,
            auth: {
              user: c.user.trim(),
              pass: c.pass.trim(),
            },
          }),
          senderEmail: (c.senderEmail || c.user).trim(),
          senderName: c.senderName || "CONNECT",
        };
      }
    }
  } catch (err) {
    console.error("[Mail] Error al leer system_settings/email_config:", err);
  }

  const envUser = process.env.SMTP_USER;
  const envPass = process.env.SMTP_PASS;
  if (envUser && envPass) {
    const host = (process.env.SMTP_HOST || "smtp.gmail.com").trim();
    const port = Number(process.env.SMTP_PORT) || (host.includes("gmail") ? 465 : 587);
    return {
      transporter: nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user: envUser.trim(), pass: envPass.trim() },
      }),
      senderEmail: (process.env.SMTP_SENDER_EMAIL || envUser).trim(),
      senderName: process.env.SMTP_SENDER_NAME || "CONNECT",
    };
  }

  return null;
}

/**
 * Trigger para despachar correos automáticamente cuando se crea un registro en mail/
 * con status: 'sending' y category: 'sent'
 */
exports.sendEmailOnNewDoc = functions.firestore
  .document("mail/{mailId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;
    if (data.status !== "sending" || data.category !== "sent") return null;

    try {
      const emailConfig = await getEmailTransporter();
      if (!emailConfig) {
        console.warn("[Mail] No hay configuración SMTP activa en system_settings/email_config.");
        await snap.ref.update({
          status: "error",
          error: "Falta configurar credenciales SMTP en Ajustes > Servidor de Correo (ej. Gmail y Contraseña de Aplicación) para despachar a buzones externos.",
        });
        return null;
      }

      const { transporter, senderEmail, senderName } = emailConfig;
      const to = data.to;
      const subject = data.subject || "(Sin Asunto)";
      const text = data.message || data.text || "";
      const html =
        data.html ||
        `<div style="font-family: Arial, sans-serif; color: #1e293b; max-width: 600px; margin: 0 auto; padding: 25px; border: 1px solid #e2e8f0; border-radius: 8px;">
          <h2 style="color: #0094FF; font-size: 20px; font-weight: 800; margin-bottom: 20px;">CONNECT APP</h2>
          <div style="font-size: 14px; line-height: 1.6; color: #334155; margin-bottom: 25px;">
            ${(text || "").replace(/\n/g, "<br>")}
          </div>
          <div style="margin-top: 30px; border-top: 1px solid #e2e8f0; padding-top: 15px;">
            <p style="font-size: 11px; color: #94a3b8; text-align: center; margin: 0;">
              CONNECT © 2026. Todos los derechos reservados.
            </p>
          </div>
        </div>`;

      const info = await transporter.sendMail({
        from: `"${data.fromName || senderName}" <${senderEmail}>`,
        replyTo: data.from || "contacto@connectapp.com.co",
        to: to,
        subject: subject,
        text: text,
        html: html,
      });

      console.log(`[Mail] Correo enviado exitosamente a ${to}. MessageId: ${info.messageId}`);
      await snap.ref.update({
        status: "sent",
        messageId: info.messageId,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return info;
    } catch (error) {
      console.error("[Mail] Error enviando correo:", error);
      await snap.ref.update({
        status: "error",
        error: error.message,
      });
      return null;
    }
  });

/**
 * Endpoint HTTP para envío directo de correos desde el Panel Admin o servicios
 */
exports.sendDirectEmail = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { to, subject, text, html, from, fromName } = req.body || {};
  if (!to || !subject) {
    return res.status(400).json({ error: "Faltan campos obligatorios (to, subject)" });
  }

  try {
    const emailConfig = await getEmailTransporter();
    if (!emailConfig) {
      return res.status(500).json({
        error: "Falta configurar credenciales SMTP en Ajustes > Servidor de Correo para despachar a buzones externos.",
      });
    }

    const { transporter, senderEmail, senderName } = emailConfig;
    const info = await transporter.sendMail({
      from: `"${fromName || senderName}" <${senderEmail}>`,
      replyTo: from || "contacto@connectapp.com.co",
      to: to,
      subject: subject,
      text: text || "",
      html: html || `<p>${(text || "").replace(/\n/g, "<br>")}</p>`,
    });

    return res.status(200).json({ success: true, messageId: info.messageId });
  } catch (error) {
    console.error("[Mail Direct] Error:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * Endpoint de compatibilidad para evitar eliminación accidental en deploy
 */
exports.api = functions.https.onRequest((req, res) => {
  res.status(200).send("CONNECT API Active");
});

