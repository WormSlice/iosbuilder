import React from 'react';

export const PrivacyPolicy: React.FC = () => {
    return (
        <div className="gradient-bg min-h-screen py-16 animate-in fade-in duration-700">
            <div className="container-custom max-w-3xl">
                <header className="mb-12 border-b border-white/[0.04] pb-8">
                    <h1 className="text-3xl md:text-5xl font-black tracking-tighter font-archivo mb-3 text-gradient uppercase">Privacidad</h1>
                    <p className="text-zinc-600 text-[9px] font-black uppercase tracking-[0.3em]">Última actualización: 1 de marzo de 2026</p>
                </header>

                <div className="space-y-12 leading-relaxed text-zinc-400">
                    <section className="space-y-3">
                        <p className="text-xs font-medium">
                            En <strong className="text-white">CONNECT</strong>, la soberanía de los datos es un pilar fundamental. Esta arquitectura garantiza que su información sea procesada bajo los estándares más estrictos de seguridad.
                        </p>
                    </section>

                    <section className="space-y-6">
                        <h2 className="text-sm font-black text-white uppercase tracking-widest flex items-center gap-2">
                            <span className="text-primary">/</span> Recopilación de Datos
                        </h2>
                        <ul className="space-y-4">
                            <li className="flex gap-4">
                                <span className="w-1 h-1 bg-primary mt-1.5 shrink-0"></span>
                                <p className="text-[11px]"><strong className="text-white">Identidad Digital:</strong> Datos derivados de la vinculación con Google, Apple o credenciales directas.</p>
                            </li>
                            <li className="flex gap-4">
                                <span className="w-1 h-1 bg-primary mt-1.5 shrink-0"></span>
                                <p className="text-[11px]"><strong className="text-white">Geoprocesamiento:</strong> Datos de ubicación precisa utilizados exclusivamente para la funcionalidad del mapa y búsqueda local.</p>
                            </li>
                        </ul>
                    </section>

                    <section className="border-l border-primary/20 pl-8 space-y-4">
                        <h2 className="text-sm font-black text-white uppercase tracking-widest flex items-center gap-2">
                            <span className="text-primary">/</span> Multimedia y Sensores
                        </h2>
                        <p className="text-[11px]">Solicitamos acceso a la <strong className="text-white">Cámara</strong> para personalización de perfil y escaneo de códigos. No procesamos información biométrica ni accedemos a sensores en segundo plano.</p>
                    </section>

                    <section className="space-y-6">
                        <h2 className="text-sm font-black text-white uppercase tracking-widest flex items-center gap-2">
                            <span className="text-primary">/</span> Google Cloud (Firebase)
                        </h2>
                        <p className="text-[11px]">Toda la infraestructura de datos reside en servidores encriptados de alta disponibilidad, garantizando integridad y recuperación ante desastres en tiempo real.</p>
                    </section>

                    <div className="pt-12 border-t border-white/[0.04]">
                        <p className="text-[9px] font-black uppercase tracking-widest text-zinc-700">Dudas o Solicitudes de Datos:</p>
                        <p className="text-xs font-bold text-white mt-1">soporte@connectapp.com.co</p>
                    </div>
                </div>
            </div>
        </div>
    );
};
