import React, { useState } from 'react';
import { ChevronDown, ChevronUp } from 'lucide-react';

export const FAQ: React.FC = () => {
    const faqs = [
        {
            q: "¿Es gratuita la descarga de ConnectApp?",
            a: "Sí, la descarga y el registro básico son totalmente gratuitos en Google Play y App Store."
        },
        {
            q: "¿Cómo garantizan la seguridad de mis datos?",
            a: "Utilizamos infraestructura de Google Cloud y encripción de punto a punto para proteger tu información personal y transaccional."
        },
        {
            q: "¿Qué significan los niveles de reputación?",
            a: "Son indicadores que reflejan tu confiabilidad dentro de la comunidad basados en tus interacciones positivas y verificaciones de identidad."
        },
        {
            q: "¿Puedo usar ConnectApp en varios dispositivos?",
            a: "Sí, puedes sincronizar tu cuenta en múltiples dispositivos manteniendo tu historial y configuraciones intactas."
        },
        {
            q: "¿Cómo reporto a un usuario sospechoso?",
            a: "Puedes hacerlo directamente desde el perfil del usuario en la app o a través de nuestra página de Soporte en la sección 'Reportar un Problema'."
        }
    ];

    const [openIndex, setOpenIndex] = useState<number | null>(null);

    return (
        <div className="animate-in fade-in duration-700 pb-24">
            <section className="relative pt-32 pb-24 gradient-bg border-b border-white/[0.04]">
                <div className="container-custom relative z-10">
                    <h1 className="text-5xl md:text-8xl font-black tracking-tighter font-archivo mb-10 text-gradient uppercase">FAQ</h1>
                    <p className="text-lg md:text-xl text-zinc-400 max-w-2xl leading-relaxed font-medium">
                        Respuestas a las preguntas más frecuentes sobre el ecosistema y funcionamiento de CONNECT.
                    </p>
                </div>
            </section>

            <section className="py-24">
                <div className="container-custom max-w-3xl">
                    <div className="space-y-4">
                        {faqs.map((faq, i) => (
                            <div key={i} className="border border-white/[0.05] rounded-[2rem] overflow-hidden bg-[#0a0a0a] transition-all hover:bg-white/[0.01]">
                                <button
                                    className="w-full flex justify-between items-center p-6 md:p-8 text-left transition-all"
                                    onClick={() => setOpenIndex(openIndex === i ? null : i)}
                                >
                                    <span className="font-black text-white uppercase tracking-tight text-sm md:text-base">{faq.q}</span>
                                    {openIndex === i ? <ChevronUp size={20} className="text-primary" /> : <ChevronDown size={20} className="text-zinc-600" />}
                                </button>
                                {openIndex === i && (
                                    <div className="p-6 md:p-8 pt-0 text-zinc-500 text-xs md:text-sm leading-relaxed font-medium border-t border-white/[0.05] animate-in slide-in-from-top-2 duration-300">
                                        {faq.a}
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
