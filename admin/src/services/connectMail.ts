/**
 * Servicio de envío y consulta de correos electrónicos para CONNECT (CONNECT Mail).
 * 1. Intenta enviar a través de la Cloud Function de Firebase (sendDirectEmail), que soporta cualquier destinatario vía SMTP.
 * 2. Si la Cloud Function no está disponible o no tiene SMTP aún, recurre al Cloudflare Worker como fallback.
 */

const CLOUD_FUNCTION_URL = 'https://us-central1-connect2025-37b7c.cloudfunctions.net/sendDirectEmail';
const WORKER_URL = import.meta.env.VITE_MAIL_WORKER_URL || 'https://connect-email-receiver.irenzulsierra.workers.dev';

export interface EmailData {
    to: string;
    subject: string;
    text?: string;
    html?: string;
    from?: string; // Formato: "Nombre <email@dominio.com>" o "email@dominio.com"
    attachments?: File[];
}

/**
 * Convierte un File a Base64 para adjuntarlo en el correo.
 */
const fileToBase64 = (file: File): Promise<string> => {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onload = () => {
            const base64String = reader.result as string;
            resolve(base64String.split(',')[1]);
        };
        reader.onerror = (error) => reject(error);
    });
};

/**
 * Envía un correo electrónico intentando primero vía Cloud Function (SMTP) y con fallback a Cloudflare.
 */
export const sendEmail = async (data: EmailData) => {
    let fromEmail = 'contacto@connectapp.com.co';
    let fromName = 'CONNECT';
    
    if (data.from) {
        const match = data.from.match(/(.*)<(.*)>/);
        if (match) {
            fromName = match[1].trim();
            fromEmail = match[2].trim();
        } else {
            fromEmail = data.from.trim();
        }
    }

    const toEmail = data.to.trim();

    const payload: any = {
        from: fromEmail,
        fromEmail,
        fromName,
        to: toEmail,
        subject: data.subject,
        text: data.text,
        html: data.html
    };

    if (data.attachments && data.attachments.length > 0) {
        const attachments = await Promise.all(
            data.attachments.map(async (file) => ({
                content: await fileToBase64(file),
                filename: file.name,
                disposition: 'attachment'
            }))
        );
        payload.attachments = attachments;
    }

    // 1. Intentar primero con la Cloud Function de Firebase
    try {
        const cfResponse = await fetch(CLOUD_FUNCTION_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const cfText = await cfResponse.text();
        let cfJson: any = null;
        try { cfJson = JSON.parse(cfText); } catch (_) {}

        if (cfResponse.ok) {
            return cfJson || { success: true };
        }

        console.warn('Firebase Cloud Function sendDirectEmail reportó:', cfJson?.error || cfText);
    } catch (cfError) {
        console.warn('Fallo de conexión a Firebase Cloud Function sendDirectEmail:', cfError);
    }

    // 2. Fallback a Cloudflare Worker
    try {
        const response = await fetch(WORKER_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const resText = await response.text();
        let resJson: any = null;
        try { resJson = JSON.parse(resText); } catch (_) {}

        if (!response.ok) {
            const errorDetail = resJson?.error || resJson?.message || resText || response.statusText;
            throw new Error(`Error en entrega: ${errorDetail}`);
        }

        return resJson || { success: true };
    } catch (error: any) {
        console.error('CONNECT Mail Service Error:', error);
        throw error;
    }
};

/**
 * Obtiene eventos de correo (si aplica)
 */
export const fetchMailEvents = async () => {
    return { items: [] };
};

/**
 * Obtiene contenido detallado de un mensaje
 */
export const fetchMessageContent = async (_messageId: string) => {
    return { body: 'Contenido procesado por CONNECT Mail.', attachments: [] };
};
