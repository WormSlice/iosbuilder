import React, { useState, FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Mail, Lock, LogIn } from 'lucide-react';
import { signInWithEmailAndPassword, auth } from '../services/firebase';

export const Login: React.FC = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    const handleLogin = async (e: FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        setLoading(true);
        setError(null);
        try {
            await signInWithEmailAndPassword(auth, email, password);
            navigate('/admin/dashboard');
        } catch (err: any) {
            setError('Error en credenciales.');
        } finally {
            setLoading(false);
        }
    };

    const handleGoogleLogin = async () => {
        setLoading(true);
        setError(null);
        try {
            const { googleProvider, signInWithPopup, ALLOWED_EMAILS, signOut } = await import('../services/firebase');
            const result = await signInWithPopup(auth, googleProvider);
            if (result.user.email && !ALLOWED_EMAILS.includes(result.user.email)) {
                await signOut(auth);
                setError('Este correo no está autorizado para acceder al panel de administración.');
            } else {
                navigate('/admin/dashboard');
            }
        } catch (err: any) {
            setError('Error al iniciar sesión con Google.');
        } finally {
            setLoading(false);
        }
    };

    const handleAppleLogin = async () => {
        setLoading(true);
        setError(null);
        try {
            const { appleProvider, signInWithPopup, ALLOWED_EMAILS, signOut } = await import('../services/firebase');
            const result = await signInWithPopup(auth, appleProvider);
            if (result.user.email && !ALLOWED_EMAILS.includes(result.user.email)) {
                await signOut(auth);
                setError('Este correo no está autorizado para acceder al panel de administración.');
            } else {
                navigate('/admin/dashboard');
            }
        } catch (err: any) {
            console.error(err);
            setError('Error al iniciar sesión con Apple.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-[#F8FAFC] p-4">
            <div className="w-full max-w-sm bg-white border border-slate-200 rounded-xl p-6 space-y-5 shadow-sm">
                <div className="text-center space-y-1">
                    <Link to="/" className="inline-flex justify-center mb-2">
                        <img src="/logo.png" alt="CONNECT" className="h-8 w-8" />
                    </Link>
                    <h1 className="text-lg font-bold text-slate-900 tracking-tight">Acceso Administrativo</h1>
                    <p className="text-xs text-slate-500">Panel de Control Oficial CONNECT</p>
                </div>

                <div className="space-y-2">
                    <button
                        onClick={handleGoogleLogin}
                        disabled={loading}
                        className="w-full bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 py-2 px-3 rounded-lg text-xs font-semibold transition-all flex items-center justify-center gap-2 active:scale-95 disabled:opacity-50"
                    >
                        <svg viewBox="0 0 24 24" className="w-4 h-4" xmlns="http://www.w3.org/2000/svg">
                            <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
                            <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
                            <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05" />
                            <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
                        </svg>
                        <span>Continuar con Google</span>
                    </button>

                    <button
                        onClick={handleAppleLogin}
                        disabled={loading}
                        className="w-full bg-[#0A0A0A] hover:bg-slate-800 text-white py-2 px-3 rounded-lg text-xs font-semibold transition-all flex items-center justify-center gap-2 active:scale-95 disabled:opacity-50"
                    >
                        <svg viewBox="0 0 24 24" className="w-4 h-4 fill-white" xmlns="http://www.w3.org/2000/svg">
                            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.1 2.48-1.34.03-1.77-.79-3.29-.79-1.53 0-2.01.77-3.27.82-1.31.05-2.31-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91 1.65.07 2.49.52 3.01.99.11.11.23.23.33.36-1.3.77-2.13 2.1-2.09 3.63.04 1.88 1.58 3.32 3.44 3.42-.04.42-.1.85-.2 1.25zM12.91 5.99c.35-1.5 1.77-2.61 3.35-2.6.14 1.58-1.28 3.16-3.35 3.1-.14-1.58-.2-2.5.3-3.1z" />
                        </svg>
                        <span>Continuar con Apple</span>
                    </button>
                </div>

                <div className="flex items-center gap-2">
                    <div className="flex-1 h-px bg-slate-200"></div>
                    <span className="text-[10px] font-semibold text-slate-400 uppercase">o con correo</span>
                    <div className="flex-1 h-px bg-slate-200"></div>
                </div>

                <form onSubmit={handleLogin} className="space-y-3.5">
                    <div>
                        <label className="block text-xs font-semibold text-slate-700 mb-1">Correo Electrónico</label>
                        <div className="relative">
                            <Mail className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
                            <input
                                type="email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                required
                                className="input-clean w-full pl-8 py-1.5 text-xs"
                                placeholder="admin@connectapp.com.co"
                            />
                        </div>
                    </div>

                    <div>
                        <div className="flex justify-between items-center mb-1">
                            <label className="text-xs font-semibold text-slate-700">Contraseña</label>
                            <Link to="/reset-password" className="text-[11px] text-[#0094FF] hover:underline">¿Olvidaste?</Link>
                        </div>
                        <div className="relative">
                            <Lock className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
                            <input
                                type="password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                required
                                className="input-clean w-full pl-8 py-1.5 text-xs"
                                placeholder="••••••••"
                            />
                        </div>
                    </div>

                    {error && (
                        <div className="p-2.5 rounded-md bg-red-50 border border-red-200 text-red-600 text-xs font-medium text-center">
                            {error}
                        </div>
                    )}

                    <button
                        type="submit"
                        disabled={loading}
                        className="btn-primary w-full text-xs py-2 flex items-center justify-center gap-1.5"
                    >
                        {loading ? (
                            <div className="animate-spin h-4 w-4 border-2 border-white/20 border-t-white rounded-full" />
                        ) : (
                            <>
                                <LogIn size={13} />
                                <span>Iniciar Sesión</span>
                            </>
                        )}
                    </button>
                </form>

                <div className="text-center pt-2 border-t border-slate-100">
                    <p className="text-xs text-slate-500">
                        ¿Nuevo administrador?{' '}
                        <Link to="/signup" className="text-[#0094FF] font-semibold hover:underline">
                            Registrarse
                        </Link>
                    </p>
                </div>
            </div>
        </div>
    );
};
