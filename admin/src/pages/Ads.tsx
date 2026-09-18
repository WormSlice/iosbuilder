import React, { useState, useEffect } from 'react';
import {
    Megaphone,
    Plus,
    Search,
    RefreshCw,
    Play,
    Pause,
    Trash2,
    ExternalLink,
    Image as ImageIcon,
    CheckCircle2,
    XCircle,
    X,
    MousePointer2,
    Eye
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
    limit
} from 'firebase/firestore';
import toast from 'react-hot-toast';

interface AdCampaign {
    id: string;
    title: string;
    client: string;
    imageUrl: string;
    linkUrl: string;
    placement: 'home_top' | 'feed_interstitial' | 'explore_banner' | 'search_top';
    status: 'active' | 'paused';
    clicks: number;
    impressions: number;
    createdAt?: any;
}

export const Ads: React.FC = () => {
    const [ads, setAds] = useState<AdCampaign[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'paused'>('all');
    const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);

    // Formulario de nuevo Anuncio
    const [formTitle, setFormTitle] = useState('');
    const [formClient, setFormClient] = useState('');
    const [formImageUrl, setFormImageUrl] = useState('');
    const [formLinkUrl, setFormLinkUrl] = useState('');
    const [formPlacement, setFormPlacement] = useState<AdCampaign['placement']>('home_top');
    const [isSubmitting, setIsSubmitting] = useState(false);

    const fetchAds = async () => {
        setLoading(true);
        try {
            const adsSnap = await getDocs(query(collection(db, 'ads'), limit(50)));
            const items: AdCampaign[] = [];
            adsSnap.forEach(d => {
                const data = d.data();
                items.push({
                    id: d.id,
                    title: data.title || 'Campaña publicitaria',
                    client: data.client || data.sponsor || 'Anunciante',
                    imageUrl: data.imageUrl || data.image || '',
                    linkUrl: data.linkUrl || data.targetUrl || data.link || '',
                    placement: data.placement || 'home_top',
                    status: data.status === 'paused' ? 'paused' : 'active',
                    clicks: Number(data.clicks || 0),
                    impressions: Number(data.impressions || 0),
                    createdAt: data.createdAt
                });
            });
            setAds(items);
        } catch (error) {
            console.error('Error fetching ads:', error);
            toast.error('Error al cargar las campañas publicitarias');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchAds();
    }, []);

    const handleToggleStatus = async (ad: AdCampaign) => {
        const newStatus = ad.status === 'active' ? 'paused' : 'active';
        try {
            await updateDoc(doc(db, 'ads', ad.id), {
                status: newStatus,
                updatedAt: serverTimestamp()
            });
            setAds(prev => prev.map(a => a.id === ad.id ? { ...a, status: newStatus } : a));
            toast.success(`Campaña ${newStatus === 'active' ? 'activada' : 'pausada'}`);
        } catch (e) {
            toast.error('Error al actualizar estado del anuncio');
        }
    };

    const handleDelete = async (id: string) => {
        if (!window.confirm('¿Deseas eliminar permanentemente esta campaña publicitaria?')) return;
        try {
            await deleteDoc(doc(db, 'ads', id));
            setAds(prev => prev.filter(a => a.id !== id));
            toast.success('Campaña eliminada');
        } catch (e) {
            toast.error('Error al eliminar');
        }
    };

    const handleCreateAd = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!formTitle.trim() || !formImageUrl.trim()) {
            toast.error('Completa el título y la URL de imagen del banner');
            return;
        }

        setIsSubmitting(true);
        try {
            const adId = `ad_${Date.now()}`;
            const newAd = {
                title: formTitle.trim(),
                client: formClient.trim() || 'Directo',
                imageUrl: formImageUrl.trim(),
                linkUrl: formLinkUrl.trim(),
                placement: formPlacement,
                status: 'active',
                clicks: 0,
                impressions: 0,
                createdAt: serverTimestamp()
            };

            await setDoc(doc(db, 'ads', adId), newAd);
            toast.success('¡Campaña publicitaria registrada!');
            setIsCreateModalOpen(false);
            setFormTitle('');
            setFormClient('');
            setFormImageUrl('');
            setFormLinkUrl('');
            fetchAds();
        } catch (e: any) {
            toast.error(`Error al guardar campaña: ${e.message}`);
        } finally {
            setIsSubmitting(false);
        }
    };

    const placementLabels: Record<AdCampaign['placement'], string> = {
        home_top: 'Home Banner Superior',
        feed_interstitial: 'Feed Intersticial',
        explore_banner: 'Explorar Banner',
        search_top: 'Búsqueda Patrocinada'
    };

    const filtered = ads.filter(a => {
        const matchesSearch = a.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
            a.client.toLowerCase().includes(searchTerm.toLowerCase());
        const matchesStatus = statusFilter === 'all' ? true : a.status === statusFilter;
        return matchesSearch && matchesStatus;
    });

    const totalActive = ads.filter(a => a.status === 'active').length;
    const totalClicks = ads.reduce((acc, a) => acc + a.clicks, 0);

    return (
        <div className="space-y-5">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-200 pb-4">
                <div>
                    <h1 className="text-xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
                        <Megaphone size={20} className="text-[#0094FF]" />
                        Publicidad & Campañas (Ads)
                    </h1>
                    <p className="text-xs text-slate-500 mt-0.5">
                        Administración de banners, ubicaciones patrocinadas y métricas de clic reales
                    </p>
                </div>

                <div className="flex items-center gap-2">
                    <button
                        onClick={fetchAds}
                        disabled={loading}
                        className="btn-secondary flex items-center gap-1.5"
                        title="Actualizar datos"
                    >
                        <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
                        <span>Actualizar</span>
                    </button>
                    <button
                        onClick={() => setIsCreateModalOpen(true)}
                        className="btn-primary flex items-center gap-1.5"
                    >
                        <Plus size={14} />
                        <span>Nuevo Anuncio</span>
                    </button>
                </div>
            </div>

            {/* Metrics bar (100% real Firestore data, NO fake statistics) */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="bg-white border border-slate-200 rounded-lg p-3.5 flex items-center justify-between">
                    <div>
                        <p className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">Total Campañas</p>
                        <p className="text-xl font-bold text-slate-900 mt-0.5">{ads.length}</p>
                    </div>
                    <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-slate-600">
                        <Megaphone size={16} />
                    </div>
                </div>

                <div className="bg-white border border-slate-200 rounded-lg p-3.5 flex items-center justify-between">
                    <div>
                        <p className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">Campañas Activas</p>
                        <p className="text-xl font-bold text-[#0094FF] mt-0.5">{totalActive}</p>
                    </div>
                    <div className="w-8 h-8 rounded-lg bg-blue-50 flex items-center justify-center text-[#0094FF]">
                        <CheckCircle2 size={16} />
                    </div>
                </div>

                <div className="bg-white border border-slate-200 rounded-lg p-3.5 flex items-center justify-between">
                    <div>
                        <p className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">Clics Registrados</p>
                        <p className="text-xl font-bold text-slate-900 mt-0.5">
                            {totalClicks.toLocaleString('es-CO')}
                        </p>
                    </div>
                    <div className="w-8 h-8 rounded-lg bg-emerald-50 flex items-center justify-center text-emerald-600">
                        <MousePointer2 size={16} />
                    </div>
                </div>
            </div>

            {/* Filters Bar */}
            <div className="flex flex-col sm:flex-row items-center justify-between gap-3 bg-white border border-slate-200 rounded-lg p-3">
                <div className="relative w-full sm:w-80">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
                    <input
                        type="text"
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        placeholder="Buscar por título o cliente..."
                        className="input-clean pl-8 py-1.5 text-xs w-full"
                    />
                </div>

                <div className="flex items-center gap-1.5 self-start sm:self-auto">
                    <span className="text-xs text-slate-500 mr-1 font-medium">Estado:</span>
                    {(['all', 'active', 'paused'] as const).map(st => (
                        <button
                            key={st}
                            onClick={() => setStatusFilter(st)}
                            className={`px-2.5 py-1 text-xs font-semibold rounded-md transition-colors ${
                                statusFilter === st
                                    ? 'bg-[#0094FF] text-white'
                                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                            }`}
                        >
                            {st === 'all' ? 'Todos' : st === 'active' ? 'Activos' : 'Pausados'}
                        </button>
                    ))}
                </div>
            </div>

            {/* Table */}
            <div className="bg-white border border-slate-200 rounded-lg overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table-clean">
                        <thead>
                            <tr>
                                <th>Banner</th>
                                <th>Título & Cliente</th>
                                <th>Ubicación</th>
                                <th>Enlace Destino</th>
                                <th>Clics Reales</th>
                                <th>Estado</th>
                                <th className="text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-10 text-slate-400 text-xs">
                                        Cargando campañas publicitarias...
                                    </td>
                                </tr>
                            ) : filtered.length === 0 ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-12">
                                        <div className="flex flex-col items-center justify-center text-slate-400">
                                            <Megaphone size={32} className="text-slate-300 mb-2 stroke-1" />
                                            <p className="text-xs font-semibold text-slate-600">No hay campañas publicitarias</p>
                                            <p className="text-[11px] text-slate-400 mt-0.5">
                                                Registra un nuevo banner o anuncio para comenzar a mostrar publicidad en la app.
                                            </p>
                                            <button
                                                onClick={() => setIsCreateModalOpen(true)}
                                                className="btn-primary mt-3 text-xs"
                                            >
                                                Crear Primer Anuncio
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ) : (
                                filtered.map(ad => (
                                    <tr key={ad.id}>
                                        <td className="w-20">
                                            {ad.imageUrl ? (
                                                <img
                                                    src={ad.imageUrl}
                                                    alt={ad.title}
                                                    className="w-16 h-10 object-cover rounded-md border border-slate-200"
                                                    onError={(e) => {
                                                        (e.target as any).src = 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=100';
                                                    }}
                                                />
                                            ) : (
                                                <div className="w-16 h-10 bg-slate-100 rounded-md flex items-center justify-center text-slate-400">
                                                    <ImageIcon size={16} />
                                                </div>
                                            )}
                                        </td>
                                        <td>
                                            <div className="font-semibold text-slate-900 text-xs">{ad.title}</div>
                                            <div className="text-[11px] text-slate-400">Cliente: {ad.client}</div>
                                        </td>
                                        <td>
                                            <span className="text-xs px-2 py-0.5 bg-slate-100 text-slate-700 rounded-md font-medium">
                                                {placementLabels[ad.placement] || ad.placement}
                                            </span>
                                        </td>
                                        <td>
                                            {ad.linkUrl ? (
                                                <a
                                                    href={ad.linkUrl}
                                                    target="_blank"
                                                    rel="noopener noreferrer"
                                                    className="text-xs text-[#0094FF] hover:underline flex items-center gap-1 truncate max-w-[180px]"
                                                >
                                                    <span className="truncate">{ad.linkUrl}</span>
                                                    <ExternalLink size={11} className="shrink-0" />
                                                </a>
                                            ) : (
                                                <span className="text-xs text-slate-400">Sin enlace</span>
                                            )}
                                        </td>
                                        <td className="font-mono text-xs font-semibold text-slate-800">
                                            {ad.clicks.toLocaleString('es-CO')}
                                        </td>
                                        <td>
                                            <span className={`inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-full ${
                                                ad.status === 'active'
                                                    ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                                    : 'bg-amber-50 text-amber-700 border border-amber-200'
                                            }`}>
                                                <span className={`w-1.5 h-1.5 rounded-full ${ad.status === 'active' ? 'bg-emerald-500' : 'bg-amber-500'}`} />
                                                {ad.status === 'active' ? 'Activo' : 'Pausado'}
                                            </span>
                                        </td>
                                        <td>
                                            <div className="flex items-center justify-end gap-1.5">
                                                <button
                                                    onClick={() => handleToggleStatus(ad)}
                                                    className="btn-outline text-[11px] py-1 px-2 flex items-center gap-1"
                                                    title={ad.status === 'active' ? 'Pausar campaña' : 'Activar campaña'}
                                                >
                                                    {ad.status === 'active' ? (
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
                                                    onClick={() => handleDelete(ad.id)}
                                                    className="btn-danger text-[11px] py-1 px-2 flex items-center gap-1"
                                                    title="Eliminar campaña"
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

            {/* Modal Crear Anuncio */}
            {isCreateModalOpen && (
                <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
                    <div className="bg-white border border-slate-200 rounded-xl max-w-md w-full p-5 shadow-xl">
                        <div className="flex items-center justify-between border-b border-slate-200 pb-3 mb-4">
                            <h3 className="font-bold text-slate-900 text-sm flex items-center gap-2">
                                <Megaphone size={16} className="text-[#0094FF]" />
                                Registrar Nueva Campaña Publicitaria
                            </h3>
                            <button
                                onClick={() => setIsCreateModalOpen(false)}
                                className="text-slate-400 hover:text-slate-600 p-1"
                            >
                                <X size={16} />
                            </button>
                        </div>

                        <form onSubmit={handleCreateAd} className="space-y-3.5">
                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    Título de la Campaña <span className="text-red-500">*</span>
                                </label>
                                <input
                                    type="text"
                                    required
                                    value={formTitle}
                                    onChange={(e) => setFormTitle(e.target.value)}
                                    placeholder="Ej: Promo Verano 2026"
                                    className="input-clean w-full text-xs"
                                />
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    Cliente / Anunciante
                                </label>
                                <input
                                    type="text"
                                    value={formClient}
                                    onChange={(e) => setFormClient(e.target.value)}
                                    placeholder="Ej: Tienda Nike Oficial"
                                    className="input-clean w-full text-xs"
                                />
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    URL de la Imagen / Banner <span className="text-red-500">*</span>
                                </label>
                                <input
                                    type="url"
                                    required
                                    value={formImageUrl}
                                    onChange={(e) => setFormImageUrl(e.target.value)}
                                    placeholder="https://ejemplo.com/banner.jpg"
                                    className="input-clean w-full text-xs font-mono"
                                />
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    Enlace de Destino (Opcional)
                                </label>
                                <input
                                    type="url"
                                    value={formLinkUrl}
                                    onChange={(e) => setFormLinkUrl(e.target.value)}
                                    placeholder="https://sitio-cliente.com"
                                    className="input-clean w-full text-xs font-mono"
                                />
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    Ubicación del Banner
                                </label>
                                <select
                                    value={formPlacement}
                                    onChange={(e) => setFormPlacement(e.target.value as any)}
                                    className="input-clean w-full text-xs"
                                >
                                    <option value="home_top">Home Banner Superior</option>
                                    <option value="feed_interstitial">Feed Intersticial</option>
                                    <option value="explore_banner">Explorar Banner</option>
                                    <option value="search_top">Búsqueda Patrocinada</option>
                                </select>
                            </div>

                            <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-200">
                                <button
                                    type="button"
                                    onClick={() => setIsCreateModalOpen(false)}
                                    className="btn-secondary text-xs"
                                >
                                    Cancelar
                                </button>
                                <button
                                    type="submit"
                                    disabled={isSubmitting}
                                    className="btn-primary text-xs flex items-center gap-1.5"
                                >
                                    <Plus size={14} />
                                    <span>{isSubmitting ? 'Guardando...' : 'Guardar Campaña'}</span>
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
};
