import React, { useState, useRef, useEffect } from 'react';
import {
    Mail as MailIcon,
    Send,
    Trash2,
    Plus,
    Search,
    CheckCircle,
    AlertCircle,
    RefreshCw,
    MoreVertical,
    Zap,
    Mail as LucideInbox,
    ShieldAlert,
    ChevronDown,
    Plus as LucidePaperclip,
    X,
    ExternalLink,
    Image as ImageIcon,
    LogOut,
    ChevronRight,
    Menu
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { sendEmail } from '../services/mailgun';
import {
    saveMail,
    subscribeToMail,
    updateMailStatus,
    syncIncomingMail,
    type MailLog
} from '../services/mailService';
import { Timestamp } from 'firebase/firestore';
import logo from '../assets/logo.jpeg';

export const Mail: React.FC = () => {
    const [isComposing, setIsComposing] = useState(false);
    const [to, setTo] = useState('');
    const [subject, setSubject] = useState('');
    const [message, setMessage] = useState('');
    const [ctaText, setCtaText] = useState('');
    const [ctaLink, setCtaLink] = useState('');
    const [attachments, setAttachments] = useState<File[]>([]);
    const [logs, setLogs] = useState<MailLog[]>([]);
    const [isSending, setIsSending] = useState(false);
    const [activeCategory, setActiveCategory] = useState<'principal' | 'spam' | 'trash' | 'sent' | 'automations'>('principal');
    const [selectedAccount, setSelectedAccount] = useState('contacto@connectapp.com.co');
    const [selectedMail, setSelectedMail] = useState<MailLog | null>(null);

    const fileInputRef = useRef<HTMLInputElement>(null!);

    useEffect(() => {
        // Suscribirse a cambios en Firestore
        const unsubscribe = subscribeToMail((newLogs: MailLog[]) => {
            setLogs(newLogs);
        });

        // Sincronización automática de correos entrantes cada 30 segundos
        syncIncomingMail();
        const syncInterval = setInterval(() => {
            syncIncomingMail();
        }, 30000);

        return () => {
            unsubscribe();
            clearInterval(syncInterval);
        };
    }, []);

    const accounts = [
        'contacto@connectapp.com.co',
        'soporte@connectapp.com.co',
        'info@connectapp.com.co'
    ];

    const getAvatarUrl = (email: string) => {
        const cleanEmail = email.toLowerCase().trim();
        const isConnect = accounts.some(acc => cleanEmail.includes(acc.toLowerCase()));

        if (isConnect) return logo;

        // Extraer nombre para el avatar o usar el email directamente
        const nameMatch = email.match(/^([^<]+)/);
        const name = nameMatch ? nameMatch[1].trim() : email.split('@')[0];
        return `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=random&color=fff&bold=true`;
    };

    const handleFileChange = (e: any) => {
        if (e.target.files) {
            const newFiles = Array.from(e.target.files) as File[];
            setAttachments((prev: File[]) => [...prev, ...newFiles]);
        }
    };

    const removeAttachment = (index: number) => {
        setAttachments((prev: File[]) => prev.filter((_, i) => i !== index));
    };

    const handleSend = async () => {
        if (!to || !subject || !message) return;

        setIsSending(true);

        try {
            // Generar HTML con botón interactivo si existe
            const buttonHtml = ctaText && ctaLink ? `
                <div style="margin: 30px 0;">
                    <a href="${ctaLink}" style="background-color: #0094FF; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: bold; font-family: sans-serif; display: inline-block;">
                        ${ctaText}
                    </a>
                </div>
            ` : '';

            // Enviar vía MailGun
            const htmlMessage = `
                <div style="font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1a1a1a; max-width: 600px; margin: 0 auto; padding: 40px; border: 1px solid #f0f0f0; rounded: 24px;">
                    <h1 style="color: #007AFF; font-size: 22px; font-weight: 900; margin-bottom: 24px; letter-spacing: -0.5px; font-family: 'Inter', sans-serif;">CONNECT APP S.A.S</h1>
                    <div style="font-size: 16px; line-height: 1.6; color: #333; margin-bottom: 30px;">
                        ${message.replace(/\n/g, '<br>')}
                    </div>
                    ${attachments.length > 0 ? `<p style="font-size: 12px; color: #666; font-style: italic;">Adjuntos eliminados para visualización por seguridad/política de envío.</p>` : ''}
                    ${buttonHtml}
                    <div style="margin-top: 40px; border-top: 1px solid #eee; padding-top: 20px;">
                        <p style="font-size: 11px; color: #999; text-align: center; margin: 0;">
                            CONNECT  ©  2026. Todos los derechos reservados.
                        </p>
                    </div>
                </div>
            `;

            await sendEmail({
                to: to,
                subject: subject,
                text: message,
                html: htmlMessage,
                from: `${selectedAccount.split('@')[0].toUpperCase()} <${selectedAccount}>`,
                attachments: attachments
            });

            // Guardar en Firestore
            await saveMail({
                from: selectedAccount,
                to,
                subject,
                message,
                status: 'sent',
                category: 'sent',
                attachmentsCount: attachments.length,
                timestamp: Timestamp.now()
            });

            resetForm();
            setIsComposing(false);
            alert('¡Correo enviado con éxito!');
        } catch (error) {
            console.error(error);
            alert('Error al enviar el correo.');
        } finally {
            setIsSending(false);
        }
    };

    const resetForm = () => {
        setTo('');
        setSubject('');
        setMessage('');
        setCtaText('');
        setCtaLink('');
        setAttachments([]);
    };

    const handleMoveToTrash = async (id: string, currentCategory: string) => {
        if (currentCategory === 'trash') {
            // Si ya está en la basura, podríamos borrarlo permanentemente o no hacer nada
            // Por ahora, lo mantenemos en basura.
            return;
        }
        await updateMailStatus(id, 'trash', 'trash');
    };

    const handleRefresh = async () => {
        setIsSending(true);
        await syncIncomingMail();
        setIsSending(false);
    };

    const categories = [
        { id: 'principal', label: 'Principal', icon: LucideInbox },
        { id: 'sent', label: 'Enviados', icon: Send },
        { id: 'automations', label: 'Automatizaciones', icon: Zap },
        { id: 'spam', label: 'Spam', icon: ShieldAlert },
        { id: 'trash', label: 'Basura', icon: Trash2 },
    ];

    const filteredLogs = logs.filter(log => {
        if (activeCategory === 'principal') {
            return log.category === 'principal' && log.status === 'received';
        }
        return log.category === activeCategory;
    });

    return (
        <div className="relative min-h-[calc(100vh-120px)] flex flex-col">
            {/* Top Bar - Account Selector */}
            <div className="flex justify-between items-center mb-8 bg-zinc-50 p-4 rounded-3xl border border-zinc-100 flex-wrap gap-4">
                <div className="flex items-center gap-4">
                    <div className="w-10 h-10 bg-primary/10 rounded-xl flex items-center justify-center">
                        <MailIcon className="text-primary" size={20} />
                    </div>
                    <div>
                        <p className="text-[10px] font-black uppercase text-zinc-400 tracking-widest leading-none mb-1">Cuenta Activa</p>
                        <div className="relative group cursor-pointer">
                            <div className="flex items-center gap-2">
                                <span className="text-sm font-black tracking-tight">{selectedAccount}</span>
                                <ChevronDown size={14} className="text-zinc-400 group-hover:text-black transition-colors" />
                            </div>
                            <div className="absolute top-full left-0 mt-2 w-64 bg-white border border-zinc-100 rounded-2xl shadow-premium opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all z-50 p-2">
                                {accounts.map(acc => (
                                    <button
                                        key={acc}
                                        onClick={() => setSelectedAccount(acc)}
                                        className="w-full text-left px-4 py-3 text-xs font-bold hover:bg-zinc-50 rounded-xl transition-all"
                                    >
                                        {acc}
                                    </button>
                                ))}
                            </div>
                        </div>
                    </div>
                </div>

                <div className="relative max-w-xs w-full">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-300" size={14} />
                    <input
                        className="w-full bg-white border-zinc-100 rounded-xl pl-10 pr-4 py-2 text-[10px] font-bold outline-none focus:border-black transition-all"
                        placeholder="Buscar correos..."
                    />
                </div>
            </div>

            <div className="flex flex-1 gap-8 relative overflow-hidden">
                {/* Main Content Area */}
                <div className="flex-1 bg-white border border-zinc-100 rounded-[3rem] p-8 shadow-sm relative flex flex-col min-w-0">
                    <div className="flex justify-between items-center mb-6">
                        <h2 className="text-lg font-black tracking-tighter uppercase">{categories.find(c => c.id === activeCategory)?.label}</h2>
                        <button
                            onClick={handleRefresh}
                            className="p-3 text-zinc-400 hover:text-black bg-zinc-50 rounded-xl transition-all flex items-center gap-2 text-[9px] font-black uppercase tracking-widest"
                        >
                            <RefreshCw size={14} /> Actualizar
                        </button>
                    </div>

                    <div className="space-y-1 overflow-y-auto flex-1 pr-2 custom-scrollbar">
                        <AnimatePresence mode="popLayout">
                            {filteredLogs.length > 0 ? filteredLogs.map((log) => (
                                <motion.div
                                    key={log.id}
                                    layout
                                    initial={{ opacity: 0, x: -10 }}
                                    animate={{ opacity: 1, x: 0 }}
                                    exit={{ opacity: 0, scale: 0.95 }}
                                    onClick={() => setSelectedMail(log)}
                                    className="flex items-center gap-6 p-5 hover:bg-zinc-50 rounded-3xl transition-all group cursor-pointer border border-transparent hover:border-zinc-100"
                                >
                                    <div className="w-8 h-8 rounded-lg flex items-center justify-center overflow-hidden bg-zinc-100 shrink-0 border border-zinc-50 shadow-inner">
                                        <img
                                            src={getAvatarUrl(activeCategory === 'sent' ? log.to : log.from)}
                                            alt="Avatar"
                                            className="w-full h-full object-cover"
                                        />
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center gap-2">
                                            <p className="text-[11px] font-black uppercase tracking-tight truncate">
                                                {activeCategory === 'sent' ? `Para: ${log.to}` : (log.from || 'Desconocido')}
                                            </p>
                                            {log.attachmentsCount ? <LucidePaperclip size={10} className="text-primary" /> : null}
                                        </div>
                                        <p className="text-[10px] font-bold text-zinc-400 truncate leading-none mt-1.5 opacity-80">
                                            {log.subject}: <span className="font-medium opacity-60">{log.message?.substring(0, 100)}...</span>
                                        </p>
                                    </div>
                                    <div className="text-right flex items-center gap-4 shrink-0">
                                        <div className="flex flex-col items-end gap-1">
                                            <p className="text-[8px] font-black text-zinc-300 uppercase whitespace-nowrap">{log.timestamp}</p>
                                            <p className="text-[7px] font-black text-primary/40 bg-primary/5 px-2 py-0.5 rounded-full border border-primary/10 uppercase tracking-tighter">
                                                {log.to}
                                            </p>
                                        </div>
                                        <button
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                handleMoveToTrash(log.id, log.category);
                                            }}
                                            className="opacity-0 group-hover:opacity-100 transition-opacity p-2 hover:bg-zinc-100 rounded-lg text-zinc-400 hover:text-red-500"
                                        >
                                            <Trash2 size={14} />
                                        </button>
                                    </div>
                                </motion.div>
                            )) : (
                                <div className="flex flex-col items-center justify-center h-full text-zinc-300 py-20">
                                    <MailIcon size={48} strokeWidth={1} className="mb-4 opacity-20" />
                                    <p className="text-[10px] font-black uppercase tracking-widest text-center">
                                        {activeCategory === 'principal' ? 'Bandeja vacía. No hay correos entrantes nuevos.' : 'No hay mensajes en esta categoría'}
                                    </p>
                                    {activeCategory === 'principal' && (
                                        <p className="text-[8px] font-bold text-zinc-400 mt-2 uppercase tracking-tight max-w-[200px] text-center">
                                            Recuerda que para recibir correos debes configurar rutas en MailGun.
                                        </p>
                                    )}
                                </div>
                            )}
                        </AnimatePresence>
                    </div>
                </div>

                {/* Categories Right Navbar */}
                <div className="w-20 hidden sm:flex flex-col gap-4 bg-zinc-900 rounded-[2.5rem] p-4 shadow-premium h-fit">
                    {categories.map((cat) => (
                        <button
                            key={cat.id}
                            onClick={() => setActiveCategory(cat.id as any)}
                            className={`w-12 h-12 rounded-2xl flex items-center justify-center transition-all group relative ${activeCategory === cat.id ? 'bg-primary text-white scale-110' : 'bg-zinc-800 text-zinc-500 hover:text-white hover:bg-zinc-700'
                                }`}
                        >
                            <cat.icon size={20} strokeWidth={activeCategory === cat.id ? 2.5 : 2} />

                            {/* Tooltip */}
                            <div className="absolute right-full mr-4 bg-black text-white px-3 py-1.5 rounded-lg text-[9px] font-black uppercase tracking-widest opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all whitespace-nowrap pointer-events-none border border-zinc-800 translate-x-2 group-hover:translate-x-0">
                                {cat.label}
                            </div>
                        </button>
                    ))}
                </div>
            </div>

            {/* Gmail-style Compose FAB */}
            <motion.button
                whileHover={{ scale: 1.1, rotate: 90 }}
                whileTap={{ scale: 0.9 }}
                onClick={() => setIsComposing(true)}
                className="fixed bottom-12 right-12 w-20 h-20 bg-primary text-white rounded-[2rem] shadow-primary-glow flex items-center justify-center z-40 group border-4 border-white"
            >
                <Plus size={32} className="group-hover:scale-110 transition-transform" />
            </motion.button>

            {/* Compose Modal Overlay */}
            <AnimatePresence>
                {isComposing && (
                    <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-[100] flex items-center justify-center p-4 sm:p-8">
                        <motion.div
                            initial={{ opacity: 0, scale: 0.9, y: 20 }}
                            animate={{ opacity: 1, scale: 1, y: 0 }}
                            exit={{ opacity: 0, scale: 0.9, y: 20 }}
                            className="bg-white rounded-[2.5rem] sm:rounded-[3.5rem] w-full max-w-4xl max-h-[90vh] shadow-2xl relative flex flex-col overflow-hidden"
                        >
                            <div className="absolute top-0 right-0 w-64 h-64 bg-primary/5 rounded-full blur-3xl -mr-32 -mt-32"></div>

                            {/* Modal Header */}
                            <div className="p-8 pb-4 flex justify-between items-center relative z-10">
                                <div>
                                    <h3 className="text-xl sm:text-2xl font-black tracking-tighter uppercase leading-none">Nueva Comunicación</h3>
                                    <div className="text-[10px] font-black text-zinc-400 uppercase tracking-widest mt-2 flex items-center gap-2">
                                        <div className="w-1.5 h-1.5 rounded-full bg-green-500"></div>
                                        Sistema de envío avanzado
                                    </div>
                                </div>
                                <div className="flex items-center gap-2">
                                    <button onClick={() => setIsComposing(false)} className="text-zinc-300 hover:text-black transition-colors p-2">
                                        <X size={32} strokeWidth={2} />
                                    </button>
                                </div>
                            </div>

                            {/* Modal Body - Scrollable */}
                            <div className="flex-1 overflow-y-auto px-8 pb-8 space-y-8 relative z-10 custom-scrollbar">
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                    <div className="space-y-3">
                                        <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-2">De</label>
                                        <div className="w-full bg-zinc-50 border border-zinc-100 rounded-2xl px-6 py-4 text-xs font-bold text-zinc-400">
                                            {selectedAccount}
                                        </div>
                                    </div>
                                    <div className="space-y-3">
                                        <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-2">Para</label>
                                        <input
                                            value={to}
                                            onChange={(e) => setTo(e.target.value)}
                                            className="w-full bg-zinc-50 border border-zinc-100 rounded-2xl px-6 py-4 text-xs font-bold outline-none focus:border-primary transition-all"
                                            placeholder="destinatario@email.com"
                                        />
                                    </div>
                                </div>

                                <div className="space-y-3">
                                    <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-2">Asunto del mensaje</label>
                                    <input
                                        value={subject}
                                        onChange={(e) => setSubject(e.target.value)}
                                        className="w-full bg-zinc-50 border border-zinc-100 rounded-2xl px-6 py-4 text-xs font-bold outline-none focus:border-primary transition-all"
                                        placeholder="Propósito oficial..."
                                    />
                                </div>

                                <div className="space-y-3">
                                    <div className="flex justify-between items-center">
                                        <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-2">Contenido principal</label>
                                        <div className="flex gap-2">
                                            <button
                                                onClick={() => fileInputRef.current?.click()}
                                                className="flex items-center gap-2 px-3 py-1.5 bg-zinc-50 hover:bg-zinc-100 text-zinc-500 rounded-lg text-[9px] font-black uppercase tracking-tight transition-all"
                                            >
                                                <LucidePaperclip size={12} /> adjuntar
                                            </button>
                                            <input type="file" multiple ref={fileInputRef} className="hidden" onChange={handleFileChange} />
                                        </div>
                                    </div>
                                    <textarea
                                        value={message}
                                        onChange={(e) => setMessage(e.target.value)}
                                        className="w-full bg-zinc-50 border border-zinc-100 rounded-[2rem] px-8 py-8 text-xs font-bold outline-none focus:border-primary transition-all h-40 resize-none"
                                        placeholder="Escribe el cuerpo del mensaje..."
                                    />
                                </div>

                                {/* Link interactivo (Botón) */}
                                <div className="bg-zinc-50/50 p-6 rounded-[2rem] border border-dashed border-zinc-200 space-y-4">
                                    <p className="text-[9px] font-black uppercase tracking-widest text-zinc-400 flex items-center gap-2">
                                        <ExternalLink size={12} /> Botón Interactivo (CTA)
                                    </p>
                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                        <input
                                            value={ctaText}
                                            onChange={(e) => setCtaText(e.target.value)}
                                            className="bg-white border border-zinc-100 rounded-xl px-4 py-3 text-[10px] font-bold outline-none focus:border-primary transition-all"
                                            placeholder="Texto del botón (ej: Ver Pedido)"
                                        />
                                        <input
                                            value={ctaLink}
                                            onChange={(e) => setCtaLink(e.target.value)}
                                            className="bg-white border border-zinc-100 rounded-xl px-4 py-3 text-[10px] font-bold outline-none focus:border-primary transition-all"
                                            placeholder="URL (https://...)"
                                        />
                                    </div>
                                </div>

                                {/* List of attachments */}
                                {attachments.length > 0 && (
                                    <div className="flex flex-wrap gap-2">
                                        {attachments.map((file, i) => (
                                            <div key={i} className="flex items-center gap-2 bg-zinc-900 text-white px-3 py-1.5 rounded-xl text-[9px] font-bold group">
                                                <ImageIcon size={12} className="text-primary" />
                                                <span className="truncate max-w-[150px]">{file.name}</span>
                                                <button onClick={() => removeAttachment(i)} className="text-zinc-500 hover:text-red-400">
                                                    <X size={12} />
                                                </button>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>

                            {/* Modal Footer */}
                            <div className="p-8 pt-4 border-t border-zinc-50 bg-white relative z-10 flex justify-end">
                                <motion.button
                                    whileHover={{ scale: 1.02 }}
                                    whileTap={{ scale: 0.98 }}
                                    onClick={handleSend}
                                    disabled={isSending || !to || !subject || !message}
                                    className="w-full sm:w-auto px-16 bg-black text-white h-16 rounded-2xl font-black uppercase tracking-widest text-[10px] hover:shadow-2xl shadow-black/20 transition-all flex items-center justify-center gap-4 disabled:opacity-50"
                                >
                                    {isSending ? <RefreshCw className="animate-spin" size={18} /> : <Send size={18} />}
                                    {isSending ? 'PROCESANDO...' : 'ENVIAR COMUNICACIÓN'}
                                </motion.button>
                            </div>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>

            {/* Detail View Modal */}
            <AnimatePresence>
                {selectedMail && (
                    <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-[110] flex items-center justify-center p-4">
                        <motion.div
                            initial={{ opacity: 0, scale: 0.9 }}
                            animate={{ opacity: 1, scale: 1 }}
                            exit={{ opacity: 0, scale: 0.9 }}
                            className="bg-white rounded-[2.5rem] w-full max-w-2xl max-h-[85vh] shadow-2xl flex flex-col overflow-hidden"
                        >
                            <div className="p-8 pb-4 flex justify-between items-start">
                                <div className="flex-1 pr-8">
                                    <p className="text-[10px] font-black uppercase text-primary tracking-[0.2em] mb-2">{selectedMail.category}</p>
                                    <h3 className="text-2xl font-black tracking-tighter leading-tight">{selectedMail.subject}</h3>
                                </div>
                                <button onClick={() => setSelectedMail(null)} className="text-zinc-300 hover:text-black p-2 bg-zinc-50 rounded-xl transition-all">
                                    <X size={24} />
                                </button>
                            </div>

                            <div className="flex-1 overflow-y-auto px-8 pb-8 space-y-8 custom-scrollbar">
                                <div className="flex items-center gap-4 bg-zinc-50 p-4 rounded-2xl border border-zinc-100">
                                    <div className="w-10 h-10 bg-white rounded-xl flex items-center justify-center overflow-hidden border border-zinc-100 shadow-sm">
                                        <img
                                            src={getAvatarUrl(selectedMail.from)}
                                            alt={selectedMail.from}
                                            className="w-full h-full object-cover"
                                        />
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <div className="flex justify-between items-center">
                                            <p className="text-xs font-black truncate">{selectedMail.from}</p>
                                            <p className="text-[8px] font-black text-zinc-300 uppercase shrink-0">{selectedMail.timestamp}</p>
                                        </div>
                                        <p className="text-[10px] font-bold text-zinc-400 truncate mt-0.5">Para: {selectedMail.to}</p>
                                    </div>
                                </div>

                                <div className="bg-zinc-100/50 p-8 rounded-[2.5rem] relative overflow-hidden">
                                    {/* Background Decor */}
                                    <div className="absolute top-0 right-0 w-32 h-32 bg-primary/5 rounded-full blur-2xl -mr-16 -mt-16"></div>

                                    <div className="relative z-10 text-xs font-medium text-zinc-700 leading-relaxed whitespace-pre-wrap">
                                        {selectedMail.message}
                                    </div>
                                </div>

                                {selectedMail.attachmentsCount ? (
                                    <div className="p-4 bg-zinc-50 rounded-2xl border border-zinc-100 flex items-center gap-3">
                                        <LucidePaperclip size={14} className="text-primary" />
                                        <p className="text-[9px] font-black uppercase tracking-wider">Este mensaje tiene {selectedMail.attachmentsCount} adjuntos</p>
                                        <p className="ml-auto text-[8px] font-bold text-zinc-400">(Visibles en MailGun)</p>
                                    </div>
                                ) : null}
                            </div>

                            <div className="p-8 pt-4 border-t border-zinc-50 bg-zinc-50/50 flex justify-between items-center">
                                <button
                                    onClick={() => {
                                        handleMoveToTrash(selectedMail.id, selectedMail.category);
                                        setSelectedMail(null);
                                    }}
                                    className="px-6 py-3 text-red-500 hover:bg-red-50 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all flex items-center gap-2"
                                >
                                    <Trash2 size={14} /> Mover a Papelera
                                </button>

                                <button
                                    onClick={() => {
                                        setTo(selectedMail.from);
                                        setSubject(`Re: ${selectedMail.subject}`);
                                        setIsComposing(true);
                                        setSelectedMail(null);
                                    }}
                                    className="px-8 py-4 bg-black text-white rounded-xl text-[10px] font-black uppercase tracking-widest transition-all shadow-lg hover:shadow-black/20"
                                >
                                    Responder
                                </button>
                            </div>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>

            <style>{`
                .custom-scrollbar::-webkit-scrollbar {
                    width: 4px;
                }
                .custom-scrollbar::-webkit-scrollbar-track {
                    background: transparent;
                }
                .custom-scrollbar::-webkit-scrollbar-thumb {
                    background: #f1f1f1;
                    border-radius: 10px;
                }
                .custom-scrollbar::-webkit-scrollbar-thumb:hover {
                    background: #e1e1e1;
                }
            `}</style>
        </div>
    );
};
