import React from 'react';
import { DownloadButtons } from '../components/DownloadButtons';
import { Shield, Zap, Globe, ChevronRight } from 'lucide-react';
import { Link } from 'react-router-dom';

export const Home: React.FC = () => {
    return (
        <div className="animate-in fade-in duration-1000">
            {/* Hero Section */}
            <section className="relative pt-24 pb-28 gradient-bg">
                <div className="container-custom relative z-10 text-center space-y-12">
                    <div className="space-y-6 max-w-4xl mx-auto">
                        <h1 className="text-5xl md:text-9xl font-black tracking-tighter leading-[0.9] md:leading-[0.85] font-archivo text-gradient">
                            EL FUTURO <br /> DE LA <span className="text-primary italic">CONEXIÓN</span>
                        </h1>
                        <p className="text-base md:text-lg text-zinc-500 font-medium leading-relaxed max-w-2xl mx-auto">
                            Seguridad avanzada y rendimiento excepcional en una plataforma diseñada para la confianza comunitaria.
                        </p>
                    </div>

                    <div className="flex flex-col items-center gap-8">
                        <DownloadButtons />
                    </div>
                </div>
            </section>

            {/* Philosophy Section - No cards, just integrated layout */}
            <section className="py-24 border-t border-white/[0.03]">
                <div className="container-custom">
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-16">
                        <div className="space-y-4">
                            <Shield className="text-primary mb-2" size={24} />
                            <h3 className="text-base font-black tracking-tight text-white uppercase">Privacidad</h3>
                            <p className="text-zinc-500 text-xs leading-relaxed font-medium">Protocolos de encriptación avanzados y soberanía de datos garantizada por arquitectura distribuida.</p>
                        </div>

                        <div className="space-y-4 md:border-l md:border-white/[0.03] md:pl-16">
                            <Zap className="text-primary mb-2" size={24} />
                            <h3 className="text-base font-black tracking-tight text-white uppercase">Velocidad</h3>
                            <p className="text-zinc-500 text-xs leading-relaxed font-medium">Respuestas instantáneas procesadas en el borde de la red para una experiencia sin latencia.</p>
                        </div>

                        <div className="space-y-4 md:border-l md:border-white/[0.03] md:pl-16">
                            <Zap className="text-primary mb-2" size={24} />
                            <h3 className="text-base font-black tracking-tight text-white uppercase">Confianza</h3>
                            <p className="text-zinc-500 text-xs leading-relaxed font-medium">Sistema de reputación inteligente verificado por la comunidad y validado por IA.</p>
                        </div>
                    </div>
                </div>
            </section>

            {/* Minimal CTA */}
            <section className="py-28 border-t border-white/[0.03]">
                <div className="container-custom text-center space-y-8">
                    <h2 className="text-4xl md:text-6xl font-black tracking-tighter leading-none font-archivo max-w-2xl mx-auto text-gradient uppercase">
                        Experimenta <br /> CONNECT HOY
                    </h2>
                    <div className="flex justify-center">
                        <Link to="/signup" className="premium-button-primary hover:scale-105">
                            Comenzar Ahora <ChevronRight size={14} />
                        </Link>
                    </div>
                </div>
            </section>
        </div>
    );
};
