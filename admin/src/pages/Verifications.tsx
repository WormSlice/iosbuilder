import React, { useEffect, useState, useMemo, MouseEvent } from 'react';
import { collection, query, where, limit, onSnapshot, doc, updateDoc, getDocs, addDoc } from 'firebase/firestore';
import * as Firestore from 'firebase/firestore'; // Fallback for types if needed
import { db } from '../services/firebase';
import {
    ShieldCheck,
    CheckCircle,
    X,
    Trash2,
    Plus,
    Check,
    Shield,
    Search,
    AlertCircle,
    Info
} from 'lucide-react';

interface UserData {
    id: string; // Add id
    uid: string;
    email: string;
    displayName?: string;
    isVerified?: boolean;
}

interface VerificationRequest {
    id: string;
    uid: string;
    firstName: string;
    lastName: string;
    dob: string;
    frontIdUrl: string;
    backIdUrl: string;
    faceFrontUrl?: string;
    faceLeftUrl?: string;
    faceRightUrl?: string;
    idNumber?: string;
    status: string;
    email: string;
}

export const Verifications: React.FC = () => {
    const [users, setUsers] = useState<UserData[]>([]);
    const [requests, setRequests] = useState<VerificationRequest[]>([]);
    const [manualEmail, setManualEmail] = useState('');
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [viewImage, setViewImage] = useState<string | null>(null);

    // Modal de Confirmación Personalizado
    const [confirmModal, setConfirmModal] = useState<{
        isOpen: boolean;
        title: string;
        message: string;
        onConfirm: () => void;
        type: 'danger' | 'success' | 'info';
    }>({
        isOpen: false,
        title: '',
        message: '',
        onConfirm: () => { },
        type: 'info'
    });

    useEffect(() => {
        // Show already verified users
        const qUsers = query(
            collection(db, 'users'),
            where('isVerified', '==', true),
            limit(20)
        );
        const unsubUsers = onSnapshot(qUsers, (s: any) => {
            setUsers(s.docs.map((d: any) => ({ id: d.id, ...d.data() } as UserData)));
            setLoading(false);
        });

        // Listen for new verification requests
        const qReqs = query(
            collection(db, 'verifications'),
            where('status', '==', 'pending')
        );
        const unsubRequests = onSnapshot(qReqs, (s: any) => {
            setRequests(s.docs.map((d: any) => ({ id: d.id, ...d.data() } as VerificationRequest)));
        });

        return () => {
            unsubUsers();
            unsubRequests();
        };
    }, []);

    const filteredUsers = useMemo(() => {
        return users.filter(u =>
            u.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            u.displayName?.toLowerCase().includes(searchTerm.toLowerCase())
        );
    }, [users, searchTerm]);

    const revokeVerification = async (e: MouseEvent, user: UserData) => {
        e.stopPropagation();
        setConfirmModal({
            isOpen: true,
            title: 'Revocar Verificación',
            message: `¿Estás seguro de que deseas quitarle la insignia de verificado a ${user.displayName || user.email}? Esta acción es inmediata.`,
            type: 'danger',
            onConfirm: async () => {
                try {
                    await updateDoc(doc(db, 'users', user.id), { isVerified: false });
                    await updateDoc(doc(db, 'verifications', user.id), { status: 'revoked' }).catch(() => { });
                    setConfirmModal(prev => ({ ...prev, isOpen: false }));
                } catch (error) {
                    console.error('Error revoking verification:', error);
                    alert('Error al revocar verificación.');
                }
            }
        });
    };

    const approveRequest = async (req: VerificationRequest) => {
        setConfirmModal({
            isOpen: true,
            title: 'Aprobar Solicitud',
            message: `Vas a aprobar la identidad de ${req.firstName} ${req.lastName}. El usuario recibirá un correo de confirmación.`,
            type: 'success',
            onConfirm: async () => {
                try {
                    await updateDoc(doc(db, 'verifications', req.id), { status: 'approved' });
                    await updateDoc(doc(db, 'users', req.uid), { isVerified: true });

                    await addDoc(collection(db, 'mail'), {
                        to: req.email,
                        message: {
                            subject: '¡Tu cuenta ha sido verificada! ✅',
                            html: `Hola ${req.firstName},<br><br>Nos complace informarte que tu identidad ha sido verificada exitosamente. Ahora posees la insignia de usuario verificado en tu perfil de CONNECT.<br><br>Saludos,<br>El equipo de CONNECT.`
                        }
                    });
                    setConfirmModal(prev => ({ ...prev, isOpen: false }));
                } catch (error) {
                    console.error('Error approving request', error);
                }
            }
        });
    };

    const rejectRequest = async (req: VerificationRequest) => {
        setConfirmModal({
            isOpen: true,
            title: 'Rechazar Solicitud',
            message: `¿Rechazar la verificación de ${req.firstName}? Se le enviará un correo sugiriendo que intente de nuevo con mejores fotos.`,
            type: 'danger',
            onConfirm: async () => {
                try {
                    await updateDoc(doc(db, 'verifications', req.id), { status: 'rejected' });

                    await addDoc(collection(db, 'mail'), {
                        to: req.email,
                        message: {
                            subject: 'Actualización sobre tu verificación en CONNECT ❌',
                            html: `Hola ${req.firstName},<br><br>Lamentablemente no pudimos verificar tu identidad con los documentos proporcionados. Por favor, asegúrate de que las fotos sean claras y legibles, y que todos tus datos coincidan.<br><br>Puedes volver a enviar tu solicitud desde la sección Perfil -> Verificación en la aplicación móvil.<br><br>Saludos,<br>El equipo de CONNECT.`
                        }
                    });
                    setConfirmModal(prev => ({ ...prev, isOpen: false }));
                } catch (error) {
                    console.error('Error rejecting request', error);
                }
            }
        });
    };

    const verifyManually = async () => {
        if (!manualEmail) return;
        setConfirmModal({
            isOpen: true,
            title: 'Verificación Forzada',
            message: `¿Verificar directamente al correo ${manualEmail}? El usuario no necesita enviar documentos para esto.`,
            type: 'info',
            onConfirm: async () => {
                try {
                    const q = query(collection(db, 'users'), where('email', '==', manualEmail.trim()));
                    const snap = await getDocs(q);
                    if (!snap.empty) {
                        await updateDoc(doc(db, 'users', snap.docs[0].id), { isVerified: true });
                        alert('Usuario verificado con éxito.');
                        setManualEmail('');
                        setConfirmModal(prev => ({ ...prev, isOpen: false }));
                    } else {
                        alert('Usuario no encontrado.');
                    }
                } catch (error) {
                    console.error('Error in manual verification:', error);
                    alert('Error en el proceso.');
                }
            }
        });
    };

    return (
        <div className="space-y-8 animate-in fade-in duration-500 max-w-7xl mx-auto">
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div className="space-y-1">
                    <h1 className="text-4xl font-black tracking-tighter uppercase italic text-zinc-900">Centro de Verificaciones</h1>
                    <p className="text-zinc-500 text-xs font-bold uppercase tracking-[0.3em]">Gestión de Identidad y Confianza CONNECT</p>
                </div>
                <div className="glass-button p-2 rounded-2xl flex gap-2">
                    <div className="glass-panel px-4 py-2 rounded-xl shadow-sm">
                        <p className="text-[10px] font-black uppercase text-zinc-400">Total Verificados</p>
                        <p className="text-xl font-black">{users.length}</p>
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 xl:grid-cols-12 gap-12">
                {/* Panel de Verificación Directa */}
                <div className="xl:col-span-4 space-y-12 xl:border-r border-white/10 xl:pr-8">
                    <div className="space-y-6 relative group">
                        <div className="space-y-2 relative z-10">
                            <h3 className="font-bold text-xl tracking-tighter uppercase flex items-center gap-3 text-zinc-900">
                                <ShieldCheck size={20} className="text-blue-600" />
                                Verificación Directa
                            </h3>
                            <p className="text-zinc-500 text-[10px] font-bold uppercase tracking-widest leading-relaxed pl-8">
                                Otorga la insignia instantáneamente mediante el correo electrónico.
                            </p>
                        </div>
                        <div className="space-y-4 relative z-10 pl-8">
                            <div className="space-y-2">
                                <label className="text-[9px] font-black uppercase text-zinc-500 tracking-[0.2em] ml-2">Email del Usuario</label>
                                <div className="relative">
                                    <Search className="absolute left-6 top-1/2 -translate-y-1/2 text-zinc-500" size={14} />
                                    <input
                                        value={manualEmail}
                                        onChange={e => setManualEmail(e.target.value)}
                                        placeholder="usuario@tuconnect.com"
                                        className="w-full glass-panel border border-white/10 rounded-[1.2rem] pl-14 pr-8 py-4 text-sm focus:glass-panel focus:border-white/30 transition-all outline-none font-medium"
                                    />
                                </div>
                            </div>
                            <button
                                onClick={verifyManually}
                                className="w-full bg-blue-600 hover:bg-blue-500 text-white h-14 rounded-[1.2rem] font-black uppercase tracking-widest text-[10px] active:scale-[0.98] transition-all flex items-center justify-center gap-3"
                            >
                                <CheckCircle size={14} /> Verificar ahora
                            </button>
                        </div>
                    </div>

                    <div className="space-y-6 pt-12 border-t border-white/10">
                        <div className="flex justify-between items-center">
                            <h3 className="font-black text-lg tracking-tight uppercase italic text-zinc-900 flex items-center gap-3">
                                <CheckCircle size={20} className="text-green-600" /> 
                                Usuarios Verificados
                            </h3>
                            <span className="bg-green-100 text-green-700 text-[10px] px-2 py-1 rounded-lg font-bold">{filteredUsers.length}</span>
                        </div>

                        <div className="relative group">
                            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-400" size={14} />
                            <input
                                type="text"
                                placeholder="Buscar por nombre o email..."
                                value={searchTerm}
                                onChange={(e) => setSearchTerm(e.target.value)}
                                className="w-full pl-10 pr-6 py-3 bg-transparent border-b border-white/20 text-sm focus:border-zinc-900 transition-all outline-none text-zinc-900 font-medium"
                            />
                        </div>

                        <div className="space-y-1 max-h-[500px] overflow-y-auto pr-2 custom-scrollbar">
                            {filteredUsers.map(u => (
                                <div key={u.id} className="flex justify-between items-center p-3 rounded-2xl hover:glass-panel transition-all group">
                                    <div className="flex items-center gap-3 overflow-hidden">
                                        <div className="w-10 h-10 glass-panel-dark rounded-xl flex-shrink-0 flex items-center justify-center text-white font-black text-xs uppercase">
                                            {u.displayName?.[0] || u.email?.[0] || '?'}
                                        </div>
                                        <div className="min-w-0 pr-2">
                                            <div className="flex items-center gap-1.5">
                                                <p className="text-xs font-black leading-none truncate text-zinc-800">{u.displayName || 'Usuario'}</p>
                                                <CheckCircle size={10} className="text-blue-500 flex-shrink-0" />
                                            </div>
                                            <p className="text-[9px] text-zinc-400 font-bold uppercase tracking-wider mt-1 truncate">{u.email}</p>
                                        </div>
                                    </div>
                                    <button
                                        onClick={(e) => revokeVerification(e, u)}
                                        className="p-2 rounded-lg text-zinc-300 hover:text-red-500 hover:bg-red-50 transition-all flex-shrink-0"
                                        title="Revocar"
                                    >
                                        <Trash2 size={16} />
                                    </button>
                                </div>
                            ))}
                            {!loading && users.length === 0 && (
                                <div className="py-12 text-center">
                                    <ShieldCheck size={24} className="mx-auto text-zinc-100 mb-2" />
                                    <p className="text-zinc-300 text-[9px] font-black uppercase tracking-widest">Sin registros</p>
                                </div>
                            )}
                        </div>
                    </div>
                </div>

                {/* Panel de Solicitudes Pendientes */}
                <div className="xl:col-span-8 space-y-8">
                    <div className="flex items-center gap-3 border-b border-white/10 pb-4">
                        <h3 className="font-black text-2xl tracking-tighter uppercase italic text-blue-600">
                            Solicitudes Pendientes (KYC)
                        </h3>
                        {requests.length > 0 && (
                            <span className="bg-red-500 text-white text-[10px] font-black px-2.5 py-1 rounded-full animate-pulse">
                                {requests.length} NUEVAS
                            </span>
                        )}
                    </div>

                    {requests.length === 0 ? (
                        <div className="py-32 flex flex-col items-center justify-center space-y-4 opacity-50">
                            <ShieldCheck size={48} strokeWidth={1} className="text-zinc-400" />
                            <p className="text-zinc-400 text-xs font-black uppercase tracking-[0.2em]">Bandeja de entrada limpia</p>
                        </div>
                    ) : (
                        <div className="flex flex-col gap-8">
                            {requests.map(req => (
                                <div key={req.id} className="group transition-all pb-8 border-b border-white/10 last:border-0 relative">
                                    <div className="flex flex-col lg:flex-row lg:justify-between items-start gap-4 mb-6">
                                        <div className="space-y-1">
                                            <h4 className="font-black text-lg tracking-tight text-zinc-900 leading-none">{req.firstName} {req.lastName}</h4>
                                            <p className="text-xs text-blue-500 font-bold">{req.email}</p>
                                            <div className="flex flex-wrap items-center gap-2 mt-2">
                                                <span className="text-[10px] px-2 py-0.5 glass-button rounded-md font-bold text-zinc-500 uppercase tracking-wider">DOB: {req.dob}</span>
                                                {req.idNumber && (
                                                    <span className="text-[10px] px-2 py-0.5 bg-blue-50 rounded-md font-bold text-blue-600 uppercase tracking-wider">C.C. {req.idNumber}</span>
                                                )}
                                            </div>
                                        </div>
                                        <div className="flex gap-2">
                                            <button
                                                onClick={() => approveRequest(req)}
                                                className="text-green-600 hover:bg-green-100 bg-green-50 p-3 rounded-2xl transition-all active:scale-95 flex items-center justify-center"
                                                title="Aprobar"
                                            >
                                                <CheckCircle size={20} />
                                            </button>
                                            <button
                                                onClick={() => rejectRequest(req)}
                                                className="text-red-600 hover:bg-red-100 bg-red-50 p-3 rounded-2xl transition-all active:scale-95 flex items-center justify-center"
                                                title="Rechazar"
                                            >
                                                <X size={20} />
                                            </button>
                                        </div>
                                    </div>

                                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                                        <div className="space-y-3">
                                            <p className="text-[9px] font-black uppercase text-zinc-400 tracking-[0.2em] flex items-center gap-2"><Shield size={12} /> Documentación</p>
                                            <div className="grid grid-cols-2 gap-3">
                                                <div className="relative group cursor-pointer aspect-video bg-white/20 rounded-2xl overflow-hidden border border-white/20" onClick={() => setViewImage(req.frontIdUrl)}>
                                                    <img src={req.frontIdUrl} alt="Front ID" className="w-full h-full object-cover transition-transform group-hover:scale-110" />
                                                    <div className="absolute inset-0 glass-panel-dark opacity-0 group-hover:opacity-100 flex items-center justify-center transition-all">
                                                        <Search className="text-white" size={24} />
                                                    </div>
                                                </div>
                                                <div className="relative group cursor-pointer aspect-video glass-button rounded-2xl overflow-hidden border border-zinc-100" onClick={() => setViewImage(req.backIdUrl)}>
                                                    <img src={req.backIdUrl} alt="Back ID" className="w-full h-full object-cover transition-transform group-hover:scale-110" />
                                                    <div className="absolute inset-0 glass-panel-dark opacity-0 group-hover:opacity-100 flex items-center justify-center transition-all">
                                                        <Search className="text-white" size={24} />
                                                    </div>
                                                </div>
                                            </div>
                                        </div>

                                        {(req.faceFrontUrl || req.faceLeftUrl || req.faceRightUrl) && (
                                            <div className="space-y-3">
                                                <p className="text-[9px] font-black uppercase text-zinc-400 tracking-[0.2em]">Mapeo Facial</p>
                                                <div className="flex gap-3 overflow-x-auto pb-2 custom-scrollbar">
                                                    {req.faceFrontUrl && (
                                                        <div className="relative group cursor-pointer w-20 h-20 flex-shrink-0 bg-blue-50 rounded-2xl overflow-hidden border-2 border-blue-100" onClick={() => setViewImage(req.faceFrontUrl!)}>
                                                            <img src={req.faceFrontUrl} alt="Face Front" className="w-full h-full object-cover transition-transform group-hover:scale-110" />
                                                            <div className="absolute inset-0 bg-blue-900/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-all">
                                                                <Search className="text-white" size={16} />
                                                            </div>
                                                        </div>
                                                    )}
                                                    {req.faceLeftUrl && (
                                                        <div className="relative group cursor-pointer w-20 h-20 flex-shrink-0 bg-blue-50 rounded-2xl overflow-hidden border-2 border-blue-100" onClick={() => setViewImage(req.faceLeftUrl!)}>
                                                            <img src={req.faceLeftUrl} alt="Face Left" className="w-full h-full object-cover transition-transform group-hover:scale-110" />
                                                        </div>
                                                    )}
                                                    {req.faceRightUrl && (
                                                        <div className="relative group cursor-pointer w-20 h-20 flex-shrink-0 bg-blue-50 rounded-2xl overflow-hidden border-2 border-blue-100" onClick={() => setViewImage(req.faceRightUrl!)}>
                                                            <img src={req.faceRightUrl} alt="Face Right" className="w-full h-full object-cover transition-transform group-hover:scale-110" />
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>

            {/* Modal de Confirmación Ultra Premium */}
            {confirmModal.isOpen && (
                <div className="fixed inset-0 z-[120] flex items-center justify-center p-4">
                    <div className="absolute inset-0 bg-zinc-950/60 backdrop-blur-md animate-in fade-in duration-300" onClick={() => setConfirmModal(prev => ({ ...prev, isOpen: false }))} />
                    <div className="relative glass-panel w-full max-w-md rounded-[2.5rem] p-8 shadow-2xl animate-in zoom-in-95 slide-in-from-bottom-10 duration-500 overflow-hidden">
                        {/* Decoración de fondo del modal */}
                        <div className={`absolute top-0 left-0 w-full h-2 ${confirmModal.type === 'danger' ? 'bg-red-500' :
                            confirmModal.type === 'success' ? 'bg-green-500' : 'bg-blue-600'
                            }`} />

                        <div className="flex flex-col items-center text-center space-y-6">
                            <div className={`p-4 rounded-3xl ${confirmModal.type === 'danger' ? 'bg-red-50' :
                                confirmModal.type === 'success' ? 'bg-green-50' : 'bg-blue-50'
                                }`}>
                                {confirmModal.type === 'danger' && <AlertCircle size={32} className="text-red-500" />}
                                {confirmModal.type === 'success' && <CheckCircle size={32} className="text-green-500" />}
                                {confirmModal.type === 'info' && <Info size={32} className="text-blue-600" />}
                            </div>

                            <div className="space-y-2">
                                <h3 className="text-2xl font-black tracking-tight text-zinc-900 leading-tight">
                                    {confirmModal.title}
                                </h3>
                                <p className="text-zinc-500 text-sm font-medium leading-relaxed">
                                    {confirmModal.message}
                                </p>
                            </div>

                            <div className="flex flex-col w-full gap-3 pt-4">
                                <button
                                    onClick={confirmModal.onConfirm}
                                    className={`w-full py-4 rounded-2xl font-black uppercase tracking-widest text-[10px] shadow-lg transition-all active:scale-[0.98] ${confirmModal.type === 'danger' ? 'bg-red-500 hover:bg-red-600 text-white shadow-red-100' :
                                        confirmModal.type === 'success' ? 'bg-green-500 hover:bg-green-600 text-white shadow-green-100' :
                                            'bg-blue-600 hover:bg-blue-700 text-white shadow-blue-100'
                                        }`}
                                >
                                    Confirmar Acción
                                </button>
                                <button
                                    onClick={() => setConfirmModal(prev => ({ ...prev, isOpen: false }))}
                                    className="w-full py-4 rounded-2xl font-black uppercase tracking-widest text-[10px] text-zinc-400 hover:text-zinc-600 hover:glass-button transition-all"
                                >
                                    Cancelar
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
