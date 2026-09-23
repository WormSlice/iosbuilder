import React, { useState } from 'react';
import { ChevronDown } from 'lucide-react';

export const FAQ: React.FC = () => {
    const faqs = [
        {
            q: "¿Es gratuita la descarga y el uso de CONNECT?",
            a: "Sí, la descarga de la aplicación y el registro son 100% gratuitos tanto en Google Play como en la App Store. Puedes publicar, chatear y concretar acuerdos personales sin comisiones intermedias."
        },
        {
            q: "¿Cómo se protege la privacidad de mis datos?",
            a: "CONNECT opera bajo arquitectura zero-trust. Tus chats cuentan con cifrado de extremo a extremo, la verificación telefónica se procesa silenciosamente sin redirecciones web vulnerables y nunca comercializamos información personal con anunciantes."
        },
        {
            q: "¿Cómo funciona el sistema de traducción en el chat?",
            a: "El chat incluye un motor de traducción automática en tiempo real. Cuando una persona te escribe en otro idioma, verás el texto traducido instantáneamente en tu idioma preferido sin necesidad de salir de la aplicación ni usar traductores externos."
        },
        {
            q: "¿Cómo se calcula la reputación comunitaria?",
            a: "La reputación se basa estrictamente en transacciones e interacciones reales confirmadas por ambas partes. Ningún algoritmo ni pago puede alterar o comprar una calificación."
        },
        {
            q: "¿Cómo puedo reportar una irregularidad o conducta inapropiada?",
            a: "Puedes reportar cualquier perfil o publicación directamente desde la aplicación tocando el botón de opciones en el perfil o mensaje, o mediante el Canal de Denuncias en nuestra plataforma web."
        }
    ];

    const [openIndex, setOpenIndex] = useState<number | null>(0);

    return (
        <div className="pb-32 bg-[#07080A] text-white">
            <section className="relative pt-16 sm:pt-24 pb-16 sm:pb-24 border-b border-white/[0.05]">
                <div className="container-custom max-w-4xl space-y-6">
                    <h1 className="text-4xl sm:text-6xl md:text-7xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                        Preguntas <br />
                        <span className="text-gradient-silver">Frecuentes.</span>
                    </h1>
                    <p className="text-base sm:text-xl text-zinc-400 leading-relaxed font-normal max-w-2xl">
                        Todo lo que necesitas saber sobre el uso, la seguridad y el funcionamiento de la aplicación CONNECT.
                    </p>
                </div>
            </section>

            <section className="py-20 sm:py-28">
                <div className="container-custom max-w-4xl">
                    <div className="divide-y divide-white/[0.08] border-y border-white/[0.08]">
                        {faqs.map((faq, i) => {
                            const isOpen = openIndex === i;
                            return (
                                <div key={i} className="py-6 sm:py-8">
                                    <button
                                        className="w-full flex justify-between items-center text-left group focus:outline-none"
                                        onClick={() => setOpenIndex(isOpen ? null : i)}
                                    >
                                        <span className="font-bold text-white text-base sm:text-xl font-archivo pr-6 group-hover:text-[#0094FF] transition-colors">
                                            {faq.q}
                                        </span>
                                        <ChevronDown
                                            size={20}
                                            className={`text-zinc-400 transition-transform duration-300 shrink-0 ${
                                                isOpen ? 'rotate-180 text-[#0094FF]' : 'group-hover:text-white'
                                            }`}
                                        />
                                    </button>
                                    {isOpen && (
                                        <div className="pt-4 text-zinc-400 text-sm sm:text-base leading-relaxed max-w-3xl">
                                            {faq.a}
                                        </div>
                                    )}
                                </div>
                            );
                        })}
                    </div>
                </div>
            </section>
        </div>
    );
};
