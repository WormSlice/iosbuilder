/**
 * Utilidades para decodificación y parseo de correos electrónicos en CONNECT Mail.
 * Soporta decodificación de Quoted-Printable, MIME Encoded Words (RFC 2047),
 * Multipart boundaries (text/plain, text/html, imágenes inline CID y archivos adjuntos).
 */

export interface MailAttachment {
    filename: string;
    contentType: string;
    size: number;
    data: string;
    isInline?: boolean;
}

export interface ParsedEmailContent {
    html: string;
    text: string;
    snippet: string;
    isHtml: boolean;
    isTruncatedOrEmptyHtml?: boolean;
    attachments: MailAttachment[];
}

export interface FriendlySender {
    name: string;
    email: string;
    initials: string;
}

/**
 * Decodifica texto codificado en Quoted-Printable (RFC 2045)
 */
export function decodeQuotedPrintable(str: any): string {
    if (!str || typeof str !== 'string') return String(str || '');

    // Eliminar saltos suaves de línea (= al final de línea)
    let s = str.replace(/=(?:\r\n|\r|\n)/g, '');

    // Decodificar secuencias continuas de bytes hexadecimales (=XX)
    s = s.replace(/((?:=[0-9A-Fa-f]{2})+)/g, (match) => {
        try {
            const hexPairs = match.split('=').filter(Boolean);
            const bytes = new Uint8Array(hexPairs.map(h => parseInt(h, 16)));
            return new TextDecoder('utf-8', { fatal: false }).decode(bytes);
        } catch {
            return match;
        }
    });

    s = s.replace(/=3D/gi, '=')
         .replace(/=20/g, ' ')
         .replace(/=09/g, '\t');

    return s;
}

/**
 * Decodifica palabras codificadas según RFC 2047 (=?charset?encoding?encoded_text?=)
 */
export function decodeMimeWords(str: any): string {
    if (!str || typeof str !== 'string') return String(str || '(Sin asunto)');

    let decoded = str.replace(/=\?([a-zA-Z0-9_-]+)\?([bBqQ])\?([^?]*)\?=/g, (_, charset, encoding, text) => {
        try {
            const enc = encoding.toUpperCase();
            if (enc === 'B') {
                const bin = atob(text.trim());
                const bytes = new Uint8Array(bin.length);
                for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
                return new TextDecoder(charset, { fatal: false }).decode(bytes);
            } else if (enc === 'Q') {
                const qp = text.replace(/_/g, '=20');
                return decodeQuotedPrintable(qp);
            }
        } catch {
            return text;
        }
        return text;
    });

    return decoded.trim();
}

/**
 * Convierte código HTML a texto plano legible para previsualizaciones (snippets).
 */
export function cleanHtmlToText(html: string): string {
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
        .replace(/&#x27;/gi, "'")
        .replace(/\s+/g, ' ')
        .trim();
}

/**
 * Repara etiquetas HTML y comillas cortadas abruptamente
 */
export function repairTruncatedHtml(html: string): string {
    if (!html) return '';
    let repaired = html;

    // Si tiene comillas desbalanceadas al final de un atributo
    const quotesCount = (repaired.match(/"/g) || []).length;
    if (quotesCount % 2 !== 0) {
        repaired += '"';
    }

    // Si tiene una etiqueta abierta sin cerrar (ej: <table ... )
    const lastOpen = repaired.lastIndexOf('<');
    const lastClose = repaired.lastIndexOf('>');
    if (lastOpen > lastClose) {
        repaired += '>';
    }

    // Cerrar etiquetas comunes si quedaron huérfanas
    if (repaired.includes('<table') && !repaired.includes('</table>')) repaired += '</table>';
    if (repaired.includes('<div') && !repaired.includes('</div>')) repaired += '</div>';
    if (repaired.includes('<body') && !repaired.includes('</body>')) repaired += '</body>';
    if (repaired.includes('<html') && !repaired.includes('</html>')) repaired += '</html>';

    return repaired;
}

/**
 * Parsea el contenido de un correo (MIME, HTML o Texto plano)
 * Extrae texto, html, imágenes inline (CID) y adjuntos.
 */
export function parseEmailBody(raw: any, existingAttachments: MailAttachment[] = []): ParsedEmailContent {
    if (!raw) {
        return {
            html: '',
            text: '',
            snippet: '(Sin contenido)',
            isHtml: false,
            isTruncatedOrEmptyHtml: false,
            attachments: existingAttachments
        };
    }

    // Si viene como objeto
    if (typeof raw === 'object' && !Array.isArray(raw)) {
        const rawHtml = raw.html || '';
        const rawText = raw.text || raw.message || '';
        const cleanText = rawText || cleanHtmlToText(rawHtml);
        const isEmptyHtml = !!rawHtml && cleanHtmlToText(rawHtml).trim().length === 0;

        return {
            html: rawHtml ? wrapHtmlDocument(rawHtml, isEmptyHtml) : '',
            text: cleanText,
            snippet: cleanText.substring(0, 120) || (isEmptyHtml ? '(Correo sin texto visible)' : '(Mensaje con formato HTML)'),
            isHtml: !!rawHtml,
            isTruncatedOrEmptyHtml: isEmptyHtml,
            attachments: existingAttachments
        };
    }

    const rawStr = String(raw);
    let html = '';
    let text = '';
    const cidMap: Record<string, string> = {};
    const extractedAttachments: MailAttachment[] = [...existingAttachments];

    // Poblar cidMap con adjuntos existentes si tienen data
    for (const att of existingAttachments) {
        if (att.data && att.filename) {
            cidMap[att.filename] = att.data;
        }
    }

    function parseHeaders(headerStr: string) {
        const headers: Record<string, string> = {};
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

    function extractBoundary(contentTypeHeader: string, body: string) {
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

    function decodeBody(content: string, encoding: string) {
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

    function processEntity(rawEntity: string) {
        if (!rawEntity) return;

        let headers: Record<string, string> = {};
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
        let filename: string | null = null;
        const fnMatch = (disposition + ';' + contentTypeHeader).match(/(?:filename|name)=["']?([^"';\r\n]+)["']?/i);
        if (fnMatch) {
            filename = decodeMimeWords(fnMatch[1].trim());
        }

        // Extraer Content-ID para imágenes inline
        let contentId: string | null = null;
        if (headers['content-id']) {
            contentId = headers['content-id'].trim().replace(/^<|>$/g, '');
        }

        // 1. Contenedor Multipart
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

        // 2. Imágenes inline o adjuntos
        const isImage = contentType.startsWith('image/');
        const isAttachment = disposition.toLowerCase().includes('attachment') || (!contentType.startsWith('text/') && !!filename);
        const isInlineImage = isImage && (!!contentId || disposition.toLowerCase().includes('inline') || !!filename);

        if (isInlineImage || (isImage && isAttachment)) {
            let cleanB64 = body.replace(/[\r\n\s]+/g, '');
            if (encoding.toLowerCase().includes('quoted-printable')) {
                try { cleanB64 = btoa(decodeQuotedPrintable(body)); } catch {}
            }
            const dataUri = `data:${contentType};base64,${cleanB64}`;

            if (contentId) {
                cidMap[contentId] = dataUri;
            }
            extractedAttachments.push({
                filename: filename || contentId || 'imagen.jpg',
                contentType,
                size: Math.round((cleanB64.length * 3) / 4),
                data: dataUri,
                isInline: true
            });
            return;
        }

        if (isAttachment) {
            let cleanB64 = body.replace(/[\r\n\s]+/g, '');
            const dataUri = `data:${contentType};base64,${cleanB64}`;
            extractedAttachments.push({
                filename: filename || 'archivo_adjunto',
                contentType,
                size: Math.round((cleanB64.length * 3) / 4),
                data: dataUri,
                isInline: false
            });
            return;
        }

        // 3. Texto o HTML
        let decoded = decodeBody(body, encoding);
        if (contentType.includes('text/html')) {
            if (!html) html = decoded.trim();
        } else if (contentType.includes('text/plain')) {
            if (/<(?:html|!doctype|body|table|div|p|span|section)[\s>]/i.test(decoded) && !headers['content-type']) {
                if (!html) html = decoded.trim();
            } else {
                if (!text) text = decoded.trim();
            }
        }
    }

    processEntity(rawStr);

    // Reemplazar referencias cid: en HTML con Data URI real
    if (html) {
        if (Object.keys(cidMap).length > 0) {
            for (const [cid, dataUri] of Object.entries(cidMap)) {
                const reg = new RegExp(`src=["']?cid:${cid.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&')}["']?`, 'gi');
                html = html.replace(reg, `src="${dataUri}"`);
            }
        }

        // Reemplazar imágenes cid que NO tengan datos para que NUNCA muestren el icono roto del navegador
        html = html.replace(/<img([^>]*?)src=["']cid:([^"']+)["']([^>]*?)>/gi, (_, before, cid, after) => {
            const altMatch = (before + ' ' + after).match(/alt=["']([^"']+)["']/i);
            const altText = altMatch ? altMatch[1] : cid;
            return `<div style="display:inline-flex;align-items:center;gap:8px;padding:8px 14px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;margin:8px 0;font-size:12px;color:#334155;font-family:sans-serif;box-shadow:0 1px 2px rgba(0,0,0,0.05);"><span style="font-size:16px;">🖼️</span> <span><strong>Imagen adjunta:</strong> ${altText}</span></div>`;
        });
    }

    // Si tiene un tag de imagen cortado o con base64 corrupto que no cierra
    if (html.includes('src="data:image/') && !html.includes('">') && !html.includes('" >')) {
        html = repairTruncatedHtml(html);
    }

    const isHtml = !!html && /<(?:html|!doctype|body|table|div|p|span|section)[\s>]/i.test(html);
    const hasMediaOrAttachments = extractedAttachments.length > 0 || /<img[\s>]/i.test(html) || /data:image\//i.test(html) || /📸|📷|🖼️/.test(html);
    const visibleText = cleanHtmlToText(html || text);

    // Un correo SOLO se considera "histórico incompleto" si:
    // 1. NO tiene adjuntos ni imágenes
    // 2. NO tiene texto visible en el cuerpo
    // 3. Su longitud es exactamente <= 4096 caracteres (recorte del script antiguo)
    const isTruncatedOrEmptyHtml = !hasMediaOrAttachments && isHtml && visibleText.trim().length === 0 && (rawStr.length <= 4096 || rawStr.includes('style="table-layout: fixed; vertical-align: top;'));

    const snippet = text ? text.substring(0, 120) : (isTruncatedOrEmptyHtml ? '(Correo sin texto visible / incompleto)' : (hasMediaOrAttachments ? '(Mensaje con imagen o archivo adjunto)' : '(Mensaje con contenido HTML)'));

    const finalHtml = html ? wrapHtmlDocument(repairTruncatedHtml(html), isTruncatedOrEmptyHtml) : '';

    return {
        html: finalHtml,
        text: text || '',
        snippet,
        isHtml,
        isTruncatedOrEmptyHtml,
        attachments: extractedAttachments
    };
}

/**
 * Asegura que el HTML tenga un contenedor aislado, codificación utf-8,
 * enlaces que abran en nueva pestaña y estilos responsivos básicos.
 */
export function wrapHtmlDocument(html: string, isTruncatedOrEmpty = false): string {
    const hasHtmlTag = /<html[\s>]/i.test(html);
    const hasHeadTag = /<head[\s>]/i.test(html);

    const baseTarget = '<base target="_blank">';
    const responsiveStyles = `
        <style>
            html, body {
                margin: 0;
                padding: 16px;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                color: #1e293b;
                line-height: 1.6;
                background-color: #ffffff;
                word-wrap: break-word;
            }
            img { max-width: 100% !important; height: auto !important; border-radius: 6px; }
            table { max-width: 100% !important; }
            a { color: #0094FF; text-decoration: underline; }
            .legacy-warning {
                background-color: #fffbeb;
                border: 1px solid #fef3c7;
                border-radius: 8px;
                padding: 16px;
                margin-bottom: 20px;
                color: #92400e;
                font-size: 13px;
                line-height: 1.5;
            }
        </style>
    `;

    const warningBanner = isTruncatedOrEmpty ? `
        <div class="legacy-warning">
            <strong>⚠️ Nota de Correo Histórico:</strong> Este correo fue almacenado previamente de forma incompleta por la configuración antigua del servidor (cortado a 4.000 caracteres antes del contenido del cuerpo). Los correos entrantes actuales ya se reciben de manera íntegra y completa con imágenes y adjuntos.
        </div>
    ` : '';

    if (hasHtmlTag && hasHeadTag) {
        let modified = html.replace(/<head[^>]*>/i, `$&${baseTarget}${responsiveStyles}`);
        if (warningBanner && modified.includes('<body')) {
            modified = modified.replace(/<body[^>]*>/i, `$&${warningBanner}`);
        }
        return modified;
    } else if (hasHtmlTag) {
        return html.replace(/<html[^>]*>/i, `$&<head><meta charset="utf-8">${baseTarget}${responsiveStyles}</head><body>${warningBanner}`);
    }

    return `<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    ${baseTarget}
    ${responsiveStyles}
</head>
<body>
    ${warningBanner}
    ${html}
</body>
</html>`;
}

/**
 * Obtiene un nombre de remitente amigable y legible para mostrar en la interfaz.
 */
export function getFriendlySender(from: string, subject?: string, content?: string): FriendlySender {
    const cleanFrom = (from || '').trim();
    let name = '';
    let email = cleanFrom;

    // Formato RFC: "Nombre Remitente" <correo@dominio.com> o Nombre <correo@dominio.com>
    const match = cleanFrom.match(/^(?:"?([^"]*)"?\s)?<?([^>]+)>?$/);
    if (match) {
        if (match[1]) name = decodeMimeWords(match[1]).trim();
        if (match[2]) email = match[2].trim();
    }

    // Si el remitente es un correo de rebote de Amazon SES (hash largo @amazonses.com)
    if (email.includes('amazonses.com')) {
        const fullContext = ((subject || '') + ' ' + (content || '')).toUpperCase();
        if (fullContext.includes('PRICESMART')) name = 'PriceSmart Colombia';
        else if (fullContext.includes('EPAYCO')) name = 'ePayco';
        else if (fullContext.includes('WOMPI')) name = 'Wompi';
        else if (fullContext.includes('APPLE')) name = 'Apple';
        else if (fullContext.includes('DIAN')) name = 'DIAN';
        else name = 'Notificación Externa';
    } else if (!name) {
        const userPart = email.split('@')[0] || 'Remitente';
        name = userPart.replace(/[._-]/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    }

    const initials = name
        .split(' ')
        .filter(Boolean)
        .slice(0, 2)
        .map(w => w[0].toUpperCase())
        .join('') || 'EM';

    return { name, email, initials };
}
