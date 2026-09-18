import React, { useState, useEffect, FormEvent } from 'react';
import {
    User,
    Shield,
    Camera,
    Check,
    Lock,
    Mail,
    LogOut,
    CheckCircle2,
    AlertCircle,
    Server,
    Key
} from 'lucide-react';
import {
    auth,
    db,
    updateProfile,
    updatePassword,
    signOut
} from '../services/firebase';
import { doc, getDoc, updateDoc } from 'firebase/firestore';
import toast from 'react-hot-toast';

export const Settings: React.FC = () => {
    const [activeTab, setActiveTab] = useState<'perfil' | 'seguridad' | 'sistema'>('perfil');
    const [name, setName] = useState(auth.currentUser?.displayName || '');
    const [photoURL, setPhotoURL] = useState(auth.currentUser?.photoURL || '');
    const [email] = useState(auth.currentUser?.email || '');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        const fetchUserData = async () => {
            if (auth.currentUser) {
                try {
                    const userDoc = await getDoc(doc(db, 'users', auth.currentUser.uid));
                    if (userDoc.exists()) {
                        const data = userDoc.data();
                        setName(data.displayName || auth.currentUser.displayName || '');
                        setPhotoURL(data.photoURL || auth.currentUser.photoURL || '');
                    }
                } catch (error) {
                    console.error('Error fetching user data:', error);
                }
            }
        };
        fetchUserData();
    }, []);

    const handleUpdateProfile = async (e: FormEvent) => {
        e.preventDefault();
        if (!auth.currentUser) return;
        setLoading(true);
        try {
            await updateProfile(auth.currentUser, {
                displayName: name.trim(),
                photoURL: photoURL.trim()
            });
            await updateDoc(doc(db, 'users', auth.currentUser.uid), {
                displayName: name.trim(),
                photoURL: photoURL.trim()
            });
            toast.success('Perfil de administrador actualizado');
        } catch (error: any) {
            toast.error(`Error al actualizar perfil: ${error.message}`);
        } finally {
            setLoading(false);
        }
    };

    const handleChangePassword = async (e: FormEvent) => {
        e.preventDefault();
        if (newPassword !== confirmPassword) {
            toast.error('Las contraseñas no coinciden');
            return;
        }
        if (newPassword.length < 6) {
            toast.error('La contraseña debe tener al menos 6 caracteres');
            return;
        }
        if (!auth.currentUser) return;

        setLoading(true);
        try {
            await updatePassword(auth.currentUser, newPassword);
            toast.success('Contraseña actualizada correctamente');
            setNewPassword('');
            setConfirmPassword('');
        } catch (error: any) {
            toast.error('Error al cambiar contraseña. Vuelve a iniciar sesión para validar credenciales.');
        } finally {
            setLoading(false);
        }
    };

    const handleSignOut = async () => {
        if (!window.confirm('¿Seguro que deseas cerrar la sesión administrativa?')) return;
        try {
            await signOut(auth);
            toast.success('Sesión cerrada');
        } catch (error) {
            console.error('Error signing out:', error);
        }
    };

    return (
        <div className="space-y-5 max-w-4xl">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-200 pb-4">
                <div>
                    <h1 className="text-xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
                        <Shield size={20} className="text-[#0094FF]" />
                        Configuración de la Cuenta
                    </h1>
                    <p className="text-xs text-slate-500 mt-0.5">
                        Perfil administrativo, credenciales de acceso y preferencias del sistema
                    </p>
                </div>

                <button
                    onClick={handleSignOut}
                    className="btn-danger flex items-center gap-1.5 self-start sm:self-auto"
                >
                    <LogOut size={13} />
                    <span>Cerrar Sesión</span>
                </button>
            </div>

            {/* Navigation Tabs */}
            <div className="flex items-center gap-1 border-b border-slate-200">
                <button
                    onClick={() => setActiveTab('perfil')}
                    className={`px-3 py-2 text-xs font-semibold border-b-2 transition-colors flex items-center gap-1.5 ${
                        activeTab === 'perfil'
                            ? 'border-[#0094FF] text-[#0094FF]'
                            : 'border-transparent text-slate-500 hover:text-slate-800'
                    }`}
                >
                    <User size={13} />
                    <span>Perfil de Administrador</span>
                </button>
                <button
                    onClick={() => setActiveTab('seguridad')}
                    className={`px-3 py-2 text-xs font-semibold border-b-2 transition-colors flex items-center gap-1.5 ${
                        activeTab === 'seguridad'
                            ? 'border-[#0094FF] text-[#0094FF]'
                            : 'border-transparent text-slate-500 hover:text-slate-800'
                    }`}
                >
                    <Lock size={13} />
                    <span>Seguridad & Contraseña</span>
                </button>
                <button
                    onClick={() => setActiveTab('sistema')}
                    className={`px-3 py-2 text-xs font-semibold border-b-2 transition-colors flex items-center gap-1.5 ${
                        activeTab === 'sistema'
                            ? 'border-[#0094FF] text-[#0094FF]'
                            : 'border-transparent text-slate-500 hover:text-slate-800'
                    }`}
                >
                    <Server size={13} />
                    <span>Estado del Sistema</span>
                </button>
            </div>

            {/* Tab: Perfil */}
            {activeTab === 'perfil' && (
                <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
                    {/* User summary card */}
                    <div className="bg-white border border-slate-200 rounded-lg p-5 flex flex-col items-center text-center">
                        <div className="w-20 h-20 rounded-full overflow-hidden border-2 border-slate-200 bg-slate-100 mb-3 flex items-center justify-center">
                            {photoURL ? (
                                <img src={photoURL} alt="Avatar" className="w-full h-full object-cover" />
                            ) : (
                                <User size={36} className="text-slate-400" />
                            )}
                        </div>
                        <p className="font-bold text-slate-900 text-sm">{name || 'Administrador CONNECT'}</p>
                        <p className="text-xs text-slate-500 font-mono mt-0.5">{email}</p>
                        <span className="mt-3 px-2 py-0.5 bg-blue-50 text-[#0094FF] text-[10px] font-bold uppercase rounded-md border border-blue-200">
                            Super Administrador
                        </span>
                    </div>

                    {/* Edit Form */}
                    <div className="md:col-span-2 bg-white border border-slate-200 rounded-lg p-5">
                        <h2 className="text-sm font-bold text-slate-900 mb-4 pb-2 border-b border-slate-100">
                            Editar Información Personal
                        </h2>
                        <form onSubmit={handleUpdateProfile} className="space-y-4">
                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    Nombre Público
                                </label>
                                <input
                                    type="text"
                                    value={name}
                                    onChange={(e) => setName(e.target.value)}
                                    className="input-clean w-full text-xs"
                                    placeholder="Tu nombre completo"
                                />
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    Correo Electrónico (Solo Lectura)
                                </label>
                                <input
                                    type="email"
                                    disabled
                                    value={email}
                                    className="input-clean w-full text-xs bg-slate-50 text-slate-500 cursor-not-allowed"
                                />
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    URL de la Foto de Perfil
                                </label>
                                <input
                                    type="url"
                                    value={photoURL}
                                    onChange={(e) => setPhotoURL(e.target.value)}
                                    placeholder="https://..."
                                    className="input-clean w-full text-xs font-mono"
                                />
                            </div>

                            <div className="pt-2 flex justify-end">
                                <button
                                    type="submit"
                                    disabled={loading}
                                    className="btn-primary text-xs"
                                >
                                    {loading ? 'Guardando...' : 'Guardar Cambios'}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Tab: Seguridad */}
            {activeTab === 'seguridad' && (
                <div className="bg-white border border-slate-200 rounded-lg p-5 max-w-xl">
                    <h2 className="text-sm font-bold text-slate-900 mb-1">Cambiar Contraseña de Acceso</h2>
                    <p className="text-xs text-slate-500 mb-4 pb-3 border-b border-slate-100">
                        Asegúrate de utilizar una contraseña segura con al menos 6 caracteres.
                    </p>

                    <form onSubmit={handleChangePassword} className="space-y-4">
                        <div>
                            <label className="block text-xs font-semibold text-slate-700 mb-1">
                                Nueva Contraseña
                            </label>
                            <input
                                type="password"
                                required
                                value={newPassword}
                                onChange={(e) => setNewPassword(e.target.value)}
                                placeholder="••••••••"
                                className="input-clean w-full text-xs font-mono"
                            />
                        </div>

                        <div>
                            <label className="block text-xs font-semibold text-slate-700 mb-1">
                                Confirmar Nueva Contraseña
                            </label>
                            <input
                                type="password"
                                required
                                value={confirmPassword}
                                onChange={(e) => setConfirmPassword(e.target.value)}
                                placeholder="••••••••"
                                className="input-clean w-full text-xs font-mono"
                            />
                        </div>

                        <div className="pt-2 flex justify-end">
                            <button
                                type="submit"
                                disabled={loading}
                                className="btn-primary text-xs"
                            >
                                {loading ? 'Actualizando...' : 'Actualizar Contraseña'}
                            </button>
                        </div>
                    </form>
                </div>
            )}

            {/* Tab: Sistema */}
            {activeTab === 'sistema' && (
                <div className="bg-white border border-slate-200 rounded-lg p-5 space-y-4 max-w-2xl">
                    <h2 className="text-sm font-bold text-slate-900 pb-2 border-b border-slate-100">
                        Información del Entorno
                    </h2>

                    <div className="grid grid-cols-2 gap-4 text-xs">
                        <div className="p-3 bg-slate-50 border border-slate-200 rounded-lg">
                            <span className="text-slate-500 font-medium">Plataforma:</span>
                            <p className="font-bold text-slate-800 mt-0.5">CONNECT Web Admin Panel</p>
                        </div>
                        <div className="p-3 bg-slate-50 border border-slate-200 rounded-lg">
                            <span className="text-slate-500 font-medium">Versión:</span>
                            <p className="font-bold text-slate-800 mt-0.5">v2.4.0 (Septiembre 2026)</p>
                        </div>
                        <div className="p-3 bg-slate-50 border border-slate-200 rounded-lg">
                            <span className="text-slate-500 font-medium">Motor de Datos:</span>
                            <p className="font-bold text-slate-800 mt-0.5 flex items-center gap-1.5">
                                <span className="w-2 h-2 rounded-full bg-emerald-500" />
                                Google Cloud Firestore (Live)
                            </p>
                        </div>
                        <div className="p-3 bg-slate-50 border border-slate-200 rounded-lg">
                            <span className="text-slate-500 font-medium">Autenticación:</span>
                            <p className="font-bold text-slate-800 mt-0.5 flex items-center gap-1.5">
                                <span className="w-2 h-2 rounded-full bg-emerald-500" />
                                Firebase Authentication
                            </p>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
