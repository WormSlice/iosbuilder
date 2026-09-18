import React, { useState, useEffect } from 'react';
import {
    AlertCircle,
    CheckCircle,
    Trash2,
    Eye,
    X,
    Filter,
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
    status?: 'pending' | 'resolved';
    timestamp?: any;
}

export const Reports: React.FC = () => {
    const [filter, setFilter] = useState<'pending' | 'resolved' | 'all'>('pending');
    const [reports, setReports] = useState<Report[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedImages, setSelectedImages] = useState<string[] | null>(null);

    useEffect(() => {
        const q = query(collection(db, 'reports'), orderBy('timestamp', 'desc'));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const fetched = snapshot.docs.map(d => ({
                id: d.id,
                ...d.data()
            })) as Report[];
            setReports(fetched);
            setLoading(false);
        }, (err) => {
            console.error('Error al escuchar reportes:', err);
            setLoading(false);
        });
        return () => unsubscribe();
    }, []);

    const handleResolve = async (id: string) => {
        try {
            await updateDoc(doc(db, 'reports', id), { status: 'resolved' });
            toast.success('Reporte marcado como resuelto');
        } catch (error: any) {
            toast.error(`Error: ${error.message}`);
        }
    };

    const handleDelete = async (id: string) => {
        if (!window.confirm('¿Eliminar este reporte permanentemente?')) return;
        try {
            await deleteDoc(doc(db, 'reports', id));
            toast.success('Reporte eliminado');
        } catch (err: any) {
            toast.error(`Error: ${err.message}`);
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

    const filteredReports = reports.filter(r => {
        if (filter === 'all') return true;
        if (filter === 'pending') return r.status !== 'resolved';
        if (filter === 'resolved') return r.status === 'resolved';
        return true;
    });

    return (
        <div className="space-y-5">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-zinc-200">
                <div>
                    <h1 className="text-xl font-bold text-zinc-900 tracking-tight">Centro de Moderación y Reportes</h1>
                    <p className="text-xs text-zinc-500">Supervisión de denuncias comunitarias sobre publicaciones o usuarios</p>
                </div>

                <div className="flex items-center gap-1.5">
                    {(['pending', 'resolved', 'all'] as const).map((f) => (
                        <button
                            key={f}
                            onClick={() => setFilter(f)}
                            className={`px-3 py-1 text-xs font-semibold rounded-lg transition-colors capitalize ${
                                filter === f
                                    ? 'bg-zinc-900 text-white'
                                    : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                            }`}
                        >
                            {f === 'pending' ? 'Pendientes' : f === 'resolved' ? 'Resueltos' : 'Todos'}
                        </button>
                    ))}
                </div>
            </div>

            {/* Tabla Plana de Reportes */}
            <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table-clean">
                        <thead>
                            <tr>
                                <th>Elemento / Usuario</th>
                                <th>Motivo & Descripción</th>
                                <th>Fecha</th>
                                <th>Evidencias</th>
                                <th>Estado</th>
                                <th className="text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan={6} className="text-center py-8 text-zinc-400">
                                        Cargando reportes en vivo de Firebase...
                                    </td>
                                </tr>
                            ) : filteredReports.length === 0 ? (
                                <tr>
                                    <td colSpan={6} className="text-center py-8 text-zinc-400">
                                        No hay reportes en este estado.
                                    </td>
                                </tr>
                            ) : (
                                filteredReports.map((report) => (
                                    <tr key={report.id}>
                                        <td>
                                            <div>
                                                <p className="font-semibold text-zinc-900 truncate max-w-xs">
                                                    {report.postTitle || (report.postId ? `Post ID: ${report.postId.substring(0, 8)}` : 'Reporte General')}
                                                </p>
                                                <p className="text-[11px] text-zinc-500 truncate max-w-xs">
                                                    Por: {report.userEmail || report.userId || 'Anónimo'}
                                                </p>
                                            </div>
                                        </td>
                                        <td>
                                            <div>
                                                <span className="font-semibold text-zinc-800 text-[11px] block">
                                                    {report.reason || 'Sin motivo especificado'}
                                                </span>
                                                <p className="text-zinc-500 text-xs line-clamp-2 mt-0.5">
                                                    {report.description || 'Sin descripción detallada.'}
                                                </p>
                                            </div>
                                        </td>
                                        <td>
                                            <span className="text-[11px] text-zinc-500">
                                                {formatDate(report.timestamp)}
                                            </span>
                                        </td>
                                        <td>
                                            {report.images && report.images.length > 0 ? (
                                                <button
                                                    onClick={() => setSelectedImages(report.images!)}
                                                    className="btn-outline px-2 py-1 text-[11px]"
                                                >
                                                    <ImageIcon size={12} />
                                                    <span>{report.images.length} fotos</span>
                                                </button>
                                            ) : (
                                                <span className="text-zinc-400 text-[11px]">Sin fotos</span>
                                            )}
                                        </td>
                                        <td>
                                            <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-bold ${
                                                report.status === 'resolved'
                                                    ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                                    : 'bg-amber-50 text-amber-700 border border-amber-200'
                                            }`}>
                                                <span className={`w-1.5 h-1.5 rounded-full ${report.status === 'resolved' ? 'bg-emerald-500' : 'bg-amber-500'}`} />
                                                <span>{report.status === 'resolved' ? 'Resuelto' : 'Pendiente'}</span>
                                            </span>
                                        </td>
                                        <td className="text-right">
                                            <div className="inline-flex items-center gap-1.5">
                                                {report.status !== 'resolved' && (
                                                    <button
                                                        onClick={() => handleResolve(report.id)}
                                                        className="btn-primary px-2.5 py-1"
                                                    >
                                                        <CheckCircle size={12} />
                                                        <span>Resolver</span>
                                                    </button>
                                                )}
                                                <button
                                                    onClick={() => handleDelete(report.id)}
                                                    className="btn-danger px-2 py-1"
                                                    title="Eliminar reporte"
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

            {/* Modal de Evidencias */}
            {selectedImages && (
                <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
                    <div className="bg-white rounded-xl max-w-xl w-full p-4 space-y-3">
                        <div className="flex items-center justify-between border-b border-zinc-200 pb-2">
                            <h3 className="text-xs font-bold text-zinc-900 uppercase">Evidencias Adjuntas al Reporte</h3>
                            <button onClick={() => setSelectedImages(null)} className="text-zinc-400 hover:text-zinc-700">
                                <X size={16} />
                            </button>
                        </div>
                        <div className="grid grid-cols-2 gap-2 max-h-[60vh] overflow-y-auto">
                            {selectedImages.map((img, i) => (
                                <img key={i} src={img} alt="" className="w-full h-40 object-cover rounded-lg border border-zinc-200" />
                            ))}
                        </div>
                        <div className="flex justify-end">
                            <button onClick={() => setSelectedImages(null)} className="btn-outline">
                                Cerrar
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
