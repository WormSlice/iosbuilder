import React from 'react';

export const About: React.FC = () => {
    return (
        <div className="animate-in fade-in duration-700 pb-24">
            <section className="relative pt-32 pb-24 gradient-bg border-b border-white/[0.04]">
                <div className="container-custom relative z-10">
                    <h1 className="text-4xl md:text-8xl font-black tracking-tighter font-archivo mb-10 text-gradient uppercase">SOBRE <br /><span className="text-primary italic">CONNECT</span></h1>
                    <p className="text-lg md:text-xl text-zinc-400 max-w-2xl leading-relaxed font-medium">
                        Nacimos con la visión de crear un puente digital donde la seguridad y la oportunidad convergen en un solo ecosistema inteligente.
                    </p>
                </div>
            </section>

            <section className="py-24">
                <div className="container-custom grid grid-cols-1 md:grid-cols-2 gap-24">
                    <div className="space-y-12">
                        <div className="space-y-4">
                            <h2 className="text-3xl font-black tracking-tighter text-white uppercase">Nuestra Visión</h2>
                            <p className="text-zinc-500 leading-relaxed font-medium">Ser la plataforma líder global en interacciones comunitarias verificadas, devolviendo el control de los datos y la reputación a los usuarios.</p>
                        </div>
                        <div className="space-y-4">
                            <h2 className="text-3xl font-black tracking-tighter text-white uppercase">Nuestra Misión</h2>
                            <p className="text-zinc-500 leading-relaxed font-medium">Proporcionar herramientas tecnológicas avanzadas que faciliten la comunicación, el comercio y la conexión profesional en un entorno blindado.</p>
                        </div>
                    </div>

                    <div className="space-y-12 bg-white/[0.02] p-8 md:p-12 rounded-[2.5rem] border border-white/[0.05]">
                        <div className="space-y-2">
                            <h3 className="text-[10px] font-black uppercase tracking-widest text-primary">Enfoque Tecnológico</h3>
                            <p className="text-base font-black text-white">Infraestructura Distribuida</p>
                            <p className="text-zinc-500 text-xs font-medium">Arquitectura de microservicios diseñada para una escalabilidad horizontal y respuesta global inmediata.</p>
                        </div>
                        <div className="space-y-2">
                            <h3 className="text-[10px] font-black uppercase tracking-widest text-primary">Seguridad Elitista</h3>
                            <p className="text-base font-black text-white">Criptografía de Vanguardia</p>
                            <p className="text-zinc-500 text-xs font-medium">Cada interacción está protegida por protocolos de encripción asimétrica y validación biométrica.</p>
                        </div>
                    </div>
                </div>
            </section>
        </div>
    );
};
