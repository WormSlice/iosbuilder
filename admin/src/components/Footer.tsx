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
        <footer className="py-12 bg-[#0a0a0a] border-t border-white/[0.04]">
            <div className="container-custom">
                <div className="flex flex-col md:flex-row justify-between items-start gap-12 mb-12">
                    <div className="space-y-4">
                        <div className="flex items-center gap-2">
                            <img src="/logo.png" alt="CONNECT" className="h-5 w-5 brightness-125 saturate-0" />
                            <span className="text-xs font-black tracking-tighter text-white font-archivo">CONNECT</span>
                        </div>
                        <p className="text-zinc-600 text-[10px] leading-relaxed max-w-[180px] font-bold uppercase tracking-wider">
                            TRASCENDIENDO LA CONEXIÓN DIGITAL.
                        </p>
                    </div>

                    <div className="grid grid-cols-2 md:grid-cols-3 gap-12 md:gap-20">
                        <div className="space-y-4">
                            <h4 className="text-[8px] font-black uppercase tracking-[0.2em] text-zinc-500">Compañía</h4>
                            <ul className="space-y-2">
                                <li><Link to="/about" className="text-zinc-500 hover:text-white transition-colors text-[9px] font-bold uppercase tracking-widest">Misión</Link></li>
                                <li><Link to="/how-it-works" className="text-zinc-500 hover:text-white transition-colors text-[9px] font-bold uppercase tracking-widest">Tecnología</Link></li>
                            </ul>
                        </div>

                        <div className="space-y-4">
                            <h4 className="text-[8px] font-black uppercase tracking-[0.2em] text-zinc-500">Legal</h4>
                            <ul className="space-y-2">
                                <li><Link to="/privacy-policy" className="text-zinc-500 hover:text-white transition-colors text-[9px] font-bold uppercase tracking-widest">Privacidad</Link></li>
                                <li><Link to="/support" className="text-zinc-500 hover:text-white transition-colors text-[9px] font-bold uppercase tracking-widest">Soporte</Link></li>
                            </ul>
                        </div>

                        <div className="space-y-4 hidden md:block">
                            <h4 className="text-[8px] font-black uppercase tracking-[0.2em] text-zinc-500">Contacto</h4>
                            <p className="text-zinc-500 text-[9px] font-bold uppercase tracking-widest break-all">soporte@connectapp.com.co</p>
                        </div>
                    </div>
                </div>

                <div className="pt-8 border-t border-white/[0.03] flex justify-between items-center">
                    <p className="text-[7px] font-black uppercase tracking-[0.3em] text-zinc-800">
                        © 2026 CONNECT. TODOS LOS DERECHOS RESERVADOS.
                    </p>
                    <div className="flex items-center gap-6">
                        {isAdmin && (
                            <Link to="/admin/dashboard" className="text-[7px] font-black uppercase tracking-[0.3em] text-primary/40 hover:text-primary transition-colors">
                                GESTIÓN
                            </Link>
                        )}
                    </div>
                </div>
            </div>
        </footer>
    );
};
