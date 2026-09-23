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
import { doc, getDoc, updateDoc, setDoc } from 'firebase/firestore';
import toast from 'react-hot-toast';

export const Settings: React.FC = () => {
    const [activeTab, setActiveTab] = useState<'perfil' | 'seguridad' | 'sistema' | 'correo'>('perfil');
    const [name, setName] = useState(auth.currentUser?.displayName || '');
    const [photoURL, setPhotoURL] = useState(auth.currentUser?.photoURL || '');
    const [email] = useState(auth.currentUser?.email || '');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [loading, setLoading] = useState(false);

    // Cloudflare Email State & Diagnostics
    const [testToEmail, setTestToEmail] = useState('');
    const [isTestingEmail, setIsTestingEmail] = useState(false);
    const [testResult, setTestResult] = useState<{ success?: boolean; message?: string; error?: string } | null>(null);

    const handleTestCloudflareEmail = async () => {
        if (!testToEmail.trim()) {
            toast.error('Ingresa un correo de prueba');
            return;
        }
        setIsTestingEmail(true);
        setTestResult(null);
        try {
            const resp = await fetch('https://connect-email-receiver.irenzulsierra.workers.dev', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    to: testToEmail.trim(),
                    from: 'contacto@connectapp.com.co',
                    subject: 'Prueba de Diagnóstico CONNECT Mail',
                    text: 'Este es un mensaje de prueba enviado directamente desde el Cloudflare Worker de CONNECT Mail.'
                })
            });
            const text = await resp.text();
            let json: any = {};
            try { json = JSON.parse(text); } catch (_) {}

            if (resp.ok) {
                setTestResult({ success: true, message: json.message || 'Correo entregado exitosamente por Cloudflare Worker.' });
                toast.success('¡Correo enviado con éxito!');
            } else {
                setTestResult({ success: false, error: json.error || text || resp.statusText });
                toast.error(`Aviso de Cloudflare: ${json.error || text}`);
            }
        } catch (err: any) {
            setTestResult({ success: false, error: err.message });
            toast.error(`Error al conectar con Worker: ${err.message}`);
        } finally {
            setIsTestingEmail(false);
        }
    };

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
                <button
                    onClick={() => setActiveTab('correo')}
                    className={`px-3 py-2 text-xs font-semibold border-b-2 transition-colors flex items-center gap-1.5 ${
                        activeTab === 'correo'
                            ? 'border-[#0094FF] text-[#0094FF]'
                            : 'border-transparent text-slate-500 hover:text-slate-800'
                    }`}
                >
                    <Mail size={13} />
                    <span>Servidor de Correo (SMTP)</span>
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
                        <span className="mt-2 text-xs font-semibold text-zinc-500">
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

            {/* Tab: Servidor de Correo (Cloudflare) */}
            {activeTab === 'correo' && (
                <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
                    {/* Tarjeta Informativa de Dominio */}
                    <div className="bg-white border border-slate-200 rounded-lg p-5 flex flex-col space-y-4">
                        <div className="flex items-center gap-2 pb-3 border-b border-slate-100">
                            <div className="w-8 h-8 rounded-lg bg-blue-50 text-[#0094FF] flex items-center justify-center font-bold">
                                <Mail size={18} />
                            </div>
                            <div>
                                <h3 className="text-xs font-bold text-slate-900">Cloudflare Email</h3>
                                <p className="text-[10px] text-slate-400">Dominio oficial CONNECT</p>
                            </div>
                        </div>

                        <div className="space-y-3 text-xs">
                            <div className="p-3 bg-slate-50 border border-slate-200 rounded-lg">
                                <span className="text-slate-400 text-[10px] font-bold uppercase tracking-wider block mb-0.5">Correo Emisor</span>
                                <p className="font-bold text-slate-800 font-mono">contacto@connectapp.com.co</p>
                            </div>
                            <div className="p-3 bg-slate-50 border border-slate-200 rounded-lg">
                                <span className="text-slate-400 text-[10px] font-bold uppercase tracking-wider block mb-0.5">Dominio DNS</span>
                                <p className="font-bold text-slate-800 font-mono">connectapp.com.co (Cloudflare)</p>
                            </div>
                            <div className="p-3 bg-slate-50 border border-slate-200 rounded-lg">
                                <span className="text-slate-400 text-[10px] font-bold uppercase tracking-wider block mb-0.5">Worker Activo</span>
                                <p className="font-medium text-slate-600 text-[11px] font-mono break-all">connect-email-receiver.irenzulsierra.workers.dev</p>
                            </div>
                        </div>
                    </div>

                    {/* Herramienta de Diagnóstico en Vivo */}
                    <div className="md:col-span-2 bg-white border border-slate-200 rounded-lg p-5 space-y-5">
                        <div>
                            <h2 className="text-sm font-bold text-slate-900 mb-1">Diagnóstico en Vivo de Cloudflare Worker</h2>
                            <p className="text-xs text-slate-500 pb-3 border-b border-slate-100">
                                Prueba el despacho directo de correos desde tu Worker de Cloudflare hacia cualquier buzón de correo.
                            </p>
                        </div>

                        <div className="bg-slate-50 border border-slate-200 rounded-lg p-4 space-y-3">
                            <label className="block text-xs font-semibold text-slate-700">
                                Destinatario para prueba de entrega
                            </label>
                            <div className="flex gap-2">
                                <input
                                    type="email"
                                    value={testToEmail}
                                    onChange={(e) => setTestToEmail(e.target.value)}
                                    placeholder="ejemplo@gmail.com"
                                    className="input-clean flex-1 text-xs bg-white font-mono"
                                />
                                <button
                                    type="button"
                                    onClick={handleTestCloudflareEmail}
                                    disabled={isTestingEmail}
                                    className="btn-primary text-xs flex items-center gap-1.5"
                                >
                                    {isTestingEmail ? 'Probando...' : 'Enviar Prueba Cloudflare'}
                                </button>
                            </div>

                            {testResult && (
                                <div className={`p-3 rounded-lg text-xs mt-3 border ${testResult.success ? 'bg-emerald-50 border-emerald-200 text-emerald-800' : 'bg-rose-50 border-rose-200 text-rose-800'}`}>
                                    <span className="font-bold block mb-1">
                                        {testResult.success ? '✅ Envío Exitoso' : '❌ Respuesta de Cloudflare'}
                                    </span>
                                    <p className="font-mono text-[11px] whitespace-pre-wrap">
                                        {testResult.success ? testResult.message : testResult.error}
                                    </p>
                                </div>
                            )}
                        </div>

                        <div className="p-4 bg-blue-50/50 border border-blue-100 rounded-lg text-xs text-slate-600 space-y-2">
                            <span className="font-bold text-[#0094FF] flex items-center gap-1 text-[11px]">
                                ℹ️ Reglas de Entrega de Cloudflare Email
                            </span>
                            <p className="text-[11px] leading-relaxed">
                                • <strong>Recepción:</strong> Todo correo que reciba <code>contacto@connectapp.com.co</code> entra de forma automática a la bandeja de entrada de CONNECT Mail.<br />
                                • <strong>Envíos a Usuarios:</strong> Cloudflare Email Routing autoriza envíos a direcciones que estén activas en tu panel de Cloudflare o mediante Cloudflare Email Sending.
                            </p>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
