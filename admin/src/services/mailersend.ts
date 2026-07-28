/**
 * Servicio de integración con MailerSend para el envío de correos electrónicos.
 * Utiliza la API v1 de MailerSend con autenticación Bearer.
 */

const API_KEY = import.meta.env.VITE_MAILERSEND_API_KEY;
const BASE_URL = import.meta.env.DEV ? '/api/mailersend' : 'https://api.mailersend.com/v1';

export interface EmailData {
    to: string;
    subject: string;
    text?: string;
    html?: string;
    from?: string; // Formato: "Nombre <email@dominio.com>" o "email@dominio.com"
    attachments?: File[];
}

/**
 * Convierte un File a Base64 para adjuntarlo en MailerSend.
 */
const fileToBase64 = (file: File): Promise<string> => {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onload = () => {
            const base64String = reader.result as string;
            // Extraer solo la parte base64 sin el prefijo data:tipo/mime;base64,
            resolve(base64String.split(',')[1]);
        };
        reader.onerror = (error) => reject(error);
    });
};

/**
 * Envía un correo electrónico utilizando la API de MailerSend.
 */
export const sendEmail = async (data: EmailData) => {
    if (!API_KEY) {
        throw new Error('Configuración de MailerSend incompleta en las variables de entorno.');
    }

    // Parsear el "from" que puede venir en formato "CONNECT <contacto@connectapp.com.co>"
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

    // Parsear el "to" (asumimos que en el admin solo se envía a uno a la vez, o se puede separar)
    const toEmail = data.to.trim();

    const payload: any = {
        from: {
            email: fromEmail,
            name: fromName
        },
        to: [
            {
                email: toEmail
            }
        ],
        subject: data.subject
    };

    if (data.html) {
        payload.html = data.html;
    }
    if (data.text) {
        payload.text = data.text;
    }

    // Procesar adjuntos
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
        const response = await fetch(`${BASE_URL}/email`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${API_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        // MailerSend retorna 202 Accepted cuando el envío es exitoso sin body JSON
        if (!response.ok) {
            let errorMessage = `Error de MailerSend: ${response.status} ${response.statusText}`;
            try {
                const errorData = await response.json();
                console.error('MailerSend Detailed Error:', errorData);
                if (errorData.message) errorMessage += ` - ${errorData.message}`;
                if (errorData.errors) errorMessage += ` - Detalles: ${JSON.stringify(errorData.errors)}`;
            } catch (e) {}
            throw new Error(errorMessage);
        }

        return { success: true };
    } catch (error: any) {
        console.error('MailerSend Service Error:', error);
        throw error;
    }
};

/**
 * Función vacía para compatibilidad temporal (MailerSend usa Webhooks para eventos de entrada)
 */
export const fetchMailEvents = async () => {
    return { items: [] };
};

/**
 * Función vacía para compatibilidad temporal
 */
export const fetchMessageContent = async (storageUrl: string) => {
    return { body: 'Inbound mail content not supported directly via API polling in MailerSend. Configure Webhooks.', attachments: [] };
};
