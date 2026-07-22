import React from 'react';

export const Report: React.FC = () => {
    return (
        <div className="animate-in fade-in duration-700 pb-24">
            <section className="py-24 bg-white border-b border-border">
                <div className="container-custom">
                    <h1 className="text-5xl md:text-7xl font-black tracking-tighter font-archivo mb-10">REPORTAR <span className="text-primary">PROBLEMA</span></h1>
                    <p className="text-xl text-secondary max-w-2xl leading-relaxed">
                        Tu reporte nos ayuda a mantener CONNECT seguro y eficiente. Por favor, sé lo más descriptivo posible.
                    </p>
                </div>
            </section>

            <section className="py-24">
                <div className="container-custom max-w-2xl">
                    <form className="space-y-8 bg-muted p-10 md:p-16 rounded-[2.5rem] border border-border">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                            <div className="space-y-2">
                                <label className="text-[10px] font-black uppercase tracking-widest text-secondary">Tipo de Problema</label>
                                <select className="w-full bg-white border border-border px-4 py-3 rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-primary/20">
                                    <option>Error Técnico (Bug)</option>
                                    <option>Usuario Sospechoso</option>
                                    <option>Problema de Pago</option>
                                    <option>Sugerencia</option>
                                    <option>Otro</option>
                                </select>
                            </div>
                            <div className="space-y-2">
                                <label className="text-[10px] font-black uppercase tracking-widest text-secondary">ID de Usuario (Opcional)</label>
                                <input type="text" placeholder="@usuario123" className="w-full bg-white border border-border px-4 py-3 rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-primary/20" />
                            </div>
                        </div>

                        <div className="space-y-2">
                            <label className="text-[10px] font-black uppercase tracking-widest text-secondary">Descripción Detallada</label>
                            <textarea placeholder="Explica qué sucedió..." rows={5} className="w-full bg-white border border-border px-4 py-3 rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-primary/20"></textarea>
                        </div>

                        <div className="space-y-2">
                            <label className="text-[10px] font-black uppercase tracking-widest text-secondary">Correo Electrónico de Contacto</label>
                            <input type="email" placeholder="email@ejemplo.com" className="w-full bg-white border border-border px-4 py-3 rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-primary/20" />
                        </div>

                        <div className="space-y-4">
                            <label className="text-[10px] font-black uppercase tracking-widest text-secondary">Evidencia (Opcional)</label>
                            <div className="border-2 border-dashed border-border rounded-2xl p-8 text-center text-xs text-secondary hover:border-primary transition-colors cursor-pointer">
                                Haz clic o arrastra una imagen aquí
                            </div>
                        </div>

                        <button type="submit" className="w-full bg-foreground text-white py-4 rounded-xl font-black text-sm uppercase tracking-widest hover:bg-zinc-800 transition-all shadow-lg">
                            Enviar Reporte
                        </button>
                    </form>
                </div>
            </section>
        </div>
    );
};
