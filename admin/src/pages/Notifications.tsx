import React, { useState, useEffect } from 'react';
import {
    Bell,
    Send,
    User,
    Globe,
    CheckCircle,
    Clock,
    Trash2,
    RefreshCw
} from 'lucide-react';
import { db } from '../services/firebase';
import { collection, addDoc, query, orderBy, limit, onSnapshot, serverTimestamp } from 'firebase/firestore';
import toast from 'react-hot-toast';

interface RealNotification {
    id: string;
    title?: string;
    body?: string;
    target?: string;
    createdAt?: any;
    status?: string;
}

export const Notifications: React.FC = () => {
    const [target, setTarget] = useState<'all' | 'specific'>('all');
    const [targetUserId, setTargetUserId] = useState('');
    const [title, setTitle] = useState('');
    const [body, setBody] = useState('');
    const [isSending, setIsSending] = useState(false);
    const [history, setHistory] = useState<RealNotification[]>([]);
    const [loadingHistory, setLoadingHistory] = useState(true);

    useEffect(() => {
        const q = query(
            collection(db, 'system_notifications'),
            orderBy('createdAt', 'desc'),
            limit(30)
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const list = snapshot.docs.map(d => ({
                id: d.id,
                ...d.data()
            })) as RealNotification[];
            setHistory(list);
            setLoadingHistory(false);
        }, (err) => {
            // Si la colección aún no tiene índice o no existe, intentar sin orderBy
            getFallbackHistory();
        });

        return () => unsubscribe();
    }, []);

    const getFallbackHistory = () => {
        const qSimple = query(collection(db, 'system_notifications'), limit(30));
        onSnapshot(qSimple, (snapshot) => {
            setHistory(snapshot.docs.map(d => ({ id: d.id, ...d.data() } as RealNotification)));
            setLoadingHistory(false);
        });
    };

    const handleSend = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!title.trim() || !body.trim()) {
            toast.error('Por favor completa el título y el mensaje.');
            return;
        }

        setIsSending(true);
        try {
            // Guardar notificación real en Firestore
            await addDoc(collection(db, 'system_notifications'), {
                title: title.trim(),
                body: body.trim(),
                target: target === 'all' ? 'global' : targetUserId.trim(),
                status: 'sent',
                createdAt: serverTimestamp(),
            });

            // Si es dirigida a un usuario específico, registrar en su subcolección de notificaciones
            if (target === 'specific' && targetUserId.trim()) {
                await addDoc(collection(db, `users/${targetUserId.trim()}/notifications`), {
                    title: title.trim(),
                    body: body.trim(),
                    type: 'system',
                    read: false,
                    createdAt: serverTimestamp(),
                });
            }

            toast.success('Notificación enviada y registrada correctamente');
            setTitle('');
            setBody('');
            setTargetUserId('');
        } catch (error: any) {
            toast.error(`Error al enviar: ${error.message}`);
        } finally {
            setIsSending(false);
        }
    };

    const formatDate = (timestamp: any) => {
        if (!timestamp) return 'Reciente';
        try {
            if (timestamp.toDate) return timestamp.toDate().toLocaleDateString('es-ES', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
            if (timestamp.seconds) return new Date(timestamp.seconds * 1000).toLocaleDateString('es-ES', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
            return new Date(timestamp).toLocaleDateString('es-ES', { day: '2-digit', month: 'short' });
        } catch {
            return 'Reciente';
        }
    };

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-zinc-200">
                <div>
                    <h1 className="text-xl font-bold text-zinc-900 tracking-tight">Centro de Notificaciones Push</h1>
                    <p className="text-xs text-zinc-500">Emisión de avisos globales y mensajes del sistema a la aplicación móvil CONNECT</p>
                </div>
            </div>

            {/* Dos Columnas: Formulario de Envío a la izquierda y Registro Histórico a la derecha */}
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
                {/* Formulario de Emisión */}
                <div className="lg:col-span-5 bg-white border border-zinc-200 rounded-xl p-5 space-y-4">
                    <div className="flex items-center gap-2 pb-2 border-b border-zinc-100">
                        <Send size={16} className="text-[#0094FF]" />
                        <h2 className="text-xs font-bold uppercase tracking-wider text-zinc-800">
                            Redactar Notificación
                        </h2>
                    </div>

                    <form onSubmit={handleSend} className="space-y-3.5">
                        {/* Selector de Audiencia */}
                        <div className="space-y-1">
                            <label className="text-[11px] font-semibold text-zinc-600 uppercase tracking-wider block">
                                Audiencia Destinataria
                            </label>
                            <div className="flex items-center gap-2">
                                <button
                                    type="button"
                                    onClick={() => setTarget('all')}
                                    className={`flex-1 py-1.5 px-3 rounded-lg text-xs font-semibold transition-colors flex items-center justify-center gap-1.5 ${
                                        target === 'all'
                                            ? 'bg-zinc-900 text-white'
                                            : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
                                    }`}
                                >
                                    <Globe size={13} />
                                    <span>Todos (Global)</span>
                                </button>
                                <button
                                    type="button"
                                    onClick={() => setTarget('specific')}
                                    className={`flex-1 py-1.5 px-3 rounded-lg text-xs font-semibold transition-colors flex items-center justify-center gap-1.5 ${
                                        target === 'specific'
                                            ? 'bg-zinc-900 text-white'
                                            : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
                                    }`}
                                >
                                    <User size={13} />
                                    <span>Usuario Específico</span>
                                </button>
                            </div>
                        </div>

                        {target === 'specific' && (
                            <div className="space-y-1">
                                <label className="text-[11px] font-semibold text-zinc-600 uppercase tracking-wider block">
                                    UID del Usuario
                                </label>
                                <input
                                    type="text"
                                    placeholder="Ingresa el UID del usuario..."
                                    value={targetUserId}
                                    onChange={(e) => setTargetUserId(e.target.value)}
                                    className="input-clean font-mono"
                                    required
                                />
                            </div>
                        )}

                        {/* Título */}
                        <div className="space-y-1">
                            <label className="text-[11px] font-semibold text-zinc-600 uppercase tracking-wider block">
                                Título del Aviso
                            </label>
                            <input
                                type="text"
                                placeholder="Ej: Nueva función disponible en CONNECT"
                                value={title}
                                onChange={(e) => setTitle(e.target.value)}
                                className="input-clean"
                                required
                            />
                        </div>

                        {/* Mensaje */}
                        <div className="space-y-1">
                            <label className="text-[11px] font-semibold text-zinc-600 uppercase tracking-wider block">
                                Contenido del Mensaje
                            </label>
                            <textarea
                                rows={3}
                                placeholder="Escribe el mensaje claro y conciso..."
                                value={body}
                                onChange={(e) => setBody(e.target.value)}
                                className="input-clean resize-none"
                                required
                            />
                        </div>

                        <button
                            type="submit"
                            disabled={isSending}
                            className="btn-primary w-full py-2 justify-center"
                        >
                            <Send size={13} className={isSending ? 'animate-spin' : ''} />
                            <span>{isSending ? 'Enviando...' : 'Enviar Notificación'}</span>
                        </button>
                    </form>
                </div>

                {/* Historial Real de Notificaciones Enviadas */}
                <div className="lg:col-span-7 bg-white border border-zinc-200 rounded-xl overflow-hidden flex flex-col">
                    <div className="p-4 border-b border-zinc-100 flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <Bell size={16} className="text-[#0094FF]" />
                            <h2 className="text-xs font-bold uppercase tracking-wider text-zinc-800">
                                Historial Real de Notificaciones
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
                                    <th>Título & Mensaje</th>
                                    <th>Destinatario</th>
                                    <th>Fecha</th>
                                    <th className="text-right">Estado</th>
                                </tr>
                            </thead>
                            <tbody>
                                {loadingHistory ? (
                                    <tr>
                                        <td colSpan={4} className="text-center py-8 text-zinc-400">
                                            Cargando historial real de notificaciones...
                                        </td>
                                    </tr>
                                ) : history.length === 0 ? (
                                    <tr>
                                        <td colSpan={4} className="text-center py-8 text-zinc-400">
                                            No se han emitido notificaciones del sistema aún.
                                        </td>
                                    </tr>
                                ) : (
                                    history.map((n) => (
                                        <tr key={n.id}>
                                            <td>
                                                <div>
                                                    <p className="font-semibold text-zinc-900 truncate max-w-xs">{n.title || 'Sin título'}</p>
                                                    <p className="text-[11px] text-zinc-500 line-clamp-1 max-w-xs">{n.body || 'Sin mensaje'}</p>
                                                </div>
                                            </td>
                                            <td>
                                                <span className="text-[11px] font-mono text-zinc-600 bg-zinc-100 px-1.5 py-0.5 rounded">
                                                    {n.target === 'global' ? 'Global' : (n.target ? `${n.target.substring(0, 10)}...` : 'Global')}
                                                </span>
                                            </td>
                                            <td>
                                                <span className="text-[11px] text-zinc-500">
                                                    {formatDate(n.createdAt)}
                                                </span>
                                            </td>
                                            <td className="text-right">
                                                <span className="inline-flex items-center gap-1 text-emerald-600 font-semibold text-[11px]">
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
