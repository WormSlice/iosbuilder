import React, { useState, useEffect } from 'react';
import {
    AlertCircle,
    ShieldAlert,
    UserX,
    CheckCircle,
    Eye,
    MoreVertical,
    Clock,
    Filter,
    ArrowUpRight,
    Trash,
    Image as ImageIcon
} from 'lucide-react';
import { db } from '../services/firebase';
import { collection, query, orderBy, onSnapshot, doc, updateDoc, deleteDoc } from 'firebase/firestore';
import toast from 'react-hot-toast';

interface Report {
    id: string;
    postId?: string;
    postTitle?: string;
    reason?: string;
    description?: string;
    images?: string[];
    userId?: string;
    userEmail?: string;
    status: 'pending' | 'resolved';
    timestamp: any;
}

export const Reports: React.FC = () => {
    const [filter, setFilter] = useState<'all' | 'pending' | 'resolved'>('all');
    const [reports, setReports] = useState<Report[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedImages, setSelectedImages] = useState<string[] | null>(null);

    useEffect(() => {
        const q = query(collection(db, 'reports'), orderBy('timestamp', 'desc'));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const fetched = snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            })) as Report[];
            setReports(fetched);
            setLoading(false);
        });
        return () => unsubscribe();
    }, []);

    const handleResolve = async (id: string) => {
        try {
            await updateDoc(doc(db, 'reports', id), { status: 'resolved' });
            toast.success('Reporte marcado como resuelto');
        } catch (error) {
            toast.error('Error al resolver reporte');
        }
    };

    const handleDelete = async (id: string) => {
        if (window.confirm('¿Eliminar este reporte permanentemente?')) {
            try {
                await deleteDoc(doc(db, 'reports', id));
                toast.success('Reporte eliminado');
            } catch (err) {
                toast.error('Error al eliminar');
            }
        }
    };

    return (
        <div className="space-y-12 animate-in slide-in-from-bottom duration-700">
            <div className="flex items-center justify-between">
                <div className="space-y-1">
                    <h1 className="text-4xl font-black tracking-tighter uppercase italic">Moderation Center</h1>
                    <p className="text-zinc-400 text-[10px] font-bold uppercase tracking-widest">Community Safety & Reports Control</p>
                </div>
                <div className="flex p-1 bg-zinc-50 rounded-2xl border border-zinc-100 shadow-sm">
                    {(['pending', 'resolved', 'all'] as const).map((f) => (
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

            <div className="bg-white rounded-[3.5rem] border border-zinc-100 overflow-hidden shadow-2xl shadow-zinc-200/20">
                <table className="w-full text-left">
                    <thead>
                        <tr className="bg-zinc-50 pb-4">
                            <th className="px-10 py-8 text-[10px] font-black uppercase tracking-widest text-zinc-400">Tipo / Usuario</th>
                            <th className="px-10 py-8 text-[10px] font-black uppercase tracking-widest text-zinc-400">Descripción / Motivo</th>
                            <th className="px-10 py-8 text-[10px] font-black uppercase tracking-widest text-zinc-400">Evidencias</th>
                            <th className="px-10 py-8 text-[10px] font-black uppercase tracking-widest text-zinc-400 text-center">Estado</th>
                            <th className="px-10 py-8 text-[10px] font-black uppercase tracking-widest text-zinc-400 text-right">Acciones</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-zinc-50">
                        {loading && <tr><td colSpan={5} className="text-center py-10 font-black text-xs">CARGANDO REVISIONES...</td></tr>}
                        {!loading && reports.filter(r => filter === 'all' || r.status === filter).map((report) => (
                            <tr key={report.id} className="hover:bg-zinc-50/50 transition-colors group">
                                <td className="px-10 py-8">
                                    <div className="flex items-center gap-4">
                                        <div className={`w-12 h-12 rounded-2xl flex items-center justify-center font-black text-[10px] uppercase ${report.postId ? 'bg-amber-50 text-amber-600' : 'bg-red-50 text-red-600'}`}>
                                            {report.postId ? 'Post' : 'App'}
                                        </div>
                                        <div>
                                            <p className="text-sm font-black tracking-tight">{report.userEmail || 'Usuario Anónimo'}</p>
                                            <p className="text-[10px] text-zinc-400 font-bold uppercase truncate max-w-[150px]">{report.userId || 'N/A'}</p>
                                        </div>
                                    </div>
                                </td>
                                <td className="px-10 py-8">
                                    <div className="space-y-1 max-w-xs">
                                        <p className="text-xs font-bold text-zinc-800 leading-relaxed">
                                            {report.reason || report.description || 'Sin descripción'}
                                        </p>
                                        {report.postTitle && <p className="text-[10px] text-primary font-black uppercase">Post: {report.postTitle}</p>}
                                    </div>
                                </td>
                                <td className="px-10 py-8">
                                    {report.images && report.images.length > 0 ? (
                                        <div className="flex gap-1">
                                            {report.images.slice(0, 3).map((img, idx) => (
                                                <img 
                                                    key={idx} 
                                                    src={img} 
                                                    onClick={() => setSelectedImages(report.images || null)}
                                                    className="w-8 h-8 rounded-lg object-cover border border-zinc-100 cursor-pointer hover:scale-110 transition-transform" 
                                                    alt="Evidencia" 
                                                />
                                            ))}
                                            {report.images.length > 3 && (
                                                <div className="w-8 h-8 rounded-lg bg-zinc-100 flex items-center justify-center text-[10px] font-black text-zinc-400">
                                                    +{report.images.length - 3}
                                                </div>
                                            )}
                                        </div>
                                    ) : (
                                        <span className="text-[10px] font-bold text-zinc-300 italic uppercase">Sin fotos</span>
                                    )}
                                </td>
                                <td className="px-10 py-8 text-center">
                                    <span className={`px-4 py-1.5 rounded-full text-[9px] font-black uppercase tracking-[0.1em] ${report.status === 'pending' ? 'bg-red-50 text-red-600' : 'bg-black text-white'
                                        }`}>
                                        {report.status}
                                    </span>
                                </td>
                                <td className="px-10 py-8 text-right">
                                    <div className="flex items-center justify-end gap-2">
                                        {report.status === 'pending' && (
                                            <button
                                                onClick={() => handleResolve(report.id)}
                                                className="p-3 bg-zinc-50 hover:bg-black hover:text-white transition-all rounded-xl text-green-500"
                                                title="Marcar como Resuelto">
                                                <CheckCircle size={16} />
                                            </button>
                                        )}
                                        <button onClick={() => handleDelete(report.id)} className="p-3 bg-zinc-50 hover:bg-red-50 hover:text-red-500 transition-all rounded-xl text-zinc-400">
                                            <Trash size={16} />
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {/* Modal de Imágenes */}
            {selectedImages && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-8 bg-black/95 animate-in fade-in duration-300" onClick={() => setSelectedImages(null)}>
                    <div className="grid grid-cols-2 md:grid-cols-3 gap-4 max-w-5xl" onClick={e => e.stopPropagation()}>
                        {selectedImages.map((img, idx) => (
                            <img key={idx} src={img} className="w-full h-64 object-cover rounded-3xl border-4 border-white/10" alt="Full Preview" />
                        ))}
                    </div>
                    <button className="absolute top-10 right-10 text-white font-black uppercase text-xs tracking-widest bg-white/10 px-6 py-3 rounded-2xl hover:bg-white hover:text-black transition-all">Cerrar</button>
                </div>
            )}
        </div>
    );
};
