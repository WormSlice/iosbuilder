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
    Eye,
    Globe,
    Layers,
    Sparkles,
    Upload,
    Loader2
} from 'lucide-react';
import { db, storage } from '../services/firebase';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
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
    const [previewAd, setPreviewAd] = useState<AdCampaign | null>(null);

    // Formulario de nuevo Anuncio
    const [formTitle, setFormTitle] = useState('');
    const [formClient, setFormClient] = useState('');
    const [formImageUrl, setFormImageUrl] = useState('');
    const [formLinkUrl, setFormLinkUrl] = useState('');
    const [formPlacement, setFormPlacement] = useState<AdCampaign['placement']>('home_top');
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [isUploadingImage, setIsUploadingImage] = useState(false);

    const handleImageFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        if (!file.type.startsWith('image/')) {
            toast.error('Por favor selecciona un archivo de imagen válido');
            return;
        }

        if (file.size > 8 * 1024 * 1024) {
            toast.error('La imagen no debe superar los 8MB');
            return;
        }

        setIsUploadingImage(true);
        const toastId = toast.loading('Subiendo imagen a Firebase Storage...');
        try {
            const fileExt = file.name.split('.').pop() || 'jpg';
            const storageRef = ref(storage, `ads/${Date.now()}_${Math.random().toString(36).substring(7)}.${fileExt}`);
            const snapshot = await uploadBytes(storageRef, file);
            const downloadUrl = await getDownloadURL(snapshot.ref);
            setFormImageUrl(downloadUrl);
            toast.success('¡Imagen subida exitosamente!', { id: toastId });
        } catch (err: any) {
            console.error('Error uploading ad image:', err);
            toast.error(`Error al subir imagen: ${err.message || 'Error desconocido'}`, { id: toastId });
        } finally {
            setIsUploadingImage(false);
        }
    };

    const fetchAds = async () => {
        setLoading(true);
        try {
            const adsSnap = await getDocs(query(collection(db, 'ads'), limit(100)));
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
                updatedAt: new Date()
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
            toast.error('Completa el título y la URL de la imagen del banner');
            return;
        }

        setIsSubmitting(true);
        try {
            const adId = `ad_${Date.now()}`;
            const newAd = {
                id: adId,
                title: formTitle.trim(),
                client: formClient.trim() || 'Directo',
                imageUrl: formImageUrl.trim(),
                linkUrl: formLinkUrl.trim(),
                placement: formPlacement,
                status: 'active',
                clicks: 0,
                impressions: 0,
                createdAt: new Date()
            };

            await setDoc(doc(db, 'ads', adId), newAd);
            toast.success('¡Campaña publicitaria registrada y activada!');
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
            a.client.toLowerCase().includes(searchTerm.toLowerCase()) ||
            a.id.toLowerCase().includes(searchTerm.toLowerCase());
        const matchesStatus = statusFilter === 'all' ? true : a.status === statusFilter;
        return matchesSearch && matchesStatus;
    });

    const totalActive = ads.filter(a => a.status === 'active').length;
    const totalClicks = ads.reduce((acc, a) => acc + (a.clicks || 0), 0);

    return (
        <div className="space-y-5 animate-in fade-in duration-300">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-zinc-200 pb-4">
                <div>
                    <h1 className="text-xl font-black text-zinc-900 tracking-tight flex items-center gap-2">
                        <Megaphone size={22} className="text-[#0094FF]" />
                        Campañas Publicitarias (Ads)
                    </h1>
                    <p className="text-xs text-zinc-500 mt-0.5">
                        Administración de banners, anuncios de patrocinadores y previsualización interactiva
                    </p>
                </div>

                <div className="flex items-center gap-2">
                    <button
                        onClick={fetchAds}
                        disabled={loading}
                        className="btn-secondary flex items-center gap-1.5 text-xs py-2"
                        title="Actualizar datos"
                    >
                        <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
                        <span>Actualizar</span>
                    </button>
                    <button
                        onClick={() => setIsCreateModalOpen(true)}
                        className="btn-primary flex items-center gap-1.5 text-xs py-2 font-bold"
                    >
                        <Plus size={14} />
                        <span>Crear y Previsualizar Anuncio</span>
                    </button>
                </div>
            </div>

            {/* Metrics bar */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="bg-white border border-zinc-200 rounded-xl p-3.5 flex items-center justify-between shadow-sm">
                    <div>
                        <p className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Total Campañas</p>
                        <p className="text-xl font-black text-zinc-900 mt-0.5">{ads.length}</p>
                    </div>
                    <div className="w-9 h-9 rounded-xl bg-zinc-100 flex items-center justify-center text-zinc-700">
                        <Megaphone size={18} />
                    </div>
                </div>

                <div className="bg-white border border-zinc-200 rounded-xl p-3.5 flex items-center justify-between shadow-sm">
                    <div>
                        <p className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Campañas Activas</p>
                        <p className="text-xl font-black text-[#0094FF] mt-0.5">{totalActive}</p>
                    </div>
                    <div className="w-9 h-9 rounded-xl bg-blue-50 flex items-center justify-center text-[#0094FF]">
                        <CheckCircle2 size={18} />
                    </div>
                </div>

                <div className="bg-white border border-zinc-200 rounded-xl p-3.5 flex items-center justify-between shadow-sm">
                    <div>
                        <p className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider">Clics Totales</p>
                        <p className="text-xl font-black text-zinc-900 mt-0.5">{totalClicks.toLocaleString('es-CO')}</p>
                    </div>
                    <div className="w-9 h-9 rounded-xl bg-purple-50 flex items-center justify-center text-purple-600">
                        <MousePointer2 size={18} />
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
                        placeholder="Buscar por título, anunciante o ID..."
                        className="input-clean pl-8 py-1.5 text-xs w-full"
                    />
                </div>

                <div className="flex items-center gap-1.5 self-start sm:self-auto">
                    <span className="text-xs text-zinc-500 mr-1 font-medium">Estado:</span>
                    {(['all', 'active', 'paused'] as const).map(st => (
                        <button
                            key={st}
                            onClick={() => setStatusFilter(st)}
                            className={`px-3 py-1 text-xs font-bold rounded-lg transition-colors ${
                                statusFilter === st
                                    ? 'bg-[#0094FF] text-white'
                                    : 'bg-zinc-100 text-zinc-600 hover:bg-zinc-200'
                            }`}
                        >
                            {st === 'all' ? 'Todos' : st === 'active' ? 'Activos' : 'Pausados'}
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
                                <th>Campaña & Banner</th>
                                <th>Anunciante</th>
                                <th>Ubicación</th>
                                <th>Enlace Destino</th>
                                <th>Clics</th>
                                <th>Estado</th>
                                <th className="text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-10 text-zinc-400 text-xs">
                                        Cargando campañas publicitarias...
                                    </td>
                                </tr>
                            ) : filtered.length === 0 ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-12">
                                        <div className="flex flex-col items-center justify-center text-zinc-400">
                                            <Megaphone size={36} className="text-zinc-300 mb-2 stroke-1" />
                                            <p className="text-xs font-bold text-zinc-600">No hay campañas registradas</p>
                                            <p className="text-[11px] text-zinc-400 mt-0.5">
                                                Crea una nueva campaña publicitaria para monetizar la aplicación.
                                            </p>
                                            <button
                                                onClick={() => setIsCreateModalOpen(true)}
                                                className="btn-primary mt-3 text-xs font-bold"
                                            >
                                                Crear Primer Anuncio
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ) : (
                                filtered.map(ad => (
                                    <tr key={ad.id} className="hover:bg-zinc-50/80 transition-colors">
                                        <td>
                                            <div className="flex items-center gap-2.5">
                                                {ad.imageUrl ? (
                                                    <img src={ad.imageUrl} alt="" className="w-12 h-8 rounded-md object-cover border border-zinc-200 flex-shrink-0" />
                                                ) : (
                                                    <div className="w-12 h-8 rounded-md bg-zinc-100 flex items-center justify-center text-zinc-400 flex-shrink-0 border border-zinc-200">
                                                        <ImageIcon size={14} />
                                                    </div>
                                                )}
                                                <div>
                                                    <div className="font-bold text-zinc-900 text-xs">{ad.title}</div>
                                                    <div className="text-[10px] text-zinc-400 font-mono">ID: {ad.id}</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td className="text-xs font-semibold text-zinc-800">
                                            {ad.client}
                                        </td>
                                        <td>
                                            <span className="text-xs px-2.5 py-0.5 bg-zinc-100 text-zinc-700 rounded-md font-semibold border border-zinc-200">
                                                {placementLabels[ad.placement] || ad.placement}
                                            </span>
                                        </td>
                                        <td>
                                            {ad.linkUrl ? (
                                                <a
                                                    href={ad.linkUrl}
                                                    target="_blank"
                                                    rel="noreferrer"
                                                    className="inline-flex items-center gap-1 text-xs text-[#0094FF] hover:underline font-mono truncate max-w-[140px]"
                                                >
                                                    <span className="truncate">{ad.linkUrl.replace(/^https?:\/\//, '')}</span>
                                                    <ExternalLink size={11} className="shrink-0" />
                                                </a>
                                            ) : (
                                                <span className="text-xs text-zinc-400">Sin enlace</span>
                                            )}
                                        </td>
                                        <td className="font-mono text-xs font-bold text-zinc-900">
                                            {ad.clicks.toLocaleString('es-CO')}
                                        </td>
                                        <td>
                                            <span className={`inline-flex items-center gap-1.5 text-[11px] font-bold px-2.5 py-0.5 rounded-full ${
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
                                                {/* BOTÓN PREVISUALIZAR ANUNCIO */}
                                                <button
                                                    onClick={() => setPreviewAd(ad)}
                                                    className="btn-outline text-xs py-1 px-2.5 flex items-center gap-1 font-bold text-[#0094FF] border-blue-200 hover:bg-blue-50"
                                                    title="Previsualizar cómo se ve en la app"
                                                >
                                                    <Eye size={12} />
                                                    <span>Previsualizar</span>
                                                </button>
                                                <button
                                                    onClick={() => handleToggleStatus(ad)}
                                                    className="btn-outline text-xs py-1 px-2 flex items-center gap-1"
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
                                                    className="btn-danger text-xs py-1 px-2 flex items-center gap-1"
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

            {/* MODAL CREAR Y PREVISUALIZAR ANUNCIO */}
            {isCreateModalOpen && (
                <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-3 sm:p-6 animate-in fade-in">
                    <div className="bg-white rounded-2xl max-w-4xl w-full max-h-[92vh] flex flex-col shadow-2xl overflow-hidden border border-zinc-200">
                        {/* Cabecera */}
                        <div className="p-4 sm:p-5 border-b border-zinc-200 bg-zinc-50 flex items-center justify-between flex-shrink-0">
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 rounded-xl bg-blue-100 text-[#0094FF] flex items-center justify-center font-bold">
                                    <Megaphone size={22} />
                                </div>
                                <div>
                                    <h2 className="text-base font-black text-zinc-900">
                                        Crear y Previsualizar Campaña Publicitaria
                                    </h2>
                                    <p className="text-xs text-zinc-500 mt-0.5">
                                        Configura el banner, destino de clics y observa la previsualización interactiva
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

                        {/* Cuerpo 2 Columnas */}
                        <div className="flex-1 overflow-y-auto p-4 sm:p-6 grid grid-cols-1 lg:grid-cols-12 gap-6">
                            {/* Formulario */}
                            <form onSubmit={handleCreateAd} className="lg:col-span-7 space-y-4">
                                <div>
                                    <label className="block text-xs font-bold text-zinc-700 mb-1">
                                        Título de la Campaña <span className="text-red-500">*</span>
                                    </label>
                                    <input
                                        type="text"
                                        required
                                        value={formTitle}
                                        onChange={(e) => setFormTitle(e.target.value)}
                                        placeholder="Ej: Descuentos de Temporada 2026"
                                        className="input-clean w-full text-xs"
                                    />
                                </div>

                                <div className="grid grid-cols-2 gap-3">
                                    <div>
                                        <label className="block text-xs font-bold text-zinc-700 mb-1">
                                            Cliente / Patrocinador
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
                                        <label className="block text-xs font-bold text-zinc-700 mb-1">
                                            Ubicación en la App
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
                                </div>

                                <div>
                                    <div className="flex items-center justify-between mb-1">
                                        <label className="block text-xs font-bold text-zinc-700">
                                            Imagen del Banner <span className="text-red-500">*</span>
                                        </label>
                                        <label className="cursor-pointer text-[11px] font-bold text-[#0094FF] hover:underline flex items-center gap-1">
                                            <Upload size={12} />
                                            <span>{isUploadingImage ? 'Subiendo...' : 'Subir imagen local'}</span>
                                            <input
                                                type="file"
                                                accept="image/*"
                                                className="hidden"
                                                disabled={isUploadingImage}
                                                onChange={handleImageFileChange}
                                            />
                                        </label>
                                    </div>
                                    <div className="relative">
                                        <input
                                            type="url"
                                            required
                                            value={formImageUrl}
                                            onChange={(e) => setFormImageUrl(e.target.value)}
                                            placeholder="Pega un enlace https://... o sube una imagen"
                                            className="input-clean w-full text-xs font-mono pr-8"
                                        />
                                        {isUploadingImage && (
                                            <div className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[#0094FF] animate-spin">
                                                <Loader2 size={14} />
                                            </div>
                                        )}
                                    </div>
                                    <p className="text-[10px] text-zinc-400 mt-1">
                                        Recomendado: 1200x600px o formato panorámico. Se sube a Firebase Storage.
                                    </p>
                                </div>

                                <div>
                                    <label className="block text-xs font-bold text-zinc-700 mb-1">
                                        Enlace de Destino (Web o WhatsApp)
                                    </label>
                                    <input
                                        type="url"
                                        value={formLinkUrl}
                                        onChange={(e) => setFormLinkUrl(e.target.value)}
                                        placeholder="https://tienda-cliente.com/promocion"
                                        className="input-clean w-full text-xs font-mono"
                                    />
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
                                        disabled={isSubmitting}
                                        className="btn-primary text-xs py-2 px-4 font-bold flex items-center gap-1.5"
                                    >
                                        <Plus size={14} />
                                        <span>{isSubmitting ? 'Guardando...' : 'Activar Campaña'}</span>
                                    </button>
                                </div>
                            </form>

                            {/* Previsualizador en Vivo */}
                            <div className="lg:col-span-5 bg-zinc-50 border border-zinc-200 rounded-2xl p-4 flex flex-col items-center justify-between space-y-4">
                                <div className="w-full text-center border-b border-zinc-200 pb-2">
                                    <span className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider flex items-center justify-center gap-1">
                                        <Eye size={12} className="text-[#0094FF]" /> Previsualización en Vivo ({placementLabels[formPlacement]})
                                    </span>
                                </div>

                                {/* Mockup Banner según ubicación */}
                                <div className="w-full max-w-[280px] bg-white rounded-2xl shadow-lg border border-zinc-200 overflow-hidden relative">
                                    <div className="absolute top-2.5 left-2.5 z-10 bg-black/70 backdrop-blur-md text-white px-2 py-0.5 rounded-full text-[9px] font-bold uppercase tracking-wider flex items-center gap-1">
                                        <Sparkles size={10} className="text-[#0094FF]" />
                                        <span>Publicidad • {formClient || 'Patrocinador'}</span>
                                    </div>

                                    <div className={`w-full bg-zinc-200 overflow-hidden ${formPlacement === 'home_top' ? 'h-32' : formPlacement === 'feed_interstitial' ? 'h-48' : 'h-36'}`}>
                                        {formImageUrl ? (
                                            <img src={formImageUrl} alt="Banner" className="w-full h-full object-cover" />
                                        ) : (
                                            <div className="w-full h-full flex flex-col items-center justify-center text-zinc-400 p-4 text-center">
                                                <ImageIcon size={32} className="mb-1 opacity-40" />
                                                <span className="text-[10px]">Ingresa una URL de imagen para previsualizar el banner</span>
                                            </div>
                                        )}
                                    </div>

                                    <div className="p-3 flex items-center justify-between gap-2">
                                        <div className="overflow-hidden">
                                            <p className="font-bold text-zinc-900 text-xs truncate">
                                                {formTitle || 'Título del anuncio'}
                                            </p>
                                            <p className="text-[10px] text-zinc-500 font-mono truncate">
                                                {formLinkUrl ? formLinkUrl.replace(/^https?:\/\//, '') : 'Toca para más información'}
                                            </p>
                                        </div>
                                        <div className="px-2.5 py-1 bg-[#0094FF] text-white text-[10px] font-bold rounded-lg flex-shrink-0 flex items-center gap-1">
                                            <span>Abrir</span>
                                            <ExternalLink size={10} />
                                        </div>
                                    </div>
                                </div>

                                <div className="w-full bg-zinc-100 p-3 rounded-xl text-xs text-zinc-600 space-y-1">
                                    <p className="font-bold text-zinc-800">Ubicación elegida: {placementLabels[formPlacement]}</p>
                                    <p className="text-[11px] text-zinc-500">
                                        Los clics generados dentro de la aplicación móvil serán contabilizados en tiempo real y redirigirán al enlace de destino.
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* MODAL PREVISUALIZAR ANUNCIO EXISTENTE */}
            {previewAd && (
                <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 animate-in fade-in">
                    <div className="bg-white rounded-2xl max-w-sm w-full p-5 shadow-2xl border border-zinc-200 space-y-4">
                        <div className="flex items-center justify-between border-b border-zinc-200 pb-2">
                            <div className="flex items-center gap-2">
                                <Megaphone size={18} className="text-[#0094FF]" />
                                <h3 className="font-black text-zinc-900 text-sm">Vista Previa de Publicidad</h3>
                            </div>
                            <button onClick={() => setPreviewAd(null)} className="text-zinc-400 hover:text-zinc-600">
                                <X size={18} />
                            </button>
                        </div>

                        {/* Tarjeta Banner */}
                        <div className="bg-white rounded-2xl shadow-lg border border-zinc-200 overflow-hidden relative">
                            <div className="absolute top-2.5 left-2.5 z-10 bg-black/70 backdrop-blur-md text-white px-2 py-0.5 rounded-full text-[9px] font-bold uppercase tracking-wider flex items-center gap-1">
                                <Sparkles size={10} className="text-[#0094FF]" />
                                <span>Publicidad • {previewAd.client}</span>
                            </div>

                            <div className="w-full h-44 bg-zinc-200 overflow-hidden">
                                {previewAd.imageUrl ? (
                                    <img src={previewAd.imageUrl} alt="" className="w-full h-full object-cover" />
                                ) : (
                                    <div className="w-full h-full flex items-center justify-center text-zinc-400">
                                        <ImageIcon size={36} />
                                    </div>
                                )}
                            </div>

                            <div className="p-3 flex items-center justify-between gap-2">
                                <div className="overflow-hidden">
                                    <p className="font-bold text-zinc-900 text-xs truncate">{previewAd.title}</p>
                                    <p className="text-[10px] text-zinc-500 font-mono truncate">{previewAd.linkUrl || 'Sin enlace'}</p>
                                </div>
                                {previewAd.linkUrl && (
                                    <a
                                        href={previewAd.linkUrl}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="px-2.5 py-1 bg-[#0094FF] text-white text-[10px] font-bold rounded-lg flex items-center gap-1"
                                    >
                                        <span>Visitar</span>
                                        <ExternalLink size={10} />
                                    </a>
                                )}
                            </div>
                        </div>

                        <div className="bg-zinc-50 p-3 rounded-xl border border-zinc-200 text-xs space-y-1">
                            <div className="flex justify-between">
                                <span className="text-zinc-500">Ubicación:</span>
                                <span className="font-bold text-zinc-800">{placementLabels[previewAd.placement]}</span>
                            </div>
                            <div className="flex justify-between">
                                <span className="text-zinc-500">Clics registrados:</span>
                                <span className="font-bold text-zinc-800">{previewAd.clicks.toLocaleString('es-CO')}</span>
                            </div>
                            <div className="flex justify-between">
                                <span className="text-zinc-500">Estado:</span>
                                <span className={`font-bold ${previewAd.status === 'active' ? 'text-emerald-600' : 'text-amber-600'}`}>
                                    {previewAd.status === 'active' ? 'Activo en la App' : 'Pausado'}
                                </span>
                            </div>
                        </div>

                        <button
                            onClick={() => setPreviewAd(null)}
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
