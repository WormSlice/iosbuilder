import React, { useState, useEffect, FormEvent } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
    User as UserIcon,
    Shield,
    Lock,
    LogOut,
    Check,
    ArrowLeft,
    Smartphone,
    Mail
} from 'lucide-react';
import {
    auth,
    db,
    updateProfile,
    updatePassword,
    signOut,
    ALLOWED_EMAILS
} from '../services/firebase';
import { doc, getDoc, updateDoc } from 'firebase/firestore';
import toast from 'react-hot-toast';

export const AccountSettings: React.FC = () => {
    const navigate = useNavigate();
    const currentUser = auth.currentUser;

    const [displayName, setDisplayName] = useState(currentUser?.displayName || '');
    const [photoURL, setPhotoURL] = useState(currentUser?.photoURL || '');
    const [email] = useState(currentUser?.email || '');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [loadingProfile, setLoadingProfile] = useState(false);
    const [loadingPassword, setLoadingPassword] = useState(false);
    const [isAdmin, setIsAdmin] = useState(false);

    // 2FA State
    const [twoFactorEnabled, setTwoFactorEnabled] = useState(false);
    const [twoFactorMethod, setTwoFactorMethod] = useState<'sms' | 'email'>('sms');
    const [phoneNumber, setPhoneNumber] = useState('');
    const [saving2FA, setSaving2FA] = useState(false);

    useEffect(() => {
        if (!currentUser) return;
        setIsAdmin(ALLOWED_EMAILS.includes(currentUser.email || ''));

        const loadProfile = async () => {
            try {
                const userDoc = await getDoc(doc(db, 'users', currentUser.uid));
                if (userDoc.exists()) {
                    const data = userDoc.data();
                    if (data?.photoURL && !photoURL) setPhotoURL(data.photoURL);
                    if (data?.displayName && !displayName) setDisplayName(data.displayName);
                    if (data?.twoFactorEnabled !== undefined) setTwoFactorEnabled(data.twoFactorEnabled);
                    if (data?.twoFactorMethod) setTwoFactorMethod(data.twoFactorMethod);
                    if (data?.phone) setPhoneNumber(data.phone);
                }
            } catch (err) {
                console.error('Error fetching profile from Firestore:', err);
            }
        };
        loadProfile();
    }, [currentUser]);

    const handleSave2FASettings = async (e: FormEvent) => {
        e.preventDefault();
        if (!currentUser) return;

        if (twoFactorEnabled && twoFactorMethod === 'sms' && !phoneNumber.trim()) {
            toast.error('Ingresa un número de teléfono con indicativo para activar 2FA por SMS.');
            return;
        }

        setSaving2FA(true);
        try {
            await updateDoc(doc(db, 'users', currentUser.uid), {
                twoFactorEnabled,
                twoFactorMethod,
                phone: phoneNumber.trim() || null
            });
            toast.success('Preferencias de 2FA actualizadas');
        } catch (err: any) {
            toast.error(`Error al actualizar 2FA: ${err.message}`);
        } finally {
            setSaving2FA(false);
        }
    };

    const handleUpdateProfile = async (e: FormEvent) => {
        e.preventDefault();
        if (!currentUser) return;

        setLoadingProfile(true);
        try {
            await updateProfile(currentUser, {
                displayName: displayName.trim(),
                photoURL: photoURL.trim()
            });

            try {
                await updateDoc(doc(db, 'users', currentUser.uid), {
                    displayName: displayName.trim(),
                    photoURL: photoURL.trim()
                });
            } catch (firestoreErr) {
                console.warn('Could not update Firestore user doc:', firestoreErr);
            }

            toast.success('Perfil actualizado correctamente');
        } catch (error: any) {
            toast.error(`Error al actualizar perfil: ${error.message}`);
        } finally {
            setLoadingProfile(false);
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
        if (!currentUser) return;

        setLoadingPassword(true);
        try {
            await updatePassword(currentUser, newPassword);
            toast.success('Contraseña actualizada con éxito');
            setNewPassword('');
            setConfirmPassword('');
        } catch (error: any) {
            toast.error('Error al cambiar contraseña. Por seguridad, vuelve a iniciar sesión para validar tus credenciales.');
        } finally {
            setLoadingPassword(false);
        }
    };

    const handleSignOut = async () => {
        try {
            await signOut(auth);
            toast.success('Sesión finalizada');
            navigate('/');
        } catch (error: any) {
            toast.error('Error al cerrar sesión');
        }
    };

    return (
        <div className="min-h-screen bg-[#07080A] text-white pt-32 pb-24 px-6 md:px-12 selection:bg-[#0094FF] selection:text-white">
            <div className="max-w-2xl mx-auto space-y-12">
                {/* Back button */}
                <Link
                    to="/"
                    className="inline-flex items-center gap-2 text-xs font-semibold text-zinc-400 hover:text-white transition-colors"
                >
                    <ArrowLeft size={14} />
                    <span>Volver al inicio</span>
                </Link>

                {/* Page Title & Profile Snapshot */}
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-6 pb-8 border-b border-white/10">
                    <div className="flex items-center gap-4">
                        <div className="w-16 h-16 rounded-full border border-white/20 bg-zinc-900 overflow-hidden flex items-center justify-center shrink-0">
                            {photoURL ? (
                                <img src={photoURL} alt="Avatar" className="w-full h-full object-cover" />
                            ) : (
                                <UserIcon size={24} className="text-zinc-500" />
                            )}
                        </div>
                        <div>
                            <h1 className="text-2xl font-bold tracking-tight text-white font-archivo">
                                {displayName || 'Mi Cuenta'}
                            </h1>
                            <p className="text-xs text-zinc-400 font-mono mt-0.5">{email}</p>
                        </div>
                    </div>

                    <div className="flex items-center gap-3">
                        {isAdmin && (
                            <Link
                                to="/admin"
                                className="px-4 py-2 rounded-full bg-[#0094FF] hover:bg-[#0080DE] text-white text-xs font-bold transition-colors inline-flex items-center gap-2"
                            >
                                <Shield size={13} />
                                <span>Panel Admin</span>
                            </Link>
                        )}
                        <button
                            onClick={handleSignOut}
                            className="px-4 py-2 rounded-full border border-red-500/30 text-red-400 hover:bg-red-500/10 text-xs font-semibold transition-colors inline-flex items-center gap-1.5 cursor-pointer"
                        >
                            <LogOut size={13} />
                            <span>Cerrar Sesión</span>
                        </button>
                    </div>
                </div>

                {/* Section 1: Edit Profile */}
                <section className="space-y-6">
                    <div>
                        <h2 className="text-lg font-bold text-white tracking-tight">Datos del Perfil</h2>
                        <p className="text-xs text-zinc-400 mt-1">
                            Actualiza el nombre público y el avatar que te identifican en CONNECT.
                        </p>
                    </div>

                    <form onSubmit={handleUpdateProfile} className="space-y-5">
                        <div>
                            <label className="block text-xs font-semibold text-zinc-300 mb-2">
                                Nombre Completo
                            </label>
                            <input
                                type="text"
                                value={displayName}
                                onChange={(e) => setDisplayName(e.target.value)}
                                placeholder="Tu nombre"
                                className="w-full bg-[#0E1015] border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-[#0094FF] transition-colors"
                            />
                        </div>

                        <div>
                            <label className="block text-xs font-semibold text-zinc-300 mb-2">
                                URL de Foto de Perfil (Opcional)
                            </label>
                            <input
                                type="url"
                                value={photoURL}
                                onChange={(e) => setPhotoURL(e.target.value)}
                                placeholder="https://..."
                                className="w-full bg-[#0E1015] border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-[#0094FF] transition-colors font-mono text-xs"
                            />
                        </div>

                        <div>
                            <label className="block text-xs font-semibold text-zinc-400 mb-2">
                                Correo Registrado (Solo Lectura)
                            </label>
                            <input
                                type="email"
                                value={email}
                                disabled
                                className="w-full bg-white/[0.03] border border-white/5 rounded-xl px-4 py-3 text-sm text-zinc-500 font-mono text-xs cursor-not-allowed"
                            />
                        </div>

                        <button
                            type="submit"
                            disabled={loadingProfile}
                            className="bg-white hover:bg-zinc-200 text-zinc-950 text-xs font-bold px-6 py-3 rounded-full inline-flex items-center gap-2 transition-colors cursor-pointer disabled:opacity-50"
                        >
                            <Check size={14} />
                            <span>{loadingProfile ? 'Guardando...' : 'Guardar Cambios'}</span>
                        </button>
                    </form>
                </section>

                <hr className="border-white/10" />

                {/* Section 2: Security & Password */}
                <section className="space-y-6">
                    <div>
                        <h2 className="text-lg font-bold text-white tracking-tight">Seguridad & Contraseña</h2>
                        <p className="text-xs text-zinc-400 mt-1">
                            Si ingresas mediante correo y contraseña, puedes renovar tu clave de acceso aquí.
                        </p>
                    </div>

                    <form onSubmit={handleChangePassword} className="space-y-5">
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <div>
                                <label className="block text-xs font-semibold text-zinc-300 mb-2">
                                    Nueva Contraseña
                                </label>
                                <input
                                    type="password"
                                    value={newPassword}
                                    onChange={(e) => setNewPassword(e.target.value)}
                                    placeholder="Mínimo 6 caracteres"
                                    className="w-full bg-[#0E1015] border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-[#0094FF] transition-colors"
                                />
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-zinc-300 mb-2">
                                    Confirmar Nueva Contraseña
                                </label>
                                <input
                                    type="password"
                                    value={confirmPassword}
                                    onChange={(e) => setConfirmPassword(e.target.value)}
                                    placeholder="Repite la contraseña"
                                    className="w-full bg-[#0E1015] border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-[#0094FF] transition-colors"
                                />
                            </div>
                        </div>

                        <button
                            type="submit"
                            disabled={loadingPassword || !newPassword}
                            className="border border-white/20 hover:border-white/40 text-white text-xs font-bold px-6 py-3 rounded-full inline-flex items-center gap-2 transition-colors cursor-pointer disabled:opacity-30"
                        >
                            <Lock size={14} />
                            <span>{loadingPassword ? 'Actualizando...' : 'Actualizar Contraseña'}</span>
                        </button>
                    </form>
                </section>

                <hr className="border-white/10" />

                {/* Section 3: Two-Factor Authentication (2FA) */}
                <section className="space-y-6">
                    <div className="flex items-center justify-between">
                        <div>
                            <h2 className="text-lg font-bold text-white tracking-tight flex items-center gap-2">
                                <Shield size={18} className="text-[#0094FF]" />
                                <span>Verificación en Dos Pasos (2FA)</span>
                            </h2>
                            <p className="text-xs text-zinc-400 mt-1">
                                Añade una capa de máxima seguridad a tu cuenta en la app móvil y en la web.
                            </p>
                        </div>

                        {/* Switch toggle */}
                        <button
                            type="button"
                            onClick={() => setTwoFactorEnabled(!twoFactorEnabled)}
                            className={`w-12 h-6 rounded-full transition-colors relative cursor-pointer ${
                                twoFactorEnabled ? 'bg-[#0094FF]' : 'bg-white/10'
                            }`}
                        >
                            <div
                                className={`w-4 h-4 rounded-full bg-white absolute top-1 transition-transform ${
                                    twoFactorEnabled ? 'left-7' : 'left-1'
                                }`}
                            />
                        </button>
                    </div>

                    {twoFactorEnabled && (
                        <form onSubmit={handleSave2FASettings} className="space-y-5 pt-2">
                            <div>
                                <label className="block text-xs font-semibold text-zinc-300 mb-2">
                                    Método Preferido de Verificación
                                </label>
                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                                    <button
                                        type="button"
                                        onClick={() => setTwoFactorMethod('sms')}
                                        className={`p-3.5 rounded-xl border text-left flex items-center gap-3 transition-colors cursor-pointer ${
                                            twoFactorMethod === 'sms'
                                                ? 'border-[#0094FF] bg-[#0094FF]/10 text-white'
                                                : 'border-white/10 bg-white/[0.02] text-zinc-400 hover:text-white'
                                        }`}
                                    >
                                        <Smartphone size={18} className={twoFactorMethod === 'sms' ? 'text-[#0094FF]' : 'text-zinc-500'} />
                                        <div>
                                            <p className="text-xs font-bold text-white">Mensaje de Texto (SMS)</p>
                                            <p className="text-[11px] text-zinc-400">Recibe un código en tu teléfono</p>
                                        </div>
                                    </button>

                                    <button
                                        type="button"
                                        onClick={() => setTwoFactorMethod('email')}
                                        className={`p-3.5 rounded-xl border text-left flex items-center gap-3 transition-colors cursor-pointer ${
                                            twoFactorMethod === 'email'
                                                ? 'border-[#0094FF] bg-[#0094FF]/10 text-white'
                                                : 'border-white/10 bg-white/[0.02] text-zinc-400 hover:text-white'
                                        }`}
                                    >
                                        <Mail size={18} className={twoFactorMethod === 'email' ? 'text-[#0094FF]' : 'text-zinc-500'} />
                                        <div>
                                            <p className="text-xs font-bold text-white">Correo Electrónico</p>
                                            <p className="text-[11px] text-zinc-400">Recibe un código en tu email</p>
                                        </div>
                                    </button>
                                </div>
                            </div>

                            {twoFactorMethod === 'sms' && (
                                <div>
                                    <label className="block text-xs font-semibold text-zinc-300 mb-2">
                                        Número de Teléfono para SMS (con indicativo de país)
                                    </label>
                                    <input
                                        type="tel"
                                        value={phoneNumber}
                                        onChange={(e) => setPhoneNumber(e.target.value)}
                                        placeholder="+573001234567"
                                        className="w-full bg-[#0E1015] border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-[#0094FF] transition-colors font-mono text-xs"
                                    />
                                    <p className="text-[11px] text-zinc-500 mt-1.5">
                                        Incluye el código de país (ej. +57 para Colombia, +52 para México).
                                    </p>
                                </div>
                            )}

                            <button
                                type="submit"
                                disabled={saving2FA}
                                className="bg-[#0094FF] hover:bg-[#0080DE] text-white text-xs font-bold px-6 py-3 rounded-full inline-flex items-center gap-2 transition-colors cursor-pointer disabled:opacity-50"
                            >
                                <Check size={14} />
                                <span>{saving2FA ? 'Guardando...' : 'Guardar Preferencias de 2FA'}</span>
                            </button>
                        </form>
                    )}

                    {!twoFactorEnabled && (
                        <button
                            type="button"
                            onClick={handleSave2FASettings}
                            disabled={saving2FA}
                            className="bg-white/10 hover:bg-white/20 text-white text-xs font-bold px-6 py-2.5 rounded-full inline-flex items-center gap-2 transition-colors cursor-pointer"
                        >
                            <span>Guardar Estado (Desactivado)</span>
                        </button>
                    )}
                </section>
            </div>
        </div>
    );
};
