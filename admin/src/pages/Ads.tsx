import React, { useState } from 'react';
import {
    Megaphone,
    Plus,
    Monitor,
    Smartphone,
    MousePointer2,
    Eye,
    TrendingUp,
    MoreVertical,
    CheckCircle2,
    Clock
} from 'lucide-react';

interface AdSlot {
    id: string;
    name: string;
    client: string;
    clicks: number;
    status: string;
    performance: string;
}

export const Ads: React.FC = () => {
    const [filter, setFilter] = useState<'all' | 'active' | 'scheduled'>('all');

    const adSlots: AdSlot[] = [
        { id: '1', name: 'Home Banner Primary', client: 'Nexus Tech', clicks: 1240, status: 'active', performance: '+12%' },
        { id: '2', name: 'Sidebar Sticky', client: 'EcoMarket', clicks: 850, status: 'active', performance: '+5%' },
        { id: '3', name: 'Interstitial Video', client: 'Brave Browser', clicks: 3200, status: 'scheduled', performance: '0%' },
    ];

    return (
        <div className="space-y-12 animate-in fade-in duration-700">
            <div className="flex items-center justify-between">
                <div className="space-y-1">
                    <h1 className="text-4xl font-black tracking-tighter uppercase italic">Ad Engine</h1>
                    <p className="text-zinc-400 text-[10px] font-bold uppercase tracking-widest">Inventory & Campaign Management</p>
                </div>
                <button className="h-16 px-8 bg-black text-white rounded-2xl font-black text-xs uppercase tracking-widest hover:scale-105 active:scale-95 transition-all flex items-center gap-3 shadow-xl shadow-black/10">
                    <Plus size={18} /> New Campaign
                </button>
            </div>

            {/* Metrics Overview */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                {[
                    { label: 'Total Impressions', value: '1.2M', icon: Eye },
                    { label: 'Global CTR', value: '4.8%', icon: MousePointer2 },
                    { label: 'Active Slots', value: '12/15', icon: Monitor },
                    { label: 'Rev. Estimation', value: '$8.4k', icon: TrendingUp },
                ].map((stat: any, i: number) => (
                    <div key={i} className="bg-white border border-zinc-100 p-8 rounded-[2.5rem] shadow-sm hover:shadow-xl hover:shadow-zinc-100 transition-all group">
                        <div className="flex items-center justify-between mb-6">
                            <div className="p-3 bg-zinc-50 rounded-xl group-hover:bg-black group-hover:text-white transition-colors">
                                <stat.icon size={20} />
                            </div>
                            <span className="text-[10px] font-black text-zinc-300 uppercase tracking-widest">Live Now</span>
                        </div>
                        <p className="text-3xl font-black tracking-tighter">{stat.value}</p>
                        <p className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest mt-1">{stat.label}</p>
                    </div>
                ))}
            </div>

            {/* Empty State Message */}
            <div className="bg-white rounded-[3.5rem] border border-zinc-100 overflow-hidden shadow-sm py-40 flex flex-col items-center justify-center space-y-6">
                <div className="w-20 h-20 bg-zinc-50 rounded-full flex items-center justify-center text-zinc-200">
                    <Megaphone size={40} />
                </div>
                <div className="text-center space-y-2 max-w-sm">
                    <h3 className="font-black text-xs uppercase tracking-[0.2em] text-black">Sin Campañas Activas</h3>
                    <p className="text-zinc-400 text-[10px] font-bold uppercase tracking-widest leading-relaxed">
                        Actualmente no hay nada publicado de anuncios. Regresa más tarde o actualiza el sistema.
                    </p>
                </div>
                <button
                    onClick={() => window.location.reload()}
                    className="mt-4 px-8 py-3 bg-zinc-50 text-zinc-400 hover:text-black hover:bg-zinc-100 rounded-2xl text-[10px] font-black uppercase tracking-[0.2em] transition-all"
                >
                    Actualizar Engine
                </button>
            </div>
        </div>
    );
};
