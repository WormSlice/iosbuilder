import React from 'react';
import { motion } from 'framer-motion';
import { Rocket, Zap, Shield, Sparkles } from 'lucide-react';

export const Boosts: React.FC = () => {
    return (
        <div className="h-full min-h-[70vh] flex flex-col items-center justify-center text-center space-y-12">
            {/* Animated Rocket Container */}
            <div className="relative">
                <motion.div
                    animate={{
                        y: [0, -40, 0],
                        rotate: [0, 5, -5, 0],
                        scale: [1, 1.05, 1]
                    }}
                    transition={{
                        duration: 3,
                        repeat: Infinity,
                        ease: "easeInOut"
                    }}
                    className="relative z-10 p-12 bg-black rounded-[3rem] shadow-2xl shadow-black/20"
                >
                    <Rocket size={80} className="text-white fill-white/10" />

                    {/* Sparkles */}
                    <motion.div
                        animate={{ opacity: [0, 1, 0], scale: [0.5, 1.2, 0.5] }}
                        transition={{ duration: 2, repeat: Infinity, delay: 0 }}
                        className="absolute -top-4 -right-4 text-white"
                    >
                        <Sparkles size={24} />
                    </motion.div>
                </motion.div>

                {/* Trail/Particles */}
                <div className="absolute -bottom-10 left-1/2 -translate-x-1/2 flex flex-col items-center gap-1">
                    {[1, 2, 3].map(i => (
                        <motion.div
                            key={i}
                            animate={{
                                y: [0, 20, 40],
                                opacity: [0, 0.8, 0],
                                scale: [1, 0.5, 0]
                            }}
                            transition={{
                                duration: 1.5,
                                repeat: Infinity,
                                delay: i * 0.4,
                                ease: "easeOut"
                            }}
                            className="w-2 h-2 bg-zinc-200 rounded-full blur-[1px]"
                        />
                    ))}
                </div>

                {/* Glow Effect */}
                <motion.div
                    animate={{
                        scale: [1, 1.8, 1],
                        opacity: [0.1, 0.3, 0.1]
                    }}
                    transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
                    className="absolute -bottom-8 left-1/2 -translate-x-1/2 w-32 h-12 bg-zinc-200 blur-3xl rounded-full"
                />
            </div>

            <div className="space-y-4 max-w-xl px-6">
                <h1 className="text-5xl font-black tracking-tighter uppercase italic opacity-10">Section Locked</h1>
                <div className="flex items-center justify-center gap-4 py-2">
                    <div className="h-px w-12 bg-zinc-100"></div>
                    <p className="text-zinc-400 text-[10px] font-black uppercase tracking-[0.4em]">Propulsión de Contenido</p>
                    <div className="h-px w-12 bg-zinc-100"></div>
                </div>
                <p className="text-zinc-300 text-sm font-medium leading-relaxed">
                    Estamos calibrando los motores de visibilidad. El marketplace pronto despegará con opciones de pauta premium y destacados automáticos.
                </p>
            </div>

            <div className="grid grid-cols-3 gap-8 pt-8">
                {[
                    { icon: Zap, label: 'Visibilidad' },
                    { icon: Shield, label: 'Garantía' },
                    { icon: Sparkles, label: 'Premium' }
                ].map((item, i) => (
                    <motion.div
                        key={i}
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.5 + (i * 0.1) }}
                        className="flex flex-col items-center gap-2"
                    >
                        <div className="p-4 bg-zinc-50 rounded-2xl text-zinc-300">
                            <item.icon size={20} />
                        </div>
                        <span className="text-[9px] font-black uppercase tracking-widest text-zinc-400">{item.label}</span>
                    </motion.div>
                ))}
            </div>
        </div>
    );
};
