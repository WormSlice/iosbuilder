import React from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Layout as LayoutIcon,
    Users,
    User as UserCheck,
    Zap,
    Megaphone,
    Edit as FileEdit,
    AlertCircle,
    Bell,
    Settings as Wrench,
    Mail as MailIcon,
    LogOut,
    ChevronRight,
    Menu,
    Headphones
} from 'lucide-react';
import { useState } from 'react';
import { auth } from '../services/firebase';
import { ErrorBoundary } from './ErrorBoundary';

const menuItems = [
    { path: '/admin/dashboard', label: 'Dashboard', icon: LayoutIcon },
    { path: '/admin/users', label: 'Usuarios', icon: Users },
    { path: '/admin/verifications', label: 'Verificaciones', icon: UserCheck },
    { path: '/admin/boosts', label: 'Impulsos', icon: Zap },
    { path: '/admin/ads', label: 'Anuncios', icon: Megaphone },
    { path: '/admin/publications', label: 'Publicaciones', icon: FileEdit },
    { path: '/admin/reports', label: 'Reportes', icon: AlertCircle },
    { path: '/admin/notifications', label: 'Notificaciones', icon: Bell },
    { path: '/admin/mail', label: 'Mail', icon: MailIcon },
    { path: '/admin/support', label: 'Soporte', icon: Headphones },
    { path: '/admin/tools', label: 'Herramientas', icon: Wrench },
];

export const Layout: React.FC = () => {
    const [isCollapsed, setIsCollapsed] = useState(false);
    const navigate = useNavigate();
    const location = useLocation();
    const user = auth.currentUser;

    const handleLogout = () => {
        auth.signOut();
    };

    return (
        <div className="flex min-h-screen bg-white text-zinc-900 font-inter">
            {/* Sidebar */}
            <motion.aside
                animate={{ width: isCollapsed ? 100 : 288 }}
                className="bg-black text-white flex flex-col border-r border-zinc-900 z-20 overflow-hidden relative"
            >
                <div className={`p-10 flex items-center ${isCollapsed ? 'justify-center' : 'justify-between'}`}>
                    <AnimatePresence mode="wait">
                        {!isCollapsed && (
                            <motion.h1
                                initial={{ opacity: 0, x: -10 }}
                                animate={{ opacity: 1, x: 0 }}
                                exit={{ opacity: 0, x: -10 }}
                                className="text-3xl font-black font-archivo tracking-tighter uppercase leading-none"
                            >
                                CONNECT
                            </motion.h1>
                        )}
                    </AnimatePresence>
                    <button
                        onClick={() => setIsCollapsed(!isCollapsed)}
                        className="text-zinc-600 hover:text-white transition-colors p-2 bg-zinc-900 rounded-lg"
                    >
                        {isCollapsed ? <Menu size={16} /> : <ChevronRight size={16} className="rotate-180" />}
                    </button>
                </div>

                {!isCollapsed && <div className="h-1 w-8 bg-zinc-800 ml-10 rounded-full"></div>}

                <nav className="flex-1 px-6 space-y-2 mt-4">
                    {menuItems.map((item) => (
                        <NavLink
                            key={item.path}
                            to={item.path}
                            end={item.path === '/admin/dashboard'} // <--- Importante para que el dashboard no quede active siempre
                            className={({ isActive }: { isActive: boolean }) => `
                                relative flex items-center gap-4 px-6 py-4 rounded-2xl text-sm font-bold transition-all group overflow-hidden
                                ${isActive ? 'text-black' : 'text-zinc-500 hover:text-white'}
                            `}
                        >
                            {({ isActive }: { isActive: boolean }) => (
                                <>
                                    {isActive && (
                                        <motion.div
                                            layoutId="piano-key"
                                            className="absolute inset-0 bg-white z-0"
                                            initial={false}
                                            transition={{
                                                type: "spring",
                                                stiffness: 300,
                                                damping: 30
                                            }}
                                        />
                                    )}
                                    <span className={`relative z-10 ${isCollapsed ? 'w-full flex justify-center' : ''}`}>
                                        <item.icon size={20} strokeWidth={isActive ? 2.5 : 2} />
                                    </span>
                                    {!isCollapsed && (
                                        <>
                                            <span className="relative z-10 flex-1">{item.label}</span>
                                            <ChevronRight
                                                size={14}
                                                className={`relative z-10 transition-opacity ${isActive ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'}`}
                                            />
                                        </>
                                    )}
                                </>
                            )}
                        </NavLink>
                    ))}
                </nav>

                <div className="p-8 border-t border-zinc-900">
                    <div className="flex items-center gap-4 px-4 py-2 hover:bg-zinc-900/50 rounded-2xl transition-all group">
                        <div className={`w-10 h-10 flex-shrink-0 rounded-xl bg-zinc-800 border border-zinc-700 flex items-center justify-center text-sm font-black group-hover:scale-110 transition-transform`}>
                            {user?.email?.[0].toUpperCase()}
                        </div>
                        {!isCollapsed && (
                            <>
                                <div className="flex-1 min-w-0 text-left">
                                    <p className="text-xs font-black truncate uppercase tracking-tight">{user?.displayName || 'Root Admin'}</p>
                                    <p className="text-[9px] text-zinc-500 truncate font-bold">{user?.email}</p>
                                </div>
                                <button
                                    onClick={handleLogout}
                                    className="text-zinc-600 hover:text-red-500 transition-colors"
                                >
                                    <LogOut size={18} />
                                </button>
                            </>
                        )}
                    </div>
                </div>
            </motion.aside>

            {/* Main Content */}
            <main className="flex-1 flex flex-col h-screen overflow-hidden bg-white">
                <header className="h-20 flex items-center justify-between px-12 z-10 border-b border-zinc-50 bg-white/80 backdrop-blur-xl">
                    <div className="flex items-center gap-3">
                        <div className="w-2 h-2 rounded-full bg-blue-500"></div>
                        <div className="text-[10px] font-black text-zinc-400 uppercase tracking-[0.4em]">
                            {menuItems.find(item => item.path === location.pathname)?.label || 'System Master'}
                        </div>
                    </div>

                    <div className="flex items-center gap-6">
                        <div className="h-10 w-px bg-zinc-100"></div>
                        <button className="p-3 text-zinc-400 hover:text-black transition-all relative group bg-zinc-50 rounded-xl">
                            <Bell size={20} />
                            <span className="absolute top-3 right-3 w-2 h-2 bg-black rounded-full border-2 border-white ring-4 ring-black/5 opacity-0 group-hover:opacity-100 transition-opacity"></span>
                        </button>
                    </div>
                </header>

                <div className="flex-1 overflow-hidden relative">
                    <AnimatePresence mode="wait">
                        <ErrorBoundary>
                            <motion.section
                                key={location.pathname}
                                initial={{ x: -20, opacity: 0, scale: 0.98 }}
                                animate={{ x: 0, opacity: 1, scale: 1 }}
                                exit={{ x: 20, opacity: 0, scale: 1.02 }}
                                transition={{
                                    type: "spring",
                                    stiffness: 260,
                                    damping: 20
                                }}
                                className="absolute inset-0 overflow-y-auto px-12 pb-12"
                            >
                                <Outlet />
                            </motion.section>
                        </ErrorBoundary>
                    </AnimatePresence>
                </div>
            </main>
        </div>
    );
};
