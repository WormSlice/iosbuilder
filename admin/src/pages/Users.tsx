import React, { useEffect, useState } from 'react';
import { collection, query, limit, onSnapshot, doc, updateDoc, deleteDoc } from 'firebase/firestore';
import { db } from '../services/firebase';
import {
    Search,
    Users as UsersIcon,
    Shield,
    CheckCircle,
    XCircle,
    UserX,
    Trash2,
    Eye,
    RefreshCw,
    X,
    Filter
} from 'lucide-react';
import toast from 'react-hot-toast';

interface UserData {
    uid: string;
    email?: string;
    displayName?: string;
    photoURL?: string;
    role?: string;
    createdAt?: any;
    status?: 'active' | 'suspended';
    isVerified?: boolean;
    phone?: string;
}

export const Users: React.FC = () => {
    const [users, setUsers] = useState<UserData[]>([]);
    const [loading, setLoading] = useState<boolean>(true);
    const [searchTerm, setSearchTerm] = useState<string>('');
    const [selectedUser, setSelectedUser] = useState<UserData | null>(null);
    const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'suspended'>('all');

    useEffect(() => {
        const q = query(collection(db, 'users'), limit(100));

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const docs = snapshot.docs.map((docSnap) => ({
                uid: docSnap.id,
                ...docSnap.data()
            })) as UserData[];
            setUsers(docs);
            setLoading(false);
        }, (err) => {
            console.error('Error al escuchar usuarios:', err);
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    const handleToggleStatus = async (user: UserData) => {
        const newStatus = user.status === 'suspended' ? 'active' : 'suspended';
        const actionText = newStatus === 'suspended' ? 'suspender' : 'activar';
        if (!window.confirm(`¿Estás seguro de que deseas ${actionText} la cuenta de ${user.displayName || user.email}?`)) return;

        try {
            await updateDoc(doc(db, 'users', user.uid), { status: newStatus });
            toast.success(`Usuario ${newStatus === 'suspended' ? 'suspendido' : 'activado'}`);
        } catch (error: any) {
            toast.error(`Error al actualizar estado: ${error.message}`);
        }
    };

    const handleToggleVerification = async (user: UserData) => {
        const nextVerified = !user.isVerified;
        try {
            await updateDoc(doc(db, 'users', user.uid), { isVerified: nextVerified });
            toast.success(`Verificación ${nextVerified ? 'otorgada' : 'retirada'}`);
        } catch (error: any) {
            toast.error(`Error al cambiar verificación: ${error.message}`);
        }
    };

    const formatDate = (timestamp: any) => {
        if (!timestamp) return 'No registrado';
        try {
            if (timestamp.toDate) return timestamp.toDate().toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' });
            if (timestamp.seconds) return new Date(timestamp.seconds * 1000).toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' });
            return new Date(timestamp).toLocaleDateString('es-ES', { day: '2-digit', month: 'short', year: 'numeric' });
        } catch {
            return 'No registrado';
        }
    };

    const filteredUsers = users.filter(user => {
        const matchesSearch = (
            user.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            user.displayName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            user.uid.toLowerCase().includes(searchTerm.toLowerCase())
        );
        if (statusFilter === 'active') return matchesSearch && user.status !== 'suspended';
        if (statusFilter === 'suspended') return matchesSearch && user.status === 'suspended';
        return matchesSearch;
    });

    return (
        <div className="space-y-5">
            {/* Header y Buscador Compacto */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-zinc-200">
                <div>
                    <h1 className="text-xl font-bold text-zinc-900 tracking-tight">Usuarios Registrados</h1>
                    <p className="text-xs text-zinc-500">Gestión de cuentas, estado de suspensión y verificación oficial</p>
                </div>

                <div className="flex items-center gap-2">
                    <span className="text-xs font-semibold text-zinc-500 bg-white border border-zinc-200 px-2.5 py-1 rounded-lg">
                        Total: {users.length}
                    </span>
                </div>
            </div>

            {/* Barra de Filtros y Búsqueda */}
            <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 bg-white p-3 rounded-xl border border-zinc-200">
                <div className="relative flex-1 max-w-md">
                    <input
                        type="text"
                        placeholder="Buscar por nombre, correo o UID..."
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
                    {(['all', 'active', 'suspended'] as const).map((filter) => (
                        <button
                            key={filter}
                            onClick={() => setStatusFilter(filter)}
                            className={`px-3 py-1 text-xs font-semibold rounded-lg transition-colors capitalize ${
                                statusFilter === filter
                                    ? 'bg-zinc-900 text-white'
                                    : 'bg-zinc-100 hover:bg-zinc-200 text-zinc-600'
                            }`}
                        >
                            {filter === 'all' ? 'Todos' : filter === 'active' ? 'Activos' : 'Suspendidos'}
                        </button>
                    ))}
                </div>
            </div>

            {/* Tabla Plana de Usuarios */}
            <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table-clean">
                        <thead>
                            <tr>
                                <th>Usuario</th>
                                <th>Identificador (UID)</th>
                                <th>Rol</th>
                                <th>Verificado</th>
                                <th>Estado</th>
                                <th>Registro</th>
                                <th className="text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-8 text-zinc-400">
                                        Cargando usuarios reales de la base de datos...
                                    </td>
                                </tr>
                            ) : filteredUsers.length === 0 ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-8 text-zinc-400">
                                        No se encontraron usuarios que coincidan con la búsqueda.
                                    </td>
                                </tr>
                            ) : (
                                filteredUsers.map((user) => (
                                    <tr key={user.uid}>
                                        <td>
                                            <div className="flex items-center gap-2.5">
                                                {user.photoURL ? (
                                                    <img src={user.photoURL} alt="" className="w-8 h-8 rounded-full object-cover border border-zinc-200 flex-shrink-0" />
                                                ) : (
                                                    <div className="w-8 h-8 rounded-full bg-zinc-100 text-zinc-700 font-bold text-xs flex items-center justify-center flex-shrink-0 border border-zinc-200">
                                                        {(user.displayName || user.email || 'U')[0].toUpperCase()}
                                                    </div>
                                                )}
                                                <div className="overflow-hidden">
                                                    <div className="font-semibold text-zinc-900 truncate flex items-center gap-1.5">
                                                        <span>{user.displayName || 'Sin nombre'}</span>
                                                        {user.isVerified && (
                                                            <span className="text-[#0094FF] text-[11px]" title="Verificado Oficial">●</span>
                                                        )}
                                                    </div>
                                                    <div className="text-[11px] text-zinc-500 truncate">{user.email || 'Sin correo'}</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td>
                                            <span className="font-mono text-[10px] text-zinc-500 bg-zinc-50 px-1.5 py-0.5 rounded border border-zinc-200">
                                                {user.uid.substring(0, 12)}...
                                            </span>
                                        </td>
                                        <td>
                                            <span className="text-[11px] font-medium text-zinc-600">
                                                {user.role || 'Usuario'}
                                            </span>
                                        </td>
                                        <td>
                                            <button
                                                onClick={() => handleToggleVerification(user)}
                                                className={`px-2 py-0.5 rounded text-[10px] font-bold transition-colors ${
                                                    user.isVerified
                                                        ? 'bg-blue-50 text-[#0094FF] border border-blue-200 hover:bg-blue-100'
                                                        : 'bg-zinc-100 text-zinc-500 hover:bg-zinc-200'
                                                }`}
                                            >
                                                {user.isVerified ? 'Verificado' : 'No verificado'}
                                            </button>
                                        </td>
                                        <td>
                                            <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-bold ${
                                                user.status === 'suspended'
                                                    ? 'bg-red-50 text-red-600 border border-red-200'
                                                    : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                            }`}>
                                                <span className={`w-1.5 h-1.5 rounded-full ${user.status === 'suspended' ? 'bg-red-500' : 'bg-emerald-500'}`} />
                                                <span>{user.status === 'suspended' ? 'Suspendido' : 'Activo'}</span>
                                            </span>
                                        </td>
                                        <td>
                                            <span className="text-[11px] text-zinc-500">
                                                {formatDate(user.createdAt)}
                                            </span>
                                        </td>
                                        <td className="text-right">
                                            <div className="inline-flex items-center gap-1.5">
                                                <button
                                                    onClick={() => setSelectedUser(user)}
                                                    className="btn-outline px-2 py-1"
                                                    title="Ver Ficha Completa"
                                                >
                                                    <Eye size={12} />
                                                    <span>Detalles</span>
                                                </button>
                                                <button
                                                    onClick={() => handleToggleStatus(user)}
                                                    className={`px-2 py-1 rounded-lg text-xs font-semibold transition-colors ${
                                                        user.status === 'suspended'
                                                            ? 'bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200'
                                                            : 'btn-danger'
                                                    }`}
                                                >
                                                    {user.status === 'suspended' ? 'Activar' : 'Suspender'}
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

            {/* Modal de Detalle de Usuario */}
            {selectedUser && (
                <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
                    <div className="bg-white rounded-xl border border-zinc-200 max-w-lg w-full p-5 space-y-4 shadow-xl">
                        <div className="flex items-center justify-between pb-3 border-b border-zinc-200">
                            <h3 className="font-bold text-sm text-zinc-900">Detalles de Usuario</h3>
                            <button onClick={() => setSelectedUser(null)} className="text-zinc-400 hover:text-zinc-700">
                                <X size={16} />
                            </button>
                        </div>

                        <div className="space-y-3 text-xs">
                            <div className="flex items-center gap-3">
                                {selectedUser.photoURL ? (
                                    <img src={selectedUser.photoURL} alt="" className="w-12 h-12 rounded-full object-cover border border-zinc-200" />
                                ) : (
                                    <div className="w-12 h-12 rounded-full bg-zinc-100 text-zinc-700 font-bold text-sm flex items-center justify-center border border-zinc-200">
                                        {(selectedUser.displayName || selectedUser.email || 'U')[0].toUpperCase()}
                                    </div>
                                )}
                                <div>
                                    <p className="font-bold text-sm text-zinc-900">{selectedUser.displayName || 'Sin nombre'}</p>
                                    <p className="text-zinc-500">{selectedUser.email}</p>
                                </div>
                            </div>

                            <div className="grid grid-cols-2 gap-2 pt-2 border-t border-zinc-100">
                                <div>
                                    <span className="text-zinc-400 block text-[10px] uppercase font-bold">UID</span>
                                    <span className="font-mono text-zinc-700 select-all">{selectedUser.uid}</span>
                                </div>
                                <div>
                                    <span className="text-zinc-400 block text-[10px] uppercase font-bold">Fecha de Registro</span>
                                    <span className="text-zinc-700">{formatDate(selectedUser.createdAt)}</span>
                                </div>
                                <div>
                                    <span className="text-zinc-400 block text-[10px] uppercase font-bold">Rol</span>
                                    <span className="text-zinc-700">{selectedUser.role || 'Usuario estándar'}</span>
                                </div>
                                <div>
                                    <span className="text-zinc-400 block text-[10px] uppercase font-bold">Teléfono</span>
                                    <span className="text-zinc-700">{selectedUser.phone || 'No especificado'}</span>
                                </div>
                            </div>
                        </div>

                        <div className="flex justify-end pt-3 border-t border-zinc-200">
                            <button onClick={() => setSelectedUser(null)} className="btn-outline">
                                Cerrar
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
