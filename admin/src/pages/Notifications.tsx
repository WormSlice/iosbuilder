import React, { useState } from 'react';
import {
    Bell,
    Send,
    User,
    Smartphone,
    Mail,
    Globe,
    Megaphone,
    Zap,
    Users
} from 'lucide-react';

interface NotificationHistory {
    id: string;
    title: string;
    target: string;
    channel: string;
    timestamp: string;
    status: 'Sent' | 'Scheduled' | 'Failed';
}

export const Notifications: React.FC = () => {
    const [target, setTarget] = useState<'all' | 'specific'>('all');
    const [title, setTitle] = useState('');
    const [body, setBody] = useState('');
    const [channel, setChannel] = useState('Push');
    const [priority, setPriority] = useState('Normal');

    const history: NotificationHistory[] = [
        { id: '1', title: 'Nueva Actualización v2.4', target: 'Global', channel: 'Push', timestamp: '7 ENE 2026, 09:12', status: 'Sent' },
        { id: '2', title: 'Verificación Exitosa', target: 'irenzulsierra@gmail.com', channel: 'Email', timestamp: '6 ENE 2026, 14:05', status: 'Sent' },
        { id: '3', title: 'Mantenimiento Programado', target: 'Global', channel: 'Push', timestamp: '8 ENE 2026, 02:00', status: 'Scheduled' },
    ];

    const handleSend = () => {
        alert(`Difundiendo via ${channel} a ${target === 'all' ? 'Todos' : 'Usuario'}...`);
        setTitle('');
        setBody('');
    };

    return (
        <div className="space-y-12 animate-in slide-in-from-right duration-700 pb-20">
            <div className="flex justify-between items-end">
                <div className="space-y-1">
                    <h1 className="text-4xl font-black tracking-tighter uppercase leading-none">Broadcast Engine</h1>
                    <p className="text-zinc-400 text-xs font-bold uppercase tracking-widest mt-2">Omnichannel Communications Control</p>
                </div>
                <div className="flex gap-4">
                    <div className="flex items-center gap-2 px-4 py-2 bg-zinc-50 rounded-xl border border-zinc-100">
                        <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>
                        <span className="text-[9px] font-black uppercase text-zinc-500 tracking-widest">Gateway Active</span>
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-12">
                <div className="lg:col-span-2 space-y-8">
                    <div className="bg-white rounded-[3.5rem] p-12 border border-zinc-100 shadow-sm space-y-10">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                            <div className="space-y-4">
                                <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-2">Audiencia</label>
                                <div className="flex p-1.5 bg-zinc-50 rounded-2xl">
                                    <button onClick={() => setTarget('all')} className={`flex-1 py-3 rounded-xl font-black text-[9px] uppercase tracking-widest transition-all ${target === 'all' ? 'bg-black text-white' : 'text-zinc-400'}`}>
                                        Global
                                    </button>
                                    <button onClick={() => setTarget('specific')} className={`flex-1 py-3 rounded-xl font-black text-[9px] uppercase tracking-widest transition-all ${target === 'specific' ? 'bg-black text-white' : 'text-zinc-400'}`}>
                                        Targeted
                                    </button>
                                </div>
                            </div>
                            <div className="space-y-4">
                                <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-2">Canal de Envío</label>
                                <div className="flex p-1.5 bg-zinc-50 rounded-2xl overflow-x-auto no-scrollbar">
                                    {['Push', 'Email', 'SMS', 'In-App'].map(c => (
                                        <button key={c} onClick={() => setChannel(c)} className={`flex-1 px-4 py-3 rounded-xl font-black text-[9px] uppercase tracking-widest transition-all whitespace-nowrap ${channel === c ? 'bg-black text-white' : 'text-zinc-400'}`}>
                                            {c}
                                        </button>
                                    ))}
                                </div>
                            </div>
                        </div>

                        {target === 'specific' && (
                            <div className="space-y-3 animate-in fade-in slide-in-from-top-2">
                                <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-2">User ID / Email</label>
                                <input className="w-full bg-zinc-50 border-zinc-100 rounded-2xl px-6 py-4 text-xs font-bold outline-none focus:border-black transition-all" placeholder="uuid-example-1234" />
                            </div>
                        )}

                        <div className="space-y-3">
                            <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-2">Título de Notificación</label>
                            <input
                                value={title}
                                onChange={(e) => setTitle(e.target.value)}
                                className="w-full bg-zinc-50 border-zinc-100 rounded-2xl px-6 py-4 text-xs font-bold outline-none focus:border-black transition-all"
                                placeholder="Escribe un asunto impactante..."
                            />
                        </div>

                        <div className="space-y-3">
                            <label className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-2">Cuerpo del Mensaje</label>
                            <textarea
                                value={body}
                                onChange={(e) => setBody(e.target.value)}
                                className="w-full bg-zinc-50 border-zinc-100 rounded-[2rem] px-6 py-6 text-xs font-bold outline-none focus:border-black transition-all h-40 resize-none"
                                placeholder="Detalla el contenido aquí..."
                            />
                        </div>

                        <div className="pt-4 flex items-center justify-between gap-8">
                            <div className="flex-1 flex gap-4">
                                {['Normal', 'High', 'Urgent'].map(p => (
                                    <button key={p} onClick={() => setPriority(p)} className={`px-4 py-2 rounded-lg text-[8px] font-black uppercase tracking-widest border transition-all ${priority === p ? 'bg-zinc-100 border-zinc-200 text-black' : 'border-transparent text-zinc-300'}`}>
                                        {p}
                                    </button>
                                ))}
                            </div>
                            <button
                                onClick={handleSend}
                                className="px-12 bg-black text-white h-16 rounded-2xl font-black uppercase tracking-widest text-[10px] hover:shadow-2xl shadow-black/20 hover:-translate-y-1 transition-all flex items-center gap-3"
                            >
                                <Send size={16} /> Desplegar
                            </button>
                        </div>
                    </div>
                </div>

                <div className="space-y-8">
                    <div className="space-y-1">
                        <h3 className="font-black text-xs uppercase tracking-[0.3em]">Recent Broadcasts</h3>
                        <p className="text-zinc-300 text-[10px] font-bold uppercase tracking-widest underline decoration-zinc-100 underline-offset-4">Full Logs</p>
                    </div>

                    <div className="space-y-4">
                        {history.map((item) => (
                            <div key={item.id} className="bg-white border border-zinc-100 rounded-3xl p-6 space-y-4 hover:shadow-md transition-shadow cursor-pointer group">
                                <div className="flex justify-between items-start">
                                    <div className={`px-2 py-0.5 rounded-full text-[7px] font-black uppercase tracking-tighter ${item.status === 'Sent' ? 'bg-green-50 text-green-600' : item.status === 'Scheduled' ? 'bg-blue-50 text-blue-600' : 'bg-red-50 text-red-600'}`}>
                                        {item.status}
                                    </div>
                                    <span className="text-[8px] font-black text-zinc-300 uppercase">{item.timestamp}</span>
                                </div>
                                <div>
                                    <h4 className="font-black text-[10px] uppercase line-clamp-1 group-hover:text-black transition-colors">{item.title}</h4>
                                    <div className="flex items-center gap-4 mt-2">
                                        <div className="flex items-center gap-1.5">
                                            <Globe size={10} className="text-zinc-300" />
                                            <span className="text-[8px] font-black text-zinc-400 uppercase tracking-tighter">{item.target}</span>
                                        </div>
                                        <div className="flex items-center gap-1.5">
                                            <Smartphone size={10} className="text-zinc-300" />
                                            <span className="text-[8px] font-black text-zinc-400 uppercase tracking-tighter">{item.channel}</span>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>

                    <button className="w-full py-4 border border-zinc-100 rounded-2xl text-[9px] font-black uppercase tracking-[0.3em] text-zinc-300 hover:text-black hover:bg-zinc-50 transition-all">
                        Cargar Historial Completo
                    </button>
                </div>
            </div>
        </div>
    );
};
