/**
 * Servicio de envío y consulta de correos electrónicos vía Cloudflare Worker (CONNECT Mail).
 */

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
 * Envía un correo electrónico a través del Cloudflare Worker de CONNECT Mail.
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
        from: `${fromName} <${fromEmail}>`,
        fromEmail,
        fromName,
        to: toEmail,
        subject: data.subject
    };

    if (data.html) {
        payload.html = data.html;
    }
    if (data.text) {
        payload.text = data.text;
    }

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

    try {
        const response = await fetch(WORKER_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        const resText = await response.text();
        let resJson: any = null;
        try {
            resJson = JSON.parse(resText);
        } catch (_) {}

        if (!response.ok) {
            const errorDetail = resJson?.error || resJson?.message || resText || response.statusText;
            console.error('Cloudflare Mail Worker Error:', errorDetail);
            throw new Error(`Error Cloudflare Mail (${response.status}): ${errorDetail}`);
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
    return { body: 'Contenido procesado por Cloudflare Mail.', attachments: [] };
};
