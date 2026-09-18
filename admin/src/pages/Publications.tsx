import React, { useEffect, useState } from 'react';
import { collection, limit, onSnapshot, doc, deleteDoc, updateDoc, query, orderBy, getDocs } from 'firebase/firestore';
import { db } from '../services/firebase';
import {
    Search,
    RefreshCw,
    Trash2,
    Eye,
    CheckCircle,
    XCircle,
    ShoppingBag,
    X,
    Filter,
    ExternalLink
} from 'lucide-react';
import toast from 'react-hot-toast';

interface Publication {
    id: string;
    title?: string;
    description?: string;
    price?: number;
    category?: string;
    images?: string[];
    imageUrl?: string;
    image?: string;
    status?: 'active' | 'pending' | 'rejected' | 'sold';
    createdAt?: any;
    userName?: string;
    userEmail?: string;
    userId?: string;
}

const CATEGORIES = [
    'Todas',
    'Lo Tienes',
    'Productos',
    'Vehículos',
    'Propiedades',
    'Servicios',
    'Empleos',
    'Mascotas',
    'Trueques',
    'Sugerencias'
];

export const Publications: React.FC = () => {
    const [posts, setPosts] = useState<Publication[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [activeCategory, setActiveCategory] = useState('Todas');
    const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'pending' | 'sold'>('all');
    const [selectedPost, setSelectedPost] = useState<Publication | null>(null);
    const [isSyncingAlgolia, setIsSyncingAlgolia] = useState(false);

    useEffect(() => {
        const q = query(collection(db, 'posts'), limit(150));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const list = snapshot.docs.map(d => ({
                id: d.id,
                ...d.data()
            })) as Publication[];
            setPosts(list);
            setLoading(false);
        }, (err) => {
            console.error('Error al cargar publicaciones:', err);
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    const handleDelete = async (postId: string, title?: string) => {
        if (!window.confirm(`¿Estás seguro de que deseas eliminar permanentemente "${title || 'esta publicación'}"?`)) return;
        try {
            await deleteDoc(doc(db, 'posts', postId));
            toast.success('Publicación eliminada correctamente');
            if (selectedPost?.id === postId) setSelectedPost(null);
        } catch (e: any) {
            toast.error(`Error al eliminar: ${e.message}`);
        }
    };

    const handleToggleStatus = async (post: Publication) => {
        const nextStatus = post.status === 'active' ? 'pending' : 'active';
        try {
            await updateDoc(doc(db, 'posts', post.id), { status: nextStatus });
            toast.success(`Estado cambiado a ${nextStatus === 'active' ? 'Activo' : 'Pausado'}`);
        } catch (e: any) {
            toast.error(`Error: ${e.message}`);
        }
    };

    const syncToAlgolia = async () => {
        if (!window.confirm('¿Re-indexar todas las publicaciones a Algolia Search?')) return;
        setIsSyncingAlgolia(true);
        try {
            const { algoliasearch } = await import('algoliasearch');
            const client = algoliasearch('P2CJMQDDSH', '4aa72340abeb49d79d888cc3271c23b1');

            const sanitizeData = (data: any): any => {
                const clean = { ...data };
                for (const key in clean) {
                    const val = clean[key];
                    if (val && typeof val === 'object' && val.seconds) {
                        clean[key] = val.seconds * 1000;
                    } else if (val && typeof val === 'object' && val.latitude) {
                        clean[key] = { latitude: val.latitude, longitude: val.longitude };
                    } else if (val && typeof val === 'object' && val.path) {
                        clean[key] = val.path;
                    } else if (val && typeof val === 'object') {
                        clean[key] = sanitizeData(val);
                    }
                }
                return clean;
            };

            const postsSnap = await getDocs(collection(db, 'posts'));
            const postsBatch = postsSnap.docs.map(d => {
                let data = d.data();
                data = sanitizeData(data);
                return {
                    action: 'addObject',
                    body: { ...data, objectID: d.id, id: d.id, type: data.type || 'post', status: data.status || 'active' }
                };
            });

            if (postsBatch.length > 0) {
                const batchSize = 50;
                for (let i = 0; i < postsBatch.length; i += batchSize) {
                    const batch = postsBatch.slice(i, i + batchSize);
                    await client.batch({ indexName: 'ALGOLIA', batchWriteParams: { requests: batch as any } });
                }
            }
            toast.success('Índice de Algolia actualizado con éxito');
        } catch (e: any) {
            toast.error(`Error al sincronizar Algolia: ${e.message}`);
        } finally {
            setIsSyncingAlgolia(false);
        }
    };

    const formatDate = (timestamp: any) => {
        if (!timestamp) return 'Reciente';
        try {
            if (timestamp.toDate) return timestamp.toDate().toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' });
            if (timestamp.seconds) return new Date(timestamp.seconds * 1000).toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' });
            return new Date(timestamp).toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' });
        } catch {
            return 'Reciente';
        }
    };

    const filteredPosts = posts.filter(post => {
        const matchesSearch = (
            (post.title?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
            (post.description?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
            (post.category?.toLowerCase() || '').includes(searchTerm.toLowerCase())
        );

        const matchesCat = activeCategory === 'Todas' || post.category?.toLowerCase() === activeCategory.toLowerCase();

        let matchesStatus = true;
        if (statusFilter === 'active') matchesStatus = post.status === 'active';
        if (statusFilter === 'pending') matchesStatus = post.status === 'pending';
        if (statusFilter === 'sold') matchesStatus = post.status === 'sold';

        return matchesSearch && matchesCat && matchesStatus;
    });

    const getImage = (post: Publication) => {
        return post.images?.[0] || post.imageUrl || post.image || '';
    };

    return (
        <div className="space-y-5">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-zinc-200">
                <div>
                    <h1 className="text-xl font-bold text-zinc-900 tracking-tight">Publicaciones del Catálogo</h1>
                    <p className="text-xs text-zinc-500">Supervisión, estado de moderación y sincronización de contenido en CONNECT</p>
                </div>

                <div className="flex items-center gap-2">
                    <button
                        onClick={syncToAlgolia}
                        disabled={isSyncingAlgolia}
                        className="btn-outline"
                        title="Re-indexar publicaciones a Algolia"
                    >
                        <RefreshCw size={12} className={isSyncingAlgolia ? 'animate-spin text-[#0094FF]' : ''} />
                        <span>{isSyncingAlgolia ? 'Indexando...' : 'Re-indexar Algolia'}</span>
                    </button>
                    <span className="text-xs font-semibold text-zinc-500 bg-white border border-zinc-200 px-2.5 py-1 rounded-lg">
                        Total: {posts.length}
                    </span>
                </div>
            </div>

            {/* Barra de Filtros y Búsqueda */}
            <div className="space-y-2.5 bg-white p-3 rounded-xl border border-zinc-200">
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
                    <div className="relative flex-1 max-w-md">
                        <input
                            type="text"
                            placeholder="Buscar publicación por título o descripción..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="input-clean pl-8"
                        />
                        <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-400" />
                        {searchTerm && (
                            <button onClick={() => setSearchTerm('')} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-zinc-400 hover:text-zinc-600">
                                <X size={13} />
                            </button>
                        )}
                    </div>

                    <div className="flex items-center gap-1.5 self-end sm:self-auto">
                        {(['all', 'active', 'pending', 'sold'] as const).map((st) => (
                            <button
                                key={st}
                                onClick={() => setStatusFilter(st)}
                                className={`px-2.5 py-1 text-xs font-semibold rounded-lg transition-colors capitalize ${
                                    statusFilter === st
                                        ? 'bg-zinc-900 text-white'
                                        : 'bg-zinc-100 hover:bg-zinc-200 text-zinc-600'
                                }`}
                            >
                                {st === 'all' ? 'Todas' : st === 'active' ? 'Activas' : st === 'pending' ? 'Borrador' : 'Vendidas'}
                            </button>
                        ))}
                    </div>
                </div>

                {/* Chips de Categorías */}
                <div className="flex items-center gap-1.5 overflow-x-auto pb-1 pt-1 no-scrollbar text-xs">
                    {CATEGORIES.map((cat) => (
                        <button
                            key={cat}
                            onClick={() => setActiveCategory(cat)}
                            className={`px-2.5 py-1 rounded-md whitespace-nowrap text-[11px] font-semibold transition-colors ${
                                activeCategory === cat
                                    ? 'bg-[#0094FF] text-white'
                                    : 'bg-zinc-100 hover:bg-zinc-200 text-zinc-600'
                            }`}
                        >
                            {cat}
                        </button>
                    ))}
                </div>
            </div>

            {/* Tabla Plana de Publicaciones */}
            <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table-clean">
                        <thead>
                            <tr>
                                <th>Publicación</th>
                                <th>Categoría</th>
                                <th>Precio</th>
                                <th>Estado</th>
                                <th>Fecha</th>
                                <th className="text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan={6} className="text-center py-8 text-zinc-400">
                                        Cargando publicaciones reales de Firebase...
                                    </td>
                                </tr>
                            ) : filteredPosts.length === 0 ? (
                                <tr>
                                    <td colSpan={6} className="text-center py-8 text-zinc-400">
                                        No se encontraron publicaciones con los filtros aplicados.
                                    </td>
                                </tr>
                            ) : (
                                filteredPosts.map((post) => {
                                    const img = getImage(post);
                                    return (
                                        <tr key={post.id}>
                                            <td>
                                                <div className="flex items-center gap-3">
                                                    {img ? (
                                                        <img src={img} alt="" className="w-10 h-10 rounded-lg object-cover border border-zinc-200 flex-shrink-0" />
                                                    ) : (
                                                        <div className="w-10 h-10 rounded-lg bg-zinc-100 text-zinc-400 flex items-center justify-center flex-shrink-0 border border-zinc-200">
                                                            <ShoppingBag size={16} />
                                                        </div>
                                                    )}
                                                    <div className="overflow-hidden">
                                                        <p className="font-semibold text-zinc-900 truncate max-w-xs">
                                                            {post.title || 'Sin título'}
                                                        </p>
                                                        <p className="text-[11px] text-zinc-500 truncate max-w-xs">
                                                            {post.userName || post.userEmail || post.userId || 'Autor anónimo'}
                                                        </p>
                                                    </div>
                                                </div>
                                            </td>
                                            <td>
                                                <span className="text-[11px] font-medium text-zinc-700 bg-zinc-100 px-2 py-0.5 rounded">
                                                    {post.category || 'General'}
                                                </span>
                                            </td>
                                            <td>
                                                <span className="font-semibold text-zinc-900">
                                                    {post.price !== undefined && post.price !== null ? `$${post.price.toLocaleString()}` : 'Gratis'}
                                                </span>
                                            </td>
                                            <td>
                                                <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-bold ${
                                                    post.status === 'active'
                                                        ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                                        : post.status === 'sold'
                                                        ? 'bg-blue-50 text-blue-700 border border-blue-200'
                                                        : 'bg-zinc-100 text-zinc-600 border border-zinc-200'
                                                }`}>
                                                    <span className={`w-1.5 h-1.5 rounded-full ${post.status === 'active' ? 'bg-emerald-500' : 'bg-zinc-400'}`} />
                                                    <span>{post.status === 'active' ? 'Activo' : post.status === 'sold' ? 'Vendido' : 'Borrador'}</span>
                                                </span>
                                            </td>
                                            <td>
                                                <span className="text-[11px] text-zinc-500">
                                                    {formatDate(post.createdAt)}
                                                </span>
                                            </td>
                                            <td className="text-right">
                                                <div className="inline-flex items-center gap-1.5">
                                                    <button
                                                        onClick={() => setSelectedPost(post)}
                                                        className="btn-outline px-2 py-1"
                                                        title="Ver detalles"
                                                    >
                                                        <Eye size={12} />
                                                        <span>Detalles</span>
                                                    </button>
                                                    <button
                                                        onClick={() => handleToggleStatus(post)}
                                                        className={`px-2 py-1 rounded-lg text-xs font-semibold transition-colors ${
                                                            post.status === 'active'
                                                                ? 'bg-zinc-100 hover:bg-zinc-200 text-zinc-700'
                                                                : 'bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200'
                                                        }`}
                                                    >
                                                        {post.status === 'active' ? 'Pausar' : 'Activar'}
                                                    </button>
                                                    <button
                                                        onClick={() => handleDelete(post.id, post.title)}
                                                        className="btn-danger px-2 py-1"
                                                        title="Eliminar publicación"
                                                    >
                                                        <Trash2 size={12} />
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    );
                                })
                            )}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Modal de Detalle de Publicación */}
            {selectedPost && (
                <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
                    <div className="bg-white rounded-xl border border-zinc-200 max-w-lg w-full p-5 space-y-4 shadow-xl">
                        <div className="flex items-center justify-between pb-3 border-b border-zinc-200">
                            <h3 className="font-bold text-sm text-zinc-900">Detalles de Publicación</h3>
                            <button onClick={() => setSelectedPost(null)} className="text-zinc-400 hover:text-zinc-700">
                                <X size={16} />
                            </button>
                        </div>

                        <div className="space-y-3 text-xs">
                            {getImage(selectedPost) && (
                                <img
                                    src={getImage(selectedPost)}
                                    alt=""
                                    className="w-full h-44 rounded-lg object-cover border border-zinc-200"
                                />
                            )}
                            <div>
                                <h4 className="font-bold text-sm text-zinc-900">{selectedPost.title || 'Sin título'}</h4>
                                <p className="text-zinc-600 mt-1 leading-relaxed">{selectedPost.description || 'Sin descripción detallada.'}</p>
                            </div>

                            <div className="grid grid-cols-2 gap-2 pt-2 border-t border-zinc-100">
                                <div>
                                    <span className="text-zinc-400 block text-[10px] uppercase font-bold">Precio</span>
                                    <span className="font-bold text-zinc-900">
                                        {selectedPost.price !== undefined ? `$${selectedPost.price.toLocaleString()}` : 'Gratis'}
                                    </span>
                                </div>
                                <div>
                                    <span className="text-zinc-400 block text-[10px] uppercase font-bold">Categoría</span>
                                    <span className="text-zinc-700">{selectedPost.category || 'General'}</span>
                                </div>
                                <div>
                                    <span className="text-zinc-400 block text-[10px] uppercase font-bold">ID del Documento</span>
                                    <span className="font-mono text-zinc-700 select-all">{selectedPost.id}</span>
                                </div>
                                <div>
                                    <span className="text-zinc-400 block text-[10px] uppercase font-bold">Fecha</span>
                                    <span className="text-zinc-700">{formatDate(selectedPost.createdAt)}</span>
                                </div>
                            </div>
                        </div>

                        <div className="flex items-center justify-between pt-3 border-t border-zinc-200">
                            <button
                                onClick={() => handleDelete(selectedPost.id, selectedPost.title)}
                                className="btn-danger"
                            >
                                <Trash2 size={12} />
                                <span>Eliminar Publicación</span>
                            </button>

                            <button onClick={() => setSelectedPost(null)} className="btn-outline">
                                Cerrar
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
