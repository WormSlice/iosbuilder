import React from 'react';

export const About: React.FC = () => {
    return (
        <div className="pb-32 bg-[#07080A] text-white">
            {/* Header */}
            <section className="relative pt-16 sm:pt-28 pb-16 sm:pb-24 border-b border-white/[0.05]">
                <div className="container-custom max-w-4xl space-y-6">
                    <h1 className="text-4xl sm:text-7xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                        Construyendo el futuro del comercio <br />
                        <span className="text-gradient-silver">y la conexión comunitaria.</span>
                    </h1>
                    <p className="text-lg sm:text-xl text-zinc-400 font-normal leading-relaxed max-w-2xl">
                        Nacimos para transformar la forma en que las personas compran, venden y se comunican a nivel local, devolviendo el control y la confianza a las personas.
                    </p>
                </div>
            </section>

            {/* Editorial Manifesto - ZERO BOXES */}
            <section className="py-24 sm:py-32">
                <div className="container-custom max-w-4xl space-y-24">
                    {/* Item 1 */}
                    <div className="space-y-4">
                        <span className="text-xs font-mono font-bold text-[#0094FF] tracking-widest block">
                            01 / FILOSOFÍA
                        </span>
                        <h2 className="text-2xl sm:text-4xl font-extrabold text-white tracking-tight font-archivo">
                            Cercanía e impacto directo en tu entorno.
                        </h2>
                        <p className="text-base sm:text-lg text-zinc-400 leading-relaxed max-w-3xl">
                            Las plataformas convencionales priorizan el envío masivo e impersonal a miles de kilómetros. En CONNECT reenfocamos la mirada hacia lo que tienes a tu alrededor: vecinos, profesionales y comercios cercanos con quienes puedes tratar cara a cara y generar valor en tu propia comunidad.
                        </p>
                    </div>

                    {/* Item 2 */}
                    <div className="space-y-4 pt-12 border-t border-white/[0.05]">
                        <span className="text-xs font-mono font-bold text-[#0094FF] tracking-widest block">
                            02 / CONFIANZA
                        </span>
                        <h2 className="text-2xl sm:text-4xl font-extrabold text-white tracking-tight font-archivo">
                            Reputación inalterable forjada con hechos.
                        </h2>
                        <p className="text-base sm:text-lg text-zinc-400 leading-relaxed max-w-3xl">
                            En un entorno digital saturado de perfiles anónimos y reseñas manipuladas, CONNECT implementa un sistema donde cada valoración proviene de interacciones y acuerdos reales entre miembros verificados. No existen atajos ni algoritmos de pago para inflar la reputación.
                        </p>
                    </div>

                    {/* Item 3 */}
                    <div className="space-y-4 pt-12 border-t border-white/[0.05]">
                        <span className="text-xs font-mono font-bold text-[#0094FF] tracking-widest block">
                            03 / INNOVACIÓN
                        </span>
                        <h2 className="text-2xl sm:text-4xl font-extrabold text-white tracking-tight font-archivo">
                            Comunicación sin fronteras de lenguaje.
                        </h2>
                        <p className="text-base sm:text-lg text-zinc-400 leading-relaxed max-w-3xl">
                            Nuestra tecnología de traducción simultánea integrada en el chat permite que un comprador y un vendedor de idiomas completamente distintos cierren un acuerdo sin esfuerzo y en tiempo real, rompiendo una de las barreras más antiguas del comercio.
                        </p>
                    </div>

                    {/* Item 4 */}
                    <div className="space-y-4 pt-12 border-t border-white/[0.05]">
                        <span className="text-xs font-mono font-bold text-[#0094FF] tracking-widest block">
                            04 / PRIVACIDAD
                        </span>
                        <h2 className="text-2xl sm:text-4xl font-extrabold text-white tracking-tight font-archivo">
                            Tus datos personales te pertenecen.
                        </h2>
                        <p className="text-base sm:text-lg text-zinc-400 leading-relaxed max-w-3xl">
                            No rastreamos tus hábitos para venderlos a redes publicitarias ni cobramos porcentajes sobre tus tratos personales. CONNECT está construido bajo una arquitectura segura y transparente para que uses la plataforma con total tranquilidad.
                        </p>
                    </div>
                </div>
            </section>
        </div>
    );
};
