import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Mail, ArrowLeft as ArrowLeftIcon } from 'lucide-react';
import { sendPasswordResetEmail, auth } from '../services/firebase';

export const ResetPassword: React.FC = () => {
    const [email, setEmail] = useState('');
    const [message, setMessage] = useState<string | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);

    const handleReset = async (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        setLoading(true);
        setError(null);
        setMessage(null);
        try {
            await sendPasswordResetEmail(auth, email);
            setMessage('Se ha enviado un enlace de recuperación a tu correo electrónico.');
        } catch (err: any) {
            setError('No pudimos encontrar una cuenta con ese correo electrónico.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-background p-6 animate-in fade-in duration-700 gradient-bg">
            <div className="w-full max-w-md glass-card p-10 md:p-14 space-y-10">
                <div className="text-center space-y-2">
                    <Link to="/" className="flex justify-center mb-6">
                        <img src="/logo.png" alt="CONNECT" className="h-10 w-auto brightness-110" />
                    </Link>
                    <h1 className="text-3xl font-black font-archivo tracking-tighter uppercase text-white">RECUPERACIÓN</h1>
                    <p className="text-[9px] font-black uppercase tracking-[0.3em] text-zinc-500">RECUPERA TU ACCESO DIGITAL</p>
                </div>

                <form onSubmit={handleReset} className="space-y-6">
                    <div className="space-y-2">
                        <label className="premium-label">Tu Email</label>
                        <div className="relative">
                            <Mail className="absolute left-5 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
                            <input
                                type="email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                required
                                className="premium-input pl-14"
                                placeholder="tu@identidad.com"
                            />
                        </div>
                    </div>

                    {message && <p className="text-[10px] font-black uppercase tracking-widest text-green-500 bg-green-500/10 p-4 rounded-xl border border-green-500/20 text-center">{message}</p>}
                    {error && <p className="text-[10px] font-black uppercase tracking-widest text-red-500 bg-red-500/10 p-4 rounded-xl border border-red-500/20 text-center">{error}</p>}

                    <button
                        type="submit"
                        disabled={loading}
                        className="w-full bg-primary text-white py-4 rounded-2xl font-black text-xs uppercase tracking-widest hover:bg-primary-dark transition-all shadow-premium"
                    >
                        {loading ? <div className="animate-spin h-5 w-5 mx-auto border-b-2 border-white rounded-full"></div> : 'Enviar Enlace'}
                    </button>
                </form>

                <div className="text-center pt-4">
                    <Link to="/login" className="text-[10px] font-black uppercase tracking-widest text-zinc-500 hover:text-white transition-all flex items-center justify-center gap-2">
                        <ArrowLeftIcon size={14} /> Volver al Inicio de Sesión
                    </Link>
                </div>
            </div>
        </div>
    );
};
