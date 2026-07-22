import React, { useEffect, useState } from 'react';
import { collection, query, limit, onSnapshot, doc, updateDoc } from 'firebase/firestore';
import { db } from '../services/firebase';
import {
    Search,
    Users as UsersIcon,
    Zap,
    Activity,
    Trash2,
    Clock
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
                            className="pl-12 pr-6 py-3 bg-zinc-50 border border-zinc-100 rounded-2xl text-xs w-64 focus:border-black focus:bg-white transition-all outline-none"
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                        />
                    </div>
                    <button className="bg-black text-white px-6 py-3 rounded-2xl text-[10px] font-black uppercase tracking-widest flex items-center gap-2 hover:scale-[1.02] active:scale-[0.98] transition-all shadow-lg shadow-black/10">
                        <UsersIcon size={14} /> Exportar
                    </button>
                </div>
            </div>

            <div className="bg-white border border-zinc-100 rounded-[2.5rem] overflow-hidden shadow-sm">
                <table className="w-full text-left">
                    <thead>
                        <tr className="bg-zinc-50 text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400">
                            <th className="px-10 py-6 border-b border-zinc-100">Perfil</th>
                            <th className="px-10 py-6 border-b border-zinc-100">Identificador</th>
                            <th className="px-10 py-6 border-b border-zinc-100">Estatus</th>
                            <th className="px-10 py-6 border-b border-zinc-100 text-right">Acciones</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-zinc-50">
                        {loading ? (
                            <tr>
                                <td colSpan={4} className="px-10 py-40 text-center">
                                    <div className="w-8 h-8 border-2 border-black border-t-transparent rounded-full animate-spin mx-auto"></div>
                                </td>
                            </tr>
                        ) : filteredUsers.map((user) => (
                            <tr key={user.uid} className="hover:bg-zinc-50/50 transition-all group">
                                <td className="px-10 py-6">
                                    <div className="flex items-center gap-4">
                                        <div className="w-10 h-10 rounded-2xl bg-zinc-100 border border-zinc-200 overflow-hidden shadow-sm group-hover:rotate-2 transition-transform flex items-center justify-center">
                                            {user.photoURL ? (
                                                <img src={user.photoURL} className="w-full h-full object-cover" />
                                            ) : (
                                                <span className="font-bold text-black uppercase">{user.email?.[0]}</span>
                                            )}
                                        </div>
                                        <div>
                                            <span className="font-bold text-sm tracking-tight block leading-none">{user.displayName || 'Usuario CONNECT'}</span>
                                            <span className="text-[10px] text-zinc-400 font-medium uppercase tracking-tighter">Customer</span>
                                        </div>
                                    </div>
                                </td>
                                <td className="px-10 py-6">
                                    <p className="text-[11px] font-mono text-zinc-400">{user.email}</p>
                                </td>
                                <td className="px-10 py-6">
                                    <div className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-wider ${user.isVerified ? 'bg-black text-white' : 'bg-zinc-100 text-zinc-400'
                                        }`}>
                                        {user.isVerified && <Zap size={10} />}
                                        {user.isVerified ? 'Verificado' : 'Normal'}
                                    </div>
                                </td>
                                <td className="px-10 py-6 text-right relative">
                                    <div className="flex items-center justify-end gap-2">
                                        <button
                                            onClick={() => setEditingUser(editingUser === user.uid ? null : user.uid)}
                                            className={`p-3 rounded-xl transition-all ${editingUser === user.uid ? 'bg-black text-white' : 'bg-zinc-50 text-zinc-400 hover:text-black hover:bg-zinc-100'}`}
                                            title="Opciones"
                                        >
                                            <Zap size={16} />
                                        </button>
                                        <button
                                            onClick={() => handleSuspend(user.uid, user.status)}
                                            className={`p-3 rounded-xl transition-all ${user.status === 'suspended'
                                                ? 'bg-red-50 text-red-600'
                                                : 'bg-zinc-50 text-zinc-400 hover:text-red-500 hover:bg-red-50'
                                                }`}
                                            title={user.status === 'suspended' ? 'Activar' : 'Suspender'}
                                        >
                                            <Activity size={16} />
                                        </button>
                                    </div>

                                    {editingUser === user.uid && (
                                        <div className="absolute right-10 top-20 w-48 bg-white border border-zinc-100 rounded-3xl shadow-2xl z-50 p-2 animate-in zoom-in duration-200">
                                            {[
                                                { label: 'Ver Perfil', icon: <UsersIcon size={14} />, action: () => alert('Ver: ' + user.email) },
                                                { label: 'Verificar Email', icon: <Zap size={14} />, action: () => alert('Verificando: ' + user.email) },
                                                { label: 'Cambiar Rol', icon: <UsersIcon size={14} />, action: () => alert('Cambiando rol...') },
                                                { label: 'Eliminar', icon: <Trash2 size={14} />, action: () => alert('Eliminar: ' + user.email), color: 'text-red-500' },
                                            ].map((opt, i) => (
                                                <button
                                                    key={i}
                                                    onClick={() => { opt.action(); setEditingUser(null); }}
                                                    className={`w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-[10px] font-black uppercase tracking-widest hover:bg-zinc-50 transition-all ${opt.color || 'text-zinc-600'}`}
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
                    <div className="py-40 text-center space-y-4">
                        <div className="w-12 h-12 bg-zinc-50 rounded-full flex items-center justify-center mx-auto text-zinc-300">
                            <Trash2 size={24} />
                        </div>
                        <p className="text-zinc-300 text-[10px] font-black uppercase tracking-widest">No hay registros coincidentes</p>
                    </div>
                )}
            </div>
        </div>
    );
};
