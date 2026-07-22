import React, { useState, useEffect } from 'react';
import {
    Headphones,
    MessageSquare,
    Mail,
    Clock,
    CheckCircle,
    User,
    ArrowUpRight,
    Trash,
    ExternalLink
} from 'lucide-react';
import { db } from '../services/firebase';
import { collection, query, orderBy, onSnapshot, doc, updateDoc, deleteDoc } from 'firebase/firestore';
import toast from 'react-hot-toast';

interface SupportRequest {
    id: string;
    userId: string;
    userName: string;
    userEmail: string;
    note: string;
    status: 'pending' | 'contacted';
    timestamp: any;
}

export const SupportRequests: React.FC = () => {
    const [filter, setFilter] = useState<'all' | 'pending' | 'contacted'>('pending');
    const [requests, setRequests] = useState<SupportRequest[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const q = query(collection(db, 'support_requests'), orderBy('timestamp', 'desc'));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const fetched = snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            })) as SupportRequest[];
            setRequests(fetched);
            setLoading(false);
        });
        return () => unsubscribe();
    }, []);

    const handleMarkContacted = async (id: string) => {
        try {
            await updateDoc(doc(db, 'support_requests', id), { status: 'contacted' });
            toast.success('Solicitud marcada como contactada');
        } catch (error) {
            toast.error('Error al actualizar estado');
        }
    };

    const handleDelete = async (id: string) => {
        if (window.confirm('¿Eliminar esta solicitud definitivamente?')) {
            try {
                await deleteDoc(doc(db, 'support_requests', id));
                toast.success('Solicitud eliminada');
            } catch (err) {
                toast.error('Error al eliminar');
            }
        }
    };

    return (
        <div className="space-y-12 animate-in slide-in-from-bottom duration-700">
            <div className="flex items-center justify-between">
                <div className="space-y-1">
                    <h1 className="text-4xl font-black tracking-tighter uppercase italic">SOPORTE TÉCNICO</h1>
                    <p className="text-zinc-400 text-[10px] font-bold uppercase tracking-widest">Gestión de Asesores y Consultas</p>
                </div>
                <div className="flex p-1 bg-zinc-50 rounded-2xl border border-zinc-100 shadow-sm">
                    {(['pending', 'contacted', 'all'] as const).map((f) => (
                        <button
                            key={f}
                            onClick={() => setFilter(f)}
                            className={`px-6 py-3 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${filter === f ? 'bg-black text-white' : 'text-zinc-400'
                                }`}
                        >
                            {f}
                        </button>
                    ))}
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {loading && <p className="text-xs font-black uppercase tracking-widest text-zinc-400">Cargando solicitudes...</p>}
                {!loading && requests.filter(r => filter === 'all' || r.status === filter).map((req) => (
                    <div key={req.id} className="bg-white border border-zinc-100 p-8 rounded-[2.5rem] shadow-sm hover:border-black transition-all group">
                        <div className="flex justify-between items-start mb-6">
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 rounded-xl bg-zinc-100 flex items-center justify-center text-zinc-500">
                                    <User size={18} />
                                </div>
                                <div>
                                    <p className="text-sm font-black tracking-tight">{req.userName || 'Usuario'}</p>
                                    <p className="text-[10px] text-zinc-400 font-bold uppercase">{req.userEmail}</p>
                                </div>
                            </div>
                            <span className={`px-3 py-1 rounded-full text-[8px] font-black uppercase tracking-widest ${req.status === 'pending' ? 'bg-amber-50 text-amber-600' : 'bg-black text-white'}`}>
                                {req.status}
                            </span>
                        </div>
                        
                        <div className="mb-8">
                            <p className="text-[10px] font-black text-zinc-300 uppercase tracking-widest mb-2">Nota del Usuario</p>
                            <p className="text-xs font-bold text-zinc-600 leading-relaxed bg-zinc-50 p-4 rounded-2xl italic">
                                "{req.note}"
                            </p>
                        </div>

                        <div className="flex items-center justify-between pt-6 border-t border-zinc-50">
                            <div className="flex items-center gap-2">
                                <a 
                                    href={`mailto:${req.userEmail}`}
                                    className="p-3 bg-zinc-50 hover:bg-black hover:text-white transition-all rounded-xl text-zinc-400"
                                    title="Enviar Email"
                                >
                                    <Mail size={16} />
                                </a>
                                {req.status === 'pending' && (
                                    <button 
                                        onClick={() => handleMarkContacted(req.id)}
                                        className="p-3 bg-zinc-50 hover:bg-black hover:text-white transition-all rounded-xl text-green-500"
                                        title="Marcar como Contactado"
                                    >
                                        <CheckCircle size={16} />
                                    </button>
                                )}
                            </div>
                            <button 
                                onClick={() => handleDelete(req.id)}
                                className="p-3 bg-zinc-50 hover:bg-red-50 hover:text-red-500 transition-all rounded-xl text-zinc-200"
                            >
                                <Trash size={16} />
                            </button>
                        </div>
                    </div>
                ))}
            </div>

            {!loading && requests.filter(r => filter === 'all' || r.status === filter).length === 0 && (
                <div className="text-center py-20 bg-zinc-50 rounded-[3.5rem] border border-zinc-100 border-dashed">
                    <Headphones size={48} className="mx-auto text-zinc-200 mb-4" />
                    <p className="text-xs font-black text-zinc-400 uppercase tracking-widest">No hay solicitudes en esta categoría</p>
                </div>
            )}
        </div>
    );
};
