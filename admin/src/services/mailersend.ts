/**
 * Servicio de integración con MailerSend para envío y recepción de correos electrónicos.
 * Utiliza la API v1 de MailerSend con autenticación Bearer y sincronización Firestore.
 */

const API_KEY = import.meta.env.VITE_MAILERSEND_API_KEY || 'mlsn.34131d2c738f0026306ef479f2e4dc85df9ef47633f4cdd32506dc35f33b9a1b';
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
 * Obtiene la lista de mensajes registrados en MailerSend API
 */
export const fetchMailEvents = async () => {
    try {
        const response = await fetch(`${BASE_URL}/messages`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${API_KEY}`,
                'Content-Type': 'application/json'
            }
        });

        if (!response.ok) return { items: [] };
        const data = await response.json();
        return { items: data.data || [] };
    } catch (error) {
        console.error('Error fetching MailerSend messages:', error);
        return { items: [] };
    }
};

/**
 * Obtiene el contenido detallado de un mensaje específico en MailerSend
 */
export const fetchMessageContent = async (messageId: string) => {
    try {
        const response = await fetch(`${BASE_URL}/messages/${messageId}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${API_KEY}`,
                'Content-Type': 'application/json'
            }
        });

        if (!response.ok) {
            return { body: 'Mensaje recibido mediante Inbound Webhook de MailerSend.', attachments: [] };
        }
        const data = await response.json();
        return {
            body: data.data?.text || data.data?.html || 'Sin contenido de texto.',
            subject: data.data?.subject,
            attachments: data.data?.attachments || []
        };
    } catch (error) {
        return { body: 'Inbound message content loaded.', attachments: [] };
    }
};
