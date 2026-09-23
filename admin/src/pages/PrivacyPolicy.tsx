import React from 'react';

export const PrivacyPolicy: React.FC = () => {
    return (
        <div className="pb-32 bg-[#07080A] text-white">
            <section className="relative pt-16 sm:pt-24 pb-16 sm:pb-24 border-b border-white/[0.05]">
                <div className="container-custom max-w-4xl space-y-4">
                    <h1 className="text-4xl sm:text-6xl md:text-7xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                        Política de <br />
                        <span className="text-gradient-silver">Privacidad.</span>
                    </h1>
                    <p className="text-xs font-mono text-zinc-500 uppercase tracking-widest">Última actualización: 1 de marzo de 2026</p>
                </div>
            </section>

            <section className="py-20 sm:py-28">
                <div className="container-custom max-w-4xl space-y-12 leading-relaxed text-zinc-400">
                    <div className="space-y-3">
                        <p className="text-base text-zinc-300 font-medium">
                            En <strong className="text-white">CONNECT</strong>, la soberanía de los datos es un pilar fundamental. Esta arquitectura garantiza que su información sea procesada bajo los estándares más estrictos de seguridad.
                        </p>
                    </div>

                    <div className="space-y-4 pt-8 border-t border-white/[0.06]">
                        <h2 className="text-xl font-bold text-white font-archivo">
                            Recopilación y Uso de Datos
                        </h2>
                        <ul className="space-y-3 text-sm text-zinc-400">
                            <li className="flex items-start gap-3">
                                <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                <span><strong className="text-white">Identidad Digital:</strong> Datos derivados de la vinculación con Google, Apple o número telefónico.</span>
                            </li>
                            <li className="flex items-start gap-3">
                                <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                <span><strong className="text-white">Geoprocesamiento:</strong> Ubicación precisa utilizada exclusivamente para calcular la distancia en el marketplace y filtrar anuncios cercanos.</span>
                            </li>
                        </ul>
                    </div>

                    <div className="space-y-4 pt-8 border-t border-white/[0.06]">
                        <h2 className="text-xl font-bold text-white font-archivo">
                            Cámara y Almacenamiento
                        </h2>
                        <p className="text-sm text-zinc-400">
                            Solicitamos acceso a la cámara y galería exclusivamente cuando decides subir fotos de artículos para publicaciones o personalizar tu perfil. No recolectamos información biométrica.
                        </p>
                    </div>

                    <div className="space-y-4 pt-8 border-t border-white/[0.06]">
                        <h2 className="text-xl font-bold text-white font-archivo">
                            Seguridad e Infraestructura
                        </h2>
                        <p className="text-sm text-zinc-400">
                            Toda la base de datos y la mensajería se alojan bajo protocolos cifrados y entornos cloud certificados de alta seguridad. Tus datos personales jamás se comercializan a terceros ni redes publicitarias.
                        </p>
                    </div>

                    <div className="pt-8 border-t border-white/[0.06]">
                        <p className="text-xs font-mono text-zinc-500 uppercase tracking-widest">Contacto para Dudas o Solicitudes de Datos:</p>
                        <p className="text-sm font-bold text-white mt-1">soporte@connectapp.com.co</p>
                    </div>
                </div>
            </section>
        </div>
    );
};
