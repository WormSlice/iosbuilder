import React from 'react';
import { motion } from 'framer-motion';
import { QRCodeSVG } from 'qrcode.react';
import { DownloadButtons } from '../components/DownloadButtons';

export const Home: React.FC = () => {
    return (
        <div className="relative overflow-hidden bg-[#07080A] text-white">
            {/* Ambient Background Radial Mesh (Subtle & Fluid) */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[900px] h-[500px] bg-gradient-to-b from-[#0094FF]/[0.08] via-transparent to-transparent blur-3xl pointer-events-none -z-10" />

            {/* 1. HERO SECTION */}
            <section className="relative pt-12 sm:pt-20 pb-20 sm:pb-32">
                <div className="container-custom text-center space-y-8">
                    {/* Main Headline (Zero pill tags above it!) */}
                    <motion.div
                        initial={{ opacity: 0, y: 16 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
                        className="max-w-3xl mx-auto space-y-5"
                    >
                        <h1 className="text-4xl sm:text-6xl md:text-7xl font-extrabold tracking-tight font-archivo leading-[1.05] text-white">
                            El marketplace local <br />
                            <span className="text-gradient-silver">en tu bolsillo.</span>
                        </h1>
                        <p className="text-base sm:text-lg text-zinc-400 font-normal leading-relaxed max-w-2xl mx-auto">
                            Descubre publicaciones a tu alrededor, pide lo que necesitas y negocia en tiempo real con traducción automática y reputación verificada.
                        </p>
                    </motion.div>

                    {/* App Store / Google Play Buttons */}
                    <motion.div
                        initial={{ opacity: 0, y: 16 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.6, delay: 0.15, ease: [0.16, 1, 0.3, 1] }}
                        className="pt-2"
                    >
                        <DownloadButtons />
                    </motion.div>

                    {/* CENTRAL IPHONE 16 PRO SHOWCASE */}
                    <motion.div
                        initial={{ opacity: 0, y: 35, scale: 0.98 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        transition={{ duration: 0.8, delay: 0.25, ease: [0.16, 1, 0.3, 1] }}
                        className="pt-8 max-w-[320px] sm:max-w-[360px] mx-auto"
                    >
                        <div className="iphone-frame">
                            <div className="iphone-screen aspect-[1290/2796]">
                                <div className="iphone-island" />
                                <img
                                    src="/screens/1.webp"
                                    alt="CONNECT App Inicio"
                                    className="w-full h-full object-cover"
                                />
                            </div>
                        </div>
                    </motion.div>
                </div>
            </section>

            {/* 2. FEATURE 1: "LO TIENES" (Visual Phone Storytelling - NO BOXES!) */}
            <section id="lo-tienes" className="py-24 sm:py-36 border-t border-white/[0.04]">
                <div className="container-custom">
                    <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 sm:gap-20 items-center">
                        {/* Phone Mockup on Left */}
                        <motion.div
                            initial={{ opacity: 0, x: -30 }}
                            whileInView={{ opacity: 1, x: 0 }}
                            viewport={{ once: true, amount: 0.3 }}
                            transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
                            className="lg:col-span-6 flex justify-center order-2 lg:order-1"
                        >
                            <div className="iphone-frame max-w-[300px] sm:max-w-[340px]">
                                <div className="iphone-screen aspect-[1290/2796]">
                                    <div className="iphone-island" />
                                    <img
                                        src="/screens/2.webp"
                                        alt="CONNECT Lo Tienes"
                                        className="w-full h-full object-cover"
                                    />
                                </div>
                            </div>
                        </motion.div>

                        {/* Pure Editorial Narrative on Right (NO BOXES) */}
                        <motion.div
                            initial={{ opacity: 0, x: 30 }}
                            whileInView={{ opacity: 1, x: 0 }}
                            viewport={{ once: true, amount: 0.3 }}
                            transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
                            className="lg:col-span-6 space-y-6 text-left order-1 lg:order-2"
                        >
                            <h2 className="text-3xl sm:text-5xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                                Pide lo que buscas. <br />
                                <span className="text-gradient-silver">Tu comunidad responde.</span>
                            </h2>
                            <p className="text-base sm:text-lg text-zinc-400 leading-relaxed font-normal">
                                En lugar de perder horas buscando entre miles de anuncios, crea una petición en <strong>"Lo Tienes"</strong>. Explica qué artículo, vehículo o servicio necesitas y las personas cercanas que lo tienen disponible te contactarán directamente.
                            </p>
                            <div className="pt-4 space-y-4 text-sm text-zinc-300">
                                <div className="flex items-start gap-3">
                                    <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                    <span>Demanda activa: tú pides, la gente cercana te ofrece soluciones.</span>
                                </div>
                                <div className="flex items-start gap-3">
                                    <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                    <span>Respuestas instantáneas en chat privado sin publicar tu teléfono.</span>
                                </div>
                                <div className="flex items-start gap-3">
                                    <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                    <span>Negociación limpia, rápida y sin comisiones intermedias.</span>
                                </div>
                            </div>
                        </motion.div>
                    </div>
                </div>
            </section>

            {/* 3. FEATURE 2: CHAT CON TRADUCCIÓN SIMULTÁNEA (NO BOXES!) */}
            <section id="traduccion" className="py-24 sm:py-36 border-t border-white/[0.04]">
                <div className="container-custom">
                    <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 sm:gap-20 items-center">
                        {/* Narrative on Left */}
                        <motion.div
                            initial={{ opacity: 0, x: -30 }}
                            whileInView={{ opacity: 1, x: 0 }}
                            viewport={{ once: true, amount: 0.3 }}
                            transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
                            className="lg:col-span-6 space-y-6 text-left"
                        >
                            <h2 className="text-3xl sm:text-5xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                                Chatea en cualquier idioma <br />
                                <span className="text-gradient-silver">sin salir de la app.</span>
                            </h2>
                            <p className="text-base sm:text-lg text-zinc-400 leading-relaxed font-normal">
                                La traducción en tiempo real de CONNECT elimina las barreras lingüísticas. Escribe en tu idioma nativo y el destinatario leerá la traducción automática instantáneamente dentro de la conversación.
                            </p>
                            <div className="pt-4 space-y-4 text-sm text-zinc-300">
                                <div className="flex items-start gap-3">
                                    <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                    <span>Traducción bidireccional inmediata en más de 40 idiomas.</span>
                                </div>
                                <div className="flex items-start gap-3">
                                    <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                    <span>Mensajería encriptada de punto a punto para máxima privacidad.</span>
                                </div>
                                <div className="flex items-start gap-3">
                                    <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                    <span>Envío de notas de voz, fotos de producto y confirmaciones de entrega.</span>
                                </div>
                            </div>
                        </motion.div>

                        {/* Phone Mockup on Right */}
                        <motion.div
                            initial={{ opacity: 0, x: 30 }}
                            whileInView={{ opacity: 1, x: 0 }}
                            viewport={{ once: true, amount: 0.3 }}
                            transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
                            className="lg:col-span-6 flex justify-center"
                        >
                            <div className="iphone-frame max-w-[300px] sm:max-w-[340px]">
                                <div className="iphone-screen aspect-[1290/2796]">
                                    <div className="iphone-island" />
                                    <img
                                        src="/screens/5.webp"
                                        alt="CONNECT Chats"
                                        className="w-full h-full object-cover"
                                    />
                                </div>
                            </div>
                        </motion.div>
                    </div>
                </div>
            </section>

            {/* 4. FEATURE 3: MARKETPLACE & REPUTACIÓN (NO BOXES!) */}
            <section id="marketplace" className="py-24 sm:py-36 border-t border-white/[0.04]">
                <div className="container-custom">
                    <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 sm:gap-20 items-center">
                        {/* Phone Mockup on Left */}
                        <motion.div
                            initial={{ opacity: 0, x: -30 }}
                            whileInView={{ opacity: 1, x: 0 }}
                            viewport={{ once: true, amount: 0.3 }}
                            transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
                            className="lg:col-span-6 flex justify-center order-2 lg:order-1"
                        >
                            <div className="iphone-frame max-w-[300px] sm:max-w-[340px]">
                                <div className="iphone-screen aspect-[1290/2796]">
                                    <div className="iphone-island" />
                                    <img
                                        src="/screens/3.webp"
                                        alt="CONNECT Publicación"
                                        className="w-full h-full object-cover"
                                    />
                                </div>
                            </div>
                        </motion.div>

                        {/* Narrative on Right */}
                        <motion.div
                            initial={{ opacity: 0, x: 30 }}
                            whileInView={{ opacity: 1, x: 0 }}
                            viewport={{ once: true, amount: 0.3 }}
                            transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
                            className="lg:col-span-6 space-y-6 text-left order-1 lg:order-2"
                        >
                            <h2 className="text-3xl sm:text-5xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                                Publicaciones verificadas. <br />
                                <span className="text-gradient-silver">Confianza garantizada.</span>
                            </h2>
                            <p className="text-base sm:text-lg text-zinc-400 leading-relaxed font-normal">
                                En CONNECT cada perfil cuenta con un puntaje de reputación forjado en transacciones e interacciones reales de la comunidad. Sin perfiles fantasma ni intermediarios artificiales.
                            </p>
                            <div className="pt-4 space-y-4 text-sm text-zinc-300">
                                <div className="flex items-start gap-3">
                                    <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                    <span>Filtros avanzados por categoría, rango de precio y radio geográfico.</span>
                                </div>
                                <div className="flex items-start gap-3">
                                    <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                    <span>Calificaciones mutuas al finalizar cada intercambio o acuerdo.</span>
                                </div>
                                <div className="flex items-start gap-3">
                                    <span className="w-1.5 h-1.5 rounded-full bg-[#0094FF] mt-2 shrink-0" />
                                    <span>Sigue a tus vendedores favoritos para enterarte de sus novedades.</span>
                                </div>
                            </div>
                        </motion.div>
                    </div>
                </div>
            </section>

            {/* 5. SECURITY & PRIVACY SECTION (Pure Editorial Manifesto - ZERO BOXES!) */}
            <section id="seguridad" className="py-24 sm:py-36 border-t border-white/[0.04]">
                <div className="container-custom max-w-4xl space-y-16">
                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        viewport={{ once: true, amount: 0.3 }}
                        transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
                        className="space-y-4 text-center sm:text-left"
                    >
                        <h2 className="text-3xl sm:text-5xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                            Seguridad desde el núcleo, <br />
                            <span className="text-gradient-silver">no como un añadido.</span>
                        </h2>
                        <p className="text-base sm:text-lg text-zinc-400 leading-relaxed font-normal max-w-2xl">
                            CONNECT fue diseñado para devolverte el control absoluto de tus interacciones y de tus datos.
                        </p>
                    </motion.div>

                    <div className="space-y-12">
                        {/* Principle 01 */}
                        <div className="space-y-3 pt-8 border-t border-white/[0.06]">
                            <span className="text-xs font-mono font-bold text-[#0094FF] tracking-widest block">
                                01 / VERIFICACIÓN NATIVA
                            </span>
                            <h3 className="text-xl sm:text-2xl font-bold text-white tracking-tight font-archivo">
                                Validación 100% dentro de la app móvil.
                            </h3>
                            <p className="text-sm sm:text-base text-zinc-400 leading-relaxed">
                                Sin redirecciones molestas a páginas externas ni ventanas emergentes inseguras. La confirmación de tu número y perfil se ejecuta silenciosa y directamente en la aplicación.
                            </p>
                        </div>

                        {/* Principle 02 */}
                        <div className="space-y-3 pt-8 border-t border-white/[0.06]">
                            <span className="text-xs font-mono font-bold text-[#0094FF] tracking-widest block">
                                02 / CIFRADO DIRECTO
                            </span>
                            <h3 className="text-xl sm:text-2xl font-bold text-white tracking-tight font-archivo">
                                Conversaciones y acuerdos protegidos.
                            </h3>
                            <p className="text-sm sm:text-base text-zinc-400 leading-relaxed">
                                Tus mensajes, peticiones y fotos se transmiten bajo protocolos cifrados de alta seguridad. Tus datos no se exponen ni se venden a redes publicitarias.
                            </p>
                        </div>

                        {/* Principle 03 */}
                        <div className="space-y-3 pt-8 border-t border-white/[0.06]">
                            <span className="text-xs font-mono font-bold text-[#0094FF] tracking-widest block">
                                03 / REPUTACIÓN TRANSPARENTE
                            </span>
                            <h3 className="text-xl sm:text-2xl font-bold text-white tracking-tight font-archivo">
                                Calificaciones respaldadas por hechos.
                            </h3>
                            <p className="text-sm sm:text-base text-zinc-400 leading-relaxed">
                                Solo personas que hayan interactuado o cerrado acuerdos reales pueden emitir valoraciones. No existen suscripciones ni pagos para manipular tu puntuación en la comunidad.
                            </p>
                        </div>
                    </div>
                </div>
            </section>

            {/* 5. DOWNLOAD CTA SECTION (Clean, Expansive, NO BOXES!) */}
            <section id="descargar" className="py-24 sm:py-36 border-t border-white/[0.06] text-center">
                <div className="container-custom max-w-3xl space-y-10">
                    <div className="space-y-4">
                        <h2 className="text-4xl sm:text-6xl font-extrabold text-white tracking-tight font-archivo leading-tight">
                            Descarga CONNECT <br />
                            <span className="text-gradient-silver">y conecta con tu entorno.</span>
                        </h2>
                        <p className="text-base sm:text-lg text-zinc-400 max-w-xl mx-auto font-normal">
                            Disponible gratuitamente en Google Play y App Store. Escanea el código con tu celular o haz clic para descargar.
                        </p>
                    </div>

                    {/* QR Code and Stores */}
                    <div className="flex flex-col sm:flex-row items-center justify-center gap-8 pt-4">
                        <div className="p-3.5 bg-white rounded-2xl shadow-2xl flex items-center justify-center">
                            <QRCodeSVG
                                value="https://connectapp.com.co"
                                size={120}
                                level="M"
                                includeMargin={false}
                            />
                        </div>

                        <div className="text-left space-y-4">
                            <div className="space-y-1">
                                <span className="text-sm font-bold text-white block">Escanea para instalar</span>
                                <span className="text-xs text-zinc-400 block max-w-xs">
                                    Apunta la cámara de tu teléfono para acceder a la descarga de la app móvil.
                                </span>
                            </div>
                            <DownloadButtons />
                        </div>
                    </div>
                </div>
            </section>
        </div>
    );
};
