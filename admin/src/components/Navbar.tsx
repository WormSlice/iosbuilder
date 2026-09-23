import React, { useState, useEffect, useRef } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
    Download,
    Menu,
    X,
    User as UserIcon,
    ChevronDown,
    Shield,
    Settings as SettingsIcon,
    LogOut
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { auth, db, signOut, ALLOWED_EMAILS } from '../services/firebase';
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';

export const Navbar: React.FC = () => {
    const [isOpen, setIsOpen] = useState(false);
    const [userMenuOpen, setUserMenuOpen] = useState(false);
    const [user, setUser] = useState<any>(null);
    const [isAdmin, setIsAdmin] = useState(false);
    const [profilePhoto, setProfilePhoto] = useState<string | null>(null);

    const userMenuRef = useRef<HTMLDivElement>(null);
    const location = useLocation();
    const navigate = useNavigate();

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
            setUser(currentUser);
            if (currentUser) {
                try {
                    const userDoc = await getDoc(doc(db, 'users', currentUser.uid));
                    if (userDoc.exists()) {
                        setProfilePhoto(userDoc.data()?.photoURL || currentUser.photoURL || null);
                    } else if (currentUser.photoURL) {
                        setProfilePhoto(currentUser.photoURL);
                    }
                } catch (error) {
                    console.error("Error fetching user profile:", error);
                    if (currentUser.photoURL) setProfilePhoto(currentUser.photoURL);
                }
                setIsAdmin(ALLOWED_EMAILS.includes(currentUser.email || ''));
            } else {
                setIsAdmin(false);
                setProfilePhoto(null);
            }
        });
        return () => unsubscribe();
    }, []);

    // Close user dropdown when clicking outside
    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
            if (userMenuRef.current && !userMenuRef.current.contains(event.target as Node)) {
                setUserMenuOpen(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    const scrollTo = (id: string) => {
        setIsOpen(false);
        if (location.pathname !== '/') {
            navigate(`/#${id}`);
            setTimeout(() => {
                const el = document.getElementById(id);
                if (el) el.scrollIntoView({ behavior: 'smooth' });
            }, 100);
        } else {
            const el = document.getElementById(id);
            if (el) {
                el.scrollIntoView({ behavior: 'smooth' });
            }
        }
    };

    const handleSignOut = async () => {
        setUserMenuOpen(false);
        setIsOpen(false);
        try {
            await signOut(auth);
            navigate('/');
        } catch (err) {
            console.error('Error signing out:', err);
        }
    };

    return (
        <header className="fixed top-5 left-0 right-0 z-[90] px-4 pointer-events-none">
            <motion.nav
                initial={{ y: -25, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
                className="max-w-5xl mx-auto liquid-glass-nav rounded-full px-5 sm:px-7 py-2.5 flex items-center justify-between pointer-events-auto"
            >
                {/* Brand Logo & Name */}
                <Link to="/" className="flex items-center gap-2.5 group shrink-0">
                    <img
                        src="/logo.png"
                        alt="CONNECT"
                        className="h-7 w-7 object-contain brightness-125 transition-transform duration-300 group-hover:scale-105"
                    />
                    <span className="text-base font-extrabold tracking-tighter text-white font-archivo">
                        CONNECT
                    </span>
                </Link>

                {/* Feature Anchors */}
                <div className="hidden lg:flex items-center gap-6">
                    <button
                        onClick={() => scrollTo('lo-tienes')}
                        className="text-xs font-semibold text-zinc-300 hover:text-white transition-colors cursor-pointer"
                    >
                        Lo Tienes
                    </button>
                    <button
                        onClick={() => scrollTo('traduccion')}
                        className="text-xs font-semibold text-zinc-300 hover:text-white transition-colors cursor-pointer"
                    >
                        Traducción
                    </button>
                    <button
                        onClick={() => scrollTo('marketplace')}
                        className="text-xs font-semibold text-zinc-300 hover:text-white transition-colors cursor-pointer"
                    >
                        Marketplace
                    </button>
                    <button
                        onClick={() => scrollTo('seguridad')}
                        className="text-xs font-semibold text-zinc-300 hover:text-white transition-colors cursor-pointer"
                    >
                        Seguridad
                    </button>
                </div>

                {/* Right Side: Auth / Admin + Clean Matte Download Button */}
                <div className="hidden md:flex items-center gap-4">
                    {/* Admin Panel Link (Only visible to verified admins) */}
                    {user && isAdmin && (
                        <Link
                            to="/admin"
                            className="text-xs font-semibold text-zinc-300 hover:text-[#0094FF] transition-colors"
                        >
                            Panel
                        </Link>
                    )}

                    {/* User Auth Status with Interactive Dropdown */}
                    {user ? (
                        <div className="relative" ref={userMenuRef}>
                            <button
                                onClick={() => setUserMenuOpen(!userMenuOpen)}
                                className="flex items-center gap-2 text-xs font-semibold text-zinc-300 hover:text-white transition-colors cursor-pointer py-1 px-1.5 rounded-full hover:bg-white/5 active:scale-95"
                                aria-label="Menú de cuenta"
                            >
                                <div className="w-7 h-7 rounded-full border border-white/20 overflow-hidden bg-zinc-900 flex items-center justify-center shrink-0">
                                    {profilePhoto ? (
                                        <img src={profilePhoto} alt="Perfil" className="w-full h-full object-cover" />
                                    ) : (
                                        <UserIcon size={14} className="text-zinc-400" />
                                    )}
                                </div>
                                <span>Cuenta</span>
                                <ChevronDown
                                    size={12}
                                    className={`text-zinc-400 transition-transform duration-200 ${userMenuOpen ? 'rotate-180' : ''}`}
                                />
                            </button>

                            {/* Dropdown Menu */}
                            <AnimatePresence>
                                {userMenuOpen && (
                                    <motion.div
                                        initial={{ opacity: 0, y: 8, scale: 0.96 }}
                                        animate={{ opacity: 1, y: 0, scale: 1 }}
                                        exit={{ opacity: 0, y: 8, scale: 0.96 }}
                                        transition={{ duration: 0.15, ease: [0.16, 1, 0.3, 1] }}
                                        className="absolute right-0 top-full mt-3 w-64 liquid-glass-nav rounded-2xl p-3 shadow-2xl border border-white/15 z-50 text-left"
                                    >
                                        <div className="flex items-center gap-3 p-2 pb-3 border-b border-white/10">
                                            <div className="w-9 h-9 rounded-full border border-white/20 overflow-hidden bg-zinc-900 flex items-center justify-center shrink-0">
                                                {profilePhoto ? (
                                                    <img src={profilePhoto} alt="Perfil" className="w-full h-full object-cover" />
                                                ) : (
                                                    <UserIcon size={16} className="text-zinc-400" />
                                                )}
                                            </div>
                                            <div className="min-w-0 flex-1">
                                                <p className="text-xs font-bold text-white truncate">
                                                    {user.displayName || 'Usuario CONNECT'}
                                                </p>
                                                <p className="text-[11px] text-zinc-400 truncate font-mono">
                                                    {user.email}
                                                </p>
                                            </div>
                                        </div>

                                        <div className="py-2 space-y-1">
                                            {isAdmin && (
                                                <Link
                                                    to="/admin"
                                                    onClick={() => setUserMenuOpen(false)}
                                                    className="flex items-center gap-2.5 px-3 py-2 text-xs font-semibold text-zinc-300 hover:text-white hover:bg-white/5 rounded-xl transition-colors"
                                                >
                                                    <Shield size={14} className="text-[#0094FF]" />
                                                    <span>Panel de Administrador</span>
                                                </Link>
                                            )}
                                            <Link
                                                to="/settings"
                                                onClick={() => setUserMenuOpen(false)}
                                                className="flex items-center gap-2.5 px-3 py-2 text-xs font-semibold text-zinc-300 hover:text-white hover:bg-white/5 rounded-xl transition-colors"
                                            >
                                                <SettingsIcon size={14} className="text-zinc-400" />
                                                <span>Ajustes de Perfil</span>
                                            </Link>
                                        </div>

                                        <div className="pt-2 border-t border-white/10">
                                            <button
                                                onClick={handleSignOut}
                                                className="w-full flex items-center gap-2.5 px-3 py-2 text-xs font-semibold text-red-400 hover:text-red-300 hover:bg-red-500/10 rounded-xl transition-colors cursor-pointer"
                                            >
                                                <LogOut size={14} />
                                                <span>Cerrar Sesión</span>
                                            </button>
                                        </div>
                                    </motion.div>
                                )}
                            </AnimatePresence>
                        </div>
                    ) : (
                        <Link
                            to="/login"
                            className="text-xs font-semibold text-zinc-300 hover:text-white transition-colors px-1"
                        >
                            Iniciar Sesión
                        </Link>
                    )}

                    {/* Clean Matte Download Button (Zero shine, zero glow) */}
                    <button
                        onClick={() => scrollTo('descargar')}
                        className="bg-white hover:bg-zinc-200 text-zinc-950 text-xs font-bold px-4 py-2 rounded-full inline-flex items-center gap-1.5 transition-colors cursor-pointer shadow-sm active:scale-95"
                    >
                        <Download size={13} className="shrink-0" />
                        <span>Descargar App</span>
                    </button>
                </div>

                {/* Mobile Hamburger */}
                <button
                    className="md:hidden text-white/90 hover:text-white p-1 focus:outline-none"
                    onClick={() => setIsOpen(!isOpen)}
                    aria-label="Menú de navegación"
                >
                    {isOpen ? <X size={20} /> : <Menu size={20} />}
                </button>
            </motion.nav>

            {/* Mobile Dropdown Panel */}
            <AnimatePresence>
                {isOpen && (
                    <motion.div
                        initial={{ opacity: 0, y: -10, scale: 0.98 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        exit={{ opacity: 0, y: -10, scale: 0.98 }}
                        transition={{ duration: 0.2 }}
                        className="md:hidden mt-2.5 max-w-4xl mx-auto liquid-glass-nav rounded-2xl p-5 flex flex-col gap-3 pointer-events-auto border border-white/20 shadow-2xl"
                    >
                        <button
                            onClick={() => scrollTo('lo-tienes')}
                            className="text-sm font-semibold text-zinc-200 hover:text-white py-1 text-left"
                        >
                            Lo Tienes
                        </button>
                        <button
                            onClick={() => scrollTo('traduccion')}
                            className="text-sm font-semibold text-zinc-200 hover:text-white py-1 text-left"
                        >
                            Traducción
                        </button>
                        <button
                            onClick={() => scrollTo('marketplace')}
                            className="text-sm font-semibold text-zinc-200 hover:text-white py-1 text-left"
                        >
                            Marketplace
                        </button>
                        <button
                            onClick={() => scrollTo('seguridad')}
                            className="text-sm font-semibold text-zinc-200 hover:text-white py-1 text-left"
                        >
                            Seguridad
                        </button>

                        <div className="pt-2 border-t border-white/10 flex flex-col gap-2.5">
                            {user ? (
                                <>
                                    <div className="flex items-center gap-3 p-2 bg-white/5 rounded-xl border border-white/5">
                                        <div className="w-8 h-8 rounded-full border border-white/20 overflow-hidden bg-zinc-900 flex items-center justify-center shrink-0">
                                            {profilePhoto ? (
                                                <img src={profilePhoto} alt="Perfil" className="w-full h-full object-cover" />
                                            ) : (
                                                <UserIcon size={14} className="text-zinc-400" />
                                            )}
                                        </div>
                                        <div className="min-w-0 flex-1">
                                            <p className="text-xs font-bold text-white truncate">
                                                {user.displayName || 'Usuario CONNECT'}
                                            </p>
                                            <p className="text-[10px] text-zinc-400 truncate font-mono">
                                                {user.email}
                                            </p>
                                        </div>
                                    </div>

                                    {isAdmin && (
                                        <Link
                                            to="/admin"
                                            onClick={() => setIsOpen(false)}
                                            className="text-xs font-semibold text-[#0094FF] hover:text-white py-1.5 flex items-center gap-2"
                                        >
                                            <Shield size={14} />
                                            <span>Panel de Administrador</span>
                                        </Link>
                                    )}

                                    <Link
                                        to="/settings"
                                        onClick={() => setIsOpen(false)}
                                        className="text-xs font-semibold text-zinc-200 hover:text-white py-1.5 flex items-center gap-2"
                                    >
                                        <SettingsIcon size={14} className="text-zinc-400" />
                                        <span>Ajustes de Perfil</span>
                                    </Link>

                                    <button
                                        onClick={handleSignOut}
                                        className="text-xs font-semibold text-red-400 hover:text-red-300 py-1.5 flex items-center gap-2 cursor-pointer text-left"
                                    >
                                        <LogOut size={14} />
                                        <span>Cerrar Sesión</span>
                                    </button>
                                </>
                            ) : (
                                <Link
                                    to="/login"
                                    onClick={() => setIsOpen(false)}
                                    className="text-sm font-semibold text-zinc-200 hover:text-white py-1 text-left"
                                >
                                    Iniciar Sesión
                                </Link>
                            )}

                            {/* Clean Matte Mobile Action Button */}
                            <button
                                onClick={() => scrollTo('descargar')}
                                className="w-full bg-white hover:bg-zinc-200 text-zinc-950 text-center text-xs font-bold py-2.5 rounded-full inline-flex items-center justify-center gap-2 transition-colors shadow-sm cursor-pointer"
                            >
                                <Download size={14} />
                                <span>Descargar App Gratis</span>
                            </button>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </header>
    );
};

