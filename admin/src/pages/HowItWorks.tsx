import React from 'react';
import { WorkInProgress } from '../components/WorkInProgress';

export const HowItWorks: React.FC = () => {
    const steps = [
        {
            title: "Publicaciones Inteligentes",
            desc: "Algoritmos que muestran tu contenido a quien realmente le interesa basado en geolocalización y preferencias.",
            status: "ready"
        },
        {
            title: "Sistemas de Reputación",
            desc: "Gana confianza a través de interacciones exitosas y validaciones de otros miembros de la comunidad.",
            status: "ready"
        },
        {
            title: "Chat con Traducción",
            desc: "Rompe las barreras del idioma con nuestro sistema de traducción automática integrado en cada mensaje.",
            status: "ready"
        },
        {
            title: "Membresías & Monetización",
            desc: "Accede a beneficios exclusivos y potencia tu alcance con nuestros planes empresariales.",
            status: "in-progress"
        },
        {
            title: "Envío Seguro",
            desc: "Protocolos de seguimiento y verificación para garantizar que tus productos lleguen a destino.",
            status: "in-progress"
        },
        {
            title: "Sistema de Seguidores",
            desc: "Crea tu propia audiencia y mantén a tus clientes informados de cada novedad.",
            status: "ready"
        }
    ];

    return (
        <div className="animate-in fade-in duration-700 pb-24">
            <section className="relative pt-32 pb-24 gradient-bg border-b border-white/[0.04]">
                <div className="container-custom relative z-10">
                    <h1 className="text-6xl md:text-8xl font-black tracking-tighter font-archivo mb-10 text-gradient uppercase">CÓMO <br /><span className="text-primary italic">FUNCIONA</span></h1>
                    <p className="text-lg md:text-xl text-zinc-400 max-w-2xl leading-relaxed font-medium">
                        ConnectApp es un ecosistema compuesto por múltiples módulos integrados que trabajan en armonía para potenciar tus conexiones.
                    </p>
                </div>
            </section>

            <section className="py-24">
                <div className="container-custom">
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                        {steps.map((step, i) => (
                            <div key={i} className="p-12 border border-white/[0.05] rounded-[2.5rem] hover:bg-white/[0.02] transition-all group bg-[#0a0a0a] relative overflow-hidden">
                                <div className="w-12 h-12 bg-white/[0.03] rounded-full mb-8 flex items-center justify-center font-black text-primary group-hover:bg-primary group-hover:text-white transition-all shadow-[0_0_15px_rgba(0,148,255,0.1)]">
                                    {i + 1}
                                </div>
                                <h3 className="text-xl font-black mb-4 tracking-tighter text-white uppercase">{step.title}</h3>
                                <p className="text-zinc-500 text-sm leading-relaxed font-medium">{step.desc}</p>
                                {step.status === 'in-progress' && (
                                    <div className="mt-6">
                                        <WorkInProgress />
                                    </div>
                                )}
                            </div>
                        ))}
                    </div>
                </div>
            </section>
        </div>
    );
};
