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

    // SMTP Mail Server State
    const [smtpHost, setSmtpHost] = useState('smtp.gmail.com');
    const [smtpPort, setSmtpPort] = useState('465');
    const [smtpUser, setSmtpUser] = useState('');
    const [smtpPass, setSmtpPass] = useState('');
    const [senderName, setSenderName] = useState('CONNECT');
    const [senderEmail, setSenderEmail] = useState('contacto@connectapp.com.co');
    const [testToEmail, setTestToEmail] = useState('');
    const [isSavingSmtp, setIsSavingSmtp] = useState(false);
    const [isTestingSmtp, setIsTestingSmtp] = useState(false);

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
        const fetchEmailConfig = async () => {
            try {
                const snap = await getDoc(doc(db, 'system_settings', 'email_config'));
                if (snap.exists()) {
                    const d = snap.data();
                    if (d.host) setSmtpHost(d.host);
                    if (d.port) setSmtpPort(String(d.port));
                    if (d.user) setSmtpUser(d.user);
                    if (d.pass) setSmtpPass(d.pass);
                    if (d.senderName) setSenderName(d.senderName);
                    if (d.senderEmail) setSenderEmail(d.senderEmail);
                }
            } catch (err) {
                console.error('Error fetching email config:', err);
            }
        };
        fetchUserData();
        fetchEmailConfig();
    }, []);

    const handleSaveSmtp = async (e: FormEvent) => {
        e.preventDefault();
        if (!smtpUser || !smtpPass) {
            toast.error('Completa el usuario y la contraseña SMTP');
            return;
        }
        setIsSavingSmtp(true);
        try {
            await setDoc(doc(db, 'system_settings', 'email_config'), {
                host: smtpHost.trim(),
                port: Number(smtpPort) || 465,
                user: smtpUser.trim(),
                pass: smtpPass.trim(),
                senderName: senderName.trim(),
                senderEmail: senderEmail.trim(),
                updatedAt: new Date()
            }, { merge: true });
            toast.success('Configuración de correo guardada con éxito');
        } catch (err: any) {
            toast.error(`Error al guardar: ${err.message}`);
        } finally {
            setIsSavingSmtp(false);
        }
    };

    const handleTestSmtp = async () => {
        if (!testToEmail.trim()) {
            toast.error('Ingresa un correo de prueba');
            return;
        }
        setIsTestingSmtp(true);
        try {
            const resp = await fetch('https://us-central1-connect2025-37b7c.cloudfunctions.net/sendDirectEmail', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    to: testToEmail.trim(),
                    subject: 'Prueba de Entrega de Correo - CONNECT',
                    text: '¡Hola! Este correo confirma que tu servidor de correo saliente está configurado y funcionando perfectamente en CONNECT.',
                    from: senderEmail.trim(),
                    fromName: senderName.trim()
                })
            });
            const data = await resp.json();
            if (!resp.ok) {
                throw new Error(data.error || 'Error al despachar correo de prueba');
            }
            toast.success(`¡Correo de prueba enviado con éxito a ${testToEmail}!`);
        } catch (err: any) {
            toast.error(`Fallo en la prueba: ${err.message}`);
        } finally {
            setIsTestingSmtp(false);
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

            {/* Tab: Servidor de Correo (SMTP) */}
            {activeTab === 'correo' && (
                <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
                    {/* Explicación / Instrucciones */}
                    <div className="bg-white border border-slate-200 rounded-lg p-5 flex flex-col space-y-4">
                        <div className="flex items-center gap-2 pb-3 border-b border-slate-100">
                            <div className="w-8 h-8 rounded-lg bg-blue-50 text-[#0094FF] flex items-center justify-center font-bold">
                                <Mail size={18} />
                            </div>
                            <div>
                                <h3 className="text-xs font-bold text-slate-900">Envíos Automatizados</h3>
                                <p className="text-[10px] text-slate-400">Entrega directa sin restricciones</p>
                            </div>
                        </div>

                        <p className="text-xs text-slate-600 leading-relaxed">
                            Configura aquí tu servidor SMTP para que las respuestas a reportes y correos de CONNECT se entreguen automáticamente a cualquier usuario (Gmail, Outlook, Yahoo, etc.).
                        </p>

                        <div className="bg-blue-50/70 border border-blue-100 p-3 rounded-lg text-[11px] text-slate-700 space-y-2">
                            <span className="font-bold text-[#0094FF] flex items-center gap-1">
                                💡 Recomendado: Gmail SMTP
                            </span>
                            <ol className="list-decimal pl-4 space-y-1 text-slate-600">
                                <li>Ve a tu cuenta Google &gt; <strong>Seguridad</strong>.</li>
                                <li>Activa la verificación en dos pasos.</li>
                                <li>Busca <strong>Contraseñas de aplicaciones</strong>.</li>
                                <li>Crea una llamada <em>CONNECT</em> y copia el código de 16 letras.</li>
                                <li>Pégalo en el campo Contraseña abajo.</li>
                            </ol>
                        </div>
                    </div>

                    {/* Formulario de Configuración */}
                    <div className="md:col-span-2 bg-white border border-slate-200 rounded-lg p-5 space-y-5">
                        <div>
                            <h2 className="text-sm font-bold text-slate-900 mb-1">Credenciales del Servidor SMTP</h2>
                            <p className="text-xs text-slate-500 pb-3 border-b border-slate-100">
                                Estos datos se almacenan de forma segura en Firebase y son utilizados por las Cloud Functions de CONNECT.
                            </p>
                        </div>

                        <form onSubmit={handleSaveSmtp} className="space-y-4">
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                                <div className="md:col-span-2">
                                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                                        Servidor SMTP (Host)
                                    </label>
                                    <input
                                        type="text"
                                        value={smtpHost}
                                        onChange={(e) => setSmtpHost(e.target.value)}
                                        placeholder="smtp.gmail.com"
                                        className="input-clean w-full text-xs font-mono"
                                        required
                                    />
                                </div>
                                <div>
                                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                                        Puerto
                                    </label>
                                    <input
                                        type="text"
                                        value={smtpPort}
                                        onChange={(e) => setSmtpPort(e.target.value)}
                                        placeholder="465"
                                        className="input-clean w-full text-xs font-mono"
                                        required
                                    />
                                </div>
                            </div>

                            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                <div>
                                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                                        Usuario / Correo Saliente
                                    </label>
                                    <input
                                        type="email"
                                        value={smtpUser}
                                        onChange={(e) => setSmtpUser(e.target.value)}
                                        placeholder="ejemplo@gmail.com"
                                        className="input-clean w-full text-xs"
                                        required
                                    />
                                </div>
                                <div>
                                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                                        Contraseña de Aplicación / Token
                                    </label>
                                    <input
                                        type="password"
                                        value={smtpPass}
                                        onChange={(e) => setSmtpPass(e.target.value)}
                                        placeholder="••••••••••••••••"
                                        className="input-clean w-full text-xs font-mono"
                                        required
                                    />
                                </div>
                            </div>

                            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                <div>
                                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                                        Nombre del Remitente
                                    </label>
                                    <input
                                        type="text"
                                        value={senderName}
                                        onChange={(e) => setSenderName(e.target.value)}
                                        placeholder="CONNECT"
                                        className="input-clean w-full text-xs"
                                    />
                                </div>
                                <div>
                                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                                        Correo de Respuesta (Reply-To)
                                    </label>
                                    <input
                                        type="email"
                                        value={senderEmail}
                                        onChange={(e) => setSenderEmail(e.target.value)}
                                        placeholder="contacto@connectapp.com.co"
                                        className="input-clean w-full text-xs"
                                    />
                                </div>
                            </div>

                            <div className="pt-2 flex justify-end">
                                <button
                                    type="submit"
                                    disabled={isSavingSmtp}
                                    className="btn-primary text-xs"
                                >
                                    {isSavingSmtp ? 'Guardando...' : 'Guardar Configuración SMTP'}
                                </button>
                            </div>
                        </form>

                        {/* Test Box */}
                        <div className="pt-4 mt-4 border-t border-slate-100 bg-slate-50 p-4 rounded-lg">
                            <h3 className="text-xs font-bold text-slate-800 mb-1">Probar Envío en Tiempo Real</h3>
                            <p className="text-[11px] text-slate-500 mb-3">
                                Envía un correo de prueba a cualquier destinatario para confirmar que la entrega funciona correctamente.
                            </p>
                            <div className="flex gap-2">
                                <input
                                    type="email"
                                    value={testToEmail}
                                    onChange={(e) => setTestToEmail(e.target.value)}
                                    placeholder="ejemplo.destino@gmail.com"
                                    className="input-clean flex-1 text-xs bg-white"
                                />
                                <button
                                    type="button"
                                    onClick={handleTestSmtp}
                                    disabled={isTestingSmtp}
                                    className="px-4 py-2 bg-slate-900 hover:bg-black text-white text-xs font-semibold rounded-lg transition-colors flex items-center gap-1.5"
                                >
                                    {isTestingSmtp ? 'Enviando...' : 'Enviar Prueba'}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
