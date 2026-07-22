import React, { useEffect, useState } from 'react';
import { collection, limit, onSnapshot, doc, deleteDoc, updateDoc, query, orderBy, setDoc, getDocs } from 'firebase/firestore';
import { db } from '../services/firebase';
import {
    LayoutGrid,
    Search,
    Filter,
    Trash2,
    Eye,
    Zap,
    ArrowUpRight,
    CheckCircle,
    ShoppingBag,
    Activity,
    Clock,
    RefreshCw,
    Shield,
    Users,
    Home
} from 'lucide-react';
import { motion } from 'framer-motion';

interface Publication {
    id: string;
    title: string;
    description: string;
    price?: number;
    category?: string;
    imageUrl?: string;
    status: 'active' | 'pending' | 'rejected' | 'sold';
    createdAt: any;
}

export const Publications: React.FC = () => {
    const [posts, setPosts] = useState<Publication[]>([]);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('all');
    const [searchTerm, setSearchTerm] = useState('');
    const [activeCategory, setActiveCategory] = useState('Todas');
    const [isMarketplaceHidden, setIsMarketplaceHidden] = useState(false);

    const categories = ['Todas', 'Lo Tienes', 'Productos', 'Vehículos', 'Propiedades', 'Servicios', 'Empleos', 'Mascotas', 'Trueques', 'Sugerencias'];

    const [isSyncing, setIsSyncing] = useState(false);

    const syncToAlgolia = async () => {
        if (!window.confirm('¿Seguro que deseas re-indexar todas las publicaciones a Algolia? Esto puede tomar unos segundos.')) return;
        setIsSyncing(true);
        try {
            const { algoliasearch } = await import('algoliasearch');
            const client = algoliasearch('P2CJMQDDSH', '99ec76cf710a0324bccd1f008514eb36');
            
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
            const postsBatch = postsSnap.docs.map(doc => {
                let data = doc.data();
                data = sanitizeData(data);
                return {
                    action: 'addObject',
                    body: { ...data, objectID: doc.id, id: doc.id, type: data.type || 'post', status: data.status || 'active' }
                };
            });
            
            if (postsBatch.length > 0) {
                const batchSize = 50;
                for (let i = 0; i < postsBatch.length; i += batchSize) {
                    const batch = postsBatch.slice(i, i + batchSize);
                    await client.batch({ indexName: 'posts', batchWriteParams: { requests: batch as any } });
                }
            }

            const wantsSnap = await getDocs(collection(db, 'wants'));
            const wantsBatch = wantsSnap.docs.map(doc => {
                let data = doc.data();
                data = sanitizeData(data);
                return {
                    action: 'addObject',
                    body: { ...data, objectID: doc.id, id: doc.id, type: data.type || 'want', status: data.status || 'active' }
                };
            });
            
            if (wantsBatch.length > 0) {
                const batchSize = 50;
                for (let i = 0; i < wantsBatch.length; i += batchSize) {
                    const batch = wantsBatch.slice(i, i + batchSize);
                    await client.batch({ indexName: 'wants', batchWriteParams: { requests: batch as any } });
                }
            }

            alert('¡Indexación a Algolia completada con éxito!');
        } catch (error) {
            console.error('Error syncing to Algolia:', error);
            alert('Error al indexar: ' + error);
        } finally {
            setIsSyncing(false);
        }
    };

    useEffect(() => {
        const fetchAllContent = async () => {
            setLoading(true);
            try {
                // Fetch from products/posts
                const qPosts = query(
                    collection(db, 'posts'),
                    orderBy('createdAt', 'desc'),
                    limit(60)
                );

                // Fetch from wants
                const qWants = query(
                    collection(db, 'wants'),
                    orderBy('createdAt', 'desc'),
                    limit(40)
                );

                const unsubPosts = onSnapshot(qPosts, (postsSnap) => {
                    const postsData = postsSnap.docs.map(docSnap => ({
                        id: docSnap.id,
                        type: 'post',
                        ...docSnap.data()
                    })) as Publication[];

                    onSnapshot(qWants, (wantsSnap) => {
                        const wantsData = wantsSnap.docs.map(docSnap => ({
                            id: docSnap.id,
                            type: 'want',
                            category: 'Lo Tienes', // Force category for wants
                            ...docSnap.data()
                        })) as Publication[];

                        const combined = [...postsData, ...wantsData].sort((a, b) => {
                            const dateA = a.createdAt?.seconds || 0;
                            const dateB = b.createdAt?.seconds || 0;
                            return dateB - dateA;
                        });

                        setPosts(combined);
                        setLoading(false);
                    });
                });

                return () => unsubPosts();
            } catch (err) {
                console.error("Error fetching admin content:", err);
                setLoading(false);
            }
        };

        fetchAllContent();
    }, []);

    useEffect(() => {
        const unsubscribe = onSnapshot(doc(db, 'settings', 'marketplace'), (docSnap) => {
            if (docSnap.exists()) {
                setIsMarketplaceHidden(docSnap.data().hideAllPosts || false);
            }
        });
        return () => unsubscribe();
    }, []);

    const toggleMarketplaceVisibility = async () => {
        try {
            await setDoc(doc(db, 'settings', 'marketplace'), {
                hideAllPosts: !isMarketplaceHidden,
                updatedAt: new Date()
            }, { merge: true });
        } catch (error) {
            console.error('Error toggling marketplace:', error);
        }
    };

    const handleDelete = async (id: string) => {
        if (!window.confirm('¿Eliminar publicación permanentemente?')) return;
        try {
            await deleteDoc(doc(db, 'posts', id));
        } catch (error) {
            console.error('Error deleting post:', error);
        }
    };

    const getFilteredPosts = () => {
        return posts.filter(post => {
            const matchesFilter = filter === 'all' || post.status === filter;
            
            // Fix categories matching
            const postCat = (post.category || '').toLowerCase();
            const activeCat = activeCategory.toLowerCase();
            const matchesCategory = activeCategory === 'Todas' || postCat === activeCat;
            
            const matchesSearch = post.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                post.description?.toLowerCase().includes(searchTerm.toLowerCase());
            return matchesFilter && matchesCategory && matchesSearch;
        });
    };

    const getCategoryIcon = (cat?: string) => {
        switch (cat?.toLowerCase()) {
            case 'vehículos': return <Activity size={14} />;
            case 'propiedades': return <Home size={14} />;
            case 'productos': return <ShoppingBag size={14} />;
            case 'servicios': return <Activity size={14} />;
            case 'empleos': return <Activity size={14} />;
            case 'mascotas': return <Activity size={14} />;
            case 'lo tienes': return <ShoppingBag size={14} className="text-blue-500" />;
            case 'trueques': return <RefreshCw size={14} />;
            default: return <LayoutGrid size={14} />;
        }
    };

    const filteredPosts = getFilteredPosts();

    return (
        <div className="space-y-10 animate-in slide-in-from-right duration-500">
            <div className="flex flex-col gap-8 md:flex-row md:items-end md:justify-between">
                <div className="space-y-1">
                    <h1 className="text-3xl font-black tracking-tighter uppercase leading-none">Marketplace Moderation</h1>
                    <div className="flex items-center gap-4 mt-2">
                        <p className="text-zinc-400 text-xs font-bold uppercase tracking-widest">Control de Inventario y Calidad</p>
                        <div className="h-4 w-px bg-zinc-100 mx-2"></div>
                        <div
                            onClick={toggleMarketplaceVisibility}
                            className="flex items-center gap-3 px-4 py-2 bg-zinc-50 rounded-full border border-zinc-100 hover:border-black transition-all cursor-pointer group"
                        >
                            <div className={`w-8 h-4 rounded-full relative transition-colors ${isMarketplaceHidden ? 'bg-black' : 'bg-zinc-200'}`}>
                                <motion.div
                                    animate={{ x: isMarketplaceHidden ? 18 : 2 }}
                                    className="w-3 h-3 bg-white rounded-full absolute top-0.5 shadow-sm"
                                />
                            </div>
                            <span className={`text-[9px] font-black uppercase tracking-widest ${isMarketplaceHidden ? 'text-black' : 'text-zinc-400'}`}>
                                {isMarketplaceHidden ? 'Mercado en Pausa' : 'Mercado Activo'}
                            </span>
                            {isMarketplaceHidden && <Zap size={12} className="text-black" />}
                        </div>
                        
                        <div className="h-4 w-px bg-zinc-100 mx-2"></div>
                        <button
                            onClick={syncToAlgolia}
                            disabled={isSyncing}
                            className="flex items-center gap-2 px-4 py-2 bg-blue-50 text-blue-600 rounded-full border border-blue-100 hover:border-blue-300 transition-all cursor-pointer"
                        >
                            <RefreshCw size={12} className={isSyncing ? "animate-spin" : ""} />
                            <span className="text-[9px] font-black uppercase tracking-widest">
                                {isSyncing ? 'Indexando...' : 'Algolia Index'}
                            </span>
                        </button>
                    </div>
                </div>

                <div className="flex flex-col md:flex-row gap-4">
                    {/* Search Bar */}
                    <div className="relative group">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-300 group-focus-within:text-black transition-colors" size={16} />
                        <input
                            type="text"
                            placeholder="Buscar publicación..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="bg-zinc-50 border border-zinc-100 rounded-2xl pl-12 pr-6 py-3 text-[10px] font-bold uppercase tracking-widest outline-none focus:bg-white focus:border-black transition-all w-full md:w-64"
                        />
                    </div>

                    <div className="flex p-1 bg-zinc-100 rounded-2xl">
                        {['all', 'pending', 'approved'].map(f => (
                            <button
                                key={f}
                                onClick={() => setFilter(f)}
                                className={`px-6 py-2 rounded-xl text-[9px] font-black uppercase tracking-widest transition-all ${filter === f ? 'bg-black text-white shadow-lg' : 'text-zinc-400 hover:text-black'
                                    }`}
                            >
                                {f === 'all' ? 'Todos' : f === 'pending' ? 'Borradores' : 'En Vivo'}
                            </button>
                        ))}
                    </div>
                </div>
            </div>

            {/* Category Chips */}
            <div className="flex gap-2 overflow-x-auto pb-4 no-scrollbar">
                {categories.map((cat) => (
                    <button
                        key={cat}
                        onClick={() => setActiveCategory(cat)}
                        className={`px-6 py-2 rounded-full text-[9px] font-black uppercase tracking-widest whitespace-nowrap transition-all border ${activeCategory === cat
                            ? 'bg-black border-black text-white shadow-xl shadow-black/10'
                            : 'bg-white border-zinc-100 text-zinc-400 hover:border-black hover:text-black'
                            }`}
                    >
                        {cat}
                    </button>
                ))}
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                {loading ? (
                    <div className="col-span-full py-40 text-center">
                        <div className="w-8 h-8 border-2 border-black border-t-transparent rounded-full animate-spin mx-auto"></div>
                    </div>
                ) : filteredPosts.map((post) => (
                    <div key={post.id} className="bg-white rounded-[2.5rem] p-6 border border-zinc-100 flex gap-8 items-start hover:shadow-xl transition-all group">
                        {/* Compact Card (Connect Style) */}
                        <div className="w-40 flex-shrink-0 space-y-3">
                            <div className="aspect-square bg-zinc-100 rounded-3xl overflow-hidden relative border border-zinc-50 shadow-inner">
                                {(() => {
                                    const p = post as any;
                                    const img = p.images?.[0] || p.imageUrl || p.image;
                                    return img ? (
                                        <img src={img} className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-700" alt="" />
                                    ) : (
                                        <div className="w-full h-full flex items-center justify-center text-zinc-200">
                                            <ShoppingBag size={32} strokeWidth={1} />
                                        </div>
                                    );
                                })()}
                                <div className="absolute top-2 right-2 flex gap-1">
                                    <div className={`px-2 py-1 rounded-full text-[7px] font-black uppercase tracking-tighter shadow-xl ${post.status === 'active' ? 'bg-black text-white' : 'bg-zinc-200 text-zinc-600'}`}>
                                        {post.status === 'active' ? 'LIVE' : 'WAIT'}
                                    </div>
                                </div>
                            </div>
                            <div className="px-1 space-y-1">
                                <h4 className="font-black text-[11px] leading-tight line-clamp-1 uppercase tracking-tighter">{post.title}</h4>
                                <div className="flex items-center gap-1.5 text-zinc-400">
                                    {getCategoryIcon(post.category)}
                                    <span className="text-[9px] font-bold uppercase truncate">{post.category || 'Varios'}</span>
                                </div>
                            </div>
                        </div>

                        {/* Details List (Right Side) */}
                        <div className="flex-grow space-y-4 py-2">
                            <div className="grid grid-cols-2 gap-x-12 gap-y-4">
                                <div className="space-y-1">
                                    <p className="text-[8px] font-black uppercase text-zinc-300 tracking-widest">Valor de Mercado</p>
                                    <p className="font-black text-lg tracking-tight text-black">
                                        {(() => {
                                            if (post.price == null) return post.type === 'want' ? 'N/A' : '$0';
                                            const priceStr = String(post.price).replace(/[^0-9]/g, '');
                                            const priceNum = parseInt(priceStr, 10);
                                            return isNaN(priceNum) ? '$0' : `$${priceNum.toLocaleString()}`;
                                        })()}
                                    </p>
                                </div>
                                <div className="space-y-1 text-right">
                                    <p className="text-[8px] font-black uppercase text-zinc-300 tracking-widest">Fecha Ingreso</p>
                                    <p className="font-black text-[10px] text-zinc-400 tracking-widest uppercase">
                                        {post.createdAt ? new Date(post.createdAt.seconds * 1000).toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' }).toUpperCase() : 'N/A'}
                                    </p>
                                </div>
                                <div className="space-y-1 truncate">
                                    <p className="text-[8px] font-black uppercase text-zinc-300 tracking-widest">Propietario / Autor</p>
                                    <div className="flex items-center gap-2">
                                        <div className="w-4 h-4 rounded bg-zinc-100 border border-zinc-200" />
                                        <p className="font-bold text-[10px] text-zinc-500 tracking-tight truncate">{(post as any).userId || 'Anónimo'}</p>
                                    </div>
                                </div>
                                <div className="space-y-1 text-right">
                                    <p className="text-[8px] font-black uppercase text-zinc-300 tracking-widest">Estatus Sistema</p>
                                    <div className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[8px] font-black uppercase tracking-widest ${post.status === 'active' ? 'bg-zinc-50 text-black' : 'bg-red-50 text-red-500'}`}>
                                        {post.status === 'active' ? 'Validado' : 'Pendiente'}
                                    </div>
                                </div>
                            </div>

                            <div className="pt-4 border-t border-zinc-50 flex justify-between items-center">
                                <button className="text-[9px] font-black uppercase tracking-[0.2em] text-zinc-300 hover:text-black transition-colors flex items-center gap-2 underline decoration-zinc-100 decoration-2 underline-offset-4">
                                    Ver Documentación <ArrowUpRight size={10} />
                                </button>
                                <div className="flex gap-2">
                                    <button className="h-10 w-10 flex items-center justify-center bg-zinc-50 text-zinc-300 hover:text-black hover:bg-zinc-100 rounded-xl transition-all">
                                        <Zap size={16} />
                                    </button>
                                    <button onClick={() => handleDelete(post.id)} className="h-10 w-10 flex items-center justify-center bg-zinc-50 text-zinc-300 hover:text-red-500 hover:bg-red-50 rounded-xl transition-all">
                                        <Trash2 size={16} />
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                ))}
            </div>

            {!loading && filteredPosts.length === 0 && (
                <div className="py-40 text-center space-y-4">
                    <div className="w-16 h-16 bg-zinc-50 rounded-full flex items-center justify-center mx-auto text-zinc-200">
                        <LayoutGrid size={32} />
                    </div>
                    <p className="text-zinc-300 text-xs font-black uppercase tracking-[0.2em]">Catalogo Vacío o sin coincidencias</p>
                </div>
            )}
        </div>
    );
};
