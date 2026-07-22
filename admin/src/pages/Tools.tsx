import React from 'react';
import {
    Database,
    Zap,
    ShieldCheck,
    RotateCcw,
    Download,
    Terminal,
    Activity,
    HardDrive,
    Lock
} from 'lucide-react';
import { motion } from 'framer-motion';

interface SystemAction {
    title: string;
    icon: any;
    description: string;
    color: string;
}

interface Report {
    id: string;
    item: string;
    type: 'Post' | 'User';
    reason: string;
    reporter: string;
    status: 'pending' | 'resolved';
    date: string;
}

export const Tools: React.FC = () => {
    const systemActions: SystemAction[] = [
        { title: 'Purge CDN Cache', icon: Zap, description: 'Flush global assets and edge locations.', color: 'text-orange-500' },
        { title: 'Firestore Audit', icon: Database, description: 'Check for document integrity and orphans.', color: 'text-blue-500' },
        { title: 'Export GDPR Data', icon: Download, description: 'Generate full encrypted user archives.', color: 'text-emerald-500' },
        { title: 'Reset Auth Tokens', icon: Lock, description: 'Force re-authentication across all clients.', color: 'text-red-500' },
        { title: 'DB Vacuum', icon: HardDrive, description: 'Optimize database storage and indexing.', color: 'text-purple-500' },
        { title: 'SSL Renewal', icon: ShieldCheck, description: 'Force refresh of security certificates.', color: 'text-cyan-500' },
        { title: 'Sync Legacy DB', icon: RotateCcw, description: 'Pull residual data from V1 servers.', color: 'text-zinc-500' },
        { title: 'API Key Rotation', icon: Zap, description: 'Cycle high-privilege service keys.', color: 'text-yellow-500' },
        { title: 'System Health', icon: ShieldCheck, description: 'Run full stack diagnostic tests.', color: 'text-indigo-500' },
    ];

    const logs = [
        { type: 'success', text: '[SYSTEM] Authenticated as root_admin@connect2025.local' },
        { type: 'info', text: '[INFO] Firestore Snapshot Listener initialized successfully' },
        { type: 'info', text: '[INFO] CDN purge scheduled for 04:00 UTC' },
        { type: 'log', text: '[LOG] Incoming request: GET /api/v2/metrics 200 OK' },
        { type: 'warn', text: '[WARN] High memory pressure detected in edge_node_4' },
        { type: 'error', text: '[CRITICAL] Failed to sync document: users/AX72-B1 (Retry 3/5)' },
        { type: 'success', text: '[SYNC] Legacy assets migration 82% complete' },
    ];

    return (
        <div className="space-y-12 animate-in slide-in-from-right duration-700">
            <div className="flex items-center justify-between">
                <div className="space-y-1">
                    <h1 className="text-4xl font-black tracking-tighter uppercase italic">System Utilities</h1>
                    <p className="text-zinc-400 text-[10px] font-bold uppercase tracking-widest">Low-level Controls & Maintenance</p>
                </div>
                <div className="h-12 w-12 bg-zinc-50 rounded-full border border-zinc-100 flex items-center justify-center animate-pulse">
                    <div className="h-2 w-2 bg-black rounded-full"></div>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                {[
                    { label: 'DB Latency', value: '38ms', sub: 'Optimal', icon: Database },
                    { label: 'CPU Usage', value: '14%', sub: 'Balanced', icon: Activity },
                    { label: 'Storage', value: '76%', sub: 'Safe Range', icon: HardDrive },
                ].map((stat, i) => {
                    const Icon = stat.icon;
                    return (
                        <div key={i} className="bg-white border border-zinc-100 p-8 rounded-[2.5rem] shadow-sm">
                            <div className="flex items-center gap-3 mb-4">
                                <Icon size={16} className="text-zinc-300" />
                                <span className="text-[10px] font-black text-zinc-300 uppercase tracking_widest">{stat.label}</span>
                            </div>
                            <p className="text-4xl font-black tracking-tighter">{stat.value}</p>
                            <p className="text-[10px] font-bold text-zinc-400 uppercase tracking_widest mt-2">{stat.sub}</p>
                        </div>
                    );
                })}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {systemActions.map((action, i) => {
                    const Icon = action.icon;
                    return (
                        <motion.button
                            key={i}
                            whileHover={{ scale: 1.02 }}
                            whileTap={{ scale: 0.98 }}
                            className="bg-white border border-zinc-100 p-8 rounded-[2.5rem] shadow-sm text-left group hover:border-black transition-colors"
                        >
                            <div className={`p-4 bg-zinc-50 rounded-2xl w-fit mb-6 group-hover:bg-black group-hover:text-white transition-all ${action.color}`}>
                                <Icon size={24} />
                            </div>
                            <h3 className="font-black text-xs uppercase tracking-[0.2em] mb-2">{action.title}</h3>
                            <p className="text-[10px] text-zinc-400 font-bold leading-relaxed">{action.description}</p>
                        </motion.button>
                    );
                })}
            </div>

            <div className="bg-black rounded-[3rem] p-10 overflow-hidden relative group">
                <div className="absolute top-0 right-0 p-8 opacity-10 group-hover:opacity-20 transition-opacity">
                    <Terminal size={120} className="text-white" />
                </div>
                <div className="relative z-10 space-y-6">
                    <div className="flex items-center gap-4 border-b border-white/10 pb-6">
                        <div className="h-3 w-3 bg-red-500 rounded-full animate-pulse"></div>
                        <div className="h-3 w-3 bg-yellow-400 rounded-full"></div>
                        <div className="h-3 w-3 bg-green-500 rounded-full"></div>
                        <span className="text-[10px] font-black text-white/30 uppercase tracking-[0.5em] ml-4">Terminal Console / Live Diagnostics</span>
                    </div>
                    <div className="font-mono text-[10px] space-y-2 max-h-60 overflow-y-auto no-scrollbar">
                        {logs.map((log, i) => (
                            <p key={i} className={`
                                ${log.type === 'success' ? 'text-green-500' : ''}
                                ${log.type === 'error' ? 'text-red-500' : ''}
                                ${log.type === 'warn' ? 'text-yellow-500' : ''}
                                ${log.type === 'info' ? 'text-blue-400' : ''}
                                ${log.type === 'log' ? 'text-zinc-500' : ''}
                            `}>
                                {log.text}
                            </p>
                        ))}
                        <p className="text-white animate-pulse">_</p>
                    </div>
                </div>
            </div>
        </div>
    );
};
