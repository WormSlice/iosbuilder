/**
 * Servicio de integración con MailGun para el envío de correos electrónicos.
 * Utiliza la API v3 de MailGun con autenticación Basic.
 */

const DOMAIN = import.meta.env.VITE_MAILGUN_DOMAIN;
const API_KEY = import.meta.env.VITE_MAILGUN_API_KEY;
const BASE_URL = import.meta.env.DEV ? '/api/mailgun' : import.meta.env.VITE_MAILGUN_BASE_URL;

export interface EmailData {
    to: string;
    subject: string;
    text?: string;
    html?: string;
    from?: string;
    attachments?: File[];
}

/**
 * Envía un correo electrónico utilizando la API de MailGun.
 * @param data Objeto con la información del correo (destinatario, asunto, contenido).
 * @returns Promesa con la respuesta de la API de MailGun.
 */
export const sendEmail = async (data: EmailData) => {
    if (!API_KEY || !DOMAIN || !BASE_URL) {
        throw new Error('Configuración de MailGun incompleta en las variables de entorno.');
    }

    // MailGun requiere el usuario 'api' para la autenticación Basic
    const auth = btoa(`api:${API_KEY}`);

    const formData = new FormData();
    formData.append('from', data.from || `CONNECT <contacto@${DOMAIN}>`);
    formData.append('to', data.to);
    formData.append('subject', data.subject);

    if (data.text) {
        formData.append('text', data.text);
    }

    if (data.html) {
        formData.append('html', data.html);
    }

    if (data.attachments && data.attachments.length > 0) {
        data.attachments.forEach(file => {
            formData.append('attachment', file);
        });
    }

    try {
        const response = await fetch(`${BASE_URL}/${DOMAIN}/messages`, {
            method: 'POST',
            headers: {
                'Authorization': `Basic ${auth}`
            },
            body: formData
        });

        const result = await response.json();

        if (!response.ok) {
            throw new Error(result.message || 'Error al enviar el correo a través de MailGun.');
        }

        return result;
    } catch (error: any) {
        console.error('MailGun Service Error:', error);
        throw error;
    }
};

/**
 * Fetch MailGun events to track delivery and incoming messages
 */
export const fetchMailEvents = async () => {
    try {
        // Pedimos los últimos eventos accepted con un límite mayor para procesarlos
        const response = await fetch(`${BASE_URL}/${DOMAIN}/events?event=accepted&limit=100`, {
            method: 'GET',
            headers: {
                'Authorization': `Basic ${btoa(`api:${API_KEY}`)}`
            }
        });

        if (!response.ok) {
            throw new Error(`MailGun API Error: ${response.statusText}`);
        }

        return await response.json();
    } catch (error) {
        console.error('Error fetching MailGun events:', error);
        throw error;
    }
};

/**
 * Fetches the full message content from a MailGun storage URL.
 * Routes the request through the local proxy.
 */
export const fetchMessageContent = async (storageUrl: string) => {
    try {
        // Adaptar URL de almacenamiento al proxy local
        let proxiedUrl = storageUrl;
        if (import.meta.env.DEV) {
            if (storageUrl.includes('storage.de.mailgun.net')) {
                proxiedUrl = storageUrl.replace('https://storage.de.mailgun.net/v3', '/api/mailgun-storage-eu');
            } else {
                proxiedUrl = storageUrl.replace('https://storage.mailgun.net/v3', '/api/mailgun-storage');
            }
        }

        const response = await fetch(proxiedUrl, {
            method: 'GET',
            headers: {
                'Authorization': `Basic ${btoa(`api:${API_KEY}`)}`
            }
        });

        if (!response.ok) {
            throw new Error(`MailGun Storage API Error: ${response.statusText}`);
        }

        const data = await response.json();
        return {
            body: data['body-plain'] || data['body-html'] || 'Sin contenido',
            html: data['body-html'],
            subject: data['Subject'] || data['subject'],
            attachments: data['attachments'] || []
        };
    } catch (error) {
        console.error('Error fetching message content:', error);
        return { body: 'Error al recuperar contenido.', attachments: [] };
    }
};
