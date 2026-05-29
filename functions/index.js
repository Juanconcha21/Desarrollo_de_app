const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

/**
 * Lógica Serverless (Backend):
 * Este trigger reacciona a la creación de usuarios en Firestore.
 * Si el rol es 'moderador', envío un correo electrónico automático al administrador usando Nodemailer.
 */
exports.notifyAdminOnNewModerator = onDocumentCreated({
  document: "users/{userId}",
  secrets: ["GMAIL_PASSWORD"]
}, async (event) => {
    const snap = event.data;
    if (!snap) return null;
    const userData = snap.data();

    console.log(`Procesando registro para: ${userData.email} con rol: ${userData.role}`);

    const gmailPass = process.env.GMAIL_PASSWORD;

    if (!gmailPass) {
      console.error("ERROR: La clave GMAIL_PASSWORD no está definida o no es accesible.");
      return null;
    }

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: "marketuafire@gmail.com",
        pass: gmailPass,
      },
    });

    // Verificamos si el nuevo usuario solicitó ser moderador
    if (userData.role === "moderador") {
      const mailOptions = {
        from: "Marketplace UA <noreply@marketua.com>",
        to: "marketuafire@gmail.com",
        subject: "⚠️ Nueva Solicitud de Moderador Pendiente",
        html: `
          <h1>Solicitud de Acceso</h1>
          <p>Un nuevo usuario se ha registrado como <b>Moderador</b>:</p>
          <ul>
            <li><strong>Nombre:</strong> ${userData.fullName}</li>
            <li><strong>Correo:</strong> ${userData.email}</li>
          </ul>
          <p>Revisar aprobación en el panel administrativo.</p>
        `,
      };

      try {
        await transporter.sendMail(mailOptions);
        console.log("Correo de aviso enviado con éxito.");
      } catch (error) {
        console.error("Error al enviar correo:", error);
      }
    }
    return null;
  });

/**
 * Orquestación de Mensajería:
 * Cuando se inserta un mensaje en un chat, recupero el token FCM del receptor y despacho una notificación Push.
 */
exports.onMessageCreated = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
    const messageData = event.data.data();
    const receiverId = messageData.receiverId;
    const senderName = messageData.senderName || "Alguien";
    const text = messageData.text;

    // 1. Obtener el token del destinatario
    const userDoc = await admin.firestore().collection("users").doc(receiverId).get();
    if (!userDoc.exists) return null;
    
    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return null;

    // 2. Construir el mensaje de notificación
    const payload = {
        token: fcmToken,
        notification: {
            title: senderName,
            body: text,
        },
        data: {
            type: "chat",
            chatId: event.params.chatId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            notification: {
                sound: "default",
            },
        },
        apns: {
            payload: {
                aps: {
                    sound: "default",
                },
            },
        },
    };

    try {
        await admin.messaging().send(payload);
        console.log(`Notificación enviada a ${receiverId}`);
    } catch (error) {
        console.error("Error enviando notificación:", error);
    }
    return null;
});

/**
 * Trigger de Cumplimiento Normativo:
 * Reacciona a la actualización del perfil del usuario. Si se detecta un cambio en el flag 'needsStrikeNotification',
 * envío la alerta al dispositivo móvil y reseteo el flag atómicamente.
 */
exports.onStrikeUpdated = onDocumentUpdated("users/{userId}", async (event) => {
    const newValue = event.data.after.data();
    const previousValue = event.data.before.data();

    // Solo disparamos si el flag de notificación cambió a true
    if (newValue.needsStrikeNotification === true && previousValue.needsStrikeNotification !== true) {
        const fcmToken = newValue.fcmToken;
        if (!fcmToken) return null;

        const strikeCount = newValue.strikes || 0;
        const payload = {
            token: fcmToken,
            notification: {
                title: "⚠️ Advertencia de Cuenta",
                body: `Has recibido un strike. Actualmente tienes ${strikeCount}/3 strikes.`,
            },
            data: { type: "strike" },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                    },
                },
            },
        };

        try {
            await admin.messaging().send(payload);
            // Limpiamos el flag para no repetir la notificación
            await admin.firestore().collection("users").doc(event.params.userId).update({
                needsStrikeNotification: false
            });
            console.log("Notificación de strike enviada.");
        } catch (error) {
            console.error("Error al notificar strike:", error);
        }
    }
    return null;
});
