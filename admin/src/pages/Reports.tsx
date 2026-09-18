import React, { useState, useEffect } from 'react';
import {
    AlertCircle,
    CheckCircle,
    Trash2,
    Eye,
    X,
    Filter,
    Image as ImageIcon,
    Mail,
    Send,
    User,
    ShoppingBag,
    ExternalLink,
    Copy,
    MessageSquare,
    Clock,
    ShieldAlert,
    Bell,
    Check
} from 'lucide-react';
import { db } from '../services/firebase';
import {
    collection,
    query,
    orderBy,
    onSnapshot,
    doc,
    updateDoc,
    deleteDoc,
    getDoc,
    setDoc,
    addDoc,
    limit
} from 'firebase/firestore';
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
    resolutionNotes?: string;
    timestamp?: any;
    resolvedAt?: any;
}

interface ReportedPostData {
    id: string;
    title: string;
    imageUrl?: string;
    price?: string | number;
    userName?: string;
    userId?: string;
    location?: string;
    category?: string;
}

export const Reports: React.FC = () => {
    const [filter, setFilter] = useState<'pending' | 'resolved' | 'all'>('pending');
    const [reports, setReports] = useState<Report[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');

    // Modal de Detalle de Reporte e Inspección
    const [selectedReport, setSelectedReport] = useState<Report | null>(null);
    const [reportedPost, setReportedPost] = useState<ReportedPostData | null>(null);
    const [loadingPost, setLoadingPost] = useState(false);
    const [selectedImages, setSelectedImages] = useState<string[] | null>(null);

    // Modal de Contactar al Usuario
    const [contactModalOpen, setContactModalOpen] = useState(false);
    const [contactRecipientEmail, setContactRecipientEmail] = useState('');
    const [contactRecipientId, setContactRecipientId] = useState('');
    const [contactSubject, setContactSubject] = useState('');
    const [contactMessage, setContactMessage] = useState('');
    const [sendAsEmail, setSendAsEmail] = useState(true);
    const [sendAsNotification, setSendAsNotification] = useState(true);
    const [isSendingContact, setIsSendingContact] = useState(false);

    // Modal de Resolución con Notas
    const [resolveModalOpen, setResolveModalOpen] = useState(false);
    const [resolvingReportId, setResolvingReportId] = useState<string | null>(null);
    const [resolutionNotes, setResolutionNotes] = useState('');
    const [isResolving, setIsResolving] = useState(false);

    useEffect(() => {
        const q = query(collection(db, 'reports'), orderBy('timestamp', 'desc'), limit(150));
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

    // Cargar la publicación reportada si existe
    const handleInspectReport = async (rep: Report) => {
        setSelectedReport(rep);
        setReportedPost(null);

        if (rep.postId) {
            setLoadingPost(true);
            try {
                const postSnap = await getDoc(doc(db, 'posts', rep.postId));
                if (postSnap.exists()) {
                    const data = postSnap.data();
                    setReportedPost({
                        id: postSnap.id,
                        title: data.title || data.nombre || 'Publicación',
                        imageUrl: data.imageUrl || data.image || (data.images && data.images[0]) || '',
                        price: data.price || data.precio || '',
                        userName: data.userName || data.sellerName || 'Vendedor',
                        userId: data.userId || data.uid || '',
                        location: data.location || data.ubicacion || 'Colombia',
                        category: data.category || 'Marketplace'
                    });
                }
            } catch (e) {
                console.error('Error fetching reported post:', e);
            } finally {
                setLoadingPost(false);
            }
        }
    };

    // Abrir modal de contacto hacia el usuario
    const handleOpenContact = (rep: Report) => {
        setContactRecipientEmail(rep.userEmail || '');
        setContactRecipientId(rep.userId || '');
        setContactSubject(`Atención a tu reporte en CONNECT: ${rep.reason || 'Soporte Técnico'}`);
        setContactMessage(
            `Hola,\n\nHemos recibido y revisado tu reporte sobre "${rep.reason || 'el funcionamiento de la plataforma'}".\n\nQueremos informarte que...`
        );
        setContactModalOpen(true);
    };

    // Enviar mensaje / correo / notificación de soporte
    const handleSendContact = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!contactMessage.trim()) {
            toast.error('Por favor escribe un mensaje de respuesta');
            return;
        }

        setIsSendingContact(true);
        try {
            // 1. Enviar correo si se activó y hay email
            if (sendAsEmail && contactRecipientEmail) {
                await addDoc(collection(db, 'mail'), {
                    to: contactRecipientEmail,
                    message: {
                        subject: contactSubject.trim(),
                        html: `
                            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eaeaea; border-radius: 10px;">
                                <h2 style="color: #0094FF; margin-top: 0;">Soporte Oficial CONNECT</h2>
                                <p style="font-size: 14px; line-height: 1.6; color: #333333; white-space: pre-line;">${contactMessage}</p>
                                <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
                                <p style="font-size: 11px; color: #888888;">Este correo es una respuesta directa de la administración de CONNECT para atender tu reporte.</p>
                            </div>
                        `
                    },
                    createdAt: new Date()
                });
            }

            // 2. Enviar notificación interna a la app si se activó y hay userId
            if (sendAsNotification && contactRecipientId) {
                await addDoc(collection(db, 'notifications'), {
                    userId: contactRecipientId,
                    title: contactSubject.trim() || 'Respuesta de Soporte CONNECT',
                    body: contactMessage.trim(),
                    type: 'support_reply',
                    read: false,
                    createdAt: new Date()
                });
            }

            toast.success('¡Respuesta enviada satisfactoriamente al usuario!');
            setContactModalOpen(false);
        } catch (e: any) {
            toast.error(`Error al contactar al usuario: ${e.message}`);
        } finally {
            setIsSendingContact(false);
        }
    };

    const handlePromptResolve = (reportId: string) => {
        setResolvingReportId(reportId);
        setResolutionNotes('');
        setResolveModalOpen(true);
    };

    const handleConfirmResolve = async () => {
        if (!resolvingReportId) return;
        setIsResolving(true);
        try {
            await updateDoc(doc(db, 'reports', resolvingReportId), {
                status: 'resolved',
                resolvedAt: new Date(),
                resolutionNotes: resolutionNotes.trim() || 'Atendido y resuelto por administración.'
            });
            toast.success('Reporte marcado como resuelto');
            setResolveModalOpen(false);
            if (selectedReport && selectedReport.id === resolvingReportId) {
                setSelectedReport(prev => prev ? { ...prev, status: 'resolved', resolutionNotes } : null);
            }
        } catch (error: any) {
            toast.error(`Error al resolver: ${error.message}`);
        } finally {
            setIsResolving(false);
        }
    };

    const handleDelete = async (id: string) => {
        if (!window.confirm('¿Eliminar este reporte permanentemente?')) return;
        try {
            await deleteDoc(doc(db, 'reports', id));
            toast.success('Reporte eliminado');
            if (selectedReport?.id === id) setSelectedReport(null);
        } catch (err: any) {
            toast.error(`Error al eliminar: ${err.message}`);
        }
    };

    const handleDeleteReportedPost = async (postId: string) => {
        if (!window.confirm('¿Deseas eliminar permanentemente esta publicación del marketplace por infringir las normas?')) return;
        try {
            await deleteDoc(doc(db, 'posts', postId));
            toast.success('Publicación eliminada del marketplace');
            setReportedPost(null);
        } catch (err: any) {
            toast.error(`Error al eliminar publicación: ${err.message}`);
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
        const matchesFilter = filter === 'all' ? true : filter === 'pending' ? r.status !== 'resolved' : r.status === 'resolved';
        const matchesSearch = (r.reason || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
            (r.description || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
            (r.userEmail || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
            (r.postTitle || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
            (r.postId || '').toLowerCase().includes(searchTerm.toLowerCase());
        return matchesFilter && matchesSearch;
    });

    return (
        <div className="space-y-5 animate-in fade-in duration-300">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-zinc-200">
                <div>
                    <h1 className="text-xl font-black text-zinc-900 tracking-tight flex items-center gap-2">
                        <AlertCircle size={22} className="text-amber-500" />
                        Centro de Moderación y Reportes
                    </h1>
                    <p className="text-xs text-zinc-500 mt-0.5">
                        Supervisión de denuncias comunitarias, inspección de publicaciones y atención directa al usuario
                    </p>
                </div>

                <div className="flex items-center gap-1.5">
                    {(['pending', 'resolved', 'all'] as const).map((f) => (
                        <button
                            key={f}
                            onClick={() => setFilter(f)}
                            className={`px-3.5 py-1.5 text-xs font-bold rounded-lg transition-colors capitalize ${
                                filter === f
                                    ? 'bg-zinc-900 text-white shadow-sm'
                                    : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                            }`}
                        >
                            {f === 'pending' ? 'Pendientes' : f === 'resolved' ? 'Resueltos' : 'Todos'}
                        </button>
                    ))}
                </div>
            </div>

            {/* Barra de Búsqueda */}
            <div className="relative max-w-sm">
                <input
                    type="text"
                    placeholder="Buscar por motivo, descripción, usuario o post..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="input-clean pl-8 py-2 text-xs w-full"
                />
                <Filter size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-400" />
            </div>

            {/* Tabla de Reportes */}
            <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden shadow-sm">
                <div className="overflow-x-auto">
                    <table className="table-clean">
                        <thead>
                            <tr>
                                <th>Motivo & Denunciante</th>
                                <th>Detalle del Reporte</th>
                                <th>Fecha</th>
                                <th>Evidencias</th>
                                <th>Estado</th>
                                <th className="text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan={6} className="text-center py-10 text-zinc-400 text-xs">
                                        Cargando reportes desde Firebase...
                                    </td>
                                </tr>
                            ) : filteredReports.length === 0 ? (
                                <tr>
                                    <td colSpan={6} className="text-center py-12 text-zinc-400 text-xs">
                                        No hay reportes en este estado.
                                    </td>
                                </tr>
                            ) : (
                                filteredReports.map((report) => (
                                    <tr key={report.id} className="hover:bg-zinc-50/80 transition-colors">
                                        <td>
                                            <div className="space-y-0.5">
                                                <span className="font-bold text-zinc-900 text-xs block">
                                                    {report.reason || 'Sin motivo especificado'}
                                                </span>
                                                <p className="text-[11px] text-zinc-500 truncate max-w-xs font-mono">
                                                    De: {report.userEmail || report.userId || 'Usuario'}
                                                </p>
                                            </div>
                                        </td>
                                        <td>
                                            <div className="max-w-md">
                                                <p className="text-zinc-700 text-xs line-clamp-2">
                                                    {report.description || 'Sin descripción adicional.'}
                                                </p>
                                                {report.postId && (
                                                    <span className="text-[10px] text-[#0094FF] font-mono mt-0.5 inline-block">
                                                        Relacionado con Post #{report.postId.substring(0, 8)}
                                                    </span>
                                                )}
                                            </div>
                                        </td>
                                        <td>
                                            <span className="text-[11px] text-zinc-500 font-mono">
                                                {formatDate(report.timestamp)}
                                            </span>
                                        </td>
                                        <td>
                                            {report.images && report.images.length > 0 ? (
                                                <button
                                                    onClick={() => setSelectedImages(report.images!)}
                                                    className="btn-outline px-2 py-1 text-[11px] font-bold text-[#0094FF] flex items-center gap-1"
                                                >
                                                    <ImageIcon size={12} />
                                                    <span>{report.images.length} fotos</span>
                                                </button>
                                            ) : (
                                                <span className="text-zinc-400 text-[11px]">Sin fotos</span>
                                            )}
                                        </td>
                                        <td>
                                            <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-bold ${
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
                                                {/* BOTÓN REVISAR PUBLICACIÓN Y REPORTE COMPLETO */}
                                                <button
                                                    onClick={() => handleInspectReport(report)}
                                                    className="btn-outline px-2.5 py-1 text-xs font-bold flex items-center gap-1 text-zinc-800 hover:bg-zinc-100"
                                                    title="Inspeccionar reporte y publicación"
                                                >
                                                    <Eye size={12} className="text-[#0094FF]" />
                                                    <span>Revisar</span>
                                                </button>

                                                {/* BOTÓN CONTACTAR USUARIO DIRECTAMENTE */}
                                                <button
                                                    onClick={() => handleOpenContact(report)}
                                                    className="btn-outline px-2.5 py-1 text-xs font-bold flex items-center gap-1 text-[#0094FF] border-blue-200 bg-blue-50/40 hover:bg-blue-100/50"
                                                    title="Hablar con el usuario y atenderlo"
                                                >
                                                    <MessageSquare size={12} />
                                                    <span>Contactar</span>
                                                </button>

                                                {report.status !== 'resolved' && (
                                                    <button
                                                        onClick={() => handlePromptResolve(report.id)}
                                                        className="btn-primary px-2.5 py-1 text-xs font-bold flex items-center gap-1"
                                                        title="Marcar como resuelto"
                                                    >
                                                        <CheckCircle size={12} />
                                                        <span>Resolver</span>
                                                    </button>
                                                )}

                                                <button
                                                    onClick={() => handleDelete(report.id)}
                                                    className="btn-danger p-1.5 text-xs"
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

            {/* MODAL DE INSPECCIÓN COMPLETA DE REPORTE Y PUBLICACIÓN */}
            {selectedReport && (
                <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-3 sm:p-6 animate-in fade-in">
                    <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] flex flex-col shadow-2xl overflow-hidden border border-zinc-200">
                        {/* Cabecera */}
                        <div className="p-4 sm:p-5 border-b border-zinc-200 bg-zinc-50 flex items-center justify-between flex-shrink-0">
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 rounded-xl bg-amber-100 text-amber-600 flex items-center justify-center font-bold">
                                    <ShieldAlert size={22} />
                                </div>
                                <div>
                                    <h2 className="text-base font-black text-zinc-900">
                                        Expediente de Reporte: {selectedReport.reason || 'General'}
                                    </h2>
                                    <p className="text-xs text-zinc-500 font-mono mt-0.5">
                                        Reportado por: {selectedReport.userEmail || selectedReport.userId || 'Usuario anónimo'}
                                    </p>
                                </div>
                            </div>
                            <button
                                onClick={() => setSelectedReport(null)}
                                className="text-zinc-400 hover:text-zinc-700 p-2 rounded-lg hover:bg-zinc-200 transition-colors"
                            >
                                <X size={20} />
                            </button>
                        </div>

                        {/* Cuerpo */}
                        <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-4 text-xs">
                            {/* Descripción Detallada del Usuario */}
                            <div className="bg-zinc-50 p-4 rounded-xl border border-zinc-200 space-y-1.5">
                                <span className="text-[10px] font-black uppercase tracking-wider text-zinc-400">
                                    Descripción enviada por el usuario:
                                </span>
                                <p className="text-zinc-800 text-sm leading-relaxed whitespace-pre-line font-medium">
                                    {selectedReport.description || 'Sin descripción detallada.'}
                                </p>
                                <p className="text-[11px] text-zinc-400 font-mono pt-1">
                                    Fecha: {formatDate(selectedReport.timestamp)}
                                </p>
                            </div>

                            {/* Publicación Reportada (si tiene postId) */}
                            {selectedReport.postId && (
                                <div className="border border-zinc-200 rounded-xl p-4 space-y-3 bg-white">
                                    <div className="flex items-center justify-between">
                                        <span className="text-[10px] font-black uppercase tracking-wider text-zinc-400 flex items-center gap-1.5">
                                            <ShoppingBag size={12} className="text-[#0094FF]" /> Publicación Denunciada
                                        </span>
                                        <span className="font-mono text-[10px] text-zinc-400">ID: {selectedReport.postId}</span>
                                    </div>

                                    {loadingPost ? (
                                        <p className="text-center py-4 text-zinc-400">Cargando datos de la publicación...</p>
                                    ) : reportedPost ? (
                                        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 p-3 bg-zinc-50 rounded-xl border border-zinc-200">
                                            <div className="flex items-center gap-3">
                                                {reportedPost.imageUrl ? (
                                                    <img src={reportedPost.imageUrl} alt="" className="w-14 h-14 rounded-lg object-cover border border-zinc-200 flex-shrink-0" />
                                                ) : (
                                                    <div className="w-14 h-14 rounded-lg bg-zinc-200 flex items-center justify-center text-zinc-400 flex-shrink-0">
                                                        <ShoppingBag size={20} />
                                                    </div>
                                                )}
                                                <div>
                                                    <p className="font-bold text-zinc-900 text-sm">{reportedPost.title}</p>
                                                    <p className="font-mono font-bold text-[#0094FF]">${reportedPost.price} COP</p>
                                                    <p className="text-[11px] text-zinc-500">
                                                        Vendedor: {reportedPost.userName} • {reportedPost.location}
                                                    </p>
                                                </div>
                                            </div>

                                            <div className="flex items-center gap-1.5 self-end sm:self-center">
                                                <button
                                                    onClick={() => handleDeleteReportedPost(reportedPost.id)}
                                                    className="btn-danger text-[11px] py-1.5 px-3 font-bold flex items-center gap-1"
                                                >
                                                    <Trash2 size={12} />
                                                    <span>Eliminar Post</span>
                                                </button>
                                            </div>
                                        </div>
                                    ) : (
                                        <div className="p-3 bg-amber-50 rounded-xl text-amber-800 text-[11px]">
                                            La publicación ya no existe o fue eliminada previamente.
                                        </div>
                                    )}
                                </div>
                            )}

                            {/* Evidencias fotográficas */}
                            {selectedReport.images && selectedReport.images.length > 0 && (
                                <div className="space-y-2">
                                    <span className="text-[10px] font-black uppercase tracking-wider text-zinc-400">
                                        Evidencias y Capturas Adjuntas:
                                    </span>
                                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                                        {selectedReport.images.map((img, i) => (
                                            <a key={i} href={img} target="_blank" rel="noreferrer" className="block relative group rounded-xl overflow-hidden border border-zinc-200">
                                                <img src={img} alt="" className="w-full h-28 object-cover group-hover:scale-105 transition-transform" />
                                                <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 flex items-center justify-center text-white text-xs font-bold transition-opacity">
                                                    <ExternalLink size={14} />
                                                </div>
                                            </a>
                                        ))}
                                    </div>
                                </div>
                            )}

                            {/* Notas de resolución existentes */}
                            {selectedReport.resolutionNotes && (
                                <div className="bg-emerald-50 border border-emerald-200 p-3.5 rounded-xl space-y-1">
                                    <span className="text-[10px] font-bold text-emerald-800 uppercase flex items-center gap-1">
                                        <CheckCircle size={12} /> Notas de Resolución Registradas
                                    </span>
                                    <p className="text-emerald-950 font-medium">{selectedReport.resolutionNotes}</p>
                                </div>
                            )}
                        </div>

                        {/* Pie con Acciones */}
                        <div className="p-4 bg-zinc-50 border-t border-zinc-200 flex flex-col sm:flex-row items-center justify-between gap-3 flex-shrink-0">
                            <button
                                onClick={() => handleOpenContact(selectedReport)}
                                className="btn-primary py-2 px-4 text-xs font-bold flex items-center gap-2 w-full sm:w-auto"
                            >
                                <MessageSquare size={14} />
                                <span>Contactar y Atender al Usuario</span>
                            </button>

                            <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
                                {selectedReport.status !== 'resolved' ? (
                                    <button
                                        onClick={() => handlePromptResolve(selectedReport.id)}
                                        className="btn-secondary py-2 px-4 text-xs font-bold flex items-center gap-1.5"
                                    >
                                        <CheckCircle size={14} className="text-emerald-600" />
                                        <span>Resolver Reporte</span>
                                    </button>
                                ) : (
                                    <span className="text-xs font-bold text-emerald-700 flex items-center gap-1">
                                        <CheckCircle size={14} /> Resuelto
                                    </span>
                                )}
                                <button
                                    onClick={() => setSelectedReport(null)}
                                    className="btn-outline py-2 px-4 text-xs font-bold"
                                >
                                    Cerrar
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* MODAL DE CONTACTAR AL USUARIO */}
            {contactModalOpen && (
                <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-3 sm:p-6 animate-in fade-in">
                    <div className="bg-white rounded-2xl max-w-lg w-full p-5 shadow-2xl border border-zinc-200 space-y-4">
                        <div className="flex items-center justify-between border-b border-zinc-200 pb-3">
                            <div className="flex items-center gap-2.5">
                                <div className="w-8 h-8 rounded-lg bg-blue-100 text-[#0094FF] flex items-center justify-center">
                                    <MessageSquare size={18} />
                                </div>
                                <div>
                                    <h3 className="font-black text-zinc-900 text-sm">Contactar y Atender al Usuario</h3>
                                    <p className="text-[11px] text-zinc-500">Envía una respuesta oficial al usuario que reportó</p>
                                </div>
                            </div>
                            <button onClick={() => setContactModalOpen(false)} className="text-zinc-400 hover:text-zinc-600">
                                <X size={18} />
                            </button>
                        </div>

                        <form onSubmit={handleSendContact} className="space-y-3.5 text-xs">
                            <div>
                                <label className="block font-bold text-zinc-700 mb-1">Destinatario:</label>
                                <div className="flex items-center gap-2">
                                    <input
                                        type="text"
                                        readOnly
                                        value={contactRecipientEmail || contactRecipientId || 'Usuario'}
                                        className="input-clean w-full bg-zinc-100 text-zinc-700 font-mono text-xs"
                                    />
                                    {contactRecipientEmail && (
                                        <button
                                            type="button"
                                            onClick={() => {
                                                navigator.clipboard.writeText(contactRecipientEmail);
                                                toast.success('Correo copiado al portapapeles');
                                            }}
                                            className="btn-outline py-2 px-2.5 flex-shrink-0"
                                            title="Copiar correo"
                                        >
                                            <Copy size={13} />
                                        </button>
                                    )}
                                </div>
                            </div>

                            <div>
                                <label className="block font-bold text-zinc-700 mb-1">Asunto de Respuesta:</label>
                                <input
                                    type="text"
                                    required
                                    value={contactSubject}
                                    onChange={(e) => setContactSubject(e.target.value)}
                                    placeholder="Asunto del correo o notificación"
                                    className="input-clean w-full text-xs"
                                />
                            </div>

                            <div>
                                <label className="block font-bold text-zinc-700 mb-1">Mensaje de Atención / Solución:</label>
                                <textarea
                                    required
                                    rows={5}
                                    value={contactMessage}
                                    onChange={(e) => setContactMessage(e.target.value)}
                                    placeholder="Escribe la respuesta detallada para el usuario..."
                                    className="input-clean w-full text-xs"
                                />
                            </div>

                            {/* Canales de Envío */}
                            <div className="bg-zinc-50 p-3 rounded-xl border border-zinc-200 space-y-2">
                                <span className="font-bold text-zinc-700 block text-[11px]">Canales de entrega simultánea:</span>
                                <div className="flex items-center gap-4">
                                    <label className="flex items-center gap-1.5 cursor-pointer">
                                        <input
                                            type="checkbox"
                                            checked={sendAsEmail}
                                            onChange={(e) => setSendAsEmail(e.target.checked)}
                                            className="rounded text-[#0094FF]"
                                        />
                                        <span className="text-zinc-700 font-medium">Correo Electrónico Oficial</span>
                                    </label>
                                    <label className="flex items-center gap-1.5 cursor-pointer">
                                        <input
                                            type="checkbox"
                                            checked={sendAsNotification}
                                            onChange={(e) => setSendAsNotification(e.target.checked)}
                                            className="rounded text-[#0094FF]"
                                        />
                                        <span className="text-zinc-700 font-medium">Notificación Interna en App</span>
                                    </label>
                                </div>
                            </div>

                            <div className="pt-2 border-t border-zinc-200 flex items-center justify-end gap-2">
                                <button
                                    type="button"
                                    onClick={() => setContactModalOpen(false)}
                                    className="btn-secondary py-2 px-3 text-xs font-bold"
                                >
                                    Cancelar
                                </button>
                                <button
                                    type="submit"
                                    disabled={isSendingContact}
                                    className="btn-primary py-2 px-4 text-xs font-bold flex items-center gap-1.5"
                                >
                                    <Send size={13} />
                                    <span>{isSendingContact ? 'Enviando...' : 'Enviar Respuesta al Usuario'}</span>
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* MODAL DE RESOLVER REPORTE CON NOTAS */}
            {resolveModalOpen && (
                <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-3 animate-in fade-in">
                    <div className="bg-white rounded-2xl max-w-md w-full p-5 shadow-2xl border border-zinc-200 space-y-4">
                        <div className="flex items-center justify-between border-b border-zinc-200 pb-2">
                            <h3 className="font-black text-zinc-900 text-sm flex items-center gap-2">
                                <CheckCircle size={16} className="text-emerald-600" />
                                Resolver Reporte
                            </h3>
                            <button onClick={() => setResolveModalOpen(false)} className="text-zinc-400 hover:text-zinc-600">
                                <X size={18} />
                            </button>
                        </div>

                        <div className="space-y-3 text-xs">
                            <p className="text-zinc-600">
                                Puedes agregar una nota interna de resolución para documentar qué acciones se tomaron:
                            </p>
                            <textarea
                                rows={3}
                                value={resolutionNotes}
                                onChange={(e) => setResolutionNotes(e.target.value)}
                                placeholder="Ej: Se contactó al usuario y se resolvió el fallo en la sesión / se retiró la publicación ofensiva."
                                className="input-clean w-full text-xs"
                            />
                        </div>

                        <div className="flex items-center justify-end gap-2 pt-2 border-t border-zinc-200">
                            <button
                                onClick={() => setResolveModalOpen(false)}
                                className="btn-secondary py-2 px-3 text-xs font-bold"
                            >
                                Cancelar
                            </button>
                            <button
                                onClick={handleConfirmResolve}
                                disabled={isResolving}
                                className="btn-primary py-2 px-4 text-xs font-bold flex items-center gap-1.5 bg-emerald-600 hover:bg-emerald-700"
                            >
                                <Check size={14} />
                                <span>{isResolving ? 'Guardando...' : 'Confirmar Resolución'}</span>
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
