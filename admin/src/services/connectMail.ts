/**
 * Servicio de envío y consulta de correos electrónicos para CONNECT (CONNECT Mail vía Cloudflare Worker).
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
 * Envía un correo electrónico a través del Cloudflare Worker de CONNECT Mail (contacto@connectapp.com.co).
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
            throw new Error(`Error en entrega Cloudflare Mail: ${errorDetail}`);
        }

        return resJson || { success: true };
    } catch (error: any) {
        console.error('CONNECT Mail Service Error:', error);
        throw error;
    }
};

export const fetchMailEvents = async () => {
    return { items: [] };
};

export const fetchMessageContent = async (_messageId: string) => {
    return { body: 'Contenido procesado por CONNECT Mail.', attachments: [] };
};
