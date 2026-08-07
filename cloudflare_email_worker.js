/**
 * Cloudflare Email Worker para CONNECT APP.
 * Recibe correos entrantes enviados a contacto@connectapp.com.co, limpia los límites MIME
 * y los guarda automáticamente en Firebase Firestore para su lectura limpia en el Panel Admin.
 */
export default {
  async email(message, env, ctx) {
    const from = message.from;
    const to = message.to;
    const subject = message.headers.get("subject") || "(Sin asunto)";
    
    const rawEmail = await new Response(message.raw).text();
    let bodyText = rawEmail;
    
    // Extraer parte de texto plano limpia si viene en formato MIME Multipart
    if (rawEmail.includes("Content-Type: text/plain")) {
      const parts = rawEmail.split("Content-Type: text/plain");
      let textPart = parts[1] || "";
      if (textPart.includes("\r\n\r\n")) {
        textPart = textPart.split("\r\n\r\n").slice(1).join("\r\n\r\n");
      } else if (textPart.includes("\n\n")) {
        textPart = textPart.split("\n\n").slice(1).join("\n\n");
      }
      if (textPart.includes("\r\n--")) {
        textPart = textPart.split("\r\n--")[0];
      }
      bodyText = textPart.trim();
    } else if (rawEmail.includes("\r\n\r\n")) {
      bodyText = rawEmail.split("\r\n\r\n").slice(1).join("\r\n\r\n");
    }

    // Limpiar restos de encabezados MIME
    bodyText = bodyText
      .replace(/--[a-zA-Z0-9_-]+/g, "")
      .replace(/Content-Type:[^\n]+/g, "")
      .replace(/charset=[^\n]+/g, "")
      .trim();

    const payload = {
      fields: {
        from: { stringValue: from },
        to: { stringValue: to },
        subject: { stringValue: subject },
        message: { stringValue: bodyText.substring(0, 4000) },
        status: { stringValue: "received" },
        category: { stringValue: "principal" },
        timestamp: { timestampValue: new Date().toISOString() }
      }
    };

    try {
      await fetch(
        "https://firestore.googleapis.com/v1/projects/connect2025-37b7c/databases/(default)/documents/mail",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload)
        }
      );
    } catch (err) {
      console.error("Error guardando en Firestore:", err);
    }

    try {
      await message.forward("irenzulsierra@gmail.com");
    } catch (err) {}
  }
};
