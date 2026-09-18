import React, { useState, useEffect } from 'react';
import {
    Mail as MailIcon,
    Send,
    Trash2,
    Plus,
    Search,
    RefreshCw,
    Paperclip,
    X,
    Inbox,
    ShieldAlert,
    Zap,
    ChevronDown,
    CheckCircle2,
    ExternalLink
} from 'lucide-react';
import { sendEmail } from '../services/connectMail';
import {
    saveMail,
    subscribeToMail,
    updateMailStatus,
    syncIncomingMail,
    type MailLog
} from '../services/mailService';
import { Timestamp } from 'firebase/firestore';
import logo from '../assets/logo.jpeg';
import toast from 'react-hot-toast';

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
    const [activeCategory, setActiveCategory] = useState<'principal' | 'sent' | 'automations' | 'spam' | 'trash'>('principal');
    const [selectedAccount, setSelectedAccount] = useState('contacto@connectapp.com.co');
    const [selectedMail, setSelectedMail] = useState<MailLog | null>(null);
    const [searchTerm, setSearchTerm] = useState('');

    const accounts = [
        'contacto@connectapp.com.co',
        'soporte@connectapp.com.co',
        'info@connectapp.com.co'
    ];

    const categories = [
        { id: 'principal', label: 'Bandeja de Entrada', icon: Inbox },
        { id: 'sent', label: 'Enviados', icon: Send },
        { id: 'automations', label: 'Automatizaciones', icon: Zap },
        { id: 'spam', label: 'Spam', icon: ShieldAlert },
        { id: 'trash', label: 'Papelera', icon: Trash2 },
    ] as const;

    useEffect(() => {
        const unsubscribe = subscribeToMail((newLogs) => {
            setLogs(newLogs);
        });

        syncIncomingMail();
        const syncInterval = setInterval(() => {
            syncIncomingMail();
        }, 30000);

        return () => {
            unsubscribe();
            clearInterval(syncInterval);
        };
    }, []);

    const decodeMimeHeader = (str: string) => {
        if (!str) return '(Sin asunto)';
        let s = str;
        s = s.replace(/=\?[uU][tT][fF]-8\?[qQ]\?(.*?)\?=/gi, (_, content) => {
            try {
                return decodeURIComponent(content.replace(/=/g, '%'));
            } catch {
                return content;
            }
        });
        s = s.replace(/=\?[uU][tT][fF]-8\?[bB]\?(.*?)\?=/gi, (_, content) => {
            try {
                return atob(content);
            } catch {
                return content;
            }
        });
        return s;
    };

    const getAvatarUrl = (emailStr: string) => {
        const clean = (emailStr || '').toLowerCase().trim();
        const isConnect = accounts.some(acc => clean.includes(acc.toLowerCase()));
        if (isConnect) return logo;
        const nameMatch = clean.match(/^([^<]+)/);
        const name = nameMatch ? nameMatch[1].trim() : clean.split('@')[0];
        return `https://ui-avatars.com/api/?name=${encodeURIComponent(name || 'User')}&background=0F172A&color=fff&bold=true`;
    };

    const formatMailDate = (ts: any) => {
        if (!ts) return 'Recién';
        if (typeof ts === 'string') return ts;
        try {
            if (ts.toDate) return ts.toDate().toLocaleDateString('es-CO', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
            if (ts.seconds) return new Date(ts.seconds * 1000).toLocaleDateString('es-CO', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
            return new Date(ts).toLocaleDateString('es-CO', { day: '2-digit', month: 'short' });
        } catch {
            return String(ts);
        }
    };

    const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files) {
            const newFiles = Array.from(e.target.files);
            setAttachments(prev => [...prev, ...newFiles]);
        }
    };

    const removeAttachment = (index: number) => {
        setAttachments(prev => prev.filter((_, i) => i !== index));
    };

    const resetForm = () => {
        setTo('');
        setSubject('');
        setMessage('');
        setCtaText('');
        setCtaLink('');
        setAttachments([]);
    };

    const handleSend = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!to || !subject || !message) {
            toast.error('Completa los campos obligatorios');
            return;
        }

        setIsSending(true);
        try {
            const buttonHtml = ctaText && ctaLink ? `
                <div style="margin: 25px 0;">
                    <a href="${ctaLink}" style="background-color: #0094FF; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; font-weight: bold; font-family: sans-serif; display: inline-block;">
                        ${ctaText}
                    </a>
                </div>
            ` : '';

            const htmlMessage = `
                <div style="font-family: Arial, sans-serif; color: #1e293b; max-width: 600px; margin: 0 auto; padding: 30px; border: 1px solid #e2e8f0; border-radius: 8px;">
                    <h2 style="color: #0094FF; font-size: 20px; font-weight: 800; margin-bottom: 20px;">CONNECT APP</h2>
                    <div style="font-size: 14px; line-height: 1.6; color: #334155; margin-bottom: 25px;">
                        ${message.replace(/\n/g, '<br>')}
                    </div>
                    ${buttonHtml}
                    <div style="margin-top: 30px; border-top: 1px solid #e2e8f0; padding-top: 15px;">
                        <p style="font-size: 11px; color: #94a3b8; text-align: center; margin: 0;">
                            CONNECT  ©  2026. Todos los derechos reservados.
                        </p>
                    </div>
                </div>
            `;

            await sendEmail({
                to,
                subject,
                text: message,
                html: htmlMessage,
                from: `${selectedAccount.split('@')[0].toUpperCase()} <${selectedAccount}>`,
                attachments
            });

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
            toast.success('Correo enviado con éxito');
        } catch (error: any) {
            console.error(error);
            toast.error(error.message || 'Error al enviar correo');
        } finally {
            setIsSending(false);
        }
    };

    const handleMoveToTrash = async (id: string, currentCategory: string) => {
        try {
            await updateMailStatus(id, 'trash', 'trash');
            toast.success('Movido a papelera');
            if (selectedMail?.id === id) setSelectedMail(null);
        } catch {
            toast.error('Error al mover mensaje');
        }
    };

    const handleRefresh = async () => {
        setIsSending(true);
        try {
            await syncIncomingMail();
            toast.success('Bandeja sincronizada');
        } catch {
            toast.error('Error al sincronizar correos');
        } finally {
            setIsSending(false);
        }
    };

    const filteredLogs = logs.filter(log => {
        const matchesCategory = activeCategory === 'principal'
            ? (log.category === 'principal' && log.status === 'received')
            : log.category === activeCategory;

        if (!matchesCategory) return false;

        if (!searchTerm) return true;
        const q = searchTerm.toLowerCase();
        return (
            (log.subject || '').toLowerCase().includes(q) ||
            (log.from || '').toLowerCase().includes(q) ||
            (log.to || '').toLowerCase().includes(q) ||
            (log.message || '').toLowerCase().includes(q)
        );
    });

    return (
        <div className="space-y-5">
            {/* Top Bar Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-200 pb-4">
                <div>
                    <h1 className="text-xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
                        <MailIcon size={20} className="text-[#0094FF]" />
                        Centro de Mensajería & Correo
                    </h1>
                    <p className="text-xs text-slate-500 mt-0.5">
                        Comunicaciones oficiales y respuestas directas desde @connectapp.com.co
                    </p>
                </div>

                <div className="flex items-center gap-2">
                    {/* Account Selector */}
                    <div className="flex items-center gap-1 bg-white border border-slate-200 rounded-md px-2 py-1 text-xs">
                        <span className="text-slate-400 font-medium">De:</span>
                        <select
                            value={selectedAccount}
                            onChange={(e) => setSelectedAccount(e.target.value)}
                            className="font-semibold text-slate-800 bg-transparent outline-none cursor-pointer text-xs"
                        >
                            {accounts.map(acc => (
                                <option key={acc} value={acc}>{acc}</option>
                            ))}
                        </select>
                    </div>

                    <button
                        onClick={handleRefresh}
                        disabled={isSending}
                        className="btn-secondary text-xs flex items-center gap-1.5"
                        title="Actualizar bandeja"
                    >
                        <RefreshCw size={13} className={isSending ? 'animate-spin' : ''} />
                        <span>Sincronizar</span>
                    </button>

                    <button
                        onClick={() => setIsComposing(true)}
                        className="btn-primary text-xs flex items-center gap-1.5"
                    >
                        <Plus size={14} />
                        <span>Redactar</span>
                    </button>
                </div>
            </div>

            {/* Main Email Layout: Left Categories Tabs + Main Inbox */}
            <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
                {/* Category Navigation Pills */}
                <div className="md:col-span-1 space-y-1">
                    {categories.map(cat => {
                        const count = logs.filter(l => {
                            if (cat.id === 'principal') return l.category === 'principal' && l.status === 'received';
                            return l.category === cat.id;
                        }).length;

                        const isActive = activeCategory === cat.id;
                        return (
                            <button
                                key={cat.id}
                                onClick={() => {
                                    setActiveCategory(cat.id as any);
                                    setSelectedMail(null);
                                }}
                                className={`w-full flex items-center justify-between px-3 py-2 text-xs font-semibold rounded-lg transition-colors text-left ${
                                    isActive
                                        ? 'bg-[#0094FF] text-white'
                                        : 'bg-white hover:bg-slate-100 text-slate-700 border border-slate-200'
                                }`}
                            >
                                <div className="flex items-center gap-2">
                                    <cat.icon size={14} />
                                    <span>{cat.label}</span>
                                </div>
                                <span className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono font-bold ${
                                    isActive ? 'bg-white/20 text-white' : 'bg-slate-100 text-slate-600'
                                }`}>
                                    {count}
                                </span>
                            </button>
                        );
                    })}
                </div>

                {/* Email List & Details Area */}
                <div className="md:col-span-4 bg-white border border-slate-200 rounded-lg overflow-hidden flex flex-col min-h-[500px]">
                    {/* Search & Filter sub-bar */}
                    <div className="p-3 border-b border-slate-200 flex items-center justify-between gap-3 bg-slate-50/50">
                        <div className="relative flex-1 max-w-sm">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={13} />
                            <input
                                type="text"
                                value={searchTerm}
                                onChange={(e) => setSearchTerm(e.target.value)}
                                placeholder="Buscar en esta bandeja..."
                                className="input-clean pl-8 py-1 text-xs w-full"
                            />
                        </div>

                        <span className="text-[11px] text-slate-400 font-medium">
                            {filteredLogs.length} mensaje(s)
                        </span>
                    </div>

                    {/* Email List */}
                    <div className="divide-y divide-slate-100 flex-1 overflow-y-auto max-h-[600px]">
                        {filteredLogs.length === 0 ? (
                            <div className="flex flex-col items-center justify-center py-20 text-slate-400">
                                <Inbox size={36} className="text-slate-300 mb-2 stroke-1" />
                                <p className="text-xs font-semibold text-slate-600">No hay correos en esta bandeja</p>
                                <p className="text-[11px] text-slate-400 mt-0.5">
                                    Los mensajes enviados o recibidos aparecerán aquí automáticamente.
                                </p>
                            </div>
                        ) : (
                            filteredLogs.map(log => {
                                const senderDisplay = activeCategory === 'sent' ? `Para: ${log.to}` : (log.from || 'Remitente');
                                return (
                                    <div
                                        key={log.id}
                                        onClick={() => setSelectedMail(log)}
                                        className="flex items-center gap-3 p-3 hover:bg-slate-50 cursor-pointer transition-colors group"
                                    >
                                        <img
                                            src={getAvatarUrl(activeCategory === 'sent' ? log.to : log.from)}
                                            alt="Avatar"
                                            className="w-7 h-7 rounded-full object-cover border border-slate-200 shrink-0"
                                        />

                                        <div className="w-36 shrink-0 truncate">
                                            <span className="text-xs font-semibold text-slate-900 truncate block">
                                                {senderDisplay}
                                            </span>
                                        </div>

                                        <div className="flex-1 min-w-0">
                                            <span className="text-xs font-bold text-slate-800 mr-2">
                                                {decodeMimeHeader(log.subject)}
                                            </span>
                                            <span className="text-xs text-slate-400 truncate">
                                                - {(log.message || '').substring(0, 70)}...
                                            </span>
                                        </div>

                                        {log.attachmentsCount ? (
                                            <Paperclip size={12} className="text-slate-400 shrink-0" />
                                        ) : null}

                                        <div className="text-right shrink-0 flex items-center gap-2">
                                            {activeCategory === 'sent' && (
                                                log.status === 'error' ? (
                                                    <span className="text-[9px] font-bold text-rose-600 bg-rose-50 border border-rose-200 px-1.5 py-0.5 rounded" title="Error de entrega externa: Destino no verificado en servidor">
                                                        Fallo Entrega
                                                    </span>
                                                ) : (
                                                    <span className="text-[9px] font-bold text-emerald-600 bg-emerald-50 border border-emerald-200 px-1.5 py-0.5 rounded">
                                                        Enviado
                                                    </span>
                                                )
                                            )}
                                            <span className="text-[10px] text-slate-400 font-mono">
                                                {formatMailDate(log.timestamp)}
                                            </span>
                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    handleMoveToTrash(log.id, log.category);
                                                }}
                                                className="opacity-0 group-hover:opacity-100 p-1 text-slate-400 hover:text-red-500 rounded transition-opacity"
                                                title="Mover a papelera"
                                            >
                                                <Trash2 size={13} />
                                            </button>
                                        </div>
                                    </div>
                                );
                            })
                        )}
                    </div>
                </div>
            </div>

            {/* Mail Viewer Modal */}
            {selectedMail && (
                <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
                    <div className="bg-white border border-slate-200 rounded-xl max-w-2xl w-full p-5 shadow-xl max-h-[85vh] flex flex-col">
                        <div className="flex items-center justify-between border-b border-slate-200 pb-3 mb-4">
                            <h3 className="font-bold text-slate-900 text-sm truncate flex-1 pr-4">
                                {decodeMimeHeader(selectedMail.subject)}
                            </h3>
                            <button
                                onClick={() => setSelectedMail(null)}
                                className="text-slate-400 hover:text-slate-600 p-1"
                            >
                                <X size={16} />
                            </button>
                        </div>

                        <div className="flex items-center gap-3 mb-3 bg-slate-50 p-3 rounded-lg border border-slate-200 text-xs">
                            <img
                                src={getAvatarUrl(selectedMail.from)}
                                alt="Avatar"
                                className="w-8 h-8 rounded-full object-cover border border-slate-200"
                            />
                            <div className="flex-1 min-w-0">
                                <p className="font-bold text-slate-900">De: {selectedMail.from}</p>
                                <p className="text-slate-500">Para: {selectedMail.to}</p>
                            </div>
                            <span className="text-[10px] text-slate-400 font-mono">
                                {formatMailDate(selectedMail.timestamp)}
                            </span>
                        </div>

                        {selectedMail.category === 'sent' && selectedMail.status === 'error' && (
                            <div className="bg-rose-50 border border-rose-200 p-3 rounded-lg mb-3 text-[11px] text-rose-900 space-y-1">
                                <span className="font-bold flex items-center gap-1 text-rose-700">
                                    ⚠️ Aviso de Servidor de Correo (Fallo de Entrega)
                                </span>
                                <p className="leading-relaxed">
                                    Este mensaje se registró en la bandeja de salida, pero Cloudflare Email rebotó la entrega externa porque el destinatario no es una dirección verificada en Cloudflare Email Routing.
                                </p>
                            </div>
                        )}

                        <div className="flex-1 overflow-y-auto p-3 text-xs text-slate-800 whitespace-pre-wrap leading-relaxed border border-slate-100 rounded-lg bg-white">
                            {selectedMail.message || 'Sin contenido de texto.'}
                        </div>

                        <div className="flex items-center justify-end gap-2 pt-3 mt-4 border-t border-slate-200">
                            <button
                                onClick={() => handleMoveToTrash(selectedMail.id, selectedMail.category)}
                                className="btn-danger text-xs flex items-center gap-1.5"
                            >
                                <Trash2 size={13} />
                                <span>Mover a Papelera</span>
                            </button>
                            <button
                                onClick={() => setSelectedMail(null)}
                                className="btn-secondary text-xs"
                            >
                                Cerrar
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Compose Mail Modal */}
            {isComposing && (
                <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
                    <div className="bg-white border border-slate-200 rounded-xl max-w-2xl w-full p-5 shadow-xl max-h-[90vh] flex flex-col">
                        <div className="flex items-center justify-between border-b border-slate-200 pb-3 mb-4">
                            <h3 className="font-bold text-slate-900 text-sm flex items-center gap-2">
                                <Send size={15} className="text-[#0094FF]" />
                                Redactar Correo Oficial
                            </h3>
                            <button
                                onClick={() => setIsComposing(false)}
                                className="text-slate-400 hover:text-slate-600 p-1"
                            >
                                <X size={16} />
                            </button>
                        </div>

                        <form onSubmit={handleSend} className="space-y-3 flex-1 flex flex-col">
                            <div className="grid grid-cols-2 gap-3">
                                <div>
                                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                                        Remitente
                                    </label>
                                    <input
                                        type="text"
                                        disabled
                                        value={selectedAccount}
                                        className="input-clean w-full text-xs bg-slate-50 text-slate-500 cursor-not-allowed"
                                    />
                                </div>
                                <div>
                                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                                        Destinatario <span className="text-red-500">*</span>
                                    </label>
                                    <input
                                        type="email"
                                        required
                                        value={to}
                                        onChange={(e) => setTo(e.target.value)}
                                        placeholder="usuario@ejemplo.com"
                                        className="input-clean w-full text-xs"
                                    />
                                </div>
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    Asunto <span className="text-red-500">*</span>
                                </label>
                                <input
                                    type="text"
                                    required
                                    value={subject}
                                    onChange={(e) => setSubject(e.target.value)}
                                    placeholder="Motivo del correo..."
                                    className="input-clean w-full text-xs"
                                />
                            </div>

                            <div className="flex-1 flex flex-col">
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    Cuerpo del Mensaje <span className="text-red-500">*</span>
                                </label>
                                <textarea
                                    required
                                    rows={6}
                                    value={message}
                                    onChange={(e) => setMessage(e.target.value)}
                                    placeholder="Escribe el contenido del mensaje..."
                                    className="input-clean w-full text-xs resize-none flex-1"
                                />
                            </div>

                            <div className="grid grid-cols-2 gap-3 pt-2">
                                <div>
                                    <label className="block text-[11px] font-semibold text-slate-600 mb-1">
                                        Botón de Acción (Opcional)
                                    </label>
                                    <input
                                        type="text"
                                        value={ctaText}
                                        onChange={(e) => setCtaText(e.target.value)}
                                        placeholder="Ej: Ver en CONNECT"
                                        className="input-clean w-full text-xs"
                                    />
                                </div>
                                <div>
                                    <label className="block text-[11px] font-semibold text-slate-600 mb-1">
                                        Enlace del Botón
                                    </label>
                                    <input
                                        type="url"
                                        value={ctaLink}
                                        onChange={(e) => setCtaLink(e.target.value)}
                                        placeholder="https://connectapp.com.co/..."
                                        className="input-clean w-full text-xs"
                                    />
                                </div>
                            </div>

                            <div className="flex items-center justify-between pt-3 border-t border-slate-200">
                                <div>
                                    <label className="btn-secondary text-xs cursor-pointer flex items-center gap-1.5">
                                        <Paperclip size={13} />
                                        <span>Adjuntar Archivos ({attachments.length})</span>
                                        <input
                                            type="file"
                                            multiple
                                            onChange={handleFileChange}
                                            className="hidden"
                                        />
                                    </label>
                                </div>

                                <div className="flex items-center gap-2">
                                    <button
                                        type="button"
                                        onClick={() => setIsComposing(false)}
                                        className="btn-secondary text-xs"
                                    >
                                        Cancelar
                                    </button>
                                    <button
                                        type="submit"
                                        disabled={isSending}
                                        className="btn-primary text-xs flex items-center gap-1.5"
                                    >
                                        <Send size={13} />
                                        <span>{isSending ? 'Enviando...' : 'Enviar Mensaje'}</span>
                                    </button>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
};
