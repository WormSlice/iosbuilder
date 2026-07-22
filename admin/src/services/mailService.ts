import {
    collection,
    addDoc,
    updateDoc,
    doc,
    query,
    orderBy,
    onSnapshot,
    Timestamp,
    where,
    getDocs,
    limit,
    QueryDocumentSnapshot
} from 'firebase/firestore';
import { db } from './firebase';
import { fetchMailEvents, fetchMessageContent } from './mailgun';

export interface MailLog {
    id: string;
    from: string;
    to: string;
    subject: string;
    message: string;
    timestamp: any;
    status: 'sent' | 'received' | 'trash' | 'spam' | 'sending' | 'error';
    category: 'principal' | 'sent' | 'automations' | 'spam' | 'trash';
    attachmentsCount?: number;
}

const MAIL_COLLECTION = 'mail';

/**
 * Guarda un correo enviado o recibido en Firestore
 */
export const saveMail = async (mail: Omit<MailLog, 'id'>) => {
    try {
        const docRef = await addDoc(collection(db, MAIL_COLLECTION), {
            ...mail,
            timestamp: Timestamp.now()
        });
        return docRef.id;
    } catch (error) {
        console.error('Error saving mail to Firestore:', error);
        throw error;
    }
};

/**
 * Actualiza el estado de un correo (ej. mover a papelera)
 */
export const updateMailStatus = async (id: string, status: MailLog['status'], category: MailLog['category']) => {
    try {
        const docRef = doc(db, MAIL_COLLECTION, id);
        await updateDoc(docRef, {
            status,
            category
        });
    } catch (error) {
        console.error('Error updating mail status:', error);
        throw error;
    }
};

/**
 * Escucha cambios en los correos en tiempo real
 */
export const subscribeToMail = (callback: (mail: MailLog[]) => void) => {
    const q = query(
        collection(db, MAIL_COLLECTION),
        orderBy('timestamp', 'desc')
    );

    return onSnapshot(q, (snapshot) => {
        const mailList = snapshot.docs.map((doc: any) => ({
            id: doc.id,
            ...doc.data(),
            timestamp: doc.data().timestamp?.toDate().toLocaleString() || 'Recién'
        })) as MailLog[];
        callback(mailList);
    });
};

/**
 * Sincroniza correos entrantes desde los eventos de MailGun
 */
export const syncIncomingMail = async () => {
    try {
        const eventsData = await fetchMailEvents();
        const events = eventsData.items || [];

        // Filtramos eventos de aceptación (correos recibidos por MailGun)
        // Nota: En MailGun, 'accepted' para un correo entrante significa que lo recibió para procesar
        const incomingEvents = events.filter((e: any) => {
            const isAcceptedOrStored = e.event === 'accepted' || e.event === 'stored';
            const toHeader = (e.message?.headers?.to || '').toLowerCase();
            const fromHeader = (e.message?.headers?.from || '').toLowerCase();
            
            const isConnectRecipient = e.recipient?.includes('connectapp.com.co') || 
                                       toHeader.includes('connectapp.com.co') || 
                                       toHeader.includes('@connect.com') ||
                                       (e['mailing-list'] && e['mailing-list'].address?.includes('connectapp.com.co'));
            
            // Para correos entrantes, ignoramos los enviados *desde* nosotros mismos
            const isNotFromConnect = !fromHeader.includes('connectapp.com.co') && !fromHeader.includes('@connect.com');

            return isAcceptedOrStored && isConnectRecipient && isNotFromConnect;
        });

        for (const event of incomingEvents) {
            // Verificar si ya existe en Firestore para evitar duplicados
            const originalSubject = event.message?.headers?.subject || '(Sin asunto)';
            const originalFrom = event.message?.headers?.from || 'Desconocido';
            
            const q = query(
                collection(db, MAIL_COLLECTION),
                where('subject', '==', originalSubject),
                where('from', '==', originalFrom),
                limit(1)
            );

            const existing = await getDocs(q);
            if (existing.empty) {
                // Intentar recuperar el contenido real del mensaje
                let realContent = "Contenido no disponible (Evento sin URL de almacenamiento).";
                let realSubject = originalSubject;
                let attachmentsCount = 0;
                let category: 'principal' | 'spam' | 'trash' = 'principal';

                if (realSubject.toLowerCase().includes('[spam]') || realSubject.toLowerCase().includes('spam')) {
                    category = 'spam';
                }

                if (event.storage && event.storage.url) {
                    const content = await fetchMessageContent(event.storage.url);
                    realContent = content.body;
                    if (content.subject) {
                        realSubject = content.subject;
                        if (realSubject.toLowerCase().includes('[spam]')) category = 'spam';
                    }
                    if (content.attachments) attachmentsCount = content.attachments.length;
                }

                // El "to" original es el de los headers, no el recipient final del reenvío
                const originalTo = event.message?.headers?.to || event['mailing-list']?.address || event.recipient;

                await saveMail({
                    from: originalFrom,
                    to: originalTo,
                    subject: realSubject,
                    message: realContent,
                    status: 'received',
                    category: category,
                    timestamp: Timestamp.now(),
                    attachmentsCount
                });
            }
        }
    } catch (error) {
        console.error('Error syncing incoming mail:', error);
    }
};
