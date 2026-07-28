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
        <div className="flex min-h-screen bg-transparent text-zinc-900 font-inter">
            {/* Sidebar */}
            <motion.aside
                animate={{ width: isCollapsed ? 80 : 260 }}
                className={`text-white flex flex-col z-20 overflow-hidden relative transition-all duration-500 ${isCollapsed ? 'bg-transparent border-none' : 'glass-panel-dark border-r border-white/5'}`}
            >
                <div className={`p-8 flex items-center ${isCollapsed ? 'justify-center mt-2' : 'justify-between'}`}>
                    <AnimatePresence mode="wait">
                        {!isCollapsed && (
                            <motion.h1
                                initial={{ opacity: 0, x: -10 }}
                                animate={{ opacity: 1, x: 0 }}
                                exit={{ opacity: 0, x: -10 }}
                                className="text-2xl font-black font-archivo tracking-tighter uppercase leading-none text-white/90"
                            >
                                CONNECT
                            </motion.h1>
                        )}
                    </AnimatePresence>
                    <button
                        onClick={() => setIsCollapsed(!isCollapsed)}
                        className={`text-white/60 hover:text-white transition-all p-2 rounded-xl ${isCollapsed ? 'glass-button' : 'hover:bg-white/10'}`}
                    >
                        {isCollapsed ? <Menu size={18} /> : <ChevronRight size={18} className="rotate-180" />}
                    </button>
                </div>

                {!isCollapsed && <div className="h-0.5 w-6 bg-white/20 ml-8 rounded-full mb-2"></div>}

                <nav className={`flex-1 space-y-3 mt-4 ${isCollapsed ? 'px-3' : 'px-5'}`}>
                    {menuItems.map((item) => (
                        <NavLink
                            key={item.path}
                            to={item.path}
                            end={item.path === '/admin/dashboard'} // <--- Importante para que el dashboard no quede active siempre
                            className={({ isActive }: { isActive: boolean }) => `
                                relative flex items-center gap-4 py-3 rounded-2xl text-sm font-bold transition-all duration-300 group overflow-hidden
                                ${isCollapsed ? 'px-0 justify-center' : 'px-5'}
                                ${isActive 
                                    ? 'text-white glass-panel shadow-lg shadow-white/5 scale-105' 
                                    : `text-white/50 hover:text-white hover:scale-105 ${isCollapsed ? 'hover:glass-panel' : 'hover:bg-white/5'}`
                                }
                            `}
                        >
                            {({ isActive }: { isActive: boolean }) => (
                                <>
                                    <span className={`relative z-10 flex items-center justify-center ${isCollapsed ? 'w-10 h-10' : ''}`}>
                                        <item.icon size={isCollapsed ? 22 : 18} strokeWidth={isActive ? 2.5 : 2} className={isActive ? 'text-white' : ''} />
                                    </span>
                                    {!isCollapsed && (
                                        <>
                                            <span className="relative z-10 flex-1 tracking-wide">{item.label}</span>
                                            <ChevronRight
                                                size={14}
                                                className={`relative z-10 transition-all ${isActive ? 'opacity-100 translate-x-0' : 'opacity-0 -translate-x-2 group-hover:opacity-100 group-hover:translate-x-0'}`}
                                            />
                                        </>
                                    )}
                                </>
                            )}
                        </NavLink>
                    ))}
                </nav>

                <div className={`p-6 border-t ${isCollapsed ? 'border-transparent' : 'border-white/5'}`}>
                    <div className={`flex items-center gap-4 py-2 rounded-2xl transition-all group ${isCollapsed ? 'px-0 justify-center' : 'px-4 hover:bg-white/5'}`}>
                        <div className={`flex-shrink-0 rounded-xl flex items-center justify-center text-sm font-black transition-all ${isCollapsed ? 'w-12 h-12 glass-panel group-hover:scale-110' : 'w-10 h-10 glass-panel-dark'}`}>
                            {user?.email?.[0].toUpperCase()}
                        </div>
                        {!isCollapsed && (
                            <>
                                <div className="flex-1 min-w-0 text-left">
                                    <p className="text-[11px] font-black truncate uppercase tracking-widest text-white/90">{user?.displayName || 'Root Admin'}</p>
                                    <p className="text-[9px] text-white/40 truncate font-bold">{user?.email}</p>
                                </div>
                                <button
                                    onClick={handleLogout}
                                    className="text-white/40 hover:text-red-400 transition-colors p-2 hover:bg-red-400/10 rounded-lg"
                                >
                                    <LogOut size={16} />
                                </button>
                            </>
                        )}
                    </div>
                </div>
            </motion.aside>

            {/* Main Content */}
            <main className="flex-1 flex flex-col h-screen overflow-hidden bg-transparent">
                <div className="flex-1 overflow-hidden relative">
                    <AnimatePresence>
                        <ErrorBoundary>
                            <motion.section
                                key={location.pathname}
                                initial={{ x: -10, opacity: 0 }}
                                animate={{ x: 0, opacity: 1 }}
                                exit={{ x: 10, opacity: 0 }}
                                transition={{
                                    type: "spring",
                                    stiffness: 300,
                                    damping: 20
                                }}
                                className="absolute inset-0 overflow-y-auto px-12 pb-12 pt-6"
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
