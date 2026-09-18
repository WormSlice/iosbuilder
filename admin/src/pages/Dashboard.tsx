import React, { useState, useEffect } from 'react';
import { collection, getDocs, query, orderBy, limit } from 'firebase/firestore';
import { db } from '../services/firebase';
import {
    Users,
    FileText,
    AlertCircle,
    UserCheck,
    Headphones,
    ShoppingBag,
    ArrowRight,
    Clock,
    RefreshCw
} from 'lucide-react';
import { Link } from 'react-router-dom';

interface RealStats {
    usersCount: number;
    postsCount: number;
    wantsCount: number;
    reportsCount: number;
    verificationsCount: number;
    supportCount: number;
}

interface RecentUser {
    id: string;
    email?: string;
    displayName?: string;
    photoURL?: string;
    createdAt?: any;
    role?: string;
}

interface RecentPost {
    id: string;
    title?: string;
    category?: string;
    price?: number;
    userName?: string;
    createdAt?: any;
    status?: string;
}

export const Dashboard: React.FC = () => {
    const [stats, setStats] = useState<RealStats>({
        usersCount: 0,
        postsCount: 0,
        wantsCount: 0,
        reportsCount: 0,
        verificationsCount: 0,
        supportCount: 0,
    });
    const [recentUsers, setRecentUsers] = useState<RecentUser[]>([]);
    const [recentPosts, setRecentPosts] = useState<RecentPost[]>([]);
    const [loading, setLoading] = useState(true);
    const [isRefreshing, setIsRefreshing] = useState(false);

    const loadRealData = async () => {
        setIsRefreshing(true);
        try {
            // 1. Conteo real de documentos en Firestore
            const [
                usersSnap,
                postsSnap,
                wantsSnap,
                reportsSnap,
                verificationsSnap,
                supportSnap
            ] = await Promise.all([
                getDocs(collection(db, 'users')),
                getDocs(collection(db, 'posts')),
                getDocs(collection(db, 'wants')),
                getDocs(collection(db, 'reports')),
                getDocs(collection(db, 'verifications')),
                getDocs(collection(db, 'support_requests')),
            ]);

            setStats({
                usersCount: usersSnap.size,
                postsCount: postsSnap.size,
                wantsCount: wantsSnap.size,
                reportsCount: reportsSnap.size,
                verificationsCount: verificationsSnap.size,
                supportCount: supportSnap.size,
            });

            // 2. Últimos 5 usuarios reales
            const recentUsersList: RecentUser[] = usersSnap.docs
                .slice(0, 5)
                .map(d => ({ id: d.id, ...d.data() } as RecentUser));
            setRecentUsers(recentUsersList);

            // 3. Últimas 5 publicaciones reales
            const recentPostsList: RecentPost[] = postsSnap.docs
                .slice(0, 5)
                .map(d => ({ id: d.id, ...d.data() } as RecentPost));
            setRecentPosts(recentPostsList);
        } catch (error) {
            console.error('Error al cargar datos reales del Dashboard:', error);
        } finally {
            setLoading(false);
            setIsRefreshing(false);
        }
    };

    useEffect(() => {
        loadRealData();
    }, []);

    const formatDate = (timestamp: any) => {
        if (!timestamp) return 'Reciente';
        try {
            if (timestamp.toDate) {
                return timestamp.toDate().toLocaleDateString('es-ES', { day: '2-digit', month: 'short' });
            }
            if (timestamp.seconds) {
                return new Date(timestamp.seconds * 1000).toLocaleDateString('es-ES', { day: '2-digit', month: 'short' });
            }
            return new Date(timestamp).toLocaleDateString('es-ES', { day: '2-digit', month: 'short' });
        } catch {
            return 'Reciente';
        }
    };

    return (
        <div className="space-y-6">
            {/* Título de la Página y Acción Rápida */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-zinc-200">
                <div>
                    <h1 className="text-xl font-bold text-zinc-900 tracking-tight">Resumen General</h1>
                    <p className="text-xs text-zinc-500">Métricas y actividad en tiempo real directamente desde Firebase Firestore</p>
                </div>

                <button
                    onClick={loadRealData}
                    disabled={isRefreshing}
                    className="btn-outline self-start sm:self-auto"
                >
                    <RefreshCw size={13} className={isRefreshing ? 'animate-spin' : ''} />
                    <span>{isRefreshing ? 'Actualizando...' : 'Actualizar Datos'}</span>
                </button>
            </div>

            {/* Cuadrícula de Métricas 100% Reales */}
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
                {/* Usuarios */}
                <div className="bg-white border border-zinc-200 rounded-xl p-3.5">
                    <div className="flex items-center justify-between text-zinc-500 mb-1.5">
                        <span className="text-[11px] font-semibold">Usuarios</span>
                        <Users size={15} className="text-[#0094FF]" />
                    </div>
                    <p className="text-2xl font-bold text-zinc-900 tracking-tight">
                        {loading ? '...' : stats.usersCount}
                    </p>
                    <span className="text-[10px] text-zinc-400 font-medium">Registrados en total</span>
                </div>

                {/* Publicaciones */}
                <div className="bg-white border border-zinc-200 rounded-xl p-3.5">
                    <div className="flex items-center justify-between text-zinc-500 mb-1.5">
                        <span className="text-[11px] font-semibold">Publicaciones</span>
                        <FileText size={15} className="text-[#0094FF]" />
                    </div>
                    <p className="text-2xl font-bold text-zinc-900 tracking-tight">
                        {loading ? '...' : stats.postsCount}
                    </p>
                    <span className="text-[10px] text-zinc-400 font-medium">Posts en catálogo</span>
                </div>

                {/* Lo Tienes / Wants */}
                <div className="bg-white border border-zinc-200 rounded-xl p-3.5">
                    <div className="flex items-center justify-between text-zinc-500 mb-1.5">
                        <span className="text-[11px] font-semibold">Lo Tienes</span>
                        <ShoppingBag size={15} className="text-zinc-700" />
                    </div>
                    <p className="text-2xl font-bold text-zinc-900 tracking-tight">
                        {loading ? '...' : stats.wantsCount}
                    </p>
                    <span className="text-[10px] text-zinc-400 font-medium">Solicitudes activas</span>
                </div>

                {/* Reportes */}
                <div className="bg-white border border-zinc-200 rounded-xl p-3.5">
                    <div className="flex items-center justify-between text-zinc-500 mb-1.5">
                        <span className="text-[11px] font-semibold">Reportes</span>
                        <AlertCircle size={15} className="text-amber-500" />
                    </div>
                    <p className="text-2xl font-bold text-zinc-900 tracking-tight">
                        {loading ? '...' : stats.reportsCount}
                    </p>
                    <span className="text-[10px] text-zinc-400 font-medium">Casos registrados</span>
                </div>

                {/* Verificaciones */}
                <div className="bg-white border border-zinc-200 rounded-xl p-3.5">
                    <div className="flex items-center justify-between text-zinc-500 mb-1.5">
                        <span className="text-[11px] font-semibold">Verificaciones</span>
                        <UserCheck size={15} className="text-emerald-600" />
                    </div>
                    <p className="text-2xl font-bold text-zinc-900 tracking-tight">
                        {loading ? '...' : stats.verificationsCount}
                    </p>
                    <span className="text-[10px] text-zinc-400 font-medium">Solicitudes totales</span>
                </div>

                {/* Soporte */}
                <div className="bg-white border border-zinc-200 rounded-xl p-3.5">
                    <div className="flex items-center justify-between text-zinc-500 mb-1.5">
                        <span className="text-[11px] font-semibold">Soporte</span>
                        <Headphones size={15} className="text-zinc-700" />
                    </div>
                    <p className="text-2xl font-bold text-zinc-900 tracking-tight">
                        {loading ? '...' : stats.supportCount}
                    </p>
                    <span className="text-[10px] text-zinc-400 font-medium">Tickets de ayuda</span>
                </div>
            </div>

            {/* Dos Columnas Principales: Últimos Usuarios y Últimas Publicaciones */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
                {/* Últimos Usuarios Reales */}
                <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden">
                    <div className="p-4 border-b border-zinc-100 flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <Users size={16} className="text-[#0094FF]" />
                            <h2 className="text-xs font-bold uppercase tracking-wider text-zinc-800">
                                Últimos Usuarios Registrados
                            </h2>
                        </div>
                        <Link to="/admin/users" className="text-xs font-semibold text-[#0094FF] hover:underline flex items-center gap-1">
                            <span>Ver todos</span>
                            <ArrowRight size={12} />
                        </Link>
                    </div>

                    <div className="divide-y divide-zinc-100">
                        {loading ? (
                            <div className="p-6 text-center text-xs text-zinc-400">Cargando usuarios reales...</div>
                        ) : recentUsers.length === 0 ? (
                            <div className="p-6 text-center text-xs text-zinc-400">No hay usuarios registrados aún.</div>
                        ) : (
                            recentUsers.map((user) => (
                                <div key={user.id} className="p-3.5 flex items-center justify-between gap-3 hover:bg-zinc-50/70 transition-colors">
                                    <div className="flex items-center gap-3 overflow-hidden">
                                        {user.photoURL ? (
                                            <img src={user.photoURL} alt="" className="w-8 h-8 rounded-full object-cover border border-zinc-200 flex-shrink-0" />
                                        ) : (
                                            <div className="w-8 h-8 rounded-full bg-zinc-100 text-zinc-600 font-bold text-xs flex items-center justify-center flex-shrink-0 border border-zinc-200">
                                                {(user.displayName || user.email || 'U')[0].toUpperCase()}
                                            </div>
                                        )}
                                        <div className="overflow-hidden">
                                            <p className="text-xs font-semibold text-zinc-900 truncate">
                                                {user.displayName || 'Usuario sin nombre'}
                                            </p>
                                            <p className="text-[11px] text-zinc-500 truncate">
                                                {user.email || 'Sin correo'}
                                            </p>
                                        </div>
                                    </div>
                                    <div className="text-right flex-shrink-0">
                                        <span className="text-[10px] font-mono text-zinc-400">
                                            {formatDate(user.createdAt)}
                                        </span>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                </div>

                {/* Últimas Publicaciones Reales */}
                <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden">
                    <div className="p-4 border-b border-zinc-100 flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <FileText size={16} className="text-[#0094FF]" />
                            <h2 className="text-xs font-bold uppercase tracking-wider text-zinc-800">
                                Publicaciones Recientes
                            </h2>
                        </div>
                        <Link to="/admin/publications" className="text-xs font-semibold text-[#0094FF] hover:underline flex items-center gap-1">
                            <span>Ver todas</span>
                            <ArrowRight size={12} />
                        </Link>
                    </div>

                    <div className="divide-y divide-zinc-100">
                        {loading ? (
                            <div className="p-6 text-center text-xs text-zinc-400">Cargando publicaciones reales...</div>
                        ) : recentPosts.length === 0 ? (
                            <div className="p-6 text-center text-xs text-zinc-400">No hay publicaciones en el catálogo aún.</div>
                        ) : (
                            recentPosts.map((post) => (
                                <div key={post.id} className="p-3.5 flex items-center justify-between gap-3 hover:bg-zinc-50/70 transition-colors">
                                    <div className="overflow-hidden">
                                        <p className="text-xs font-semibold text-zinc-900 truncate">
                                            {post.title || 'Publicación sin título'}
                                        </p>
                                        <div className="flex items-center gap-2 mt-0.5 text-[11px] text-zinc-500">
                                            <span className="font-medium text-[#0094FF] bg-blue-50 px-1.5 py-0.2 rounded text-[10px]">
                                                {post.category || 'General'}
                                            </span>
                                            {post.price !== undefined && (
                                                <span className="font-semibold text-zinc-700">
                                                    ${post.price.toLocaleString()}
                                                </span>
                                            )}
                                        </div>
                                    </div>
                                    <div className="text-right flex-shrink-0">
                                        <span className="text-[10px] font-mono text-zinc-400">
                                            {formatDate(post.createdAt)}
                                        </span>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
};
