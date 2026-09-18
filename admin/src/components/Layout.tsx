import React, { useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import {
    LayoutDashboard,
    Users,
    UserCheck,
    Zap,
    Megaphone,
    FileText,
    AlertCircle,
    Bell,
    Sliders,
    Mail,
    LogOut,
    Menu,
    ChevronLeft,
    Headphones,
    Shield
} from 'lucide-react';
import { auth } from '../services/firebase';
import { ErrorBoundary } from './ErrorBoundary';

const menuItems = [
    { path: '/admin/dashboard', label: 'Dashboard', icon: LayoutDashboard },
    { path: '/admin/users', label: 'Usuarios', icon: Users },
    { path: '/admin/publications', label: 'Publicaciones', icon: FileText },
    { path: '/admin/verifications', label: 'Verificaciones', icon: UserCheck },
    { path: '/admin/boosts', label: 'Impulsos', icon: Zap },
    { path: '/admin/ads', label: 'Anuncios', icon: Megaphone },
    { path: '/admin/reports', label: 'Reportes', icon: AlertCircle },
    { path: '/admin/support', label: 'Soporte', icon: Headphones },
    { path: '/admin/notifications', label: 'Notificaciones', icon: Bell },
    { path: '/admin/mail', label: 'Correo', icon: Mail },
    { path: '/admin/tools', label: 'Herramientas', icon: Sliders },
];

export const Layout: React.FC = () => {
    const [isCollapsed, setIsCollapsed] = useState(false);
    const location = useLocation();
    const user = auth.currentUser;

    const handleLogout = () => {
        if (window.confirm('¿Deseas cerrar sesión en el Panel de Administración?')) {
            auth.signOut();
        }
    };

    const currentTitle = menuItems.find(item => location.pathname.startsWith(item.path))?.label || 'Panel de Administración';

    return (
        <div className="flex min-h-screen bg-[#F8FAFC] text-[#0F172A] font-sans antialiased">
            {/* Barra Lateral Sólida (Negro CONNECT) */}
            <aside
                className={`bg-[#0A0A0A] text-white flex flex-col z-30 transition-all duration-300 border-r border-zinc-800 ${
                    isCollapsed ? 'w-16' : 'w-60'
                }`}
            >
                {/* Logo CONNECT */}
                <div className="h-14 px-4 flex items-center justify-between border-b border-zinc-800/80">
                    {!isCollapsed ? (
                        <div className="flex items-center gap-2">
                            <span className="font-archivo font-black text-lg tracking-tight text-white">CONNECT</span>
                            <span className="text-[10px] font-bold uppercase tracking-wider bg-[#0094FF] text-white px-1.5 py-0.5 rounded">
                                Admin
                            </span>
                        </div>
                    ) : (
                        <div className="mx-auto w-7 h-7 bg-[#0094FF] text-white rounded-lg flex items-center justify-center font-black text-xs">
                            C
                        </div>
                    )}
                    <button
                        onClick={() => setIsCollapsed(!isCollapsed)}
                        className="text-zinc-400 hover:text-white p-1 rounded-md hover:bg-zinc-800 transition-colors"
                        title={isCollapsed ? 'Expandir menú' : 'Colapsar menú'}
                    >
                        {isCollapsed ? <Menu size={16} /> : <ChevronLeft size={16} />}
                    </button>
                </div>

                {/* Lista de Navegación Compacta */}
                <nav className="flex-1 py-3 px-2 space-y-1 overflow-y-auto">
                    {menuItems.map((item) => {
                        const Icon = item.icon;
                        const isTools = item.path === '/admin/tools';
                        return (
                            <NavLink
                                key={item.path}
                                to={item.path}
                                end={item.path === '/admin/dashboard'}
                                className={({ isActive }) => `
                                    flex items-center gap-3 px-3 py-2 rounded-lg text-xs font-medium transition-colors
                                    ${isActive
                                        ? 'bg-[#0094FF] text-white font-semibold shadow-none'
                                        : 'text-zinc-400 hover:text-white hover:bg-zinc-900'
                                    }
                                    ${isCollapsed ? 'justify-center px-0' : ''}
                                `}
                                title={isCollapsed ? item.label : undefined}
                            >
                                <Icon size={16} className="flex-shrink-0" />
                                {!isCollapsed && (
                                    <span className="truncate flex-1">{item.label}</span>
                                )}
                            </NavLink>
                        );
                    })}
                </nav>

                {/* Perfil del Administrador y Logout */}
                <div className="p-3 border-t border-zinc-800/80 bg-zinc-950/60">
                    <div className={`flex items-center gap-2.5 ${isCollapsed ? 'justify-center' : ''}`}>
                        <div className="w-8 h-8 rounded-lg bg-zinc-800 text-zinc-200 flex items-center justify-center font-bold text-xs flex-shrink-0 border border-zinc-700">
                            {user?.email?.[0].toUpperCase() || 'A'}
                        </div>
                        {!isCollapsed && (
                            <div className="flex-1 min-w-0">
                                <p className="text-xs font-semibold text-white truncate leading-tight">
                                    {user?.displayName || 'Administrador'}
                                </p>
                                <p className="text-[11px] text-zinc-400 truncate leading-tight mt-0.5">
                                    {user?.email || 'admin@connect.com'}
                                </p>
                            </div>
                        )}
                        {!isCollapsed && (
                            <button
                                onClick={handleLogout}
                                className="text-zinc-400 hover:text-red-400 p-1.5 rounded-md hover:bg-zinc-800 transition-colors"
                                title="Cerrar sesión"
                            >
                                <LogOut size={15} />
                            </button>
                        )}
                    </div>
                </div>
            </aside>

            {/* Contenido Principal */}
            <div className="flex-1 flex flex-col h-screen overflow-hidden bg-[#F8FAFC]">
                {/* Header Superior Limpio */}
                <header className="h-14 bg-white border-b border-zinc-200 px-6 flex items-center justify-between flex-shrink-0">
                    <div className="flex items-center gap-2 text-xs font-medium text-zinc-500">
                        <span>Panel</span>
                        <span>/</span>
                        <span className="font-semibold text-zinc-900">{currentTitle}</span>
                    </div>

                    <div className="flex items-center gap-3">
                        <div className="flex items-center gap-1.5 px-2.5 py-1 bg-emerald-50 border border-emerald-200 rounded-md text-[11px] font-semibold text-emerald-700">
                            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                            <span>Conectado a Firebase</span>
                        </div>
                    </div>
                </header>

                {/* Área de Visualización */}
                <main className="flex-1 overflow-y-auto p-6 md:p-8">
                    <div className="max-w-7xl mx-auto">
                        <ErrorBoundary>
                            <Outlet />
                        </ErrorBoundary>
                    </div>
                </main>
            </div>
        </div>
    );
};
