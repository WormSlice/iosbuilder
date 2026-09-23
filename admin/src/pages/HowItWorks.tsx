import React from 'react';
import { MapPin, MessageSquare, Languages, Star, Users, Shield } from 'lucide-react';

export const HowItWorks: React.FC = () => {
    const steps = [
        {
            num: "01",
            icon: MapPin,
            title: "Descubrimiento en tu radio local",
            desc: "Abre la aplicación y explora lo que las personas y comercios ofrecen a tu alrededor. Nuestro algoritmo de geocercanía organiza las publicaciones por distancia real, permitiéndote contactar y acordar entregas directas sin esperas."
        },
        {
            num: "02",
            icon: MessageSquare,
            title: "Pide activamente en 'Lo Tienes'",
            desc: "Si no encuentras lo que buscas, no pierdas tiempo navegando: publica una solicitud en 'Lo Tienes'. Los miembros de tu zona que dispongan del artículo o servicio te contactarán directamente en el chat con propuestas claras."
        },
        {
            num: "03",
            icon: Languages,
            title: "Traducción simultánea en el chat",
            desc: "Negocia sin barreras idiomáticas. Escribe en tu idioma nativo y el sistema traducirá automáticamente los mensajes entrantes y salientes en tiempo real dentro de la misma conversación."
        },
        {
            num: "04",
            icon: Star,
            title: "Reputación comunitaria inmutable",
            desc: "Al concretar un intercambio o servicio, ambas partes califican su experiencia. Esta evaluación se suma a un historial público inalterable que fomenta la confianza mutua entre vecinos."
        },
        {
            num: "05",
            icon: Users,
            title: "Comunidad y seguidores locales",
            desc: "Construye tu propia red. Si vendes con frecuencia o prestas un servicio profesional, otros usuarios pueden seguir tu perfil para enterarse de tus próximas publicaciones al instante."
        },
        {
            num: "06",
            icon: Shield,
            title: "Seguridad y privacidad desde el dispositivo",
            desc: "Validación rápida y silenciosa dentro de la aplicación móvil sin redirecciones a navegadores externos. Cifrado en tus comunicaciones y sin comercialización de tu actividad personal."
        }
    ];

    return (
        <div className="pb-32 bg-[#07080A] text-white">
            {/* Header */}
            <section className="relative pt-16 sm:pt-24 pb-16 sm:pb-24 border-b border-white/[0.05]">
                <div className="container-custom max-w-4xl space-y-6">
                    <h1 className="text-4xl sm:text-6xl md:text-7xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                        La experiencia móvil de <br />
                        <span className="text-gradient-silver">CONNECT en 6 pasos.</span>
                    </h1>
                    <p className="text-base sm:text-xl text-zinc-400 font-normal leading-relaxed max-w-2xl">
                        Diseñado para ser intuitivo, veloz y seguro. Así es como conectas con las personas y oportunidades de tu entorno.
                    </p>
                </div>
            </section>

            {/* Editorial Flow - ZERO BOXES / NO CARDS */}
            <section className="py-20 sm:py-28">
                <div className="container-custom max-w-4xl space-y-20">
                    {steps.map((step, idx) => {
                        const Icon = step.icon;
                        return (
                            <div
                                key={idx}
                                className={`space-y-5 ${idx > 0 ? 'pt-16 border-t border-white/[0.05]' : ''}`}
                            >
                                <div className="flex items-center gap-4">
                                    <div className="w-10 h-10 rounded-xl bg-white/[0.04] border border-white/[0.08] flex items-center justify-center text-[#0094FF]">
                                        <Icon size={18} />
                                    </div>
                                    <span className="font-mono text-xs font-bold text-[#0094FF] tracking-widest">
                                        PASO {step.num}
                                    </span>
                                </div>

                                <h2 className="text-2xl sm:text-4xl font-extrabold text-white tracking-tight font-archivo">
                                    {step.title}
                                </h2>

                                <p className="text-base sm:text-lg text-zinc-400 leading-relaxed max-w-3xl">
                                    {step.desc}
                                </p>
                            </div>
                        );
                    })}
                </div>
            </section>
        </div>
    );
};
