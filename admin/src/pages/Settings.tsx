import React, { useState, useEffect, FormEvent } from 'react';
import {
    User,
    Shield,
    Camera,
    Check,
    ChevronRight,
    Lock,
    Mail,
    Smartphone,
    LogOut
} from 'lucide-react';
import {
    auth,
    db,
    updateProfile,
    updatePassword,
    signOut
} from '../services/firebase';
import { doc, getDoc, updateDoc } from 'firebase/firestore';
import { motion, AnimatePresence } from 'framer-motion';

export const Settings: React.FC = () => {
    const [activeTab, setActiveTab] = useState<'perfil' | 'seguridad'>('perfil');
    const [name, setName] = useState(auth.currentUser?.displayName || '');
    const [photoURL, setPhotoURL] = useState(auth.currentUser?.photoURL || '');
    const [email] = useState(auth.currentUser?.email || '');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [loading, setLoading] = useState(false);
    const [message, setMessage] = useState<{ type: 'success' | 'error', text: string } | null>(null);

    useEffect(() => {
        const fetchUserData = async () => {
            if (auth.currentUser) {
                try {
                    const userDoc = await getDoc(doc(db, 'users', auth.currentUser.uid));
                    if (userDoc.exists()) {
                        setName(userDoc.data().displayName || '');
                        setPhotoURL(userDoc.data().photoURL || '');
                    }
                } catch (error) {
                    console.error("Error fetching user data:", error);
                }
            }
        };
        fetchUserData();
    }, []);

    const handleUpdateProfile = async (e: FormEvent) => {
        e.preventDefault();
        if (!auth.currentUser) return;
        setLoading(true);
        setMessage(null);
        try {
            await updateProfile(auth.currentUser, {
                displayName: name,
                photoURL: photoURL
            });
            await updateDoc(doc(db, 'users', auth.currentUser.uid), {
                displayName: name,
                photoURL: photoURL
            });
            setMessage({ type: 'success', text: 'Perfil actualizado correctamente' });
        } catch (error) {
            setMessage({ type: 'error', text: 'Error al actualizar el perfil' });
        } finally {
            setLoading(false);
        }
    };

    const handleChangePassword = async (e: FormEvent) => {
        e.preventDefault();
        if (newPassword !== confirmPassword) {
            setMessage({ type: 'error', text: 'Las contraseñas no coinciden' });
            return;
        }
        if (!auth.currentUser) return;
        setLoading(true);
        setMessage(null);
        try {
            await updatePassword(auth.currentUser, newPassword);
            setMessage({ type: 'success', text: 'Contraseña actualizada correctamente' });
            setNewPassword('');
            setConfirmPassword('');
        } catch (error) {
            setMessage({ type: 'error', text: 'Error al cambiar la contraseña. Reintenta iniciando sesión nuevamente.' });
        } finally {
            setLoading(false);
        }
    };

    const handleSignOut = async () => {
        try {
            await signOut(auth);
        } catch (error) {
            console.error('Error signing out:', error);
        }
    };

    return (
        <div className="p-6 max-w-4xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 border-b border-white/[0.04] pb-8">
                <div>
                    <h1 className="text-2xl md:text-3xl font-black font-archivo tracking-tight uppercase text-white">Configuración</h1>
                    <p className="text-[10px] font-black uppercase tracking-[0.2em] text-[#0094FF] mt-1">Gestión de Cuenta y Seguridad</p>
                </div>
                <button
                    onClick={handleSignOut}
                    className="flex items-center gap-2 px-4 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-500 rounded-xl transition-all font-black text-[10px] uppercase tracking-widest border border-red-500/20"
                >
                    <LogOut size={14} />
                    Cerrar Sesión
                </button>
            </div>

            {/* Navigation Tabs */}
            <div className="flex gap-2 p-1 bg-white/[0.02] border border-white/[0.04] rounded-2xl w-fit">
                <button
                    onClick={() => setActiveTab('perfil')}
                    className={`px-6 py-2.5 rounded-xl font-black text-[10px] uppercase tracking-widest transition-all ${activeTab === 'perfil'
                        ? 'bg-[#0094FF] text-white shadow-[0_0_20px_rgba(0,148,255,0.3)]'
                        : 'text-zinc-500 hover:text-white hover:bg-white/[0.03]'
                        }`}
                >
                    Perfil
                </button>
                <button
                    onClick={() => setActiveTab('seguridad')}
                    className={`px-6 py-2.5 rounded-xl font-black text-[10px] uppercase tracking-widest transition-all ${activeTab === 'seguridad'
                        ? 'bg-[#0094FF] text-white shadow-[0_0_20px_rgba(0,148,255,0.3)]'
                        : 'text-zinc-500 hover:text-white hover:bg-white/[0.03]'
                        }`}
                >
                    Seguridad
                </button>
            </div>

            <AnimatePresence mode="wait">
                {activeTab === 'perfil' ? (
                    <motion.div
                        key="perfil"
                        initial={{ opacity: 0, x: -20 }}
                        animate={{ opacity: 1, x: 0 }}
                        exit={{ opacity: 0, x: 20 }}
                        className="grid grid-cols-1 md:grid-cols-3 gap-8"
                    >
                        {/* Avatar Section */}
                        <div className="md:col-span-1 space-y-6">
                            <div className="relative group">
                                <div className="aspect-square rounded-[2rem] overflow-hidden border-2 border-white/[0.08] relative mb-4">
                                    {photoURL ? (
                                        <img src={photoURL} alt="Profile" className="w-full h-full object-cover" />
                                    ) : (
                                        <div className="w-full h-full bg-zinc-900 flex items-center justify-center text-zinc-500">
                                            <User size={48} strokeWidth={1} />
                                        </div>
                                    )}
                                    <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center cursor-pointer">
                                        <Camera className="text-white" size={24} />
                                    </div>
                                </div>
                                <div className="text-center">
                                    <p className="text-[10px] font-black text-white uppercase tracking-wider mb-1">{name || 'Sin Nombre'}</p>
                                    <p className="text-[9px] text-zinc-600 font-bold uppercase tracking-widest truncate">{email}</p>
                                </div>
                            </div>
                        </div>

                        {/* Form Section */}
                        <div className="md:col-span-2">
                            <form onSubmit={handleUpdateProfile} className="space-y-6 bg-white/[0.02] border border-white/[0.04] p-6 md:p-8 rounded-[2rem]">
                                <div className="space-y-4">
                                    <div className="grid grid-cols-1 gap-4">
                                        <div className="space-y-2">
                                            <label className="text-[9px] font-black text-zinc-500 uppercase tracking-[0.2em] ml-1">Nombre Público</label>
                                            <div className="relative">
                                                <User className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-600" size={16} />
                                                <input
                                                    type="text"
                                                    value={name}
                                                    onChange={(e) => setName(e.target.value)}
                                                    className="w-full bg-black/40 border border-white/[0.08] rounded-2xl py-4 pl-12 pr-4 text-xs font-bold text-white focus:outline-none focus:border-[#0094FF] transition-all placeholder:text-zinc-800"
                                                    placeholder="Tu nombre administrativo"
                                                />
                                            </div>
                                        </div>
                                        <div className="space-y-2">
                                            <label className="text-[9px] font-black text-zinc-500 uppercase tracking-[0.2em] ml-1">URL de Avatar</label>
                                            <div className="relative">
                                                <Camera className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-600" size={16} />
                                                <input
                                                    type="text"
                                                    value={photoURL}
                                                    onChange={(e) => setPhotoURL(e.target.value)}
                                                    className="w-full bg-black/40 border border-white/[0.08] rounded-2xl py-4 pl-12 pr-4 text-xs font-bold text-white focus:outline-none focus:border-[#0094FF] transition-all placeholder:text-zinc-800"
                                                    placeholder="https://instancia.com/mi-foto.jpg"
                                                />
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                {message && (
                                    <div className={`p-4 rounded-xl text-[10px] font-bold uppercase tracking-widest flex items-center gap-3 ${message.type === 'success' ? 'bg-green-500/10 text-green-500 border border-green-500/20' : 'bg-red-500/10 text-red-500 border border-red-500/20'
                                        }`}>
                                        <Check size={14} />
                                        {message.text}
                                    </div>
                                )}

                                <button
                                    type="submit"
                                    disabled={loading}
                                    className="w-full bg-[#0094FF] text-white py-4 rounded-2xl font-black text-[10px] uppercase tracking-[0.2em] hover:shadow-[0_0_30px_rgba(0,148,255,0.4)] hover:brightness-110 transition-all disabled:opacity-50 active:scale-[0.98] shadow-lg"
                                >
                                    {loading ? 'Sincronizando...' : 'Guardar Cambios'}
                                </button>
                            </form>
                        </div>
                    </motion.div>
                ) : (
                    <motion.div
                        key="seguridad"
                        initial={{ opacity: 0, x: 20 }}
                        animate={{ opacity: 1, x: 0 }}
                        exit={{ opacity: 0, x: -20 }}
                        className="max-w-2xl mx-auto w-full space-y-8"
                    >
                        <form onSubmit={handleChangePassword} className="space-y-6 bg-white/[0.02] border border-white/[0.04] p-6 md:p-8 rounded-[2rem]">
                            <div className="space-y-4">
                                <h4 className="text-[10px] font-black uppercase tracking-[0.2em] text-[#0094FF] mb-6">Actualizar Credenciales</h4>

                                <div className="space-y-2">
                                    <label className="text-[9px] font-black text-zinc-500 uppercase tracking-[0.2em] ml-1">Nueva Contraseña</label>
                                    <div className="relative">
                                        <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-600" size={16} />
                                        <input
                                            type="password"
                                            value={newPassword}
                                            onChange={(e) => setNewPassword(e.target.value)}
                                            className="w-full bg-black/40 border border-white/[0.08] rounded-2xl py-4 pl-12 pr-4 text-xs font-bold text-white focus:outline-none focus:border-[#0094FF] transition-all placeholder:text-zinc-800"
                                            placeholder="••••••••"
                                        />
                                    </div>
                                </div>

                                <div className="space-y-2">
                                    <label className="text-[9px] font-black text-zinc-500 uppercase tracking-[0.2em] ml-1">Confirmar Contraseña</label>
                                    <div className="relative">
                                        <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-600" size={16} />
                                        <input
                                            type="password"
                                            value={confirmPassword}
                                            onChange={(e) => setConfirmPassword(e.target.value)}
                                            className="w-full bg-black/40 border border-white/[0.08] rounded-2xl py-4 pl-12 pr-4 text-xs font-bold text-white focus:outline-none focus:border-[#0094FF] transition-all placeholder:text-zinc-800"
                                            placeholder="••••••••"
                                        />
                                    </div>
                                </div>
                            </div>

                            {message && (
                                <div className={`p-4 rounded-xl text-[10px] font-bold uppercase tracking-widest flex items-center gap-3 ${message.type === 'success' ? 'bg-green-500/10 text-green-500 border border-green-500/20' : 'bg-red-500/10 text-red-500 border border-red-500/20'
                                    }`}>
                                    <Check size={14} />
                                    {message.text}
                                </div>
                            )}

                            <button
                                type="submit"
                                disabled={loading}
                                className="w-full bg-[#0094FF] text-white py-4 rounded-2xl font-black text-[10px] uppercase tracking-[0.2em] hover:shadow-[0_0_30px_rgba(0,148,255,0.4)] hover:brightness-110 transition-all disabled:opacity-50 active:scale-[0.98] shadow-lg"
                            >
                                {loading ? 'Actualizando...' : 'Cambiar Contraseña'}
                            </button>
                        </form>

                        <div className="pt-6 border-t border-white/[0.04] space-y-6">
                            <h4 className="text-[10px] font-black uppercase tracking-[0.2em] text-[#0094FF]">Seguridad Avanzada</h4>
                            <div className="flex items-center justify-between p-6 bg-white/[0.02] border border-white/[0.04] rounded-[2rem] group hover:bg-white/[0.03] transition-all cursor-not-allowed opacity-60">
                                <div className="flex items-center gap-4">
                                    <div className="w-12 h-12 rounded-2xl bg-zinc-900 flex items-center justify-center text-zinc-600">
                                        <Shield size={20} />
                                    </div>
                                    <div>
                                        <p className="text-[10px] font-black text-white uppercase tracking-wider">MFA (Autenticación Multi-Factor)</p>
                                        <p className="text-[9px] text-zinc-600 font-bold uppercase tracking-widest">Añade una capa extra a tu administración.</p>
                                    </div>
                                </div>
                                <Smartphone size={16} className="text-zinc-800" />
                            </div>
                            <p className="text-[8px] text-zinc-800 font-black uppercase tracking-[0.2em] text-center">La configuración de MFA debe completarse en dispositivos registrados.</p>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};
