import { EmailMessage } from "cloudflare:email";

/**
 * Cloudflare Email Worker para CONNECT APP (100% Nativo, sin dependencias externas de npm).
 * - Maneja recepción de correos entrantes (@connectapp.com.co) y los registra en Firestore (CONNECT Mail).
 * - Reenvía una copia íntegra del correo entrante al correo principal (irenzulsierra@gmail.com).
 * - Extrae texto, html, imágenes inline (CID a Data URI) y archivos adjuntos para previsualizarlos en el Panel Admin.
 * - Maneja envío saliente de correos vía Cloudflare Email Routing binding (env.SEB).
 */

/**
 * Convierte un string UTF-8 a Base64 de forma nativa sin librerías externas
 */
function stringToBase64(str) {
  if (!str) return '';
  const bytes = new TextEncoder().encode(str);
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

/**
 * Construye un mensaje MIME multipart/alternative nativo conforme a RFC 5322 y RFC 2046
 */
function buildRawMimeMessage({ fromName, fromEmail, to, subject, text, html }) {
  const boundary = `----=_Part_${Date.now()}_${Math.random().toString(36).substring(2)}`;
  const senderHeader = fromName ? `"${fromName.replace(/"/g, '')}" <${fromEmail}>` : fromEmail;
  const encodedSubject = `=?UTF-8?B?${stringToBase64(subject)}?=`;

  const headers = [
    `From: ${senderHeader}`,
    `To: ${to}`,
    `Subject: ${encodedSubject}`,
    `MIME-Version: 1.0`,
    `Content-Type: multipart/alternative; boundary="${boundary}"`
  ];

  const parts = [];

  if (text) {
    parts.push(
      `--${boundary}\r\n` +
      `Content-Type: text/plain; charset=UTF-8\r\n` +
      `Content-Transfer-Encoding: base64\r\n\r\n` +
      stringToBase64(text)
    );
  }

  if (html) {
    parts.push(
      `--${boundary}\r\n` +
      `Content-Type: text/html; charset=UTF-8\r\n` +
      `Content-Transfer-Encoding: base64\r\n\r\n` +
      stringToBase64(html)
    );
  }

  if (!text && !html) {
    parts.push(
      `--${boundary}\r\n` +
      `Content-Type: text/plain; charset=UTF-8\r\n` +
      `Content-Transfer-Encoding: base64\r\n\r\n` +
      stringToBase64(' ')
    );
  }

  parts.push(`--${boundary}--\r\n`);

  return headers.join('\r\n') + '\r\n\r\n' + parts.join('\r\n');
}

/**
 * Decodifica Quoted-Printable (RFC 2045)
 */
function decodeQuotedPrintable(str) {
  if (!str) return '';
  let s = str.replace(/=(?:\r\n|\r|\n)/g, '');
  s = s.replace(/((?:=[0-9A-Fa-f]{2})+)/g, (match) => {
    try {
      const hexPairs = match.split('=').filter(Boolean);
      const bytes = new Uint8Array(hexPairs.map(h => parseInt(h, 16)));
      return new TextDecoder('utf-8', { fatal: false }).decode(bytes);
    } catch {
      return match;
    }
  });
  s = s.replace(/=3D/gi, '=').replace(/=20/g, ' ').replace(/=09/g, '\t');
  return s;
}

/**
 * Decodifica MIME Words (RFC 2047)
 */
function decodeMimeWords(str) {
  if (!str) return '';
  return str.replace(/=\?([a-zA-Z0-9_-]+)\?([bBqQ])\?([^?]*)\?=/g, (_, charset, encoding, text) => {
    try {
      const enc = encoding.toUpperCase();
      if (enc === 'B') {
        const bin = atob(text.trim());
        const bytes = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
        return new TextDecoder(charset, { fatal: false }).decode(bytes);
      } else if (enc === 'Q') {
        return decodeQuotedPrintable(text.replace(/_/g, '=20'));
      }
    } catch {
      return text;
    }
    return text;
  });
}

/**
 * Limpia HTML a texto plano para snippets
 */
function cleanHtmlToText(html) {
  if (!html) return '';
  return html
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<head[^>]*>[\s\S]*?<\/head>/gi, '')
    .replace(/<style[^>]*>[\s\S]*$/gi, '')
    .replace(/<script[^>]*>[\s\S]*$/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/<[^>]*$/g, '')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Parsea recursivamente un mensaje MIME conforme a RFC 2046 / RFC 5322
 * Extrae HTML, Texto plano, Imágenes inline (CID) y Archivos adjuntos.
 */
function parseMimeParts(rawInput) {
  if (!rawInput) return { html: '', text: '', attachments: [] };

  let html = '';
  let text = '';
  const attachments = [];
  const cidMap = {};

  function parseHeaders(headerStr) {
    const headers = {};
    if (!headerStr) return headers;
    const unfolded = headerStr.replace(/\r?\n[ \t]+/g, ' ');
    const lines = unfolded.split(/\r?\n/);
    for (const line of lines) {
      const colonIdx = line.indexOf(':');
      if (colonIdx > 0) {
        const key = line.substring(0, colonIdx).trim().toLowerCase();
        const value = line.substring(colonIdx + 1).trim();
        headers[key] = value;
      }
    }
    return headers;
  }

  function extractBoundary(contentTypeHeader, body) {
    if (contentTypeHeader) {
      const m = contentTypeHeader.match(/boundary=["']?([^"';\r\n]+)["']?/i);
      if (m) return m[1].trim();
    }
    if (body) {
      const m = body.match(/^--([a-zA-Z0-9'()+_,-./:=?]+)/m);
      if (m) return m[1].trim();
    }
    return null;
  }

  function decodeBody(content, encoding) {
    if (!content) return '';
    const enc = (encoding || '').toLowerCase().trim();
    if (enc === 'quoted-printable') {
      return decodeQuotedPrintable(content);
    } else if (enc === 'base64') {
      try {
        const cleanB64 = content.replace(/[\r\n\s]+/g, '');
        const bin = atob(cleanB64);
        const bytes = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
        return new TextDecoder('utf-8', { fatal: false }).decode(bytes);
      } catch {
        return content;
      }
    }
    return content;
  }

  function processEntity(rawEntity) {
    if (!rawEntity) return;

    let headers = {};
    let body = rawEntity;

    const splitIdx = rawEntity.search(/\r?\n\r?\n/);
    if (splitIdx !== -1) {
      headers = parseHeaders(rawEntity.substring(0, splitIdx));
      body = rawEntity.substring(splitIdx).replace(/^\r?\n\r?\n/, '');
    }

    const contentTypeHeader = headers['content-type'] || '';
    const contentType = contentTypeHeader.split(';')[0].trim().toLowerCase() || 'text/plain';
    const encoding = headers['content-transfer-encoding'] || '';
    const disposition = headers['content-disposition'] || '';

    // Extraer nombre de archivo
    let filename = null;
    const fnMatch = (disposition + ';' + contentTypeHeader).match(/(?:filename|name)=["']?([^"';\r\n]+)["']?/i);
    if (fnMatch) {
      filename = decodeMimeWords(fnMatch[1].trim());
    }

    // Extraer Content-ID para imágenes inline
    let contentId = null;
    if (headers['content-id']) {
      contentId = headers['content-id'].trim().replace(/^<|>$/g, '');
    }

    // 1. Manejo de contenedores Multipart
    if (contentType.startsWith('multipart/')) {
      const boundary = extractBoundary(contentTypeHeader, body);
      if (boundary) {
        const escBoundary = boundary.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
        const delimiter = new RegExp('--' + escBoundary);
        const parts = body.split(delimiter);

        for (let part of parts) {
          part = part.trim();
          if (!part || part === '--' || part.startsWith('--')) continue;
          processEntity(part);
        }
        return;
      }
    }

    // 2. Manejo de imágenes (inline o adjuntos)
    const isImage = contentType.startsWith('image/');
    const isAttachment = disposition.toLowerCase().includes('attachment') || (!contentType.startsWith('text/') && filename);
    const isInlineImage = isImage && (contentId || disposition.toLowerCase().includes('inline') || filename);

    if (isInlineImage || (isImage && isAttachment)) {
      let cleanB64 = body.replace(/[\r\n\s]+/g, '');
      if (encoding.toLowerCase().includes('quoted-printable')) {
        try { cleanB64 = btoa(decodeQuotedPrintable(body)); } catch {}
      }
      const dataUri = `data:${contentType};base64,${cleanB64}`;

      if (contentId) {
        cidMap[contentId] = dataUri;
      }
      attachments.push({
        filename: filename || contentId || 'imagen.jpg',
        contentType,
        size: Math.round((cleanB64.length * 3) / 4),
        data: dataUri,
        isInline: true
      });
      return;
    }

    // 3. Manejo de otros adjuntos (PDFs, documentos, etc.)
    if (isAttachment) {
      let cleanB64 = body.replace(/[\r\n\s]+/g, '');
      const dataUri = `data:${contentType};base64,${cleanB64}`;
      attachments.push({
        filename: filename || 'archivo_adjunto',
        contentType,
        size: Math.round((cleanB64.length * 3) / 4),
        data: dataUri,
        isInline: false
      });
      return;
    }

    // 4. Manejo de Texto plano y HTML
    const decoded = decodeBody(body, encoding);
    if (contentType.includes('text/html')) {
      if (!html) html = decoded.trim();
    } else if (contentType.includes('text/plain')) {
      // Si no hay cabeceras de content-type y parece HTML, tratarlo como HTML
      if (/<(?:html|!doctype|body|table|div|p|span|section)[\s>]/i.test(decoded) && !headers['content-type']) {
        if (!html) html = decoded.trim();
      } else {
        if (!text) text = decoded.trim();
      }
    }
  }

  processEntity(rawInput);

  // Reemplazar referencias cid: en el HTML por el Data URI real en Base64 o tarjeta informativa si es muy pesada
  if (html && Object.keys(cidMap).length > 0) {
    let currentHtmlSize = html.length;
    for (const [cid, dataUri] of Object.entries(cidMap)) {
      const reg = new RegExp(`<img([^>]*?)src=["']?cid:${cid.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&')}["']?([^>]*?)>`, 'gi');
      
      // Si la imagen cabe de forma segura en Firestore (< 450KB)
      if (dataUri && dataUri.length <= 450000 && (currentHtmlSize + dataUri.length < 650000)) {
        html = html.replace(reg, `<img$1src="${dataUri}"$2>`);
        currentHtmlSize += dataUri.length;
      } else {
        // Para fotos muy pesadas (>450KB, ej. fotos de cámara de celular de 1-5MB), no romper el HTML cortándolo
        const matchedAtt = attachments.find(a => a.data === dataUri);
        const name = matchedAtt ? matchedAtt.filename : 'Foto adjunta';
        const sizeMb = matchedAtt ? (matchedAtt.size / (1024 * 1024)).toFixed(1) : '1+';
        const card = `<div style="margin: 16px 0; padding: 16px 20px; background: #f8fafc; border: 1.5px dashed #cbd5e1; border-radius: 12px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 520px;"><div style="display:flex;align-items:center;gap:12px;"><span style="font-size:26px;">📸</span><div><strong style="color:#0f172a;font-size:13px;display:block;">${name}</strong><span style="color:#64748b;font-size:11px;">Foto de alta resolución (${sizeMb} MB)</span></div></div><p style="margin:10px 0 0 0;font-size:11.5px;color:#475569;line-height:1.5;">Esta imagen supera el límite de base de datos para previsualización directa en el panel, pero fue <strong>reenviada íntegra y completa a tu correo principal</strong> (<a href="mailto:irenzulsierra@gmail.com" style="color:#0094FF;font-weight:600;">irenzulsierra@gmail.com</a>).</p></div>`;
        html = html.replace(reg, card);
      }
    }
  }

  if (html && !text) {
    text = cleanHtmlToText(html);
  }

  return { html, text, attachments };
}

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

        const rawMime = buildRawMimeMessage({
          fromName: body.fromName || "CONNECT",
          fromEmail: from,
          to,
          subject,
          text,
          html
        });

        const emailMessage = new EmailMessage(
          from,
          to,
          rawMime
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
    const rawFrom = message.headers.get("from") || message.from;
    const from = decodeMimeWords(rawFrom);
    const rawTo = message.headers.get("to") || message.to;
    const to = decodeMimeWords(rawTo);
    const rawSubject = message.headers.get("subject") || "(Sin asunto)";
    const subject = decodeMimeWords(rawSubject);

    // 1. REENVÍO INMEDIATO AL CORREO PRINCIPAL (Antes de consumir streams)
    const forwardTo = env.FORWARD_TO || "irenzulsierra@gmail.com";
    try {
      await message.forward(forwardTo);
      console.log(`Correo reenviado exitosamente a correo principal (${forwardTo})`);
    } catch (forwardErr) {
      console.error(`Error reenviando correo a ${forwardTo}:`, forwardErr.message || forwardErr);
    }

    // 2. LECTURA Y PARSEO DEL MENSAJE COMPLETO
    let rawEmail = '';
    try {
      rawEmail = await new Response(message.raw).text();
    } catch (readErr) {
      console.error("Error leyendo stream del correo:", readErr);
    }

    const { html, text, attachments } = parseMimeParts(rawEmail);

    const mainMessage = text || cleanHtmlToText(html) || "(Mensaje sin contenido)";
    const snippet = mainMessage.substring(0, 150);

    // 3. PREPARACIÓN DE ADJUNTOS PARA FIRESTORE (Máximo ~750KB total para no exceder límite de 1MB de Firestore)
    let currentPayloadSize = (html ? html.length : 0) + (text ? text.length : 0);
    const safeAttachments = [];

    for (const att of (attachments || [])) {
      let attData = att.data || '';
      // Si el adjunto es muy grande (> 350KB) o excede el límite del documento, no incluir el Base64 en Firestore
      // El archivo completo ya fue reenviado a irenzulsierra@gmail.com
      if (attData.length > 350000 || (currentPayloadSize + attData.length > 750000)) {
        attData = '';
      } else {
        currentPayloadSize += attData.length;
      }

      safeAttachments.push({
        mapValue: {
          fields: {
            filename: { stringValue: att.filename || 'adjunto' },
            contentType: { stringValue: att.contentType || 'application/octet-stream' },
            size: { integerValue: String(att.size || 0) },
            data: { stringValue: attData },
            isInline: { booleanValue: !!att.isInline }
          }
        }
      });
    }

    // Limitar HTML a 500.000 caracteres máximo sin cortar etiquetas
    let safeHtml = html || "";
    if (safeHtml.length > 500000) {
      const lastTag = safeHtml.lastIndexOf('>', 500000);
      safeHtml = lastTag !== -1 ? safeHtml.substring(0, lastTag + 1) : safeHtml.substring(0, 500000);
    }

    const payload = {
      fields: {
        from: { stringValue: from },
        to: { stringValue: to },
        subject: { stringValue: subject },
        message: { stringValue: mainMessage.substring(0, 100000) },
        html: { stringValue: safeHtml },
        text: { stringValue: (text || "").substring(0, 100000) },
        snippet: { stringValue: snippet },
        status: { stringValue: "received" },
        category: { stringValue: "principal" },
        timestamp: { timestampValue: new Date().toISOString() },
        attachmentsCount: { integerValue: String(safeAttachments.length) },
        attachments: {
          arrayValue: {
            values: safeAttachments
          }
        }
      }
    };

    // 4. GUARDADO EN FIRESTORE (CONNECT Mail)
    try {
      const res = await fetch(
        "https://firestore.googleapis.com/v1/projects/connect2025-37b7c/databases/(default)/documents/mail",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload)
        }
      );
      if (!res.ok) {
        const errorText = await res.text();
        console.error("Error respuesta Firestore REST:", res.status, errorText);
      }
    } catch (err) {
      console.error("Error guardando en Firestore:", err);
    }
  }
};
