import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Mail, ArrowLeft, ArrowRight } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
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
            await sendPasswordResetEmail(auth, email.trim());
            setMessage('Se ha enviado un enlace de recuperación a tu correo electrónico.');
        } catch (err: any) {
            setError('No pudimos encontrar una cuenta con ese correo electrónico.');
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
                        Recuperar Contraseña
                    </h1>
                    <p className="text-xs sm:text-sm text-zinc-400 font-normal">
                        Ingresa tu correo para recibir las instrucciones
                    </p>
                </div>

                <form onSubmit={handleReset} className="space-y-4">
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

                    <AnimatePresence>
                        {message && (
                            <motion.div
                                initial={{ opacity: 0, height: 0 }}
                                animate={{ opacity: 1, height: 'auto' }}
                                exit={{ opacity: 0, height: 0 }}
                                className="p-3 rounded-xl bg-green-500/10 border border-green-500/20 text-green-400 text-xs font-medium text-center"
                            >
                                {message}
                            </motion.div>
                        )}
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
                                <span>Enviar Enlace</span>
                                <ArrowRight size={15} />
                            </>
                        )}
                    </button>
                </form>

                <div className="text-center pt-6 mt-6 border-t border-white/[0.08]">
                    <Link
                        to="/login"
                        className="text-xs text-zinc-400 hover:text-white transition-colors inline-flex items-center gap-2"
                    >
                        <ArrowLeft size={14} />
                        <span>Volver a Iniciar Sesión</span>
                    </Link>
                </div>
            </motion.div>
        </div>
    );
};
