import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { auth, ALLOWED_EMAILS } from '../services/firebase';
import { onAuthStateChanged } from 'firebase/auth';

export const Footer: React.FC = () => {
    const [isAdmin, setIsAdmin] = useState(false);

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, (currentUser: any) => {
            if (currentUser?.email) {
                setIsAdmin(ALLOWED_EMAILS.includes(currentUser.email));
            } else {
                setIsAdmin(false);
            }
        });
        return () => unsubscribe();
    }, []);

    return (
        <footer className="py-16 bg-[#07080A] border-t border-white/[0.06]">
            <div className="container-custom">
                <div className="grid grid-cols-1 md:grid-cols-12 gap-12 pb-12 border-b border-white/[0.05]">
                    {/* Brand column */}
                    <div className="md:col-span-4 space-y-4">
                        <Link to="/" className="flex items-center gap-2.5">
                            <img
                                src="/logo.png"
                                alt="CONNECT"
                                className="h-6 w-6 object-contain brightness-125 saturate-0"
                            />
                            <span className="text-sm font-black tracking-tight text-white font-archivo">CONNECT</span>
                        </Link>
                        <p className="text-xs text-zinc-400 leading-relaxed max-w-xs font-normal">
                            Plataforma comunitaria de comercio y mensajería geolocalizada con verificación de reputación real y soberanía de datos.
                        </p>
                    </div>

                    {/* Navigation Columns */}
                    <div className="md:col-span-8 grid grid-cols-2 sm:grid-cols-3 gap-8">
                        <div className="space-y-3">
                            <h4 className="text-xs font-bold text-zinc-200 tracking-wide">Plataforma</h4>
                            <ul className="space-y-2 text-xs">
                                <li>
                                    <Link to="/how-it-works" className="text-zinc-400 hover:text-white transition-colors">
                                        Tecnología
                                    </Link>
                                </li>
                                <li>
                                    <Link to="/about" className="text-zinc-400 hover:text-white transition-colors">
                                        Nosotros
                                    </Link>
                                </li>
                                <li>
                                    <Link to="/faq" className="text-zinc-400 hover:text-white transition-colors">
                                        Preguntas Frecuentes
                                    </Link>
                                </li>
                            </ul>
                        </div>

                        <div className="space-y-3">
                            <h4 className="text-xs font-bold text-zinc-200 tracking-wide">Legal & Seguridad</h4>
                            <ul className="space-y-2 text-xs">
                                <li>
                                    <Link to="/privacy-policy" className="text-zinc-400 hover:text-white transition-colors">
                                        Política de Privacidad
                                    </Link>
                                </li>
                                <li>
                                    <Link to="/support" className="text-zinc-400 hover:text-white transition-colors">
                                        Centro de Soporte
                                    </Link>
                                </li>
                                <li>
                                    <Link to="/report" className="text-zinc-400 hover:text-white transition-colors">
                                        Canal de Denuncias
                                    </Link>
                                </li>
                            </ul>
                        </div>

                        <div className="space-y-3 col-span-2 sm:col-span-1">
                            <h4 className="text-xs font-bold text-zinc-200 tracking-wide">Contacto</h4>
                            <p className="text-xs text-zinc-400">
                                soporte@connectapp.com.co
                            </p>
                            <p className="text-xs text-zinc-500">
                                Bogotá, Colombia
                            </p>
                        </div>
                    </div>
                </div>

                {/* Bottom credits */}
                <div className="pt-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-zinc-500">
                    <p>© 2026 CONNECT. Todos los derechos reservados.</p>
                    <div className="flex items-center gap-6">
                        {isAdmin && (
                            <Link
                                to="/admin/dashboard"
                                className="text-xs font-medium text-zinc-400 hover:text-primary transition-colors"
                            >
                                Panel de Administración
                            </Link>
                        )}
                    </div>
                </div>
            </div>
        </footer>
    );
};
