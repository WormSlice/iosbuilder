import React, { useEffect, useState, useMemo } from 'react';
import { collection, query, where, limit, onSnapshot, doc, updateDoc, getDocs, getDoc } from 'firebase/firestore';
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
    FileCheck,
    FileText,
    ZoomIn,
    ZoomOut,
    RotateCw,
    ExternalLink,
    Camera,
    User,
    Calendar,
    Hash
} from 'lucide-react';
import toast from 'react-hot-toast';

export interface VerificationRequest {
    id: string;
    uid?: string;
    firstName?: string;
    lastName?: string;
    dob?: string;
    frontIdUrl?: string;
    backIdUrl?: string;
    faceFrontUrl?: string;
    faceLeftUrl?: string;
    faceRightUrl?: string;
    idNumber?: string;
    status?: 'pending' | 'approved' | 'rejected';
    rejectReason?: string;
    email?: string;
    createdAt?: any;
    updatedAt?: any;
}

export interface VerifiedUser {
    id: string;
    uid: string;
    email?: string;
    displayName?: string;
    isVerified?: boolean;
    photoURL?: string;
    dob?: string;
}

export const Verifications: React.FC = () => {
    const [activeTab, setActiveTab] = useState<'pending' | 'verified'>('pending');
    const [requests, setRequests] = useState<VerificationRequest[]>([]);
    const [verifiedUsers, setVerifiedUsers] = useState<VerifiedUser[]>([]);
    const [allVerificationsMap, setAllVerificationsMap] = useState<Record<string, VerificationRequest>>({});
    const [loading, setLoading] = useState(true);
    const [manualEmail, setManualEmail] = useState('');
    const [isSubmittingManual, setIsSubmittingManual] = useState(false);
    const [searchTerm, setSearchTerm] = useState('');

    // Modal de Inspección de Expediente Completo
    const [inspectingReq, setInspectingReq] = useState<VerificationRequest | null>(null);
    const [inspectingUser, setInspectingUser] = useState<VerifiedUser | null>(null);
    const [activePhotoKey, setActivePhotoKey] = useState<'front' | 'back' | 'faceFront' | 'faceLeft' | 'faceRight'>('front');
    const [zoomLevel, setZoomLevel] = useState<number>(1);
    const [rotationDeg, setRotationDeg] = useState<number>(0);

    useEffect(() => {
        // 1. Escuchar solicitudes pendientes
        const qReqs = query(
            collection(db, 'verifications'),
            where('status', '==', 'pending')
        );
        const unsubRequests = onSnapshot(qReqs, (snap) => {
            const list = snap.docs.map(d => ({ id: d.id, ...d.data() })) as VerificationRequest[];
            setRequests(list);
            setLoading(false);
        }, (err) => {
            console.error('Error al escuchar verificaciones pendientes:', err);
            setLoading(false);
        });

        // 2. Escuchar todas las verificaciones para cruce de expedientes
        const qAllVerif = query(collection(db, 'verifications'), limit(300));
        const unsubAllVerif = onSnapshot(qAllVerif, (snap) => {
            const map: Record<string, VerificationRequest> = {};
            snap.docs.forEach(d => {
                const data = d.data() as VerificationRequest;
                const reqItem: VerificationRequest = { id: d.id, ...data };
                if (data.uid) map[data.uid] = reqItem;
                map[d.id] = reqItem;
            });
            setAllVerificationsMap(map);
        });

        // 3. Escuchar usuarios verificados oficiales
        const qUsers = query(
            collection(db, 'users'),
            where('isVerified', '==', true),
            limit(150)
        );
        const unsubUsers = onSnapshot(qUsers, (snap) => {
            const list = snap.docs.map(d => ({ id: d.id, ...d.data() })) as VerifiedUser[];
            setVerifiedUsers(list);
        });

        return () => {
            unsubRequests();
            unsubAllVerif();
            unsubUsers();
        };
    }, []);

    // Abrir visor de expediente para una solicitud o usuario
    const handleOpenDossier = (req: VerificationRequest, user?: VerifiedUser) => {
        setInspectingReq(req);
        setInspectingUser(user || null);
        // Seleccionar la primera foto disponible
        if (req.frontIdUrl) setActivePhotoKey('front');
        else if (req.faceFrontUrl) setActivePhotoKey('faceFront');
        else if (req.backIdUrl) setActivePhotoKey('back');
        else if (req.faceLeftUrl) setActivePhotoKey('faceLeft');
        else if (req.faceRightUrl) setActivePhotoKey('faceRight');
        setZoomLevel(1);
        setRotationDeg(0);
    };

    // Abrir expediente de un usuario ya verificado
    const handleOpenVerifiedUserDossier = async (user: VerifiedUser) => {
        const uid = user.uid || user.id;
        let verif = allVerificationsMap[uid];

        if (!verif) {
            // Intento de búsqueda directa por doc id
            try {
                const snap = await getDoc(doc(db, 'verifications', uid));
                if (snap.exists()) {
                    verif = { id: snap.id, ...snap.data() } as VerificationRequest;
                }
            } catch (e) {
                console.error('Error fetching verification doc:', e);
            }
        }

        if (verif) {
            handleOpenDossier(verif, user);
        } else {
            // Usuario verificado manualmente sin solicitud en la colección 'verifications'
            const dummyReq: VerificationRequest = {
                id: uid,
                uid: uid,
                firstName: user.displayName || 'Usuario',
                lastName: '',
                email: user.email,
                status: 'approved',
                dob: user.dob || 'No especificada',
                idNumber: 'Verificación Administrativa Directa'
            };
            handleOpenDossier(dummyReq, user);
        }
    };

    const handleCloseDossier = () => {
        setInspectingReq(null);
        setInspectingUser(null);
        setZoomLevel(1);
        setRotationDeg(0);
    };

    const handleApprove = async (req: VerificationRequest) => {
        if (!window.confirm(`¿Aprobar oficialmente la verificación de ${req.firstName || req.email || 'este usuario'}?`)) return;
        try {
            await updateDoc(doc(db, 'verifications', req.id), {
                status: 'approved',
                updatedAt: new Date()
            });
            if (req.uid) {
                await updateDoc(doc(db, 'users', req.uid), { isVerified: true });
            }
            toast.success('¡Verificación aprobada exitosamente!');
            handleCloseDossier();
        } catch (e: any) {
            toast.error(`Error al aprobar: ${e.message}`);
        }
    };

    const handleReject = async (req: VerificationRequest) => {
        const reason = window.prompt('Ingresa el motivo del rechazo para notificar al usuario:');
        if (reason === null) return;
        try {
            await updateDoc(doc(db, 'verifications', req.id), {
                status: 'rejected',
                rejectReason: reason || 'Documento no legible o no coincide con los datos proporcionados.',
                updatedAt: new Date()
            });
            if (req.uid) {
                await updateDoc(doc(db, 'users', req.uid), { isVerified: false });
            }
            toast.success('Solicitud rechazada');
            handleCloseDossier();
        } catch (e: any) {
            toast.error(`Error al rechazar: ${e.message}`);
        }
    };

    const handleRevoke = async (user: VerifiedUser) => {
        if (!window.confirm(`¿Retirar insignia oficial de verificación a ${user.displayName || user.email}?`)) return;
        try {
            await updateDoc(doc(db, 'users', user.id), { isVerified: false });
            // También marcar como revocado en verifications si existe
            const uid = user.uid || user.id;
            if (allVerificationsMap[uid]) {
                await updateDoc(doc(db, 'verifications', allVerificationsMap[uid].id), {
                    status: 'rejected',
                    rejectReason: 'Insignia revocada administrativamente.',
                    updatedAt: new Date()
                }).catch(() => {});
            }
            toast.success('Insignia de verificación retirada');
            handleCloseDossier();
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
                toast.error(`No existe ningún usuario registrado con el correo ${email}`);
            } else {
                const targetDoc = snap.docs[0];
                await updateDoc(doc(db, 'users', targetDoc.id), { isVerified: true });
                toast.success(`Usuario ${email} verificado manualmente`);
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
            (u.displayName || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
            (u.uid || '').toLowerCase().includes(searchTerm.toLowerCase())
        );
    }, [verifiedUsers, searchTerm]);

    // Obtener la URL de la foto seleccionada en el visor
    const getCurrentPhotoUrl = () => {
        if (!inspectingReq) return null;
        switch (activePhotoKey) {
            case 'front': return inspectingReq.frontIdUrl;
            case 'back': return inspectingReq.backIdUrl;
            case 'faceFront': return inspectingReq.faceFrontUrl;
            case 'faceLeft': return inspectingReq.faceLeftUrl;
            case 'faceRight': return inspectingReq.faceRightUrl;
            default: return null;
        }
    };

    const photoTabs = [
        { key: 'front' as const, label: 'Cédula Frente', url: inspectingReq?.frontIdUrl },
        { key: 'back' as const, label: 'Cédula Reverso', url: inspectingReq?.backIdUrl },
        { key: 'faceFront' as const, label: 'Rostro Frente', url: inspectingReq?.faceFrontUrl },
        { key: 'faceLeft' as const, label: 'Perfil Izquierdo', url: inspectingReq?.faceLeftUrl },
        { key: 'faceRight' as const, label: 'Perfil Derecho', url: inspectingReq?.faceRightUrl },
    ];

    const currentPhotoUrl = getCurrentPhotoUrl();

    return (
        <div className="space-y-5 animate-in fade-in duration-300">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-zinc-200">
                <div>
                    <h1 className="text-xl font-black text-zinc-900 tracking-tight flex items-center gap-2">
                        <ShieldCheck size={22} className="text-[#0094FF]" />
                        Verificaciones de Identidad
                    </h1>
                    <p className="text-xs text-zinc-500 mt-0.5">
                        Inspección minuciosa de documentos de identidad, biometría facial y control oficial de insignias
                    </p>
                </div>

                <div className="flex items-center gap-1.5">
                    <button
                        onClick={() => setActiveTab('pending')}
                        className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-2 ${
                            activeTab === 'pending'
                                ? 'bg-zinc-900 text-white shadow-sm'
                                : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                        }`}
                    >
                        <span>Solicitudes Pendientes</span>
                        <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${activeTab === 'pending' ? 'bg-[#0094FF] text-white' : 'bg-zinc-200 text-zinc-700'}`}>
                            {requests.length}
                        </span>
                    </button>
                    <button
                        onClick={() => setActiveTab('verified')}
                        className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-2 ${
                            activeTab === 'verified'
                                ? 'bg-zinc-900 text-white shadow-sm'
                                : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                        }`}
                    >
                        <span>Usuarios Verificados</span>
                        <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${activeTab === 'verified' ? 'bg-[#0094FF] text-white' : 'bg-zinc-200 text-zinc-700'}`}>
                            {verifiedUsers.length}
                        </span>
                    </button>
                </div>
            </div>

            {/* Verificación Manual Rápida por Correo */}
            <form onSubmit={handleManualVerify} className="bg-white p-3.5 rounded-xl border border-zinc-200 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 shadow-sm">
                <div className="flex items-center gap-2.5">
                    <div className="w-8 h-8 rounded-lg bg-blue-50 text-[#0094FF] flex items-center justify-center flex-shrink-0">
                        <ShieldCheck size={18} />
                    </div>
                    <div>
                        <span className="text-xs font-bold text-zinc-900">Verificación Administrativa Directa:</span>
                        <p className="text-[11px] text-zinc-500">Otorga la insignia oficial buscando por correo registrado</p>
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    <input
                        type="email"
                        placeholder="correo@ejemplo.com"
                        value={manualEmail}
                        onChange={(e) => setManualEmail(e.target.value)}
                        className="input-clean w-64 text-xs"
                        required
                    />
                    <button
                        type="submit"
                        disabled={isSubmittingManual || !manualEmail.trim()}
                        className="btn-primary flex-shrink-0 text-xs py-2"
                    >
                        <Plus size={13} />
                        <span>{isSubmittingManual ? 'Verificando...' : 'Verificar'}</span>
                    </button>
                </div>
            </form>

            {/* TAB: SOLICITUDES PENDIENTES */}
            {activeTab === 'pending' && (
                <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden shadow-sm">
                    <div className="overflow-x-auto">
                        <table className="table-clean">
                            <thead>
                                <tr>
                                    <th>Solicitante</th>
                                    <th>Identificación</th>
                                    <th>Nacimiento</th>
                                    <th>Documentos Adjuntos (5 Fotos)</th>
                                    <th className="text-right">Acciones</th>
                                </tr>
                            </thead>
                            <tbody>
                                {loading ? (
                                    <tr>
                                        <td colSpan={5} className="text-center py-10 text-zinc-400 text-xs">
                                            Cargando solicitudes de verificación pendientes...
                                        </td>
                                    </tr>
                                ) : requests.length === 0 ? (
                                    <tr>
                                        <td colSpan={5} className="text-center py-12">
                                            <div className="flex flex-col items-center justify-center text-zinc-400">
                                                <FileCheck size={36} className="text-zinc-300 mb-2 stroke-1" />
                                                <p className="text-xs font-bold text-zinc-600">No hay solicitudes pendientes</p>
                                                <p className="text-[11px] text-zinc-400 mt-0.5">Todas las verificaciones de identidad han sido procesadas.</p>
                                            </div>
                                        </td>
                                    </tr>
                                ) : (
                                    requests.map((req) => {
                                        const totalPhotos = [req.frontIdUrl, req.backIdUrl, req.faceFrontUrl, req.faceLeftUrl, req.faceRightUrl].filter(Boolean).length;
                                        return (
                                            <tr key={req.id} className="hover:bg-zinc-50/80 transition-colors">
                                                <td>
                                                    <div className="flex items-center gap-2.5">
                                                        <div className="w-8 h-8 rounded-full bg-zinc-100 text-zinc-700 font-bold text-xs flex items-center justify-center border border-zinc-200 flex-shrink-0">
                                                            {(req.firstName || req.email || 'U')[0].toUpperCase()}
                                                        </div>
                                                        <div>
                                                            <p className="font-bold text-zinc-900 text-xs">
                                                                {req.firstName ? `${req.firstName} ${req.lastName || ''}` : req.email || 'Sin nombre'}
                                                            </p>
                                                            <p className="text-[11px] text-zinc-500 font-mono">{req.email || req.uid}</p>
                                                        </div>
                                                    </div>
                                                </td>
                                                <td>
                                                    <span className="font-mono text-xs font-semibold text-zinc-800 bg-zinc-100 px-2 py-0.5 rounded border border-zinc-200">
                                                        {req.idNumber || 'No especificado'}
                                                    </span>
                                                </td>
                                                <td>
                                                    <span className="text-xs text-zinc-600">
                                                        {req.dob || 'No registrada'}
                                                    </span>
                                                </td>
                                                <td>
                                                    <div className="flex items-center gap-2">
                                                        {/* Miniaturas */}
                                                        <div className="flex items-center -space-x-2">
                                                            {req.frontIdUrl && (
                                                                <img src={req.frontIdUrl} alt="Frente" className="w-7 h-7 rounded-md object-cover border-2 border-white shadow-sm" />
                                                            )}
                                                            {req.backIdUrl && (
                                                                <img src={req.backIdUrl} alt="Reverso" className="w-7 h-7 rounded-md object-cover border-2 border-white shadow-sm" />
                                                            )}
                                                            {req.faceFrontUrl && (
                                                                <img src={req.faceFrontUrl} alt="Rostro" className="w-7 h-7 rounded-md object-cover border-2 border-white shadow-sm" />
                                                            )}
                                                        </div>
                                                        <span className="text-[11px] font-semibold text-zinc-500">
                                                            {totalPhotos} de 5 fotos
                                                        </span>
                                                        <button
                                                            onClick={() => handleOpenDossier(req)}
                                                            className="btn-outline py-1 px-2 text-[11px] flex items-center gap-1 font-bold text-[#0094FF] border-blue-200 bg-blue-50/50 hover:bg-blue-100/50"
                                                        >
                                                            <Eye size={12} />
                                                            <span>Inspeccionar</span>
                                                        </button>
                                                    </div>
                                                </td>
                                                <td className="text-right">
                                                    <div className="inline-flex items-center gap-1.5">
                                                        <button
                                                            onClick={() => handleApprove(req)}
                                                            className="btn-primary py-1 px-2.5 text-xs font-bold flex items-center gap-1"
                                                        >
                                                            <CheckCircle size={13} />
                                                            <span>Aprobar</span>
                                                        </button>
                                                        <button
                                                            onClick={() => handleReject(req)}
                                                            className="btn-danger py-1 px-2 text-xs font-bold flex items-center gap-1"
                                                        >
                                                            <X size={13} />
                                                            <span>Rechazar</span>
                                                        </button>
                                                    </div>
                                                </td>
                                            </tr>
                                        );
                                    })
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>
            )}

            {/* TAB: USUARIOS YA VERIFICADOS (CON ACCESO COMPLETO AL EXPEDIENTE) */}
            {activeTab === 'verified' && (
                <div className="space-y-3">
                    <div className="relative max-w-sm">
                        <input
                            type="text"
                            placeholder="Buscar por nombre, correo o UID..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="input-clean pl-8 py-2 text-xs w-full"
                        />
                        <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-400" />
                    </div>

                    <div className="bg-white border border-zinc-200 rounded-xl overflow-hidden shadow-sm">
                        <div className="overflow-x-auto">
                            <table className="table-clean">
                                <thead>
                                    <tr>
                                        <th>Usuario Verificado</th>
                                        <th>UID</th>
                                        <th>Estado Oficial</th>
                                        <th>Expediente de Identidad</th>
                                        <th className="text-right">Acciones</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {filteredUsers.length === 0 ? (
                                        <tr>
                                            <td colSpan={5} className="text-center py-10 text-zinc-400 text-xs">
                                                No se encontraron usuarios verificados con ese criterio.
                                            </td>
                                        </tr>
                                    ) : (
                                        filteredUsers.map((u) => {
                                            const hasDoc = Boolean(allVerificationsMap[u.uid || u.id]);
                                            return (
                                                <tr key={u.id} className="hover:bg-zinc-50/80 transition-colors">
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
                                                                <div className="font-bold text-zinc-900 text-xs flex items-center gap-1.5">
                                                                    <span>{u.displayName || 'Sin nombre'}</span>
                                                                    <ShieldCheck size={13} className="text-[#0094FF]" />
                                                                </div>
                                                                <div className="text-[11px] text-zinc-500">{u.email || 'Sin correo'}</div>
                                                            </div>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        <span className="font-mono text-[10px] text-zinc-600 bg-zinc-50 px-1.5 py-0.5 rounded border border-zinc-200">
                                                            {u.uid || u.id}
                                                        </span>
                                                    </td>
                                                    <td>
                                                        <span className="inline-flex items-center gap-1 text-[#0094FF] font-bold text-xs bg-blue-50 px-2 py-0.5 rounded-full border border-blue-200">
                                                            <ShieldCheck size={13} /> Insignia Activa
                                                        </span>
                                                    </td>
                                                    <td>
                                                        {/* BOTÓN PARA REVISAR EXPEDIENTE AÚN DESPUÉS DE HABER SIDO VERIFICADO */}
                                                        <button
                                                            onClick={() => handleOpenVerifiedUserDossier(u)}
                                                            className="btn-outline py-1 px-2.5 text-xs font-bold flex items-center gap-1.5 text-zinc-700 hover:text-zinc-900"
                                                            title="Consultar documentos oficiales y fotos enviadas por el usuario"
                                                        >
                                                            <FileText size={13} className="text-[#0094FF]" />
                                                            <span>Ver Expediente y Fotos</span>
                                                            {hasDoc && (
                                                                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" title="Documentos disponibles" />
                                                            )}
                                                        </button>
                                                    </td>
                                                    <td className="text-right">
                                                        <button
                                                            onClick={() => handleRevoke(u)}
                                                            className="btn-danger py-1 px-2.5 text-xs font-semibold"
                                                            title="Retirar insignia de verificación oficial"
                                                        >
                                                            Retirar Verificación
                                                        </button>
                                                    </td>
                                                </tr>
                                            );
                                        })
                                    )}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            )}

            {/* MODAL DE INSPECCIÓN DE EXPEDIENTE COMPLETO EN ALTA RESOLUCIÓN */}
            {inspectingReq && (
                <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-3 sm:p-6 animate-in fade-in">
                    <div className="bg-white rounded-2xl max-w-5xl w-full max-h-[92vh] flex flex-col shadow-2xl overflow-hidden border border-zinc-200">
                        {/* Cabecera del Expediente */}
                        <div className="p-4 sm:p-5 border-b border-zinc-200 bg-zinc-50 flex items-center justify-between flex-shrink-0">
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 rounded-xl bg-blue-100 text-[#0094FF] flex items-center justify-center font-bold">
                                    <FileCheck size={22} />
                                </div>
                                <div>
                                    <div className="flex items-center gap-2">
                                        <h2 className="text-base font-black text-zinc-900">
                                            Expediente de Identidad: {inspectingReq.firstName ? `${inspectingReq.firstName} ${inspectingReq.lastName || ''}` : inspectingReq.email}
                                        </h2>
                                        <span className={`text-[10px] font-black uppercase px-2 py-0.5 rounded-full ${
                                            inspectingReq.status === 'approved'
                                                ? 'bg-emerald-100 text-emerald-800'
                                                : inspectingReq.status === 'rejected'
                                                ? 'bg-red-100 text-red-800'
                                                : 'bg-amber-100 text-amber-800'
                                        }`}>
                                            {inspectingReq.status === 'approved' ? 'Verificado Oficial' : inspectingReq.status === 'rejected' ? 'Rechazado' : 'Pendiente de Revisión'}
                                        </span>
                                    </div>
                                    <p className="text-xs text-zinc-500 font-mono mt-0.5">
                                        UID: {inspectingReq.uid || inspectingReq.id} • Correo: {inspectingReq.email || 'N/A'}
                                    </p>
                                </div>
                            </div>

                            <button
                                onClick={handleCloseDossier}
                                className="text-zinc-400 hover:text-zinc-700 p-2 rounded-lg hover:bg-zinc-200 transition-colors"
                            >
                                <X size={20} />
                            </button>
                        </div>

                        {/* Fila de Datos Clave del Solicitante */}
                        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 p-4 bg-white border-b border-zinc-200 text-xs flex-shrink-0">
                            <div className="bg-zinc-50 p-2.5 rounded-lg border border-zinc-200">
                                <span className="text-[10px] uppercase font-bold text-zinc-400 flex items-center gap-1">
                                    <Hash size={11} /> N° Identificación / Cédula
                                </span>
                                <p className="font-mono font-bold text-zinc-900 mt-0.5 text-sm">
                                    {inspectingReq.idNumber || 'No especificado'}
                                </p>
                            </div>
                            <div className="bg-zinc-50 p-2.5 rounded-lg border border-zinc-200">
                                <span className="text-[10px] uppercase font-bold text-zinc-400 flex items-center gap-1">
                                    <Calendar size={11} /> Fecha de Nacimiento
                                </span>
                                <p className="font-bold text-zinc-900 mt-0.5 text-sm">
                                    {inspectingReq.dob || 'No registrada'}
                                </p>
                            </div>
                            <div className="bg-zinc-50 p-2.5 rounded-lg border border-zinc-200">
                                <span className="text-[10px] uppercase font-bold text-zinc-400 flex items-center gap-1">
                                    <User size={11} /> Nombres y Apellidos
                                </span>
                                <p className="font-bold text-zinc-900 mt-0.5 truncate">
                                    {inspectingReq.firstName || inspectingUser?.displayName || 'N/A'} {inspectingReq.lastName || ''}
                                </p>
                            </div>
                            <div className="bg-zinc-50 p-2.5 rounded-lg border border-zinc-200">
                                <span className="text-[10px] uppercase font-bold text-zinc-400 flex items-center gap-1">
                                    <Camera size={11} /> Documentos Adjuntos
                                </span>
                                <p className="font-bold text-[#0094FF] mt-0.5">
                                    {photoTabs.filter(t => Boolean(t.url)).length} fotos cargadas
                                </p>
                            </div>
                        </div>

                        {/* Selector de Pestañas de las 5 Fotografías */}
                        <div className="flex items-center gap-2 p-3 bg-zinc-100/80 border-b border-zinc-200 overflow-x-auto flex-shrink-0">
                            {photoTabs.map((tab) => {
                                const isAvailable = Boolean(tab.url);
                                const isSelected = activePhotoKey === tab.key;
                                return (
                                    <button
                                        key={tab.key}
                                        disabled={!isAvailable}
                                        onClick={() => {
                                            setActivePhotoKey(tab.key);
                                            setZoomLevel(1);
                                            setRotationDeg(0);
                                        }}
                                        className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 flex-shrink-0 ${
                                            isSelected
                                                ? 'bg-[#0094FF] text-white shadow-sm'
                                                : isAvailable
                                                ? 'bg-white text-zinc-700 hover:bg-zinc-200/70 border border-zinc-300'
                                                : 'bg-zinc-200 text-zinc-400 cursor-not-allowed opacity-60'
                                        }`}
                                    >
                                        <Camera size={12} />
                                        <span>{tab.label}</span>
                                        {isAvailable && (
                                            <span className={`w-1.5 h-1.5 rounded-full ${isSelected ? 'bg-white' : 'bg-emerald-500'}`} />
                                        )}
                                    </button>
                                );
                            })}
                        </div>

                        {/* Visor de Imagen con Controles de Zoom, Rotación y Pantalla Completa */}
                        <div className="flex-1 bg-zinc-950 relative overflow-hidden flex items-center justify-center min-h-[350px]">
                            {/* Toolbar flotante de controles sobre la imagen */}
                            {currentPhotoUrl && (
                                <div className="absolute top-3 right-3 z-20 flex items-center gap-1.5 bg-black/60 backdrop-blur-md px-2.5 py-1.5 rounded-xl border border-white/10 text-white text-xs">
                                    <button
                                        onClick={() => setZoomLevel(prev => Math.min(prev + 0.25, 3))}
                                        className="p-1 hover:text-[#0094FF] transition-colors"
                                        title="Acercar (+)"
                                    >
                                        <ZoomIn size={16} />
                                    </button>
                                    <span className="font-mono text-[11px] px-1 font-bold">
                                        {Math.round(zoomLevel * 100)}%
                                    </span>
                                    <button
                                        onClick={() => setZoomLevel(prev => Math.max(prev - 0.25, 0.5))}
                                        className="p-1 hover:text-[#0094FF] transition-colors"
                                        title="Alejar (-)"
                                    >
                                        <ZoomOut size={16} />
                                    </button>
                                    <div className="w-[1px] h-4 bg-white/20 mx-1" />
                                    <button
                                        onClick={() => setRotationDeg(prev => (prev + 90) % 360)}
                                        className="p-1 hover:text-[#0094FF] transition-colors"
                                        title="Rotar 90°"
                                    >
                                        <RotateCw size={16} />
                                    </button>
                                    <button
                                        onClick={() => { setZoomLevel(1); setRotationDeg(0); }}
                                        className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-white/10 hover:bg-white/20"
                                        title="Restablecer vista"
                                    >
                                        Reset
                                    </button>
                                    <div className="w-[1px] h-4 bg-white/20 mx-1" />
                                    <a
                                        href={currentPhotoUrl}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="p-1 hover:text-[#0094FF] transition-colors flex items-center gap-1 text-[11px] font-bold"
                                        title="Abrir imagen completa en pestaña nueva a máxima resolución"
                                    >
                                        <ExternalLink size={15} />
                                        <span className="hidden sm:inline">Original HD</span>
                                    </a>
                                </div>
                            )}

                            {/* Contenedor de la Imagen */}
                            {currentPhotoUrl ? (
                                <div className="w-full h-full flex items-center justify-center p-4 overflow-auto">
                                    <img
                                        src={currentPhotoUrl}
                                        alt="Documento en alta resolución"
                                        style={{
                                            transform: `scale(${zoomLevel}) rotate(${rotationDeg}deg)`,
                                            transition: 'transform 0.2s ease-out'
                                        }}
                                        className="max-h-[55vh] max-w-full object-contain rounded-lg shadow-2xl select-none"
                                    />
                                </div>
                            ) : (
                                <div className="text-center p-8 text-zinc-400">
                                    <Camera size={36} className="mx-auto mb-2 opacity-50 stroke-1" />
                                    <p className="text-xs font-bold">No hay fotografía adjunta para esta sección</p>
                                    <p className="text-[11px] text-zinc-500 mt-0.5">El usuario no cargó esta imagen o la verificación fue administrativa.</p>
                                </div>
                            )}
                        </div>

                        {/* Pie del Modal con Acciones de Decisión */}
                        <div className="p-4 bg-white border-t border-zinc-200 flex flex-col sm:flex-row items-center justify-between gap-3 flex-shrink-0">
                            <div className="text-xs text-zinc-500">
                                {inspectingReq.status === 'pending' ? (
                                    <span className="text-amber-600 font-semibold flex items-center gap-1">
                                        <Clock size={13} /> Revisa que las facciones y el documento coincidan antes de aprobar.
                                    </span>
                                ) : inspectingReq.status === 'approved' ? (
                                    <span className="text-emerald-600 font-semibold flex items-center gap-1">
                                        <ShieldCheck size={14} /> Expediente verificado y activo en la plataforma.
                                    </span>
                                ) : (
                                    <span className="text-red-600 font-semibold flex items-center gap-1">
                                        <AlertCircle size={14} /> Solicitud rechazada. Motivo: {inspectingReq.rejectReason || 'No especificado'}
                                    </span>
                                )}
                            </div>

                            <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
                                {inspectingReq.status === 'pending' && (
                                    <>
                                        <button
                                            onClick={() => handleApprove(inspectingReq)}
                                            className="btn-primary py-2 px-4 text-xs font-bold flex items-center gap-1.5"
                                        >
                                            <CheckCircle size={14} />
                                            <span>Aprobar Verificación</span>
                                        </button>
                                        <button
                                            onClick={() => handleReject(inspectingReq)}
                                            className="btn-danger py-2 px-4 text-xs font-bold flex items-center gap-1.5"
                                        >
                                            <X size={14} />
                                            <span>Rechazar Solicitud</span>
                                        </button>
                                    </>
                                )}

                                {inspectingReq.status === 'approved' && inspectingUser && (
                                    <button
                                        onClick={() => handleRevoke(inspectingUser)}
                                        className="btn-danger py-2 px-3 text-xs font-bold"
                                    >
                                        Retirar Insignia Oficial
                                    </button>
                                )}

                                <button
                                    onClick={handleCloseDossier}
                                    className="btn-secondary py-2 px-4 text-xs font-bold"
                                >
                                    Cerrar Expediente
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
