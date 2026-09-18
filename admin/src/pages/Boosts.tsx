import React, { useState, useEffect } from 'react';
import {
    Zap,
    Plus,
    Search,
    RefreshCw,
    Play,
    Pause,
    Trash2,
    ExternalLink,
    CheckCircle2,
    Clock,
    AlertCircle,
    X,
    Filter,
    Eye,
    MapPin,
    DollarSign,
    Users,
    Sparkles,
    ShoppingBag
} from 'lucide-react';
import { db } from '../services/firebase';
import {
    collection,
    getDocs,
    doc,
    setDoc,
    updateDoc,
    deleteDoc,
    serverTimestamp,
    query,
    orderBy,
    limit,
    getDoc
} from 'firebase/firestore';
import toast from 'react-hot-toast';

interface BoostItem {
    id: string;
    postId: string;
    postTitle?: string;
    imageUrl?: string;
    price?: string | number;
    location?: string;
    sellerId?: string;
    sellerName?: string;
    dailyBudget: number;
    durationDays: number;
    totalBudget: number;
    targetGender: string;
    status: 'active' | 'paused' | 'completed';
    createdAt?: any;
    expiresAt?: any;
}

interface PostOption {
    id: string;
    title: string;
    imageUrl?: string;
    price?: string | number;
    location?: string;
    userName?: string;
    category?: string;
}

export const Boosts: React.FC = () => {
    const [boosts, setBoosts] = useState<BoostItem[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'paused' | 'completed'>('all');
    const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
    const [previewItem, setPreviewItem] = useState<BoostItem | null>(null);

    // Lista de publicaciones disponibles para seleccionar
    const [availablePosts, setAvailablePosts] = useState<PostOption[]>([]);
    const [loadingPosts, setLoadingPosts] = useState(false);
    const [postSearchFilter, setPostSearchFilter] = useState('');

    // Formulario de nuevo Boost
    const [formPostId, setFormPostId] = useState('');
    const [formPostTitle, setFormPostTitle] = useState('');
    const [formPostImage, setFormPostImage] = useState('');
    const [formPostPrice, setFormPostPrice] = useState('150000');
    const [formPostLocation, setFormPostLocation] = useState('Bogotá, Colombia');
    const [formSellerName, setFormSellerName] = useState('Vendedor Oficial');
    const [formDailyBudget, setFormDailyBudget] = useState(5000);
    const [formDurationDays, setFormDurationDays] = useState(7);
    const [formGender, setFormGender] = useState('Todos');
    const [isSubmitting, setIsSubmitting] = useState(false);

    const fetchBoosts = async () => {
        setLoading(true);
        try {
            const boostSnap = await getDocs(query(collection(db, 'boosts'), limit(100)));
            const items: BoostItem[] = [];
            boostSnap.forEach(d => {
                const data = d.data();
                items.push({
                    id: d.id,
                    postId: data.postId || d.id,
                    postTitle: data.postTitle || data.title || 'Publicación',
                    imageUrl: data.imageUrl || data.image || '',
                    price: data.price || 'Consultar',
                    location: data.location || 'Colombia',
                    sellerId: data.sellerId || data.userId || 'N/A',
                    sellerName: data.sellerName || data.userName || 'Usuario',
                    dailyBudget: data.dailyBudget || 5000,
                    durationDays: data.durationDays || 7,
                    totalBudget: data.totalBudget || (data.dailyBudget || 5000) * (data.durationDays || 7),
                    targetGender: data.targetGender || 'Todos',
                    status: data.status || 'active',
                    createdAt: data.createdAt,
                    expiresAt: data.expiresAt
                });
            });
            setBoosts(items);
        } catch (error) {
            console.error('Error fetching boosts:', error);
            toast.error('Error al cargar la lista de impulsos');
        } finally {
            setLoading(false);
        }
    };

    const fetchAvailablePosts = async () => {
        setLoadingPosts(true);
        try {
            const postsSnap = await getDocs(query(collection(db, 'posts'), limit(60)));
            const list: PostOption[] = [];
            postsSnap.forEach(d => {
                const data = d.data();
                const img = data.imageUrl || data.image || (data.images && data.images[0]) || '';
                list.push({
                    id: d.id,
                    title: data.title || data.nombre || data.name || `Publicación #${d.id.substring(0, 6)}`,
                    imageUrl: img,
                    price: data.price || data.precio || '',
                    location: data.location || data.ubicacion || data.city || 'Colombia',
                    userName: data.userName || data.sellerName || 'Usuario',
                    category: data.category || data.tipo || 'General'
                });
            });
            setAvailablePosts(list);
        } catch (e) {
            console.error('Error fetching posts for picker:', e);
        } finally {
            setLoadingPosts(false);
        }
    };

    useEffect(() => {
        fetchBoosts();
        fetchAvailablePosts();
    }, []);

    const handleSelectPost = (p: PostOption) => {
        setFormPostId(p.id);
        setFormPostTitle(p.title);
        setFormPostImage(p.imageUrl || '');
        setFormPostPrice(p.price?.toString() || '150000');
        setFormPostLocation(p.location || 'Colombia');
        setFormSellerName(p.userName || 'Usuario');
    };

    const handleToggleStatus = async (boost: BoostItem) => {
        const newStatus = boost.status === 'active' ? 'paused' : 'active';
        try {
            await updateDoc(doc(db, 'boosts', boost.id), {
                status: newStatus,
                updatedAt: new Date()
            });
            setBoosts(prev => prev.map(b => b.id === boost.id ? { ...b, status: newStatus } : b));
            toast.success(`Impulso ${newStatus === 'active' ? 'reactivado' : 'pausado'}`);
        } catch (e) {
            toast.error('Error al actualizar el estado del impulso');
        }
    };

    const handleDelete = async (id: string) => {
        if (!window.confirm('¿Seguro que deseas eliminar permanentemente este impulso?')) return;
        try {
            await deleteDoc(doc(db, 'boosts', id));
            setBoosts(prev => prev.filter(b => b.id !== id));
            toast.success('Impulso eliminado');
        } catch (e) {
            toast.error('Error al eliminar');
        }
    };

    const handleCreateBoost = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!formPostId.trim()) {
            toast.error('Selecciona o ingresa el ID de la publicación a impulsar');
            return;
        }

        setIsSubmitting(true);
        try {
            const boostId = `boost_${Date.now()}`;
            const total = formDailyBudget * formDurationDays;
            const expiresDate = new Date(Date.now() + formDurationDays * 24 * 60 * 60 * 1000);

            const newBoost = {
                id: boostId,
                postId: formPostId.trim(),
                postTitle: formPostTitle.trim() || `Publicación #${formPostId.substring(0, 6)}`,
                imageUrl: formPostImage.trim(),
                price: formPostPrice,
                location: formPostLocation,
                sellerName: formSellerName,
                dailyBudget: Number(formDailyBudget),
                durationDays: Number(formDurationDays),
                totalBudget: total,
                targetGender: formGender,
                status: 'active',
                createdAt: new Date(),
                expiresAt: expiresDate
            };

            await setDoc(doc(db, 'boosts', boostId), newBoost);

            // Actualizar la publicación en Firestore para reflejar el estado impulsado
            try {
                await updateDoc(doc(db, 'posts', formPostId.trim()), {
                    is_boosted: true,
                    boost_id: boostId,
                    boost_expires_at: expiresDate
                });
            } catch (err) {
                // Post puede ser de otra colección o externo
            }

            toast.success('¡Impulso creado y activado exitosamente!');
            setIsCreateModalOpen(false);
            setFormPostId('');
            setFormPostTitle('');
            setFormPostImage('');
            fetchBoosts();
        } catch (e: any) {
            toast.error(`Error al crear impulso: ${e.message}`);
        } finally {
            setIsSubmitting(false);
        }
    };

    const filtered = boosts.filter(b => {
        const matchesSearch = b.postTitle?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            b.postId?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            b.sellerName?.toLowerCase().includes(searchTerm.toLowerCase());
        const matchesStatus = statusFilter === 'all' ? true : b.status === statusFilter;
        return matchesSearch && matchesStatus;
    });

    const totalActive = boosts.filter(b => b.status === 'active').length;
    const totalInvestment = boosts.reduce((acc, b) => acc + (b.totalBudget || 0), 0);

    // Cálculos de alcance estimado
    const currentTotalBudget = formDailyBudget * formDurationDays;
    const minReach = Math.round(currentTotalBudget * 0.5);
    const maxReach = Math.round(currentTotalBudget * 1.2);

    const filteredAvailablePosts = availablePosts.filter(p =>
        p.title.toLowerCase().includes(postSearchFilter.toLowerCase()) ||
        p.id.toLowerCase().includes(postSearchFilter.toLowerCase()) ||
        p.userName?.toLowerCase().includes(postSearchFilter.toLowerCase())
    );

    return (
        <div className="space-y-5 animate-in fade-in duration-300">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-zinc-200 pb-4">
                <div>
                    <h1 className="text-xl font-black text-zinc-900 tracking-tight flex items-center gap-2">
                        <Zap size={22} className="text-[#0094FF]" />
                        Gestión de Impulsos (Boosts)
                    </h1>
                    <p className="text-xs text-zinc-500 mt-0.5">
                        Promoción de publicaciones con prioridad en feed, previsualización en vivo y segmentación
                    </p>
                </div>

                <div className="flex items-center gap-2">
                    <button
                        onClick={fetchBoosts}
                        disabled={loading}
                        className="btn-secondary flex items-center gap-1.5 text-xs py-2"
                        title="Actualizar datos"
                    >
                        <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
                        <span>Actualizar</span>
                    </button>
                    <button
                        onClick={() => {
                            setIsCreateModalOpen(true);
                            if (availablePosts.length === 0) fetchAvailablePosts();
                        }}
                        className="btn-primary flex items-center gap-1.5 text-xs py-2 font-bold"
                    >
                        <Plus size={14} />
                        <span>Crear y Previsualizar Impulso</span>
                    </button>
                </div>
            </div>

            {/* Metrics bar */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="bg-white border border-zinc-200 rounded-xl p-3.5 flex items-center justify-between shadow-sm">
                    <div>
                        <p className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Total Impulsos</p>
                        <p className="text-xl font-black text-zinc-900 mt-0.5">{boosts.length}</p>
                    </div>
                    <div className="w-9 h-9 rounded-xl bg-zinc-100 flex items-center justify-center text-zinc-700">
                        <Zap size={18} />
                    </div>
                </div>

                <div className="bg-white border border-zinc-200 rounded-xl p-3.5 flex items-center justify-between shadow-sm">
                    <div>
                        <p className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Impulsos Activos</p>
                        <p className="text-xl font-black text-[#0094FF] mt-0.5">{totalActive}</p>
                    </div>
                    <div className="w-9 h-9 rounded-xl bg-blue-50 flex items-center justify-center text-[#0094FF]">
                        <CheckCircle2 size={18} />
                    </div>
                </div>

                <div className="bg-white border border-zinc-200 rounded-xl p-3.5 flex items-center justify-between shadow-sm">
                    <div>
                        <p className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Inversión Total Promocional</p>
                        <p className="text-xl font-black text-zinc-900 mt-0.5">
                            ${totalInvestment.toLocaleString('es-CO')} <span className="text-xs font-medium text-zinc-400">COP</span>
                        </p>
                    </div>
                    <div className="w-9 h-9 rounded-xl bg-emerald-50 flex items-center justify-center text-emerald-600">
                        <Clock size={18} />
                    </div>
                </div>
            </div>

            {/* Filters Bar */}
            <div className="flex flex-col sm:flex-row items-center justify-between gap-3 bg-white border border-zinc-200 rounded-xl p-3 shadow-sm">
                <div className="relative w-full sm:w-80">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-400" size={14} />
                    <input
                        type="text"
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        placeholder="Buscar por ID, título o vendedor..."
                        className="input-clean pl-8 py-1.5 text-xs w-full"
                    />
                </div>

                <div className="flex items-center gap-1.5 self-start sm:self-auto">
                    <span className="text-xs text-zinc-500 mr-1 font-medium">Estado:</span>
                    {(['all', 'active', 'paused', 'completed'] as const).map(st => (
                        <button
                            key={st}
                            onClick={() => setStatusFilter(st)}
                            className={`px-3 py-1 text-xs font-bold rounded-lg transition-colors ${
                                statusFilter === st
                                    ? 'bg-[#0094FF] text-white'
                                    : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
                            }`}
                        >
                            {st === 'all' ? 'Todos' : st === 'active' ? 'Activos' : st === 'paused' ? 'Pausados' : 'Finalizados'}
                        </button>
                    ))}
                </div>
            </div>

            {/* Table */}
            <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden shadow-sm">
                <div className="overflow-x-auto">
                    <table className="table-clean">
                        <thead>
                            <tr>
                                <th>Publicación</th>
                                <th>Presupuesto Diario</th>
                                <th>Duración</th>
                                <th>Inversión Total</th>
                                <th>Audiencia</th>
                                <th>Estado</th>
                                <th className="text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-10 text-zinc-400 text-xs">
                                        Cargando lista de impulsos...
                                    </td>
                                </tr>
                            ) : filtered.length === 0 ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-12">
                                        <div className="flex flex-col items-center justify-center text-zinc-400">
                                            <Zap size={36} className="text-zinc-300 mb-2 stroke-1" />
                                            <p className="text-xs font-bold text-zinc-600">No hay impulsos registrados</p>
                                            <p className="text-[11px] text-zinc-400 mt-0.5">
                                                Crea un nuevo impulso para una publicación de CONNECT.
                                            </p>
                                            <button
                                                onClick={() => setIsCreateModalOpen(true)}
                                                className="btn-primary mt-3 text-xs font-bold"
                                            >
                                                Crear Primer Impulso
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ) : (
                                filtered.map(boost => (
                                    <tr key={boost.id} className="hover:bg-zinc-50/80 transition-colors">
                                        <td>
                                            <div className="flex items-center gap-2.5">
                                                {boost.imageUrl ? (
                                                    <img src={boost.imageUrl} alt="" className="w-10 h-10 rounded-lg object-cover border border-zinc-200 flex-shrink-0" />
                                                ) : (
                                                    <div className="w-10 h-10 rounded-lg bg-zinc-100 flex items-center justify-center text-zinc-400 flex-shrink-0 border border-zinc-200">
                                                        <ShoppingBag size={18} />
                                                    </div>
                                                )}
                                                <div>
                                                    <div className="font-bold text-zinc-900 text-xs">{boost.postTitle}</div>
                                                    <div className="text-[11px] text-zinc-400 font-mono">ID: {boost.postId} • {boost.sellerName}</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td className="font-mono text-xs text-zinc-800 font-semibold">
                                            ${boost.dailyBudget.toLocaleString('es-CO')} COP
                                        </td>
                                        <td className="text-xs text-zinc-700">
                                            {boost.durationDays} días
                                        </td>
                                        <td className="font-mono font-bold text-xs text-[#0094FF]">
                                            ${boost.totalBudget.toLocaleString('es-CO')} COP
                                        </td>
                                        <td>
                                            <span className="text-xs px-2.5 py-0.5 bg-zinc-100 text-zinc-700 rounded-md font-semibold border border-zinc-200">
                                                {boost.targetGender}
                                            </span>
                                        </td>
                                        <td>
                                            <span className={`inline-flex items-center gap-1.5 text-[11px] font-bold px-2.5 py-0.5 rounded-full ${
                                                boost.status === 'active'
                                                    ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                                    : boost.status === 'paused'
                                                    ? 'bg-amber-50 text-amber-700 border border-amber-200'
                                                    : 'bg-zinc-100 text-zinc-600 border border-zinc-200'
                                            }`}>
                                                <span className={`w-1.5 h-1.5 rounded-full ${
                                                    boost.status === 'active' ? 'bg-emerald-500' : boost.status === 'paused' ? 'bg-amber-500' : 'bg-zinc-400'
                                                }`} />
                                                {boost.status === 'active' ? 'Activo' : boost.status === 'paused' ? 'Pausado' : 'Finalizado'}
                                            </span>
                                        </td>
                                        <td>
                                            <div className="flex items-center justify-end gap-1.5">
                                                {/* BOTÓN PREVISUALIZAR IMPULSO */}
                                                <button
                                                    onClick={() => setPreviewItem(boost)}
                                                    className="btn-outline text-xs py-1 px-2.5 flex items-center gap-1 font-bold text-[#0094FF] border-blue-200 hover:bg-blue-50"
                                                    title="Previsualizar cómo se ve en el feed"
                                                >
                                                    <Eye size={12} />
                                                    <span>Previsualizar</span>
                                                </button>
                                                <button
                                                    onClick={() => handleToggleStatus(boost)}
                                                    className="btn-outline text-xs py-1 px-2 flex items-center gap-1"
                                                    title={boost.status === 'active' ? 'Pausar impulso' : 'Activar impulso'}
                                                >
                                                    {boost.status === 'active' ? (
                                                        <>
                                                            <Pause size={12} />
                                                            <span>Pausar</span>
                                                        </>
                                                    ) : (
                                                        <>
                                                            <Play size={12} />
                                                            <span>Activar</span>
                                                        </>
                                                    )}
                                                </button>
                                                <button
                                                    onClick={() => handleDelete(boost.id)}
                                                    className="btn-danger text-xs py-1 px-2 flex items-center gap-1"
                                                    title="Eliminar impulso"
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

            {/* MODAL CREAR Y PREVISUALIZAR IMPULSO */}
            {isCreateModalOpen && (
                <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-3 sm:p-6 animate-in fade-in">
                    <div className="bg-white rounded-2xl max-w-4xl w-full max-h-[92vh] flex flex-col shadow-2xl overflow-hidden border border-zinc-200">
                        {/* Cabecera */}
                        <div className="p-4 sm:p-5 border-b border-zinc-200 bg-zinc-50 flex items-center justify-between flex-shrink-0">
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 rounded-xl bg-blue-100 text-[#0094FF] flex items-center justify-center font-bold">
                                    <Zap size={22} />
                                </div>
                                <div>
                                    <h2 className="text-base font-black text-zinc-900">
                                        Crear y Previsualizar Nuevo Impulso
                                    </h2>
                                    <p className="text-xs text-zinc-500 mt-0.5">
                                        Selecciona una publicación, calibra presupuesto y visualiza la tarjeta en tiempo real
                                    </p>
                                </div>
                            </div>
                            <button
                                onClick={() => setIsCreateModalOpen(false)}
                                className="text-zinc-400 hover:text-zinc-700 p-2 rounded-lg hover:bg-zinc-200 transition-colors"
                            >
                                <X size={20} />
                            </button>
                        </div>

                        {/* Cuerpo dividido en 2 columnas: Formulario (Izquierda) + Previsualizador en Vivo (Derecha) */}
                        <div className="flex-1 overflow-y-auto p-4 sm:p-6 grid grid-cols-1 lg:grid-cols-12 gap-6">
                            {/* Columna Izquierda: Configuración */}
                            <form onSubmit={handleCreateBoost} className="lg:col-span-7 space-y-4">
                                <div>
                                    <label className="block text-xs font-bold text-zinc-700 mb-1">
                                        1. Seleccionar Publicación del Marketplace <span className="text-red-500">*</span>
                                    </label>
                                    
                                    {/* Selector / Buscador de publicaciones */}
                                    <div className="relative mb-2">
                                        <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-400" size={13} />
                                        <input
                                            type="text"
                                            value={postSearchFilter}
                                            onChange={(e) => setPostSearchFilter(e.target.value)}
                                            placeholder="Filtrar por título, ID o usuario..."
                                            className="input-clean pl-8 py-1.5 text-xs w-full"
                                        />
                                    </div>

                                    <div className="max-h-36 overflow-y-auto border border-zinc-200 rounded-xl divide-y divide-zinc-100 bg-zinc-50/50">
                                        {loadingPosts ? (
                                            <p className="text-center py-4 text-xs text-zinc-400">Cargando publicaciones...</p>
                                        ) : filteredAvailablePosts.length === 0 ? (
                                            <p className="text-center py-4 text-xs text-zinc-400">No se encontraron publicaciones</p>
                                        ) : (
                                            filteredAvailablePosts.map(p => (
                                                <div
                                                    key={p.id}
                                                    onClick={() => handleSelectPost(p)}
                                                    className={`p-2 flex items-center justify-between gap-2 cursor-pointer hover:bg-blue-50/60 transition-colors ${
                                                        formPostId === p.id ? 'bg-blue-100/70 font-bold border-l-4 border-[#0094FF]' : ''
                                                    }`}
                                                >
                                                    <div className="flex items-center gap-2 overflow-hidden">
                                                        {p.imageUrl ? (
                                                            <img src={p.imageUrl} alt="" className="w-8 h-8 rounded object-cover border border-zinc-200 flex-shrink-0" />
                                                        ) : (
                                                            <div className="w-8 h-8 rounded bg-zinc-200 flex items-center justify-center text-zinc-400 text-[10px] flex-shrink-0">
                                                                IMG
                                                            </div>
                                                        )}
                                                        <div className="overflow-hidden">
                                                            <p className="text-xs text-zinc-800 truncate">{p.title}</p>
                                                            <p className="text-[10px] text-zinc-400 font-mono truncate">{p.id} • {p.userName}</p>
                                                        </div>
                                                    </div>
                                                    {p.price && (
                                                        <span className="text-[11px] font-bold text-zinc-900 font-mono flex-shrink-0">
                                                            ${Number(p.price).toLocaleString('es-CO')}
                                                        </span>
                                                    )}
                                                </div>
                                            ))
                                        )}
                                    </div>

                                    {/* ID Manual por si la publicación es externa */}
                                    <div className="mt-2">
                                        <input
                                            type="text"
                                            required
                                            value={formPostId}
                                            onChange={(e) => setFormPostId(e.target.value)}
                                            placeholder="O ingresa el ID de publicación manualmente..."
                                            className="input-clean w-full text-xs font-mono"
                                        />
                                    </div>
                                </div>

                                <div className="grid grid-cols-2 gap-3">
                                    <div>
                                        <label className="block text-xs font-bold text-zinc-700 mb-1">
                                            Título del Anuncio
                                        </label>
                                        <input
                                            type="text"
                                            value={formPostTitle}
                                            onChange={(e) => setFormPostTitle(e.target.value)}
                                            placeholder="Título de la publicación"
                                            className="input-clean w-full text-xs"
                                        />
                                    </div>
                                    <div>
                                        <label className="block text-xs font-bold text-zinc-700 mb-1">
                                            Precio Referencia (COP)
                                        </label>
                                        <input
                                            type="text"
                                            value={formPostPrice}
                                            onChange={(e) => setFormPostPrice(e.target.value)}
                                            placeholder="150000"
                                            className="input-clean w-full text-xs font-mono"
                                        />
                                    </div>
                                </div>

                                <div className="grid grid-cols-2 gap-3">
                                    <div>
                                        <label className="block text-xs font-bold text-zinc-700 mb-1">
                                            Ubicación
                                        </label>
                                        <input
                                            type="text"
                                            value={formPostLocation}
                                            onChange={(e) => setFormPostLocation(e.target.value)}
                                            placeholder="Bogotá, Colombia"
                                            className="input-clean w-full text-xs"
                                        />
                                    </div>
                                    <div>
                                        <label className="block text-xs font-bold text-zinc-700 mb-1">
                                            Vendedor / Usuario
                                        </label>
                                        <input
                                            type="text"
                                            value={formSellerName}
                                            onChange={(e) => setFormSellerName(e.target.value)}
                                            placeholder="Nombre del vendedor"
                                            className="input-clean w-full text-xs"
                                        />
                                    </div>
                                </div>

                                <div className="grid grid-cols-2 gap-3">
                                    <div>
                                        <label className="block text-xs font-bold text-zinc-700 mb-1">
                                            Presupuesto Diario (COP)
                                        </label>
                                        <input
                                            type="number"
                                            min={1000}
                                            step={1000}
                                            value={formDailyBudget}
                                            onChange={(e) => setFormDailyBudget(Number(e.target.value))}
                                            className="input-clean w-full text-xs font-mono font-bold text-[#0094FF]"
                                        />
                                    </div>
                                    <div>
                                        <label className="block text-xs font-bold text-zinc-700 mb-1">
                                            Duración (Días)
                                        </label>
                                        <input
                                            type="number"
                                            min={1}
                                            max={90}
                                            value={formDurationDays}
                                            onChange={(e) => setFormDurationDays(Number(e.target.value))}
                                            className="input-clean w-full text-xs font-mono"
                                        />
                                    </div>
                                </div>

                                <div>
                                    <label className="block text-xs font-bold text-zinc-700 mb-1">
                                        Audiencia Objetivo
                                    </label>
                                    <div className="grid grid-cols-3 gap-2">
                                        {['Todos', 'Hombres', 'Mujeres'].map(g => (
                                            <button
                                                type="button"
                                                key={g}
                                                onClick={() => setFormGender(g)}
                                                className={`py-1.5 text-xs font-bold rounded-lg border transition-colors ${
                                                    formGender === g
                                                        ? 'bg-[#0094FF] text-white border-[#0094FF]'
                                                        : 'bg-white border-zinc-300 text-zinc-700 hover:bg-zinc-50'
                                                }`}
                                            >
                                                {g}
                                            </button>
                                        ))}
                                    </div>
                                </div>

                                <div className="pt-3 border-t border-zinc-200 flex items-center justify-end gap-2">
                                    <button
                                        type="button"
                                        onClick={() => setIsCreateModalOpen(false)}
                                        className="btn-secondary text-xs py-2 px-3 font-bold"
                                    >
                                        Cancelar
                                    </button>
                                    <button
                                        type="submit"
                                        disabled={isSubmitting || !formPostId.trim()}
                                        className="btn-primary text-xs py-2 px-4 font-bold flex items-center gap-1.5"
                                    >
                                        <Zap size={14} />
                                        <span>{isSubmitting ? 'Activando...' : 'Guardar y Activar Impulso'}</span>
                                    </button>
                                </div>
                            </form>

                            {/* Columna Derecha: PREVISUALIZADOR EN VIVO (Live Preview) */}
                            <div className="lg:col-span-5 bg-zinc-50 border border-zinc-200 rounded-2xl p-4 flex flex-col items-center justify-between space-y-4">
                                <div className="w-full text-center border-b border-zinc-200 pb-2">
                                    <span className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider flex items-center justify-center gap-1">
                                        <Eye size={12} className="text-[#0094FF]" /> Previsualización en Vivo (Feed Móvil)
                                    </span>
                                </div>

                                {/* Mockup de Tarjeta de Publicación Impulsada en el Feed */}
                                <div className="w-full max-w-[260px] bg-white rounded-2xl shadow-lg border border-zinc-200 overflow-hidden relative">
                                    {/* Badge Superior Impulsado */}
                                    <div className="absolute top-2.5 left-2.5 z-10 bg-[#0094FF] text-white px-2 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider flex items-center gap-1 shadow-md">
                                        <Zap size={10} className="fill-white" />
                                        <span>Impulsado</span>
                                    </div>

                                    {/* Imagen de la publicación */}
                                    <div className="w-full h-44 bg-zinc-200 relative overflow-hidden">
                                        {formPostImage ? (
                                            <img src={formPostImage} alt="Preview" className="w-full h-full object-cover" />
                                        ) : (
                                            <div className="w-full h-full flex flex-col items-center justify-center text-zinc-400 p-4 text-center">
                                                <ShoppingBag size={32} className="mb-1 opacity-40" />
                                                <span className="text-[10px]">Selecciona una publicación para ver la foto</span>
                                            </div>
                                        )}
                                    </div>

                                    {/* Contenido de la Tarjeta */}
                                    <div className="p-3 space-y-1">
                                        <p className="font-bold text-zinc-900 text-xs truncate">
                                            {formPostTitle || 'Título de la Publicación'}
                                        </p>
                                        <p className="font-mono font-black text-zinc-900 text-sm">
                                            ${Number(formPostPrice || 0).toLocaleString('es-CO')} <span className="text-[10px] font-normal text-zinc-400">COP</span>
                                        </p>
                                        <div className="flex items-center gap-1 text-[11px] text-zinc-500 pt-1">
                                            <MapPin size={11} className="text-zinc-400" />
                                            <span className="truncate">{formPostLocation || 'Colombia'}</span>
                                        </div>
                                    </div>
                                </div>

                                {/* Caja de Métricas Estimadas */}
                                <div className="w-full bg-blue-50/70 border border-blue-200 rounded-xl p-3 space-y-1.5 text-xs">
                                    <div className="flex justify-between items-center text-zinc-700">
                                        <span className="font-medium">Presupuesto Total:</span>
                                        <span className="font-mono font-black text-[#0094FF] text-sm">
                                            ${currentTotalBudget.toLocaleString('es-CO')} COP
                                        </span>
                                    </div>
                                    <div className="flex justify-between items-center text-zinc-700">
                                        <span className="font-medium">Alcance Estimado:</span>
                                        <span className="font-bold text-zinc-900">
                                            {minReach.toLocaleString('es-CO')} - {maxReach.toLocaleString('es-CO')} personas
                                        </span>
                                    </div>
                                    <p className="text-[10px] text-zinc-500 pt-1 border-t border-blue-200">
                                        La publicación aparecerá entre las primeras posiciones del feed según la segmentación ({formGender}).
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* MODAL PREVISUALIZAR IMPULSO EXISTENTE */}
            {previewItem && (
                <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 animate-in fade-in">
                    <div className="bg-white rounded-2xl max-w-sm w-full p-5 shadow-2xl border border-zinc-200 space-y-4">
                        <div className="flex items-center justify-between border-b border-zinc-200 pb-2">
                            <div className="flex items-center gap-2">
                                <Zap size={18} className="text-[#0094FF]" />
                                <h3 className="font-black text-zinc-900 text-sm">Vista Previa del Impulso</h3>
                            </div>
                            <button onClick={() => setPreviewItem(null)} className="text-zinc-400 hover:text-zinc-600">
                                <X size={18} />
                            </button>
                        </div>

                        {/* Tarjeta Feed */}
                        <div className="bg-white rounded-2xl shadow-lg border border-zinc-200 overflow-hidden relative">
                            <div className="absolute top-2.5 left-2.5 z-10 bg-[#0094FF] text-white px-2 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider flex items-center gap-1 shadow-md">
                                <Zap size={10} className="fill-white" />
                                <span>Impulsado</span>
                            </div>

                            <div className="w-full h-48 bg-zinc-200 overflow-hidden">
                                {previewItem.imageUrl ? (
                                    <img src={previewItem.imageUrl} alt="" className="w-full h-full object-cover" />
                                ) : (
                                    <div className="w-full h-full flex items-center justify-center text-zinc-400">
                                        <ShoppingBag size={36} />
                                    </div>
                                )}
                            </div>

                            <div className="p-3 space-y-1">
                                <p className="font-bold text-zinc-900 text-sm">{previewItem.postTitle}</p>
                                <p className="font-mono font-black text-zinc-900 text-base">
                                    ${Number(previewItem.price || 0).toLocaleString('es-CO')} COP
                                </p>
                                <div className="flex items-center justify-between text-xs text-zinc-500 pt-1">
                                    <span className="flex items-center gap-1">
                                        <MapPin size={12} /> {previewItem.location || 'Colombia'}
                                    </span>
                                    <span>{previewItem.sellerName}</span>
                                </div>
                            </div>
                        </div>

                        {/* Fila de datos */}
                        <div className="bg-zinc-50 p-3 rounded-xl border border-zinc-200 text-xs space-y-1">
                            <div className="flex justify-between">
                                <span className="text-zinc-500">Inversión:</span>
                                <span className="font-bold text-zinc-800">${previewItem.totalBudget.toLocaleString('es-CO')} COP</span>
                            </div>
                            <div className="flex justify-between">
                                <span className="text-zinc-500">Duración:</span>
                                <span className="font-bold text-zinc-800">{previewItem.durationDays} días</span>
                            </div>
                            <div className="flex justify-between">
                                <span className="text-zinc-500">Estado:</span>
                                <span className={`font-bold ${previewItem.status === 'active' ? 'text-emerald-600' : 'text-amber-600'}`}>
                                    {previewItem.status === 'active' ? 'Activo en Feed' : 'Pausado'}
                                </span>
                            </div>
                        </div>

                        <button
                            onClick={() => setPreviewItem(null)}
                            className="btn-primary w-full py-2 text-xs font-bold"
                        >
                            Cerrar Vista Previa
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
};
