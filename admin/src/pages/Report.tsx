import React from 'react';

export const Report: React.FC = () => {
    return (
        <div className="pb-32 bg-[#07080A] text-white">
            <section className="relative pt-16 sm:pt-24 pb-16 sm:pb-24 border-b border-white/[0.05]">
                <div className="container-custom max-w-4xl space-y-6">
                    <h1 className="text-4xl sm:text-6xl md:text-7xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                        Canal de <br />
                        <span className="text-gradient-silver">Denuncias y Reportes.</span>
                    </h1>
                    <p className="text-base sm:text-xl text-zinc-400 font-normal leading-relaxed max-w-2xl">
                        Tu colaboración preserva la integridad de la comunidad. Describe cualquier irregularidad detectada en publicaciones, perfiles o chats.
                    </p>
                </div>
            </section>

            <section className="py-20 sm:py-28">
                <div className="container-custom max-w-3xl">
                    <form className="space-y-8" onSubmit={(e) => e.preventDefault()}>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                            <div className="space-y-2">
                                <label className="text-xs font-bold text-zinc-300">Tipo de Incidencia</label>
                                <select className="w-full bg-[#0E1017] border border-white/[0.12] rounded-xl px-4 py-3 text-sm text-white focus:outline-none focus:border-[#0094FF] transition-colors">
                                    <option value="fake">Perfil o Publicación Sospechosa</option>
                                    <option value="scam">Sospecha de Fraude o Estafa</option>
                                    <option value="abuse">Comportamiento Ofensivo en Chat</option>
                                    <option value="bug">Error Técnico en la App</option>
                                    <option value="other">Otro Motivo</option>
                                </select>
                            </div>
                            <div className="space-y-2">
                                <label className="text-xs font-bold text-zinc-300">ID o Teléfono del Usuario (Opcional)</label>
                                <input
                                    type="text"
                                    placeholder="@usuario o número"
                                    className="w-full bg-white/[0.03] border border-white/[0.12] rounded-xl px-4 py-3 text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:border-[#0094FF] transition-colors"
                                />
                            </div>
                        </div>

                        <div className="space-y-2">
                            <label className="text-xs font-bold text-zinc-300">Descripción de los Hechos</label>
                            <textarea
                                rows={5}
                                placeholder="Proporciona el mayor detalle posible sobre lo sucedido..."
                                className="w-full bg-white/[0.03] border border-white/[0.12] rounded-xl px-4 py-3 text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:border-[#0094FF] transition-colors resize-none"
                            />
                        </div>

                        <div className="space-y-2">
                            <label className="text-xs font-bold text-zinc-300">Tu Correo Electrónico</label>
                            <input
                                type="email"
                                placeholder="tu@email.com"
                                className="w-full bg-white/[0.03] border border-white/[0.12] rounded-xl px-4 py-3 text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:border-[#0094FF] transition-colors"
                            />
                        </div>

                        <button
                            type="submit"
                            className="bg-[#0094FF] hover:bg-[#0080DF] text-white text-xs font-bold px-8 py-3 rounded-full transition-colors cursor-pointer shadow-none active:scale-95"
                        >
                            Enviar Denuncia
                        </button>
                    </form>
                </div>
            </section>
        </div>
    );
};
