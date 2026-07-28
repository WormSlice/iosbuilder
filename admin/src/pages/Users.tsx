import React, { useEffect, useState } from 'react';
import { collection, query, limit, onSnapshot, doc, updateDoc } from 'firebase/firestore';
import { db } from '../services/firebase';
import {
    Search,
    Users as UsersIcon,
    Zap,
    Activity,
    Trash2,
    Clock,
    X,
    Grid,
    MessageSquare,
    UserCheck
} from 'lucide-react';

interface UserData {
    uid: string;
    email: string;
    displayName?: string;
    photoURL?: string;
    role?: string;
    createdAt?: any;
    status?: 'active' | 'suspended';
    isVerified?: boolean;
}

export const Users: React.FC = () => {
    const [users, setUsers] = useState<UserData[]>([]);
    const [loading, setLoading] = useState<boolean>(true);
    const [searchTerm, setSearchTerm] = useState<string>('');
    const [editingUser, setEditingUser] = useState<string | null>(null);

    const [selectedUserForModal, setSelectedUserForModal] = useState<UserData | null>(null);

    useEffect(() => {
        const q = query(collection(db, 'users'), limit(20));

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const docs = snapshot.docs.map((docSnap: any) => ({
                uid: docSnap.id,
                ...docSnap.data()
            })) as UserData[];
            setUsers(docs);
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    const handleSuspend = async (uid: string, currentStatus?: string) => {
        const newStatus = currentStatus === 'suspended' ? 'active' : 'suspended';
        if (!window.confirm(`¿Estás seguro de que deseas ${newStatus === 'suspended' ? 'suspender' : 'activar'} a este usuario?`)) return;
        try {
            await updateDoc(doc(db, 'users', uid), { status: newStatus });
        } catch (error) {
            console.error('Error updating user status:', error);
        }
    };

    const filteredUsers = users.filter(user =>
        user.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        user.displayName?.toLowerCase().includes(searchTerm.toLowerCase())
    );

    return (
        <div className="space-y-8 animate-in slide-in-from-bottom duration-500">
            <div className="flex justify-between items-center">
                <div className="space-y-1">
                    <h1 className="text-3xl font-black tracking-tighter">Usuarios Registrados</h1>
                    <p className="text-zinc-400 text-xs font-bold uppercase tracking-widest">Customer Base</p>
                </div>
                <div className="flex gap-4">
                    <div className="relative group">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-300 group-focus-within:text-black transition-colors" size={16} />
                        <input
                            placeholder="Buscar por email..."
                            className="pl-12 pr-6 py-3 glass-button border border-zinc-100 rounded-2xl text-xs w-64 focus:border-black focus:glass-panel transition-all outline-none"
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                        />
                    </div>
                    <button className="glass-panel-dark text-white px-6 py-3 rounded-2xl text-[10px] font-black uppercase tracking-widest flex items-center gap-2 hover:scale-[1.02] active:scale-[0.98] transition-all shadow-lg shadow-black/10">
                        <UsersIcon size={14} /> Exportar
                    </button>
                </div>
            </div>

            <div className="w-full">
                <table className="w-full text-left">
                    <thead>
                        <tr className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 border-b border-white/10">
                            <th className="px-6 py-6">Perfil</th>
                            <th className="px-6 py-6">Identificador</th>
                            <th className="px-6 py-6">Estatus</th>
                            <th className="px-6 py-6 text-right">Acciones</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-white/5">
                        {loading ? (
                            <tr>
                                <td colSpan={4} className="px-6 py-40 text-center">
                                    <div className="w-8 h-8 border-2 border-white/20 border-t-white rounded-full animate-spin mx-auto"></div>
                                </td>
                            </tr>
                        ) : filteredUsers.map((user) => (
                            <tr key={user.uid} className="hover:bg-white/5 transition-colors group">
                                <td className="px-6 py-4">
                                    <div className="flex items-center gap-4">
                                        <div className="w-10 h-10 rounded-2xl bg-white/5 border border-white/10 overflow-hidden shadow-sm group-hover:scale-105 transition-transform flex items-center justify-center">
                                            {user.photoURL ? (
                                                <img src={user.photoURL} className="w-full h-full object-cover" />
                                            ) : (
                                                <span className="font-bold text-zinc-900 uppercase">{user.email?.[0]}</span>
                                            )}
                                        </div>
                                        <div>
                                            <span className="font-bold text-sm tracking-tight block leading-none text-zinc-900">{user.displayName || 'Usuario CONNECT'}</span>
                                            <span className="text-[10px] text-zinc-500 font-bold uppercase tracking-widest mt-1 block">Customer</span>
                                        </div>
                                    </div>
                                </td>
                                <td className="px-6 py-4">
                                    <p className="text-[11px] font-bold tracking-wider text-zinc-600">{user.email}</p>
                                </td>
                                <td className="px-6 py-4">
                                    <div className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-wider ${user.isVerified ? 'bg-blue-500/10 text-blue-600 border border-blue-500/20' : 'bg-white/5 text-zinc-500 border border-white/10'
                                        }`}>
                                        {user.isVerified && <Zap size={10} />}
                                        {user.isVerified ? 'Verificado' : 'Normal'}
                                    </div>
                                </td>
                                <td className="px-6 py-4 text-right relative">
                                    <div className="flex items-center justify-end gap-2">
                                        <button
                                            onClick={() => setEditingUser(editingUser === user.uid ? null : user.uid)}
                                            className={`p-2 rounded-xl transition-all ${editingUser === user.uid ? 'bg-black text-white' : 'bg-white/5 text-zinc-500 hover:text-black hover:bg-white/20'}`}
                                            title="Opciones"
                                        >
                                            <Zap size={16} />
                                        </button>
                                        <button
                                            onClick={() => handleSuspend(user.uid, user.status)}
                                            className={`p-2 rounded-xl transition-all ${user.status === 'suspended'
                                                ? 'bg-red-500/10 text-red-600'
                                                : 'bg-white/5 text-zinc-500 hover:text-red-500 hover:bg-red-500/10'
                                                }`}
                                            title={user.status === 'suspended' ? 'Activar' : 'Suspender'}
                                        >
                                            <Activity size={16} />
                                        </button>
                                    </div>

                                    {editingUser === user.uid && (
                                        <div className="absolute right-20 top-12 w-48 glass-panel border border-white/10 rounded-2xl shadow-2xl z-50 p-2 animate-in zoom-in duration-200">
                                            {[
                                                { label: 'Ver Perfil', icon: <UsersIcon size={14} />, action: () => setSelectedUserForModal(user) },
                                                ...(user.isVerified ? [] : [{ label: 'Verificar Email', icon: <Zap size={14} />, action: () => alert('Verificando: ' + user.email) }]),
                                                { label: 'Cambiar Rol', icon: <UsersIcon size={14} />, action: () => alert('Cambiando rol...') },
                                                { label: 'Eliminar', icon: <Trash2 size={14} />, action: () => alert('Eliminar: ' + user.email), color: 'text-red-500' },
                                            ].map((opt, i) => (
                                                <button
                                                    key={i}
                                                    onClick={() => { opt.action(); setEditingUser(null); }}
                                                    className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-[10px] font-black uppercase tracking-widest hover:bg-white/10 transition-all ${opt.color || 'text-zinc-900'}`}
                                                >
                                                    {opt.icon} {opt.label}
                                                </button>
                                            ))}
                                        </div>
                                    )}
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>

                {!loading && filteredUsers.length === 0 && (
                    <div className="py-32 text-center space-y-4 opacity-50">
                        <div className="w-12 h-12 border border-white/20 rounded-full flex items-center justify-center mx-auto text-zinc-400">
                            <Trash2 size={24} />
                        </div>
                        <p className="text-zinc-400 text-[10px] font-black uppercase tracking-[0.2em]">No hay registros coincidentes</p>
                    </div>
                )}
            </div>

            {selectedUserForModal && (
                <UserProfileModal user={selectedUserForModal} onClose={() => setSelectedUserForModal(null)} />
            )}
        </div>
    );
};

const UserProfileModal: React.FC<{ user: UserData; onClose: () => void }> = ({ user, onClose }) => {
    const [posts, setPosts] = useState<any[]>([]);
    const [reviews, setReviews] = useState<any[]>([]);
    const [avgRating, setAvgRating] = useState<number>(0);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState<'posts' | 'reviews' | 'info'>('posts');

    useEffect(() => {
        const fetchStats = async () => {
            try {
                const { getDocs, query, collection, where } = await import('firebase/firestore');
                
                const postsQ = query(collection(db, 'posts'), where('userId', '==', user.uid));
                const postsSnap = await getDocs(postsQ);
                setPosts(postsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() })));

                const reviewsQ = query(collection(db, 'reviews'), where('targetId', '==', user.uid));
                const reviewsSnap = await getDocs(reviewsQ);
                const fetchedReviews = reviewsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
                setReviews(fetchedReviews);
                
                if (!reviewsSnap.empty) {
                    const total = fetchedReviews.reduce((acc, rev) => acc + (rev.rating || 0), 0);
                    setAvgRating(total / fetchedReviews.length);
                }
            } catch (error) {
                console.error("Error fetching stats:", error);
            } finally {
                setLoading(false);
            }
        };
        fetchStats();
    }, [user.uid]);

    const followers = (user as any).followersCount ?? (user as any).followers ?? 0;
    const following = (user as any).followingCount ?? (user as any).following ?? 0;
    const createdAtDate = user.createdAt ? new Date(user.createdAt.seconds * 1000) : new Date();
    const memberSinceText = `Se unió el ${createdAtDate.toLocaleDateString('es-ES', { day: '2-digit', month: '2-digit', year: 'numeric' })}`;

    return (
        <div className="fixed inset-0 z-[120] flex items-center justify-center p-4">
            {/* Backdrop */}
            <div className="absolute inset-0 bg-black/40 backdrop-blur-md" onClick={onClose} />
            
            {/* Liquid Glass Modal (Compact) */}
            <div className="relative w-full max-w-[420px] max-h-[85vh] bg-white/10 backdrop-blur-2xl border border-white/20 rounded-[2rem] shadow-[0_8px_32px_0_rgba(0,0,0,0.3)] flex flex-col overflow-hidden text-white animate-in zoom-in-95 duration-300">
                
                {/* Close button */}
                <button onClick={onClose} className="absolute top-4 right-4 p-2 bg-black/20 hover:bg-black/40 rounded-full text-white transition-colors z-10">
                    <X size={18} />
                </button>

                <div className="flex-1 overflow-y-auto custom-scrollbar p-6">
                    
                    {/* Profile Header (Avatar + Info) */}
                    <div className="flex items-center gap-4">
                        {/* Avatar */}
                        <div className="w-[90px] h-[90px] rounded-full border-[2px] border-[#0094FF] p-[2px] shrink-0 shadow-lg bg-white/5">
                            <div className="w-full h-full rounded-full overflow-hidden bg-black/20 flex items-center justify-center">
                                {user.photoURL ? (
                                    <img src={user.photoURL} className="w-full h-full object-cover" />
                                ) : (
                                    <UsersIcon size={36} className="text-white/50" />
                                )}
                            </div>
                        </div>
                        
                        {/* Right Info */}
                        <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-1.5 flex-wrap">
                                <h2 className="text-lg font-bold truncate tracking-wide">
                                    {user.displayName || 'Usuario CONNECT'}
                                </h2>
                                {user.isVerified && (
                                    <svg viewBox="0 0 24 24" className="w-4 h-4 text-[#0094FF] fill-current shrink-0">
                                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                                    </svg>
                                )}
                            </div>

                            <div className="flex items-center gap-1 mt-0.5">
                                <div className="flex">
                                    {[1, 2, 3, 4, 5].map((star) => (
                                        <span key={star} className={`text-[12px] leading-none ${avgRating >= star || star <= 4.9 ? 'text-[#0094FF]' : 'text-white/30'}`}>
                                            ★
                                        </span>
                                    ))}
                                </div>
                                {user.isVerified && (
                                    <span className="ml-2 bg-[#0094FF]/20 border border-[#0094FF]/50 text-[#0094FF] px-2 py-0.5 rounded-full text-[9px] font-bold tracking-wider uppercase">
                                        Verificado
                                    </span>
                                )}
                            </div>

                            <p className="text-xs text-white/60 mt-1.5">{memberSinceText}</p>
                        </div>
                    </div>

                    {/* Stats Row */}
                    <div className="flex justify-between items-center mt-6 bg-black/20 rounded-2xl p-4 border border-white/5 shadow-inner">
                        <div className="text-center flex-1">
                            <p className="font-bold text-xl leading-none">{loading ? '-' : posts.length}</p>
                            <p className="text-[10px] text-white/50 uppercase tracking-widest mt-1">Publicaciones</p>
                        </div>
                        <div className="w-[1px] h-8 bg-white/10"></div>
                        <div className="text-center flex-1">
                            <p className="font-bold text-xl leading-none">{followers}</p>
                            <p className="text-[10px] text-white/50 uppercase tracking-widest mt-1">Seguidores</p>
                        </div>
                        <div className="w-[1px] h-8 bg-white/10"></div>
                        <div className="text-center flex-1">
                            <p className="font-bold text-xl leading-none">{following}</p>
                            <p className="text-[10px] text-white/50 uppercase tracking-widest mt-1">Seguidos</p>
                        </div>
                    </div>

                    {/* Action Buttons Row */}
                    <div className="flex gap-2 mt-4">
                        <button className="flex-1 bg-white/10 hover:bg-white/20 border border-white/10 text-white font-semibold py-2 rounded-xl text-sm transition-colors shadow-lg backdrop-blur-md">
                            Ver Perfil App
                        </button>
                        <button className="flex-1 bg-[#0094FF]/80 hover:bg-[#0094FF] border border-[#0094FF]/50 text-white font-semibold py-2 rounded-xl text-sm transition-colors shadow-lg shadow-[#0094FF]/20">
                            Suspender
                        </button>
                    </div>

                    {/* Tabs */}
                    <div className="flex mt-6 border-b border-white/10">
                        <button 
                            onClick={() => setActiveTab('posts')}
                            className={`flex-1 flex justify-center pb-3 border-b-2 transition-colors ${activeTab === 'posts' ? 'border-white text-white' : 'border-transparent text-white/40 hover:text-white/70'}`}
                        >
                            <Grid size={22} />
                        </button>
                        <button 
                            onClick={() => setActiveTab('reviews')}
                            className={`flex-1 flex justify-center pb-3 border-b-2 transition-colors ${activeTab === 'reviews' ? 'border-white text-white' : 'border-transparent text-white/40 hover:text-white/70'}`}
                        >
                            <MessageSquare size={22} />
                        </button>
                        <button 
                            onClick={() => setActiveTab('info')}
                            className={`flex-1 flex justify-center pb-3 border-b-2 transition-colors ${activeTab === 'info' ? 'border-white text-white' : 'border-transparent text-white/40 hover:text-white/70'}`}
                        >
                            <UserCheck size={24} />
                        </button>
                    </div>

                    {/* Tab Content */}
                    <div className="pt-4">
                        {activeTab === 'posts' && (
                            <div className="grid grid-cols-3 gap-2">
                                {posts.length > 0 ? posts.map((post, idx) => (
                                    <div key={post.id || idx} className="flex flex-col group">
                                        <div className="aspect-square bg-black/20 rounded-xl overflow-hidden mb-1.5 relative border border-white/10 group-hover:border-white/30 transition-colors">
                                            {(post.imageUrl || post.photoUrl || post.image) ? (
                                                <img src={post.imageUrl || post.photoUrl || post.image} className="w-full h-full object-cover" />
                                            ) : (
                                                <div className="w-full h-full bg-gradient-to-br from-white/5 to-white/10"></div>
                                            )}
                                        </div>
                                        <p className="font-bold text-[11px] text-white text-center truncate px-1">
                                            {post.price ? `$${post.price}` : (post.title || `Post ${idx+1}`)}
                                        </p>
                                        <p className="text-[9px] text-white/50 text-center truncate px-1">
                                            {post.brand ? `${post.brand} ${post.model || ''}` : (post.subtitle || 'Sin detalle')}
                                        </p>
                                    </div>
                                )) : (
                                    <div className="col-span-3 text-center py-8 text-white/40 text-sm">No hay publicaciones</div>
                                )}
                            </div>
                        )}
                        
                        {activeTab === 'reviews' && (
                            <div className="space-y-3">
                                {reviews.length > 0 ? reviews.map((review) => (
                                    <div key={review.id} className="bg-black/20 p-4 rounded-2xl border border-white/10">
                                        <div className="flex items-center justify-between mb-2">
                                            <div className="flex gap-1">
                                                {[1, 2, 3, 4, 5].map((s) => (
                                                    <span key={s} className={`text-[12px] ${review.rating >= s ? 'text-[#0094FF]' : 'text-white/20'}`}>★</span>
                                                ))}
                                            </div>
                                            <span className="text-[9px] font-bold text-white/40 uppercase">
                                                {review.createdAt ? new Date(review.createdAt.seconds * 1000).toLocaleDateString() : ''}
                                            </span>
                                        </div>
                                        <p className="text-xs text-white/80">{review.comment || review.review || 'Sin comentario'}</p>
                                    </div>
                                )) : (
                                    <div className="text-center py-8 text-white/40 text-sm">No hay reseñas</div>
                                )}
                            </div>
                        )}
                        
                        {activeTab === 'info' && (
                            <div className="space-y-3">
                                <div className="bg-black/20 p-4 rounded-2xl border border-white/10 flex justify-between items-center">
                                    <span className="text-xs font-bold text-white/50">Email</span>
                                    <span className="text-sm font-semibold truncate pl-4">{user.email}</span>
                                </div>
                                <div className="bg-black/20 p-4 rounded-2xl border border-white/10 flex justify-between items-center">
                                    <span className="text-xs font-bold text-white/50">ID Único</span>
                                    <span className="text-xs font-mono text-white/70 truncate pl-4">{user.uid}</span>
                                </div>
                                <div className="bg-black/20 p-4 rounded-2xl border border-white/10 flex justify-between items-center">
                                    <span className="text-xs font-bold text-white/50">Rol</span>
                                    <span className="text-sm font-semibold uppercase">{user.role || 'Customer'}</span>
                                </div>
                                <div className="bg-black/20 p-4 rounded-2xl border border-white/10 flex justify-between items-center">
                                    <span className="text-xs font-bold text-white/50">Estado</span>
                                    <span className={`text-sm font-bold uppercase ${user.status === 'suspended' ? 'text-red-400' : 'text-emerald-400'}`}>
                                        {user.status || 'Active'}
                                    </span>
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
};
