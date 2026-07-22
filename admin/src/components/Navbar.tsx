import React, { useEffect, useState } from 'react';
import { NavLink, Link } from 'react-router-dom';
import { Menu, X, User as UserIcon } from 'lucide-react';
import { auth, ALLOWED_EMAILS, db } from '../services/firebase';
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';

export const Navbar: React.FC = () => {
    const [isOpen, setIsOpen] = useState(false);
    const [user, setUser] = useState<any>(null);
    const [isAdmin, setIsAdmin] = useState(false);
    const [profilePhoto, setProfilePhoto] = useState<string | null>(null);

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, async (currentUser: any) => {
            setUser(currentUser);
            if (currentUser) {
                try {
                    const userDoc = await getDoc(doc(db, 'users', currentUser.uid));
                    if (userDoc.exists()) {
                        setProfilePhoto(userDoc.data()?.photoURL || null);
                    }
                } catch (error) {
                    console.error("Error fetching user profile:", error);
                }
                setIsAdmin(ALLOWED_EMAILS.includes(currentUser.email || ''));
            } else {
                setIsAdmin(false);
                setProfilePhoto(null);
            }
        });
        return () => unsubscribe();
    }, []);

    return (
        <nav className="glass-nav border-b border-white/[0.04] sticky top-0 z-[60]">
            <div className="container-custom py-4 md:py-6 flex justify-between items-center">
                <Link to="/" className="flex items-center gap-3">
                    <img src="/logo.png" alt="CONNECT" className="h-8 w-8 object-contain brightness-125" />
                    <span className="text-lg font-black tracking-tighter text-white font-archivo">CONNECT</span>
                </Link>

                {/* Desktop Menu */}
                <div className="hidden md:flex items-center gap-10">
                    <NavLink to="/" className={({ isActive }: { isActive: boolean }) => `text-[10px] font-black uppercase tracking-[0.2em] transition-all ${isActive ? 'text-primary' : 'text-zinc-500 hover:text-white'}`}>Inicio</NavLink>
                    <NavLink to="/about" className={({ isActive }: { isActive: boolean }) => `text-[10px] font-black uppercase tracking-[0.2em] transition-all ${isActive ? 'text-primary' : 'text-zinc-500 hover:text-white'}`}>Nosotros</NavLink>
                    <NavLink to="/how-it-works" className={({ isActive }: { isActive: boolean }) => `text-[10px] font-black uppercase tracking-[0.2em] transition-all ${isActive ? 'text-primary' : 'text-zinc-500 hover:text-white'}`}>Tecnología</NavLink>
                    <NavLink to="/faq" className={({ isActive }: { isActive: boolean }) => `text-[10px] font-black uppercase tracking-[0.2em] transition-all ${isActive ? 'text-primary' : 'text-zinc-500 hover:text-white'}`}>FAQ</NavLink>
                    <NavLink to="/support" className={({ isActive }: { isActive: boolean }) => `text-[10px] font-black uppercase tracking-[0.2em] transition-all ${isActive ? 'text-primary' : 'text-zinc-500 hover:text-white'}`}>Soporte</NavLink>
                </div>

                <div className="hidden md:flex items-center gap-3">
                    {user ? (
                        <div className="flex items-center gap-5">
                            {isAdmin && (
                                <Link to="/admin/dashboard" className="text-[9px] font-black uppercase tracking-widest text-primary/80 hover:text-white transition-colors">
                                    Panel
                                </Link>
                            )}
                            <NavLink
                                to="/settings"
                                className={({ isActive }: { isActive: boolean }) => `flex items-center gap-3 group transition-all ${isActive ? 'text-white' : 'text-zinc-500 hover:text-white'}`}
                            >
                                <div className="w-10 h-10 rounded-full border border-white/10 overflow-hidden bg-zinc-900 flex items-center justify-center transition-all group-hover:border-primary/50">
                                    {profilePhoto ? (
                                        <img src={profilePhoto} className="w-full h-full object-cover" />
                                    ) : (
                                        <UserIcon size={16} className="text-zinc-500" />
                                    )}
                                </div>
                                <span className="text-[10px] font-black uppercase tracking-widest transition-colors">Cuenta</span>
                            </NavLink>
                        </div>
                    ) : (
                        <>
                            <Link to="/login" className="text-[10px] font-black uppercase tracking-widest text-zinc-500 hover:text-white px-2 transition-colors">Ingresar</Link>
                            <Link to="/signup" className="premium-button-primary py-2.5 px-8 text-[10px]">
                                Registro
                            </Link>
                        </>
                    )}
                </div>

                {/* Mobile Toggle */}
                <button className="md:hidden text-white/70 p-2" onClick={() => setIsOpen(!isOpen)}>
                    {isOpen ? <X size={20} /> : <Menu size={20} />}
                </button>
            </div>

            {/* Mobile Menu */}
            {isOpen && (
                <div className="md:hidden bg-[#0a0a0a] border-t border-white/[0.04] p-8 flex flex-col gap-8 animate-in slide-in-from-top duration-300">
                    <NavLink to="/" onClick={() => setIsOpen(false)} className="text-sm font-black uppercase tracking-widest">Inicio</NavLink>
                    <NavLink to="/about" onClick={() => setIsOpen(false)} className="text-sm font-black uppercase tracking-widest">Nosotros</NavLink>
                    <NavLink to="/how-it-works" onClick={() => setIsOpen(false)} className="text-sm font-black uppercase tracking-widest">Tecnología</NavLink>
                    <NavLink to="/faq" onClick={() => setIsOpen(false)} className="text-sm font-black uppercase tracking-widest">FAQ</NavLink>
                    <NavLink to="/support" onClick={() => setIsOpen(false)} className="text-sm font-black uppercase tracking-widest">Soporte</NavLink>
                    <hr className="border-white/[0.04]" />
                    {user ? (
                        <div className="flex items-center gap-6">
                            <NavLink
                                to="/settings"
                                onClick={() => setIsOpen(false)}
                                className={({ isActive }: { isActive: boolean }) => `flex items-center gap-3 group transition-all ${isActive ? 'text-white' : 'text-white/40 hover:text-white'}`}
                            >
                                <div className="text-right hidden sm:block">
                                    <p className="text-[9px] font-black uppercase tracking-widest">{user?.displayName || 'Usuario'}</p>
                                    <p className="text-[7px] font-black uppercase tracking-[0.2em] text-[#0094FF]">Cuenta</p>
                                </div>
                                <div className="w-9 h-9 rounded-xl bg-white/[0.03] border border-white/[0.08] flex items-center justify-center overflow-hidden group-hover:border-[#0094FF]/50 transition-all">
                                    {profilePhoto ? (
                                        <img src={profilePhoto} alt="Profile" className="w-full h-full object-cover" />
                                    ) : (
                                        <UserIcon size={16} className="text-white/20" />
                                    )}
                                </div>
                            </NavLink>
                        </div>
                    ) : (
                        <div className="flex flex-col gap-4">
                            <Link to="/login" onClick={() => setIsOpen(false)} className="text-sm font-black uppercase tracking-widest text-center py-3">Ingresar</Link>
                            <Link to="/signup" onClick={() => setIsOpen(false)} className="premium-button-primary py-4">Registro</Link>
                        </div>
                    )}
                </div>
            )}
        </nav>
    );
};
