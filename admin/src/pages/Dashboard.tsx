import React, { useState, useEffect } from 'react';
import { collection, getDocs } from 'firebase/firestore';
import { db } from '../services/firebase';
import {
    Users,
    FileText,
    Activity,
    Zap,
    ArrowUpRight,
    BarChart3,
    TrendingUp,
    MousePointerClick,
    Server,
    Clock
} from 'lucide-react';
interface DashboardStats {
    users: number;
    posts: number;
    active: number;
    conversion: string;
}

export const Dashboard: React.FC = () => {
    const [stats, setStats] = useState<DashboardStats>({ users: 0, posts: 0, active: 42, conversion: '3.2%' });

    useEffect(() => {
        const fetchData = async () => {
            try {
                const usersSnapshot = await getDocs(collection(db, 'users'));
                const postsSnapshot = await getDocs(collection(db, 'posts'));
                setStats(prev => ({
                    ...prev,
                    users: usersSnapshot.size,
                    posts: postsSnapshot.size
                }));
            } catch (error) {
                console.error("Error fetching dashboard stats:", error);
            }
        };
        fetchData();
    }, []);

    return (
        <div className="space-y-12 animate-in fade-in duration-700">
            <div className="flex justify-between items-end">
                <div className="space-y-1">
                    <h1 className="text-4xl font-black tracking-tighter">Dashboard</h1>
                    <p className="text-zinc-400 text-xs font-bold uppercase tracking-widest">Global Overview</p>
                </div>
                <div className="flex p-1 bg-zinc-100 rounded-xl">
                    <button className="px-4 py-2 bg-white shadow-sm rounded-lg text-[10px] font-black uppercase tracking-wider">Hoy</button>
                    <button className="px-4 py-2 text-zinc-400 text-[10px] font-black uppercase tracking-wider hover:text-black transition-all">Semana</button>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
                <div className="bg-white border border-zinc-100 rounded-[2rem] p-8 shadow-sm border-l-4 border-l-black group hover:border-zinc-300 transition-all">
                    <div className="flex justify-between items-start mb-2">
                        <p className="text-[10px] font-black text-zinc-400 uppercase tracking-widest">Usuarios</p>
                        <Users size={18} className="text-zinc-300" />
                    </div>
                    <p className="text-4xl font-black group-hover:scale-110 transition-transform origin-left">{stats.users}</p>
                    <div className="mt-4 flex items-center gap-2 text-green-500 font-bold text-[10px]"><ArrowUpRight size={12} /> 8% <span className="text-zinc-300 font-medium">vs mes anterior</span></div>
                </div>
                <div className="bg-white border border-zinc-100 rounded-[2rem] p-8 shadow-sm group hover:border-zinc-300 transition-all">
                    <div className="flex justify-between items-start mb-2">
                        <p className="text-[10px] font-black text-zinc-400 uppercase tracking-widest">Contenido Activo</p>
                        <FileText size={18} className="text-zinc-300" />
                    </div>
                    <p className="text-4xl font-black group-hover:scale-110 transition-transform origin-left">{stats.posts}</p>
                    <div className="mt-4 flex items-center gap-2 text-green-500 font-bold text-[10px]"><TrendingUp size={12} /> +124 <span className="text-zinc-300 font-medium">hoy</span></div>
                </div>
                <div className="bg-white border border-zinc-100 rounded-[2rem] p-8 shadow-sm group hover:border-zinc-300 transition-all">
                    <div className="flex justify-between items-start mb-2">
                        <p className="text-[10px] font-black text-zinc-400 uppercase tracking-widest">Sesiones en Vivo</p>
                        <div className="w-2 h-2 rounded-full bg-green-500 animate-ping"></div>
                    </div>
                    <p className="text-4xl font-black group-hover:scale-110 transition-transform origin-left">{stats.active}</p>
                    <div className="mt-4 flex items-center gap-2 text-zinc-300 font-medium text-[10px]"><Activity size={12} /> Tráfico global estable</div>
                </div>
                <div className="bg-white border border-zinc-100 rounded-[2rem] p-8 shadow-sm group hover:border-zinc-300 transition-all">
                    <div className="flex justify-between items-start mb-2">
                        <p className="text-[10px] font-black text-zinc-400 uppercase tracking-widest">Estabilidad Core</p>
                        <Server size={18} className="text-zinc-300" />
                    </div>
                    <p className="text-4xl font-black group-hover:scale-110 transition-transform origin-left">99.9%</p>
                    <div className="mt-4 flex items-center gap-2 text-zinc-300 font-medium text-[10px]"><Clock size={12} /> Uptime garantizado</div>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                <div className="lg:col-span-2 bg-black text-white rounded-[2.5rem] p-10 h-96 flex flex-col justify-between overflow-hidden relative shadow-2xl">
                    <div className="flex justify-between items-center relative z-10">
                        <div className="flex items-center gap-3">
                            <BarChart3 size={20} className="text-zinc-500" />
                            <h3 className="font-bold text-xl tracking-tight">Analytics Predictivo</h3>
                        </div>
                        <button className="text-[10px] font-black uppercase tracking-widest border-b border-zinc-700 pb-1 hover:border-white transition-all">Ver PDF Completo</button>
                    </div>
                    <div className="flex-1 flex items-end justify-around pb-4 relative z-10">
                        {[40, 70, 50, 90, 60, 80, 45, 65, 30, 85].map((h, i) => (
                            <div key={i} className="w-6 bg-white/10 rounded-t-sm hover:bg-white transition-all cursor-crosshair group relative" style={{ height: `${h}%` }}>
                                <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-white text-black text-[10px] font-black px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity">{(h * 123).toLocaleString()}</div>
                            </div>
                        ))}
                    </div>
                    <div className="absolute top-0 right-0 w-64 h-64 bg-white/5 rounded-full -mr-20 -mt-20 blur-3xl"></div>
                </div>
                <div className="bg-zinc-50 rounded-[2.5rem] p-10 space-y-8">
                    <div className="space-y-1">
                        <h3 className="font-bold text-lg">Cálculos de Sistema</h3>
                        <p className="text-[10px] font-bold text-zinc-400 uppercase tracking-widest">Métricas de Rentabilidad</p>
                    </div>
                    <div className="space-y-6">
                        <div className="space-y-2">
                            <div className="flex justify-between items-end">
                                <span className="text-[10px] font-black uppercase tracking-widest text-zinc-400 flex items-center gap-2"><TrendingUp size={12} /> Retención</span>
                                <span className="text-sm font-black">94.2%</span>
                            </div>
                            <div className="h-1 bg-zinc-200 rounded-full overflow-hidden">
                                <div className="h-full bg-black w-[94%]"></div>
                            </div>
                        </div>
                        <div className="space-y-2">
                            <div className="flex justify-between items-end">
                                <span className="text-[10px] font-black uppercase tracking-widest text-zinc-400 flex items-center gap-2"><Server size={12} /> Estabilidad</span>
                                <span className="text-sm font-black">99.9%</span>
                            </div>
                            <div className="h-1 bg-zinc-200 rounded-full overflow-hidden">
                                <div className="h-full bg-black w-[99%]"></div>
                            </div>
                        </div>
                        <div className="pt-6 grid grid-cols-2 gap-4">
                            <div className="p-5 bg-white rounded-2xl shadow-sm">
                                <p className="text-[9px] font-black text-zinc-300 uppercase mb-1">CAC</p>
                                <p className="text-xl font-black">$1.24</p>
                            </div>
                            <div className="p-5 bg-white rounded-2xl shadow-sm">
                                <p className="text-[9px] font-black text-zinc-300 uppercase mb-1">LTV</p>
                                <p className="text-xl font-black">$48.0</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};
