import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Mail, Lock, User as UserIcon, ArrowRight, Eye, EyeOff } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { createUserWithEmailAndPassword, updateProfile, auth, ALLOWED_EMAILS } from '../services/firebase';

export const Signup: React.FC = () => {
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    const handleSignup = async (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        setLoading(true);
        setError(null);
        try {
            const userCredential = await createUserWithEmailAndPassword(auth, email.trim(), password);
            await updateProfile(userCredential.user, { displayName: name.trim() });
            if (userCredential.user.email && ALLOWED_EMAILS.includes(userCredential.user.email)) {
                navigate('/admin/dashboard');
            } else {
                navigate('/');
            }
        } catch (err: any) {
            if (err?.code === 'auth/email-already-in-use') {
                setError('Este correo electrónico ya está registrado.');
            } else if (err?.code === 'auth/weak-password') {
                setError('La contraseña debe tener al menos 6 caracteres.');
            } else {
                setError('No se pudo crear la cuenta. Verifica tus datos.');
            }
        } finally {
            setLoading(false);
        }
    };

    const handleGoogleSignup = async () => {
        setLoading(true);
        setError(null);
        try {
            const { googleProvider, signInWithPopup } = await import('../services/firebase');
            const result = await signInWithPopup(auth, googleProvider);
            if (result.user.email && ALLOWED_EMAILS.includes(result.user.email)) {
                navigate('/admin/dashboard');
            } else {
                navigate('/');
            }
        } catch (err: any) {
            setError('No se pudo completar el registro con Google.');
        } finally {
            setLoading(false);
        }
    };

    const handleAppleSignup = async () => {
        setLoading(true);
        setError(null);
        try {
            const { appleProvider, signInWithPopup } = await import('../services/firebase');
            const result = await signInWithPopup(auth, appleProvider);
            if (result.user.email && ALLOWED_EMAILS.includes(result.user.email)) {
                navigate('/admin/dashboard');
            } else {
                navigate('/');
            }
        } catch (err: any) {
            console.error('Apple Signup Error:', err);
            if (err?.code === 'auth/popup-closed-by-user') {
                setError('Ventana de registro cerrada.');
            } else {
                setError('Error con Apple Sign In. Si persiste, regístrate con Google o correo.');
            }
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-[#07080A] text-white p-4 sm:p-6 relative overflow-hidden">
            {/* Ambient Background Mesh */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[500px] bg-gradient-to-b from-[#0094FF]/[0.08] via-transparent to-transparent blur-3xl pointer-events-none -z-10" />

            <motion.div
                initial={{ opacity: 0, y: 20, scale: 0.98 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                className="w-full max-w-md bg-[#0F1117]/80 backdrop-blur-2xl border border-white/[0.08] rounded-3xl p-7 sm:p-10 shadow-2xl relative z-10"
            >
                {/* Header */}
                <div className="text-center space-y-2 mb-8">
                    <Link to="/" className="inline-flex justify-center group mb-2">
                        <img
                            src="/logo.png"
                            alt="CONNECT"
                            className="h-10 w-10 object-contain brightness-125 transition-transform duration-300 group-hover:scale-105"
                        />
                    </Link>
                    <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight font-archivo text-white">
                        Crear Cuenta
                    </h1>
                    <p className="text-xs sm:text-sm text-zinc-400 font-normal">
                        Únete a la comunidad de CONNECT
                    </p>
                </div>

                {/* Social Auth Buttons */}
                <div className="grid grid-cols-2 gap-3 mb-6">
                    <button
                        type="button"
                        onClick={handleGoogleSignup}
                        disabled={loading}
                        className="bg-white/[0.04] hover:bg-white/[0.08] text-white border border-white/[0.1] rounded-2xl py-3 px-3 text-xs font-semibold transition-all duration-200 flex items-center justify-center gap-2 active:scale-[0.98] disabled:opacity-50 cursor-pointer"
                    >
                        <svg viewBox="0 0 24 24" className="w-4 h-4 shrink-0" xmlns="http://www.w3.org/2000/svg">
                            <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
                            <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
                            <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05" />
                            <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
                        </svg>
                        <span>Google</span>
                    </button>

                    <button
                        type="button"
                        onClick={handleAppleSignup}
                        disabled={loading}
                        className="bg-white/[0.04] hover:bg-white/[0.08] text-white border border-white/[0.1] rounded-2xl py-3 px-3 text-xs font-semibold transition-all duration-200 flex items-center justify-center gap-2 active:scale-[0.98] disabled:opacity-50 cursor-pointer"
                    >
                        <svg viewBox="0 0 24 24" className="w-4 h-4 fill-white shrink-0" xmlns="http://www.w3.org/2000/svg">
                            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.1 2.48-1.34.03-1.77-.79-3.29-.79-1.53 0-2.01.77-3.27.82-1.31.05-2.31-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91 1.65.07 2.49.52 3.01.99.11.11.23.23.33.36-1.3.77-2.13 2.1-2.09 3.63.04 1.88 1.58 3.32 3.44 3.42-.04.42-.1.85-.2 1.25zM12.91 5.99c.35-1.5 1.77-2.61 3.35-2.6.14 1.58-1.28 3.16-3.35 3.1-.14-1.58-.2-2.5.3-3.1z" />
                        </svg>
                        <span>Apple</span>
                    </button>
                </div>

                {/* Divider */}
                <div className="flex items-center gap-3 my-6">
                    <div className="flex-1 h-px bg-white/[0.08]" />
                    <span className="text-[11px] font-medium text-zinc-500 uppercase tracking-wider">o con correo</span>
                    <div className="flex-1 h-px bg-white/[0.08]" />
                </div>

                {/* Signup Form */}
                <form onSubmit={handleSignup} className="space-y-4">
                    <div className="space-y-1.5">
                        <label className="text-xs font-semibold text-zinc-300">Nombre Completo</label>
                        <div className="relative">
                            <UserIcon className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
                            <input
                                type="text"
                                value={name}
                                onChange={(e) => setName(e.target.value)}
                                required
                                className="w-full bg-white/[0.03] border border-white/[0.1] hover:border-white/20 focus:border-[#0094FF] focus:bg-white/[0.05] rounded-xl pl-10 pr-4 py-3 text-xs sm:text-sm text-white placeholder:text-zinc-500 outline-none transition-all"
                                placeholder="Tu nombre"
                            />
                        </div>
                    </div>

                    <div className="space-y-1.5">
                        <label className="text-xs font-semibold text-zinc-300">Correo Electrónico</label>
                        <div className="relative">
                            <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
                            <input
                                type="email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                required
                                className="w-full bg-white/[0.03] border border-white/[0.1] hover:border-white/20 focus:border-[#0094FF] focus:bg-white/[0.05] rounded-xl pl-10 pr-4 py-3 text-xs sm:text-sm text-white placeholder:text-zinc-500 outline-none transition-all"
                                placeholder="tu@correo.com"
                            />
                        </div>
                    </div>

                    <div className="space-y-1.5">
                        <label className="text-xs font-semibold text-zinc-300">Contraseña</label>
                        <div className="relative">
                            <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
                            <input
                                type={showPassword ? 'text' : 'password'}
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                required
                                minLength={6}
                                className="w-full bg-white/[0.03] border border-white/[0.1] hover:border-white/20 focus:border-[#0094FF] focus:bg-white/[0.05] rounded-xl pl-10 pr-10 py-3 text-xs sm:text-sm text-white placeholder:text-zinc-500 outline-none transition-all"
                                placeholder="Mínimo 6 caracteres"
                            />
                            <button
                                type="button"
                                onClick={() => setShowPassword(!showPassword)}
                                className="absolute right-3.5 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-zinc-300 transition-colors"
                            >
                                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                            </button>
                        </div>
                    </div>

                    <AnimatePresence>
                        {error && (
                            <motion.div
                                initial={{ opacity: 0, height: 0 }}
                                animate={{ opacity: 1, height: 'auto' }}
                                exit={{ opacity: 0, height: 0 }}
                                className="p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs font-medium text-center"
                            >
                                {error}
                            </motion.div>
                        )}
                    </AnimatePresence>

                    <button
                        type="submit"
                        disabled={loading}
                        className="w-full bg-[#0094FF] hover:bg-[#0080DF] text-white text-xs sm:text-sm font-bold py-3 px-6 rounded-xl transition-all duration-200 active:scale-[0.98] shadow-md shadow-[#0094FF]/20 flex items-center justify-center gap-2 disabled:opacity-50 cursor-pointer pt-3"
                    >
                        {loading ? (
                            <div className="animate-spin h-4 w-4 border-2 border-white/20 border-t-white rounded-full" />
                        ) : (
                            <>
                                <span>Crear Cuenta</span>
                                <ArrowRight size={15} />
                            </>
                        )}
                    </button>
                </form>

                {/* Bottom Link */}
                <div className="text-center pt-6 mt-6 border-t border-white/[0.08]">
                    <p className="text-xs text-zinc-400">
                        ¿Ya tienes una cuenta?{' '}
                        <Link to="/login" className="text-[#0094FF] font-bold hover:underline">
                            Inicia Sesión
                        </Link>
                    </p>
                </div>
            </motion.div>
        </div>
    );
};
