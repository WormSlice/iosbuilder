import { EmailMessage } from "cloudflare:email";
import { createMimeMessage } from "mimetext";

/**
 * Cloudflare Email Worker para CONNECT APP (Nativo).
 * - Maneja recepción de correos entrantes (@connectapp.com.co) y los registra en Firestore (CONNECT Mail).
 * - Maneja envío saliente de correos vía Cloudflare Email Routing binding (env.SEB).
 */
export default {
  /**
   * Manejador HTTP para envío de correos desde CONNECT (Panel Admin y App Móvil)
   */
  async fetch(request, env, ctx) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method === "POST") {
      try {
        const body = await request.json();
        const to = (body.to || "").trim();
        const from = body.fromEmail || "contacto@connectapp.com.co";
        const subject = body.subject || "(Sin Asunto)";
        const text = body.text || "";
        const html = body.html || "";

        if (!to) {
          return new Response(JSON.stringify({ error: "Falta el destinatario (to)" }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          });
        }

        const msg = createMimeMessage();
        msg.setSender({ name: body.fromName || "CONNECT", addr: from });
        msg.setRecipient(to);
        msg.setSubject(subject);
        if (text) msg.addMessage({ contentType: "text/plain", data: text });
        if (html) msg.addMessage({ contentType: "text/html", data: html });

        const emailMessage = new EmailMessage(
          from,
          to,
          msg.asRaw()
        );

        if (!env.SEB) {
          throw new Error("El binding de envío de Cloudflare (SEB / send_email) no está configurado en este Worker.");
        }

        await env.SEB.send(emailMessage);

        return new Response(JSON.stringify({ 
          success: true, 
          message: "Correo enviado exitosamente vía Cloudflare Email" 
        }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
    }

    return new Response(JSON.stringify({ status: "CONNECT Mail Worker Activo (Cloudflare Nativo)" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  },

  /**
   * Manejador de Email Routing de Cloudflare para correos entrantes
   */
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
    } catch (err) { }
  }
};
