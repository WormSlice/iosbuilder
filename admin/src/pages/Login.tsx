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
            const { googleProvider, signInWithPopup } = await import('../services/firebase');
            await signInWithPopup(auth, googleProvider);
            navigate('/admin/dashboard');
        } catch (err: any) {
            setError('Error al iniciar sesión con Google.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-[calc(100vh-140px)] flex items-center justify-center bg-[#0a0a0a] p-4 animate-in fade-in duration-700">
            <div className="w-full max-w-[340px] space-y-8 py-8">
                <div className="text-center space-y-2">
                    <Link to="/" className="flex justify-center mb-4">
                        <img src="/logo.png" alt="CONNECT" className="h-6 w-6 brightness-125" />
                    </Link>
                    <h1 className="text-xl font-black font-archivo tracking-tighter uppercase text-white">ACCESO</h1>
                    <p className="text-[8px] font-black uppercase tracking-[0.2em] text-zinc-600">GESTIÓN DE IDENTIDAD DIGITAL</p>
                </div>

                <div className="space-y-3">
                    <button className="w-full bg-white text-black py-2.5 rounded-xl font-black text-[9px] uppercase tracking-widest hover:bg-zinc-200 transition-all flex items-center justify-center gap-2 active:scale-95 shadow-sm">
                        <svg viewBox="0 0 24 24" className="w-4 h-4 fill-black" xmlns="http://www.w3.org/2000/svg">
                            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.1 2.48-1.34.03-1.77-.79-3.29-.79-1.53 0-2.01.77-3.27.82-1.31.05-2.31-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91 1.65.07 2.49.52 3.01.99.11.11.23.23.33.36-1.3.77-2.13 2.1-2.09 3.63.04 1.88 1.58 3.32 3.44 3.42-.04.42-.1.85-.2 1.25zM12.91 5.99c.35-1.5 1.77-2.61 3.35-2.6.14 1.58-1.28 3.16-3.35 3.1-.14-1.58-.2-2.5.3-3.1z" />
                        </svg>
                        Apple
                    </button>

                    <button
                        onClick={handleGoogleLogin}
                        disabled={loading}
                        className="w-full bg-white/[0.03] border border-white/[0.08] text-white py-2.5 rounded-xl font-black text-[9px] uppercase tracking-widest hover:bg-white/[0.06] transition-all flex items-center justify-center gap-2 active:scale-95 shadow-sm disabled:opacity-50"
                    >
                        <svg viewBox="0 0 24 24" className="w-4 h-4" xmlns="http://www.w3.org/2000/svg">
                            <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
                            <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
                            <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05" />
                            <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
                        </svg>
                        Google
                    </button>
                </div>

                <div className="flex items-center gap-3">
                    <div className="flex-1 h-[1px] bg-white/[0.04]"></div>
                    <span className="text-[7px] font-black text-zinc-700 uppercase tracking-widest">CONTINUAR CON</span>
                    <div className="flex-1 h-[1px] bg-white/[0.04]"></div>
                </div>

                <form onSubmit={handleLogin} className="space-y-4">
                    <div className="space-y-1">
                        <label className="premium-label">Email</label>
                        <div className="relative">
                            <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-600" size={14} />
                            <input
                                type="email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                required
                                className="premium-input pl-11"
                                placeholder="tu@correo.com"
                            />
                        </div>
                    </div>

                    <div className="space-y-1">
                        <div className="flex justify-between items-center px-1">
                            <label className="premium-label">Password</label>
                            <Link to="/reset-password" title="Recuperar contraseña" className="text-[7px] font-black text-primary hover:text-white uppercase tracking-widest transition-colors mb-1">Recuperar</Link>
                        </div>
                        <div className="relative">
                            <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-600" size={14} />
                            <input
                                type="password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                required
                                className="premium-input pl-11"
                                placeholder="••••••••"
                            />
                        </div>
                    </div>

                    {error && <p className="text-[8px] font-bold uppercase tracking-widest text-red-500 text-center">{error}</p>}

                    <button
                        type="submit"
                        disabled={loading}
                        className="w-full bg-primary text-white py-3 rounded-xl font-bold text-[10px] uppercase tracking-widest hover:brightness-110 transition-all flex items-center justify-center gap-2 active:scale-95 pt-2"
                    >
                        {loading ? <div className="animate-spin h-4 w-4 border-b-2 border-white rounded-full"></div> : 'Entrar'}
                    </button>
                </form>

                <div className="text-center">
                    <p className="text-[10px] text-zinc-600 font-bold">Sin cuenta? <Link to="/signup" className="text-white hover:text-primary transition-colors underline-offset-4 underline">Registrar</Link></p>
                </div>
            </div>
        </div>
    );
};
