import React from 'react';
import { Link } from 'react-router-dom';
import { Mail, Clock, MessageSquare } from 'lucide-react';

export const Support: React.FC = () => {
    return (
        <div className="animate-in fade-in duration-700 pb-24">
            <section className="relative pt-32 pb-24 gradient-bg border-b border-white/[0.04]">
                <div className="container-custom relative z-10">
                    <h1 className="text-6xl md:text-8xl font-black tracking-tighter font-archivo mb-10 text-gradient uppercase">CENTRO DE <br /><span className="text-primary italic">SOPORTE</span></h1>
                    <p className="text-lg md:text-xl text-zinc-400 max-w-2xl leading-relaxed font-medium">
                        ¿Necesitas ayuda? Nuestro equipo técnico está listo para asistirte en lo que necesites.
                    </p>
                </div>
            </section>

            <section className="py-24">
                <div className="container-custom">
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-20">
                        <div className="space-y-12">
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                                <div className="p-10 bg-white/[0.02] rounded-[2.5rem] border border-white/[0.05] space-y-4">
                                    <Mail className="text-primary" size={24} />
                                    <p className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Email Oficial</p>
                                    <p className="text-white text-sm font-bold">soporte@connectapp.com.co</p>
                                </div>
                                <div className="p-10 bg-white/[0.02] rounded-[2.5rem] border border-white/[0.05] space-y-4">
                                    <Clock className="text-primary" size={24} />
                                    <p className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Tiempo de Respuesta</p>
                                    <p className="text-white text-sm font-bold">Menos de 24 horas hábiles.</p>
                                </div>
                            </div>

                            <div className="space-y-6">
                                <h3 className="text-2xl font-black tracking-tight text-white uppercase">Preguntas Frecuentes</h3>
                                <p className="text-zinc-500 text-sm font-medium">La mayoría de las dudas se resuelven en nuestra sección de FAQ. Recomendamos revisarla antes de contactar.</p>
                                <Link to="/faq" className="inline-flex items-center gap-2 text-primary font-black hover:text-white transition-colors uppercase text-[10px] tracking-widest">
                                    Ir a FAQ <MessageSquare size={14} />
                                </Link>
                            </div>
                        </div>

                        <form className="space-y-8 bg-[#0a0a0a] p-10 md:p-16 rounded-[2.5rem] border border-white/[0.05]">
                            <div className="space-y-2">
                                <label className="text-[10px] font-black uppercase tracking-widest text-zinc-600 ml-1">Asunto</label>
                                <input type="text" placeholder="¿En qué podemos ayudarte?" className="premium-input py-4 text-sm" />
                            </div>
                            <div className="space-y-2">
                                <label className="text-[10px] font-black uppercase tracking-widest text-zinc-600 ml-1">Mensaje</label>
                                <textarea placeholder="Describe tu duda aquí..." rows={5} className="premium-input py-4 text-sm"></textarea>
                            </div>
                            <button type="submit" className="premium-button-primary w-full py-5 text-[11px]">
                                Enviar Mensaje
                            </button>
                        </form>
                    </div>
                </div>
            </section>
        </div>
    );
};
