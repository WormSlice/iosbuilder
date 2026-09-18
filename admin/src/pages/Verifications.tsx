import React, { useEffect, useState, useMemo } from 'react';
import { collection, query, where, limit, onSnapshot, doc, updateDoc, getDocs } from 'firebase/firestore';
import { db } from '../services/firebase';
import {
    ShieldCheck,
    CheckCircle,
    X,
    UserCheck,
    Search,
    AlertCircle,
    Eye,
    Plus,
    Clock,
    FileCheck
} from 'lucide-react';
import toast from 'react-hot-toast';

interface VerificationRequest {
    id: string;
    uid?: string;
    firstName?: string;
    lastName?: string;
    dob?: string;
    frontIdUrl?: string;
    backIdUrl?: string;
    faceFrontUrl?: string;
    idNumber?: string;
    status?: string;
    email?: string;
    createdAt?: any;
}

interface VerifiedUser {
    id: string;
    uid: string;
    email?: string;
    displayName?: string;
    isVerified?: boolean;
    photoURL?: string;
}

export const Verifications: React.FC = () => {
    const [activeTab, setActiveTab] = useState<'pending' | 'verified'>('pending');
    const [requests, setRequests] = useState<VerificationRequest[]>([]);
    const [verifiedUsers, setVerifiedUsers] = useState<VerifiedUser[]>([]);
    const [loading, setLoading] = useState(true);
    const [manualEmail, setManualEmail] = useState('');
    const [isSubmittingManual, setIsSubmittingManual] = useState(false);
    const [viewImage, setViewImage] = useState<string | null>(null);
    const [searchTerm, setSearchTerm] = useState('');

    useEffect(() => {
        // Escuchar solicitudes pendientes reales
        const qReqs = query(
            collection(db, 'verifications'),
            where('status', '==', 'pending')
        );
        const unsubRequests = onSnapshot(qReqs, (snap) => {
            const list = snap.docs.map(d => ({ id: d.id, ...d.data() })) as VerificationRequest[];
            setRequests(list);
            setLoading(false);
        }, (err) => {
            console.error('Error al escuchar verificaciones:', err);
            setLoading(false);
        });

        // Escuchar usuarios verificados reales
        const qUsers = query(
            collection(db, 'users'),
            where('isVerified', '==', true),
            limit(100)
        );
        const unsubUsers = onSnapshot(qUsers, (snap) => {
            const list = snap.docs.map(d => ({ id: d.id, ...d.data() })) as VerifiedUser[];
            setVerifiedUsers(list);
        });

        return () => {
            unsubRequests();
            unsubUsers();
        };
    }, []);

    const handleApprove = async (req: VerificationRequest) => {
        if (!window.confirm(`¿Aprobar la verificación de ${req.firstName || req.email || 'este usuario'}?`)) return;
        try {
            await updateDoc(doc(db, 'verifications', req.id), { status: 'approved' });
            if (req.uid) {
                await updateDoc(doc(db, 'users', req.uid), { isVerified: true });
            }
            toast.success('Verificación aprobada correctamente');
        } catch (e: any) {
            toast.error(`Error al aprobar: ${e.message}`);
        }
    };

    const handleReject = async (req: VerificationRequest) => {
        const reason = window.prompt('Motivo del rechazo (opcional):');
        if (reason === null) return;
        try {
            await updateDoc(doc(db, 'verifications', req.id), {
                status: 'rejected',
                rejectReason: reason || 'Documento no legible o no coincide con los datos.'
            });
            if (req.uid) {
                await updateDoc(doc(db, 'users', req.uid), { isVerified: false });
            }
            toast.success('Solicitud rechazada');
        } catch (e: any) {
            toast.error(`Error al rechazar: ${e.message}`);
        }
    };

    const handleRevoke = async (user: VerifiedUser) => {
        if (!window.confirm(`¿Retirar verificación oficial a ${user.displayName || user.email}?`)) return;
        try {
            await updateDoc(doc(db, 'users', user.id), { isVerified: false });
            toast.success('Insignia de verificación retirada');
        } catch (e: any) {
            toast.error(`Error: ${e.message}`);
        }
    };

    const handleManualVerify = async (e: React.FormEvent) => {
        e.preventDefault();
        const email = manualEmail.trim().toLowerCase();
        if (!email) return;

        setIsSubmittingManual(true);
        try {
            const usersRef = collection(db, 'users');
            const q = query(usersRef, where('email', '==', email));
            const snap = await getDocs(q);

            if (snap.empty) {
                toast.error(`No existe ningún usuario con el correo ${email}`);
            } else {
                const targetDoc = snap.docs[0];
                await updateDoc(doc(db, 'users', targetDoc.id), { isVerified: true });
                toast.success(`Usuario ${email} verificado manualmente con éxito`);
                setManualEmail('');
            }
        } catch (err: any) {
            toast.error(`Error en verificación manual: ${err.message}`);
        } finally {
            setIsSubmittingManual(false);
        }
    };

    const filteredUsers = useMemo(() => {
        return verifiedUsers.filter(u =>
            (u.email || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
            (u.displayName || '').toLowerCase().includes(searchTerm.toLowerCase())
        );
    }, [verifiedUsers, searchTerm]);

    return (
        <div className="space-y-5">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-zinc-200">
                <div>
                    <h1 className="text-xl font-bold text-zinc-900 tracking-tight">Verificaciones de Identidad</h1>
                    <p className="text-xs text-zinc-500">Revisión de documentos de identidad oficiales y gestión de insignias de verificación</p>
                </div>

                <div className="flex items-center gap-1.5">
                    <button
                        onClick={() => setActiveTab('pending')}
                        className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors flex items-center gap-1.5 ${
                            activeTab === 'pending'
                                ? 'bg-zinc-900 text-white'
                                : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                        }`}
                    >
                        <span>Pendientes</span>
                        <span className={`px-1.5 py-0.2 rounded-full text-[10px] ${activeTab === 'pending' ? 'bg-[#0094FF] text-white' : 'bg-zinc-200 text-zinc-700'}`}>
                            {requests.length}
                        </span>
                    </button>
                    <button
                        onClick={() => setActiveTab('verified')}
                        className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors flex items-center gap-1.5 ${
                            activeTab === 'verified'
                                ? 'bg-zinc-900 text-white'
                                : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                        }`}
                    >
                        <span>Verificados</span>
                        <span className={`px-1.5 py-0.2 rounded-full text-[10px] ${activeTab === 'verified' ? 'bg-[#0094FF] text-white' : 'bg-zinc-200 text-zinc-700'}`}>
                            {verifiedUsers.length}
                        </span>
                    </button>
                </div>
            </div>

            {/* Verificación Manual Rápida por Correo */}
            <form onSubmit={handleManualVerify} className="bg-white p-3 rounded-xl border border-zinc-200 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                    <ShieldCheck size={16} className="text-[#0094FF] flex-shrink-0" />
                    <div>
                        <span className="text-xs font-bold text-zinc-900">Verificar Usuario Manualmente:</span>
                        <p className="text-[11px] text-zinc-500">Otorga insignia oficial buscando por correo electrónico registrado</p>
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    <input
                        type="email"
                        placeholder="correo@ejemplo.com"
                        value={manualEmail}
                        onChange={(e) => setManualEmail(e.target.value)}
                        className="input-clean w-60"
                        required
                    />
                    <button
                        type="submit"
                        disabled={isSubmittingManual || !manualEmail.trim()}
                        className="btn-primary flex-shrink-0"
                    >
                        <Plus size={13} />
                        <span>{isSubmittingManual ? 'Verificando...' : 'Verificar'}</span>
                    </button>
                </div>
            </form>

            {/* TAB: SOLICITUDES PENDIENTES */}
            {activeTab === 'pending' && (
                <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden">
                    <div className="overflow-x-auto">
                        <table className="table-clean">
                            <thead>
                                <tr>
                                    <th>Solicitante</th>
                                    <th>Identificación</th>
                                    <th>Fecha de Nacimiento</th>
                                    <th>Documentos (Fotos)</th>
                                    <th className="text-right">Decisión</th>
                                </tr>
                            </thead>
                            <tbody>
                                {loading ? (
                                    <tr>
                                        <td colSpan={5} className="text-center py-8 text-zinc-400">
                                            Cargando solicitudes pendientes...
                                        </td>
                                    </tr>
                                ) : requests.length === 0 ? (
                                    <tr>
                                        <td colSpan={5} className="text-center py-8 text-zinc-400">
                                            No hay solicitudes de verificación pendientes en este momento.
                                        </td>
                                    </tr>
                                ) : (
                                    requests.map((req) => (
                                        <tr key={req.id}>
                                            <td>
                                                <div>
                                                    <p className="font-semibold text-zinc-900">
                                                        {req.firstName ? `${req.firstName} ${req.lastName || ''}` : req.email || 'Sin nombre'}
                                                    </p>
                                                    <p className="text-[11px] text-zinc-500">{req.email || req.uid}</p>
                                                </div>
                                            </td>
                                            <td>
                                                <span className="font-mono text-xs text-zinc-700">
                                                    {req.idNumber || 'No especificado'}
                                                </span>
                                            </td>
                                            <td>
                                                <span className="text-xs text-zinc-600">
                                                    {req.dob || 'No registrada'}
                                                </span>
                                            </td>
                                            <td>
                                                <div className="flex items-center gap-1.5">
                                                    {req.frontIdUrl && (
                                                        <button
                                                            onClick={() => setViewImage(req.frontIdUrl!)}
                                                            className="btn-outline px-2 py-1 text-[10px]"
                                                        >
                                                            <Eye size={11} /> Frente
                                                        </button>
                                                    )}
                                                    {req.backIdUrl && (
                                                        <button
                                                            onClick={() => setViewImage(req.backIdUrl!)}
                                                            className="btn-outline px-2 py-1 text-[10px]"
                                                        >
                                                            <Eye size={11} /> Reverso
                                                        </button>
                                                    )}
                                                    {req.faceFrontUrl && (
                                                        <button
                                                            onClick={() => setViewImage(req.faceFrontUrl!)}
                                                            className="btn-outline px-2 py-1 text-[10px]"
                                                        >
                                                            <Eye size={11} /> Rostro
                                                        </button>
                                                    )}
                                                </div>
                                            </td>
                                            <td className="text-right">
                                                <div className="inline-flex items-center gap-1.5">
                                                    <button
                                                        onClick={() => handleApprove(req)}
                                                        className="btn-primary px-2.5 py-1"
                                                    >
                                                        <CheckCircle size={12} />
                                                        <span>Aprobar</span>
                                                    </button>
                                                    <button
                                                        onClick={() => handleReject(req)}
                                                        className="btn-danger px-2.5 py-1"
                                                    >
                                                        <X size={12} />
                                                        <span>Rechazar</span>
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    ))
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>
            )}

            {/* TAB: USUARIOS YA VERIFICADOS */}
            {activeTab === 'verified' && (
                <div className="space-y-3">
                    <div className="relative max-w-sm">
                        <input
                            type="text"
                            placeholder="Buscar en verificados..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="input-clean pl-8"
                        />
                        <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-400" />
                    </div>

                    <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden">
                        <div className="overflow-x-auto">
                            <table className="table-clean">
                                <thead>
                                    <tr>
                                        <th>Usuario</th>
                                        <th>UID</th>
                                        <th>Estado</th>
                                        <th className="text-right">Acciones</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {filteredUsers.length === 0 ? (
                                        <tr>
                                            <td colSpan={4} className="text-center py-8 text-zinc-400">
                                                No se encontraron usuarios verificados.
                                            </td>
                                        </tr>
                                    ) : (
                                        filteredUsers.map((u) => (
                                            <tr key={u.id}>
                                                <td>
                                                    <div className="flex items-center gap-2.5">
                                                        {u.photoURL ? (
                                                            <img src={u.photoURL} alt="" className="w-8 h-8 rounded-full object-cover border border-zinc-200 flex-shrink-0" />
                                                        ) : (
                                                            <div className="w-8 h-8 rounded-full bg-zinc-100 text-zinc-700 font-bold text-xs flex items-center justify-center border border-zinc-200 flex-shrink-0">
                                                                {(u.displayName || u.email || 'U')[0].toUpperCase()}
                                                            </div>
                                                        )}
                                                        <div>
                                                            <div className="font-semibold text-zinc-900 flex items-center gap-1.5">
                                                                <span>{u.displayName || 'Sin nombre'}</span>
                                                                <span className="text-[#0094FF] text-xs">●</span>
                                                            </div>
                                                            <div className="text-[11px] text-zinc-500">{u.email || 'Sin correo'}</div>
                                                        </div>
                                                    </div>
                                                </td>
                                                <td>
                                                    <span className="font-mono text-[10px] text-zinc-500 bg-zinc-50 px-1.5 py-0.5 rounded border border-zinc-200">
                                                        {u.uid || u.id}
                                                    </span>
                                                </td>
                                                <td>
                                                    <span className="inline-flex items-center gap-1 text-[#0094FF] font-bold text-xs">
                                                        <ShieldCheck size={14} /> Verificado Oficial
                                                    </span>
                                                </td>
                                                <td className="text-right">
                                                    <button
                                                        onClick={() => handleRevoke(u)}
                                                        className="btn-danger px-2 py-1"
                                                    >
                                                        Retirar Verificación
                                                    </button>
                                                </td>
                                            </tr>
                                        ))
                                    )}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            )}

            {/* Modal Visor de Imágenes de Documentos */}
            {viewImage && (
                <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
                    <div className="bg-white rounded-xl max-w-xl w-full p-4 space-y-3">
                        <div className="flex items-center justify-between">
                            <h3 className="text-xs font-bold text-zinc-900 uppercase tracking-wider">Documento de Identidad</h3>
                            <button onClick={() => setViewImage(null)} className="text-zinc-400 hover:text-zinc-700">
                                <X size={16} />
                            </button>
                        </div>
                        <img src={viewImage} alt="Documento" className="w-full max-h-[70vh] object-contain rounded-lg border border-zinc-200 bg-zinc-100" />
                        <div className="flex justify-end">
                            <button onClick={() => setViewImage(null)} className="btn-outline">
                                Cerrar
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
