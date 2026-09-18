import React, { useState, useEffect, useMemo } from 'react';
import {
    Bell,
    Send,
    User,
    Globe,
    CheckCircle,
    Clock,
    Search,
    X,
    Smartphone,
    AlertCircle
} from 'lucide-react';
import { db } from '../services/firebase';
import {
    collection,
    addDoc,
    query,
    orderBy,
    limit,
    onSnapshot,
    serverTimestamp,
    getDocs,
    where
} from 'firebase/firestore';
import toast from 'react-hot-toast';

interface RealNotification {
    id: string;
    title?: string;
    body?: string;
    target?: string;
    targetName?: string;
    targetEmail?: string;
    createdAt?: any;
    status?: string;
    type?: string;
}

interface UserOption {
    uid: string;
    displayName?: string;
    email?: string;
    username?: string;
    photoURL?: string;
    fcmToken?: string;
}

export const Notifications: React.FC = () => {
    const [target, setTarget] = useState<'all' | 'specific'>('all');
    const [targetUserId, setTargetUserId] = useState('');
    const [selectedUser, setSelectedUser] = useState<UserOption | null>(null);
    const [userSearchTerm, setUserSearchTerm] = useState('');
    const [userResults, setUserResults] = useState<UserOption[]>([]);
    const [isSearchingUsers, setIsSearchingUsers] = useState(false);

    const [title, setTitle] = useState('');
    const [body, setBody] = useState('');
    const [isSending, setIsSending] = useState(false);
    const [history, setHistory] = useState<RealNotification[]>([]);
    const [loadingHistory, setLoadingHistory] = useState(true);

    // Escuchar historial de notificaciones del sistema
    useEffect(() => {
        const q = query(
            collection(db, 'system_notifications'),
            orderBy('createdAt', 'desc'),
            limit(40)
        );

        const unsubscribe = onSnapshot(
            q,
            (snapshot) => {
                const list = snapshot.docs.map((d) => ({
                    id: d.id,
                    ...d.data(),
                })) as RealNotification[];
                setHistory(list);
                setLoadingHistory(false);
            },
            (err) => {
                console.warn('Fallback sin orderBy en system_notifications:', err);
                getFallbackHistory();
            }
        );

        return () => unsubscribe();
    }, []);

    const getFallbackHistory = () => {
        const qSimple = query(collection(db, 'system_notifications'), limit(40));
        onSnapshot(qSimple, (snapshot) => {
            setHistory(snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as RealNotification)));
            setLoadingHistory(false);
        });
    };

    // Búsqueda de usuarios en tiempo real para selección directa
    useEffect(() => {
        if (target !== 'specific') return;
        const term = userSearchTerm.trim().toLowerCase();
        if (!term || term.length < 2) {
            setUserResults([]);
            return;
        }

        const timer = setTimeout(async () => {
            setIsSearchingUsers(true);
            try {
                // Buscamos en usuarios registrados
                const qUsers = query(collection(db, 'users'), limit(50));
                const snap = await getDocs(qUsers);
                const matches: UserOption[] = [];

                snap.forEach((doc) => {
                    const data = doc.data();
                    const uid = doc.id;
                    const email = (data.email || '').toLowerCase();
                    const name = (data.displayName || data.name || '').toLowerCase();
                    const username = (data.username || '').toLowerCase();

                    if (
                        uid.toLowerCase().includes(term) ||
                        email.includes(term) ||
                        name.includes(term) ||
                        username.includes(term)
                    ) {
                        matches.push({
                            uid,
                            displayName: data.displayName || data.name || 'Sin nombre',
                            email: data.email || '',
                            username: data.username || '',
                            photoURL: data.photoURL || data.profileImage || '',
                            fcmToken: data.fcmToken,
                        });
                    }
                });

                setUserResults(matches.slice(0, 8));
            } catch (e) {
                console.error('Error buscando usuarios:', e);
            } finally {
                setIsSearchingUsers(false);
            }
        }, 250);

        return () => clearTimeout(timer);
    }, [userSearchTerm, target]);

    const handleSelectUser = (u: UserOption) => {
        setSelectedUser(u);
        setTargetUserId(u.uid);
        setUserResults([]);
        setUserSearchTerm('');
    };

    const handleClearSelectedUser = () => {
        setSelectedUser(null);
        setTargetUserId('');
        setUserSearchTerm('');
    };

    const handleSend = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!title.trim() || !body.trim()) {
            toast.error('Por favor completa el título y el contenido del mensaje.');
            return;
        }

        let resolvedUid = targetUserId.trim();
        let targetLabel = 'global';
        let resolvedEmail = selectedUser?.email || '';
        let resolvedName = selectedUser?.displayName || '';

        // Si es a un usuario específico, validar y resolver el UID
        if (target === 'specific') {
            if (!resolvedUid && !userSearchTerm.trim()) {
                toast.error('Por favor selecciona un usuario o ingresa su correo/UID.');
                return;
            }

            // Si no hay seleccionado pero escribió algo en el campo
            if (!resolvedUid && userSearchTerm.trim()) {
                const term = userSearchTerm.trim();
                // Buscar por email exacto o UID
                try {
                    const qByEmail = query(
                        collection(db, 'users'),
                        where('email', '==', term),
                        limit(1)
                    );
                    const snapEmail = await getDocs(qByEmail);
                    if (!snapEmail.empty) {
                        const d = snapEmail.docs[0];
                        resolvedUid = d.id;
                        resolvedEmail = d.data().email || '';
                        resolvedName = d.data().displayName || d.data().name || '';
                    } else {
                        // Considerar si es un UID directo
                        resolvedUid = term;
                    }
                } catch (e) {
                    resolvedUid = term;
                }
            }

            if (!resolvedUid) {
                toast.error('No se pudo identificar el usuario de destino.');
                return;
            }

            targetLabel = resolvedUid;
        }

        setIsSending(true);
        try {
            if (target === 'all') {
                // 1. CANAL GLOBAL: Escribir en 'broadcasts' (el canal real que escucha la app móvil en tiempo real)
                await addDoc(collection(db, 'broadcasts'), {
                    title: title.trim(),
                    body: body.trim(),
                    message: body.trim(),
                    isBroadcast: true,
                    type: 'system',
                    senderId: 'admin',
                    senderName: 'CONNECT Oficial',
                    createdAt: serverTimestamp(),
                });

                // 2. Registrar en historial administrativo
                await addDoc(collection(db, 'system_notifications'), {
                    title: title.trim(),
                    body: body.trim(),
                    target: 'global',
                    targetName: 'Todos los Usuarios (Broadcast)',
                    status: 'sent',
                    type: 'broadcast',
                    createdAt: serverTimestamp(),
                });

                toast.success('¡Aviso global (Broadcast) emitido exitosamente a todos los usuarios!');
            } else {
                // 1. CANAL INDIVIDUAL: Escribir en users/{uid}/notifications
                // Dispara automáticamente la Cloud Function sendPushNotificationOnNewDoc
                // y activa el stream en tiempo real de MessagingService en la app del usuario.
                await addDoc(collection(db, `users/${resolvedUid}/notifications`), {
                    title: title.trim(),
                    body: body.trim(),
                    type: 'system',
                    read: false,
                    senderId: 'admin',
                    senderName: 'Soporte CONNECT',
                    createdAt: serverTimestamp(),
                });

                // 2. Registrar en historial administrativo
                await addDoc(collection(db, 'system_notifications'), {
                    title: title.trim(),
                    body: body.trim(),
                    target: resolvedUid,
                    targetEmail: resolvedEmail,
                    targetName: resolvedName || 'Usuario CONNECT',
                    status: 'sent',
                    type: 'direct',
                    createdAt: serverTimestamp(),
                });

                toast.success(
                    `¡Notificación enviada con éxito a ${resolvedName || resolvedEmail || resolvedUid}!`
                );
            }

            // Limpiar formulario
            setTitle('');
            setBody('');
            handleClearSelectedUser();
        } catch (error: any) {
            console.error('Error enviando notificación:', error);
            toast.error(`Error al enviar: ${error.message}`);
        } finally {
            setIsSending(false);
        }
    };

    const formatDate = (timestamp: any) => {
        if (!timestamp) return 'Reciente';
        try {
            if (timestamp.toDate) {
                return timestamp
                    .toDate()
                    .toLocaleDateString('es-ES', {
                        day: '2-digit',
                        month: 'short',
                        hour: '2-digit',
                        minute: '2-digit',
                    });
            }
            if (timestamp.seconds) {
                return new Date(timestamp.seconds * 1000).toLocaleDateString('es-ES', {
                    day: '2-digit',
                    month: 'short',
                    hour: '2-digit',
                    minute: '2-digit',
                });
            }
            return new Date(timestamp).toLocaleDateString('es-ES', {
                day: '2-digit',
                month: 'short',
            });
        } catch {
            return 'Reciente';
        }
    };

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-zinc-200">
                <div>
                    <h1 className="text-xl font-bold text-zinc-900 tracking-tight">
                        Centro de Notificaciones Push & Broadcasts
                    </h1>
                    <p className="text-xs text-zinc-500">
                        Emisión de avisos globales a toda la red y mensajes dirigidos a la app móvil CONNECT
                    </p>
                </div>
            </div>

            {/* Dos Columnas: Formulario de Envío y Registro Histórico */}
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
                {/* Formulario de Emisión */}
                <div className="lg:col-span-5 bg-white border border-zinc-200 rounded-xl p-5 space-y-4 shadow-sm">
                    <div className="flex items-center gap-2 pb-2 border-b border-zinc-100">
                        <Send size={16} className="text-[#0094FF]" />
                        <h2 className="text-xs font-bold uppercase tracking-wider text-zinc-800">
                            Redactar Notificación
                        </h2>
                    </div>

                    <form onSubmit={handleSend} className="space-y-4">
                        {/* Selector de Audiencia */}
                        <div className="space-y-1.5">
                            <label className="text-[11px] font-bold text-zinc-700 uppercase tracking-wider block">
                                Audiencia Destinataria
                            </label>
                            <div className="grid grid-cols-2 gap-2">
                                <button
                                    type="button"
                                    onClick={() => {
                                        setTarget('all');
                                        handleClearSelectedUser();
                                    }}
                                    className={`py-2 px-3 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-1.5 ${
                                        target === 'all'
                                            ? 'bg-zinc-900 text-white shadow-sm'
                                            : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
                                    }`}
                                >
                                    <Globe size={14} />
                                    <span>Todos (Global)</span>
                                </button>
                                <button
                                    type="button"
                                    onClick={() => setTarget('specific')}
                                    className={`py-2 px-3 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-1.5 ${
                                        target === 'specific'
                                            ? 'bg-zinc-900 text-white shadow-sm'
                                            : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
                                    }`}
                                >
                                    <User size={14} />
                                    <span>Usuario Específico</span>
                                </button>
                            </div>

                            {target === 'all' ? (
                                <div className="p-2.5 rounded-lg bg-blue-50 border border-blue-100 text-[11px] text-blue-800 flex items-start gap-2">
                                    <Globe size={14} className="text-[#0094FF] flex-shrink-0 mt-0.5" />
                                    <span>
                                        <strong>Transmisión Global:</strong> Se enviará a la colección{' '}
                                        <code className="font-mono bg-blue-100 px-1 py-0.2 rounded">broadcasts</code> y disparará una notificación Push a todos los dispositivos registrados en la red CONNECT.
                                    </span>
                                </div>
                            ) : null}
                        </div>

                        {/* Selección / Búsqueda de Usuario Específico */}
                        {target === 'specific' && (
                            <div className="space-y-2 border border-zinc-200 bg-zinc-50/70 p-3 rounded-xl">
                                <label className="text-[11px] font-bold text-zinc-700 uppercase tracking-wider block">
                                    Buscar y Seleccionar Usuario
                                </label>

                                {selectedUser ? (
                                    <div className="flex items-center justify-between bg-white p-2.5 rounded-lg border border-blue-200 shadow-sm">
                                        <div className="flex items-center gap-2.5 overflow-hidden">
                                            {selectedUser.photoURL ? (
                                                <img
                                                    src={selectedUser.photoURL}
                                                    alt="Avatar"
                                                    className="w-8 h-8 rounded-full object-cover border border-zinc-200"
                                                />
                                            ) : (
                                                <div className="w-8 h-8 rounded-full bg-blue-100 text-[#0094FF] flex items-center justify-center font-bold text-xs">
                                                    {selectedUser.displayName?.charAt(0) || 'U'}
                                                </div>
                                            )}
                                            <div className="overflow-hidden">
                                                <div className="flex items-center gap-1.5">
                                                    <p className="text-xs font-bold text-zinc-900 truncate">
                                                        {selectedUser.displayName}
                                                    </p>
                                                    {selectedUser.fcmToken && (
                                                        <span className="bg-emerald-100 text-emerald-700 text-[9px] px-1.5 py-0.2 rounded font-semibold flex items-center gap-0.5" title="Dispositivo registrado para Push">
                                                            <Smartphone size={10} /> Push
                                                        </span>
                                                    )}
                                                </div>
                                                <p className="text-[10px] text-zinc-500 font-mono truncate">
                                                    {selectedUser.email || selectedUser.uid}
                                                </p>
                                            </div>
                                        </div>
                                        <button
                                            type="button"
                                            onClick={handleClearSelectedUser}
                                            className="text-zinc-400 hover:text-red-500 p-1"
                                            title="Cambiar usuario"
                                        >
                                            <X size={15} />
                                        </button>
                                    </div>
                                ) : (
                                    <div className="relative">
                                        <div className="relative">
                                            <input
                                                type="text"
                                                placeholder="Escribe nombre, correo o UID del usuario..."
                                                value={userSearchTerm}
                                                onChange={(e) => setUserSearchTerm(e.target.value)}
                                                className="input-clean pl-8 text-xs w-full bg-white"
                                            />
                                            <Search
                                                size={13}
                                                className="absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-400"
                                            />
                                        </div>

                                        {isSearchingUsers && (
                                            <p className="text-[10px] text-zinc-400 mt-1 pl-1">Buscando usuarios en Firebase...</p>
                                        )}

                                        {/* Dropdown de Resultados de Búsqueda */}
                                        {userResults.length > 0 && (
                                            <div className="absolute left-0 right-0 top-full mt-1 bg-white border border-zinc-200 rounded-xl shadow-xl z-20 max-h-48 overflow-y-auto divide-y divide-zinc-100">
                                                {userResults.map((u) => (
                                                    <div
                                                        key={u.uid}
                                                        onClick={() => handleSelectUser(u)}
                                                        className="p-2.5 hover:bg-blue-50/60 cursor-pointer flex items-center justify-between transition-colors text-xs"
                                                    >
                                                        <div className="flex items-center gap-2 overflow-hidden">
                                                            <div className="w-6 h-6 rounded-full bg-zinc-200 text-zinc-600 flex items-center justify-center font-bold text-[10px]">
                                                                {u.displayName?.charAt(0) || 'U'}
                                                            </div>
                                                            <div className="overflow-hidden">
                                                                <p className="font-semibold text-zinc-800 truncate">
                                                                    {u.displayName}
                                                                </p>
                                                                <p className="text-[10px] text-zinc-500 font-mono truncate">
                                                                    {u.email || u.uid}
                                                                </p>
                                                            </div>
                                                        </div>
                                                        {u.fcmToken ? (
                                                            <span className="text-[9px] text-emerald-600 font-bold bg-emerald-50 px-1.5 py-0.5 rounded">
                                                                Push Activo
                                                            </span>
                                                        ) : (
                                                            <span className="text-[9px] text-zinc-400">Sin Push</span>
                                                        )}
                                                    </div>
                                                ))}
                                            </div>
                                        )}
                                    </div>
                                )}
                            </div>
                        )}

                        {/* Título */}
                        <div className="space-y-1">
                            <label className="text-[11px] font-bold text-zinc-700 uppercase tracking-wider block">
                                Título de la Notificación
                            </label>
                            <input
                                type="text"
                                placeholder="Ej: Actualización Importante de CONNECT"
                                value={title}
                                onChange={(e) => setTitle(e.target.value)}
                                className="input-clean text-xs font-semibold"
                                required
                            />
                        </div>

                        {/* Contenido */}
                        <div className="space-y-1">
                            <label className="text-[11px] font-bold text-zinc-700 uppercase tracking-wider block">
                                Contenido del Mensaje
                            </label>
                            <textarea
                                rows={4}
                                placeholder="Escribe el mensaje claro y descriptivo..."
                                value={body}
                                onChange={(e) => setBody(e.target.value)}
                                className="input-clean resize-none text-xs"
                                required
                            />
                        </div>

                        <button
                            type="submit"
                            disabled={isSending}
                            className="btn-primary w-full py-2.5 justify-center text-xs font-bold shadow-sm"
                        >
                            <Send size={13} className={isSending ? 'animate-spin' : ''} />
                            <span>{isSending ? 'Transmitiendo Notificación...' : 'Emitir Notificación Real'}</span>
                        </button>
                    </form>
                </div>

                {/* Historial Real de Notificaciones Enviadas */}
                <div className="lg:col-span-7 bg-white border border-zinc-200 rounded-xl overflow-hidden flex flex-col shadow-sm">
                    <div className="p-4 border-b border-zinc-100 flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <Bell size={16} className="text-[#0094FF]" />
                            <h2 className="text-xs font-bold uppercase tracking-wider text-zinc-800">
                                Historial de Notificaciones Emitidas
                            </h2>
                        </div>
                        <span className="text-xs text-zinc-400 font-mono">
                            {history.length} registradas
                        </span>
                    </div>

                    <div className="flex-1 overflow-x-auto">
                        <table className="table-clean">
                            <thead>
                                <tr>
                                    <th>Título & Contenido</th>
                                    <th>Destinatario / Canal</th>
                                    <th>Fecha</th>
                                    <th className="text-right">Entrega</th>
                                </tr>
                            </thead>
                            <tbody>
                                {loadingHistory ? (
                                    <tr>
                                        <td colSpan={4} className="text-center py-10 text-zinc-400 text-xs">
                                            Cargando historial de notificaciones...
                                        </td>
                                    </tr>
                                ) : history.length === 0 ? (
                                    <tr>
                                        <td colSpan={4} className="text-center py-12 text-zinc-400 text-xs">
                                            No se han emitido notificaciones aún.
                                        </td>
                                    </tr>
                                ) : (
                                    history.map((n) => (
                                        <tr key={n.id} className="hover:bg-zinc-50/80 transition-colors">
                                            <td>
                                                <div className="max-w-xs space-y-0.5">
                                                    <p className="font-bold text-zinc-900 text-xs truncate">
                                                        {n.title || 'Sin título'}
                                                    </p>
                                                    <p className="text-[11px] text-zinc-500 line-clamp-1">
                                                        {n.body || 'Sin mensaje'}
                                                    </p>
                                                </div>
                                            </td>
                                            <td>
                                                {n.target === 'global' ? (
                                                    <span className="inline-flex items-center gap-1 text-[11px] font-bold text-blue-700 bg-blue-50 px-2 py-0.5 rounded-full">
                                                        <Globe size={11} /> Broadcast Global
                                                    </span>
                                                ) : (
                                                    <div className="space-y-0.5">
                                                        <span className="text-[11px] font-semibold text-zinc-800 block truncate max-w-[140px]">
                                                            {n.targetName || n.targetEmail || 'Usuario'}
                                                        </span>
                                                        <span className="text-[10px] font-mono text-zinc-400 block truncate max-w-[140px]">
                                                            {n.target ? `${n.target.substring(0, 10)}...` : 'Directo'}
                                                        </span>
                                                    </div>
                                                )}
                                            </td>
                                            <td>
                                                <span className="text-[11px] text-zinc-500 font-mono">
                                                    {formatDate(n.createdAt)}
                                                </span>
                                            </td>
                                            <td className="text-right">
                                                <span className="inline-flex items-center gap-1 text-emerald-600 font-bold text-[11px]">
                                                    <CheckCircle size={12} /> Enviada
                                                </span>
                                            </td>
                                        </tr>
                                    ))
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    );
};
