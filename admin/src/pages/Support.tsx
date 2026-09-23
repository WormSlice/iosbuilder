import React from 'react';
import { Link } from 'react-router-dom';
import { Mail, Clock, MessageSquare } from 'lucide-react';

export const Support: React.FC = () => {
    return (
        <div className="pb-32 bg-[#07080A] text-white">
            <section className="relative pt-16 sm:pt-24 pb-16 sm:pb-24 border-b border-white/[0.05]">
                <div className="container-custom max-w-4xl space-y-6">
                    <h1 className="text-4xl sm:text-6xl md:text-7xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                        Centro de <br />
                        <span className="text-gradient-silver">Soporte Técnico.</span>
                    </h1>
                    <p className="text-base sm:text-xl text-zinc-400 font-normal leading-relaxed max-w-2xl">
                        ¿Tienes dudas sobre la app móvil o necesitas asistencia técnica? Nuestro equipo está disponible para ayudarte.
                    </p>
                </div>
            </section>

            <section className="py-20 sm:py-28">
                <div className="container-custom max-w-4xl">
                    <div className="grid grid-cols-1 md:grid-cols-12 gap-16">
                        {/* Info details */}
                        <div className="md:col-span-5 space-y-12">
                            <div className="space-y-3">
                                <div className="flex items-center gap-3 text-[#0094FF]">
                                    <Mail size={18} />
                                    <span className="font-mono text-xs font-bold tracking-widest text-zinc-400 uppercase">Email Oficial</span>
                                </div>
                                <p className="text-white text-base sm:text-lg font-bold">soporte@connectapp.com.co</p>
                            </div>

                            <div className="space-y-3 pt-8 border-t border-white/[0.06]">
                                <div className="flex items-center gap-3 text-[#0094FF]">
                                    <Clock size={18} />
                                    <span className="font-mono text-xs font-bold tracking-widest text-zinc-400 uppercase">Tiempo de Respuesta</span>
                                </div>
                                <p className="text-zinc-300 text-sm sm:text-base leading-relaxed">Menos de 24 horas hábiles.</p>
                            </div>

                            <div className="space-y-3 pt-8 border-t border-white/[0.06]">
                                <h3 className="text-lg font-bold text-white font-archivo">Preguntas Frecuentes</h3>
                                <p className="text-zinc-400 text-sm leading-relaxed">
                                    La mayoría de las dudas sobre la app se resuelven de inmediato en nuestra sección de preguntas frecuentes.
                                </p>
                                <Link
                                    to="/faq"
                                    className="inline-flex items-center gap-2 text-xs font-bold text-[#0094FF] hover:text-white transition-colors"
                                >
                                    <span>Consultar Preguntas Frecuentes</span>
                                    <MessageSquare size={13} />
                                </Link>
                            </div>
                        </div>

                        {/* Form (Clean, no box card wrapping) */}
                        <div className="md:col-span-7">
                            <form className="space-y-6" onSubmit={(e) => e.preventDefault()}>
                                <div className="space-y-2">
                                    <label className="text-xs font-bold text-zinc-300">Asunto</label>
                                    <input
                                        type="text"
                                        placeholder="¿En qué podemos ayudarte?"
                                        className="w-full bg-white/[0.03] border border-white/[0.12] rounded-xl px-4 py-3 text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:border-[#0094FF] transition-colors"
                                    />
                                </div>

                                <div className="space-y-2">
                                    <label className="text-xs font-bold text-zinc-300">Correo Electrónico</label>
                                    <input
                                        type="email"
                                        placeholder="tu@email.com"
                                        className="w-full bg-white/[0.03] border border-white/[0.12] rounded-xl px-4 py-3 text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:border-[#0094FF] transition-colors"
                                    />
                                </div>

                                <div className="space-y-2">
                                    <label className="text-xs font-bold text-zinc-300">Mensaje Detallado</label>
                                    <textarea
                                        rows={5}
                                        placeholder="Describe tu consulta aquí..."
                                        className="w-full bg-white/[0.03] border border-white/[0.12] rounded-xl px-4 py-3 text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:border-[#0094FF] transition-colors resize-none"
                                    />
                                </div>

                                <button
                                    type="submit"
                                    className="bg-[#0094FF] hover:bg-[#0080DF] text-white text-xs font-bold px-6 py-3 rounded-full transition-colors cursor-pointer shadow-none active:scale-95"
                                >
                                    Enviar Mensaje
                                </button>
                            </form>
                        </div>
                    </div>
                </div>
            </section>
        </div>
    );
};
