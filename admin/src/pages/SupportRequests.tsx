import React, { useState, useEffect } from 'react';
import {
    Headphones,
    Mail,
    CheckCircle,
    Trash2,
    Clock,
    User,
    ExternalLink
} from 'lucide-react';
import { db } from '../services/firebase';
import { collection, query, orderBy, onSnapshot, doc, updateDoc, deleteDoc } from 'firebase/firestore';
import toast from 'react-hot-toast';

interface SupportRequest {
    id: string;
    userId?: string;
    userName?: string;
    userEmail?: string;
    note?: string;
    status?: 'pending' | 'contacted';
    timestamp?: any;
}

export const SupportRequests: React.FC = () => {
    const [filter, setFilter] = useState<'pending' | 'contacted' | 'all'>('pending');
    const [requests, setRequests] = useState<SupportRequest[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const q = query(collection(db, 'support_requests'), orderBy('timestamp', 'desc'));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const list = snapshot.docs.map(d => ({
                id: d.id,
                ...d.data()
            })) as SupportRequest[];
            setRequests(list);
            setLoading(false);
        }, (err) => {
            console.error('Error al escuchar solicitudes de soporte:', err);
            setLoading(false);
        });
        return () => unsubscribe();
    }, []);

    const handleMarkContacted = async (id: string) => {
        try {
            await updateDoc(doc(db, 'support_requests', id), { status: 'contacted' });
            toast.success('Marcada como contactada');
        } catch (e: any) {
            toast.error(`Error: ${e.message}`);
        }
    };

    const handleDelete = async (id: string) => {
        if (!window.confirm('¿Eliminar esta solicitud definitivamente?')) return;
        try {
            await deleteDoc(doc(db, 'support_requests', id));
            toast.success('Solicitud eliminada');
        } catch (err: any) {
            toast.error(`Error: ${err.message}`);
        }
    };

    const formatDate = (timestamp: any) => {
        if (!timestamp) return 'Reciente';
        try {
            if (timestamp.toDate) return timestamp.toDate().toLocaleDateString('es-ES', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
            if (timestamp.seconds) return new Date(timestamp.seconds * 1000).toLocaleDateString('es-ES', { day: '2-digit', month: 'short' });
            return new Date(timestamp).toLocaleDateString('es-ES', { day: '2-digit', month: 'short' });
        } catch {
            return 'Reciente';
        }
    };

    const filteredRequests = requests.filter(r => {
        if (filter === 'all') return true;
        return r.status === filter;
    });

    return (
        <div className="space-y-5">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-zinc-200">
                <div>
                    <h1 className="text-xl font-bold text-zinc-900 tracking-tight">Centro de Soporte al Usuario</h1>
                    <p className="text-xs text-zinc-500">Gestión de consultas, solicitudes de ayuda y atención personalizada de usuarios</p>
                </div>

                <div className="flex items-center gap-1.5">
                    {(['pending', 'contacted', 'all'] as const).map((f) => (
                        <button
                            key={f}
                            onClick={() => setFilter(f)}
                            className={`px-3 py-1 text-xs font-semibold rounded-lg transition-colors capitalize ${
                                filter === f
                                    ? 'bg-zinc-900 text-white'
                                    : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                            }`}
                        >
                            {f === 'pending' ? 'Pendientes' : f === 'contacted' ? 'Contactados' : 'Todos'}
                        </button>
                    ))}
                </div>
            </div>

            {/* Tabla Plana de Soporte */}
            <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table-clean">
                        <thead>
                            <tr>
                                <th>Usuario</th>
                                <th>Consulta / Mensaje</th>
                                <th>Fecha</th>
                                <th>Estado</th>
                                <th className="text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan={5} className="text-center py-8 text-zinc-400">
                                        Cargando solicitudes de soporte...
                                    </td>
                                </tr>
                            ) : filteredRequests.length === 0 ? (
                                <tr>
                                    <td colSpan={5} className="text-center py-8 text-zinc-400">
                                        No hay solicitudes de soporte en este estado.
                                    </td>
                                </tr>
                            ) : (
                                filteredRequests.map((req) => (
                                    <tr key={req.id}>
                                        <td>
                                            <div className="flex items-center gap-2.5">
                                                <div className="w-8 h-8 rounded-full bg-zinc-100 text-zinc-700 font-bold text-xs flex items-center justify-center flex-shrink-0 border border-zinc-200">
                                                    {(req.userName || req.userEmail || 'U')[0].toUpperCase()}
                                                </div>
                                                <div>
                                                    <p className="font-semibold text-zinc-900">{req.userName || 'Usuario'}</p>
                                                    <p className="text-[11px] text-zinc-500">{req.userEmail || 'Sin correo'}</p>
                                                </div>
                                            </div>
                                        </td>
                                        <td>
                                            <p className="text-xs text-zinc-700 max-w-md leading-relaxed">
                                                {req.note || 'Sin mensaje de consulta.'}
                                            </p>
                                        </td>
                                        <td>
                                            <span className="text-[11px] text-zinc-500">
                                                {formatDate(req.timestamp)}
                                            </span>
                                        </td>
                                        <td>
                                            <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-bold ${
                                                req.status === 'contacted'
                                                    ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                                    : 'bg-amber-50 text-amber-700 border border-amber-200'
                                            }`}>
                                                <span className={`w-1.5 h-1.5 rounded-full ${req.status === 'contacted' ? 'bg-emerald-500' : 'bg-amber-500'}`} />
                                                <span>{req.status === 'contacted' ? 'Contactado' : 'Pendiente'}</span>
                                            </span>
                                        </td>
                                        <td className="text-right">
                                            <div className="inline-flex items-center gap-1.5">
                                                {req.userEmail && (
                                                    <a
                                                        href={`mailto:${req.userEmail}?subject=Respuesta de Soporte CONNECT`}
                                                        className="btn-outline px-2 py-1 text-xs"
                                                        title="Enviar correo"
                                                    >
                                                        <Mail size={12} />
                                                        <span>Escribir</span>
                                                    </a>
                                                )}
                                                {req.status !== 'contacted' && (
                                                    <button
                                                        onClick={() => handleMarkContacted(req.id)}
                                                        className="btn-primary px-2.5 py-1"
                                                    >
                                                        <CheckCircle size={12} />
                                                        <span>Contactado</span>
                                                    </button>
                                                )}
                                                <button
                                                    onClick={() => handleDelete(req.id)}
                                                    className="btn-danger px-2 py-1"
                                                    title="Eliminar solicitud"
                                                >
                                                    <Trash2 size={12} />
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
};
