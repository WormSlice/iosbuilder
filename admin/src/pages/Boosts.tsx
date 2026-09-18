import React, { useState, useEffect } from 'react';
import {
    Zap,
    Plus,
    Search,
    RefreshCw,
    Play,
    Pause,
    Trash2,
    ExternalLink,
    CheckCircle2,
    Clock,
    AlertCircle,
    X,
    Filter
} from 'lucide-react';
import { db } from '../services/firebase';
import {
    collection,
    getDocs,
    doc,
    setDoc,
    updateDoc,
    deleteDoc,
    serverTimestamp,
    query,
    orderBy,
    limit
} from 'firebase/firestore';
import toast from 'react-hot-toast';

interface BoostItem {
    id: string;
    postId: string;
    postTitle?: string;
    sellerId?: string;
    sellerName?: string;
    dailyBudget: number;
    durationDays: number;
    totalBudget: number;
    targetGender: string;
    status: 'active' | 'paused' | 'completed';
    createdAt?: any;
    expiresAt?: any;
}

export const Boosts: React.FC = () => {
    const [boosts, setBoosts] = useState<BoostItem[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'paused' | 'completed'>('all');
    const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);

    // Formulario de nuevo Boost
    const [formPostId, setFormPostId] = useState('');
    const [formPostTitle, setFormPostTitle] = useState('');
    const [formDailyBudget, setFormDailyBudget] = useState(5000);
    const [formDurationDays, setFormDurationDays] = useState(7);
    const [formGender, setFormGender] = useState('Todos');
    const [isSubmitting, setIsSubmitting] = useState(false);

    const fetchBoosts = async () => {
        setLoading(true);
        try {
            const boostSnap = await getDocs(query(collection(db, 'boosts'), limit(50)));
            const items: BoostItem[] = [];
            boostSnap.forEach(d => {
                const data = d.data();
                items.push({
                    id: d.id,
                    postId: data.postId || d.id,
                    postTitle: data.postTitle || data.title || 'Publicación',
                    sellerId: data.sellerId || data.userId || 'N/A',
                    sellerName: data.sellerName || data.userName || 'Usuario',
                    dailyBudget: data.dailyBudget || 5000,
                    durationDays: data.durationDays || 7,
                    totalBudget: data.totalBudget || (data.dailyBudget || 5000) * (data.durationDays || 7),
                    targetGender: data.targetGender || 'Todos',
                    status: data.status || 'active',
                    createdAt: data.createdAt,
                    expiresAt: data.expiresAt
                });
            });
            setBoosts(items);
        } catch (error) {
            console.error('Error fetching boosts:', error);
            toast.error('Error al cargar la lista de impulsos');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchBoosts();
    }, []);

    const handleToggleStatus = async (boost: BoostItem) => {
        const newStatus = boost.status === 'active' ? 'paused' : 'active';
        try {
            await updateDoc(doc(db, 'boosts', boost.id), {
                status: newStatus,
                updatedAt: serverTimestamp()
            });
            setBoosts(prev => prev.map(b => b.id === boost.id ? { ...b, status: newStatus } : b));
            toast.success(`Impulso ${newStatus === 'active' ? 'reactivado' : 'pausado'}`);
        } catch (e) {
            toast.error('Error al actualizar el estado del impulso');
        }
    };

    const handleDelete = async (id: string) => {
        if (!window.confirm('¿Seguro que deseas eliminar este impulso?')) return;
        try {
            await deleteDoc(doc(db, 'boosts', id));
            setBoosts(prev => prev.filter(b => b.id !== id));
            toast.success('Impulso eliminado');
        } catch (e) {
            toast.error('Error al eliminar');
        }
    };

    const handleCreateBoost = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!formPostId.trim()) {
            toast.error('Ingresa el ID de la publicación');
            return;
        }

        setIsSubmitting(true);
        try {
            const boostId = `boost_${Date.now()}`;
            const total = formDailyBudget * formDurationDays;
            const newBoost = {
                postId: formPostId.trim(),
                postTitle: formPostTitle.trim() || `Publicación #${formPostId.substring(0, 6)}`,
                dailyBudget: Number(formDailyBudget),
                durationDays: Number(formDurationDays),
                totalBudget: total,
                targetGender: formGender,
                status: 'active',
                createdAt: serverTimestamp()
            };

            await setDoc(doc(db, 'boosts', boostId), newBoost);
            // Intentar marcar post como boosteado en Firestore si existe
            try {
                await updateDoc(doc(db, 'posts', formPostId.trim()), {
                    is_boosted: true,
                    boost_id: boostId,
                    boost_expires_at: new Date(Date.now() + formDurationDays * 24 * 60 * 60 * 1000)
                });
            } catch (err) {
                // Post puede no existir o tener otra clave
            }

            toast.success('¡Impulso creado y activado!');
            setIsCreateModalOpen(false);
            setFormPostId('');
            setFormPostTitle('');
            fetchBoosts();
        } catch (e: any) {
            toast.error(`Error al crear impulso: ${e.message}`);
        } finally {
            setIsSubmitting(false);
        }
    };

    const filtered = boosts.filter(b => {
        const matchesSearch = b.postTitle?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            b.postId?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            b.sellerName?.toLowerCase().includes(searchTerm.toLowerCase());
        const matchesStatus = statusFilter === 'all' ? true : b.status === statusFilter;
        return matchesSearch && matchesStatus;
    });

    const totalActive = boosts.filter(b => b.status === 'active').length;
    const totalInvestment = boosts.reduce((acc, b) => acc + (b.totalBudget || 0), 0);

    return (
        <div className="space-y-5">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-200 pb-4">
                <div>
                    <h1 className="text-xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
                        <Zap size={20} className="text-[#0094FF]" />
                        Gestión de Impulsos (Boosts)
                    </h1>
                    <p className="text-xs text-slate-500 mt-0.5">
                        Monitoreo y administración de publicaciones promocionadas en el marketplace
                    </p>
                </div>

                <div className="flex items-center gap-2">
                    <button
                        onClick={fetchBoosts}
                        disabled={loading}
                        className="btn-secondary flex items-center gap-1.5"
                        title="Actualizar datos"
                    >
                        <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
                        <span>Actualizar</span>
                    </button>
                    <button
                        onClick={() => setIsCreateModalOpen(true)}
                        className="btn-primary flex items-center gap-1.5"
                    >
                        <Plus size={14} />
                        <span>Nuevo Impulso</span>
                    </button>
                </div>
            </div>

            {/* Metrics bar */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="bg-white border border-slate-200 rounded-lg p-3.5 flex items-center justify-between">
                    <div>
                        <p className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">Total Impulsos</p>
                        <p className="text-xl font-bold text-slate-900 mt-0.5">{boosts.length}</p>
                    </div>
                    <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-slate-600">
                        <Zap size={16} />
                    </div>
                </div>

                <div className="bg-white border border-slate-200 rounded-lg p-3.5 flex items-center justify-between">
                    <div>
                        <p className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">Impulsos Activos</p>
                        <p className="text-xl font-bold text-[#0094FF] mt-0.5">{totalActive}</p>
                    </div>
                    <div className="w-8 h-8 rounded-lg bg-blue-50 flex items-center justify-center text-[#0094FF]">
                        <CheckCircle2 size={16} />
                    </div>
                </div>

                <div className="bg-white border border-slate-200 rounded-lg p-3.5 flex items-center justify-between">
                    <div>
                        <p className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">Presupuesto Acumulado</p>
                        <p className="text-xl font-bold text-slate-900 mt-0.5">
                            ${totalInvestment.toLocaleString('es-CO')} <span className="text-xs font-normal text-slate-500">COP</span>
                        </p>
                    </div>
                    <div className="w-8 h-8 rounded-lg bg-emerald-50 flex items-center justify-center text-emerald-600">
                        <Clock size={16} />
                    </div>
                </div>
            </div>

            {/* Filters Bar */}
            <div className="flex flex-col sm:flex-row items-center justify-between gap-3 bg-white border border-slate-200 rounded-lg p-3">
                <div className="relative w-full sm:w-80">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
                    <input
                        type="text"
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        placeholder="Buscar por ID, título o vendedor..."
                        className="input-clean pl-8 py-1.5 text-xs w-full"
                    />
                </div>

                <div className="flex items-center gap-1.5 self-start sm:self-auto">
                    <span className="text-xs text-slate-500 mr-1 font-medium">Estado:</span>
                    {(['all', 'active', 'paused', 'completed'] as const).map(st => (
                        <button
                            key={st}
                            onClick={() => setStatusFilter(st)}
                            className={`px-2.5 py-1 text-xs font-semibold rounded-md transition-colors ${
                                statusFilter === st
                                    ? 'bg-[#0094FF] text-white'
                                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                            }`}
                        >
                            {st === 'all' ? 'Todos' : st === 'active' ? 'Activos' : st === 'paused' ? 'Pausados' : 'Finalizados'}
                        </button>
                    ))}
                </div>
            </div>

            {/* Table */}
            <div className="bg-white border border-slate-200 rounded-lg overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table-clean">
                        <thead>
                            <tr>
                                <th>Publicación</th>
                                <th>Presupuesto Diario</th>
                                <th>Duración</th>
                                <th>Inversión Total</th>
                                <th>Audiencia</th>
                                <th>Estado</th>
                                <th className="text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-10 text-slate-400 text-xs">
                                        Cargando impulsos desde la base de datos...
                                    </td>
                                </tr>
                            ) : filtered.length === 0 ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-12">
                                        <div className="flex flex-col items-center justify-center text-slate-400">
                                            <Zap size={32} className="text-slate-300 mb-2 stroke-1" />
                                            <p className="text-xs font-semibold text-slate-600">No hay impulsos registrados</p>
                                            <p className="text-[11px] text-slate-400 mt-0.5">
                                                Crea un nuevo impulso para una publicación o espera promociones de los usuarios.
                                            </p>
                                            <button
                                                onClick={() => setIsCreateModalOpen(true)}
                                                className="btn-primary mt-3 text-xs"
                                            >
                                                Crear Primer Impulso
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ) : (
                                filtered.map(boost => (
                                    <tr key={boost.id}>
                                        <td>
                                            <div className="font-semibold text-slate-900 text-xs">{boost.postTitle}</div>
                                            <div className="text-[11px] text-slate-400 font-mono">ID: {boost.postId}</div>
                                        </td>
                                        <td className="font-mono text-xs text-slate-700">
                                            ${boost.dailyBudget.toLocaleString('es-CO')} COP/día
                                        </td>
                                        <td className="text-xs text-slate-700">
                                            {boost.durationDays} días
                                        </td>
                                        <td className="font-mono font-semibold text-xs text-slate-900">
                                            ${boost.totalBudget.toLocaleString('es-CO')} COP
                                        </td>
                                        <td>
                                            <span className="text-xs px-2 py-0.5 bg-slate-100 text-slate-700 rounded-md font-medium">
                                                {boost.targetGender}
                                            </span>
                                        </td>
                                        <td>
                                            <span className={`inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded-full ${
                                                boost.status === 'active'
                                                    ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                                    : boost.status === 'paused'
                                                    ? 'bg-amber-50 text-amber-700 border border-amber-200'
                                                    : 'bg-slate-100 text-slate-600 border border-slate-200'
                                            }`}>
                                                <span className={`w-1.5 h-1.5 rounded-full ${
                                                    boost.status === 'active' ? 'bg-emerald-500' : boost.status === 'paused' ? 'bg-amber-500' : 'bg-slate-400'
                                                }`} />
                                                {boost.status === 'active' ? 'Activo' : boost.status === 'paused' ? 'Pausado' : 'Finalizado'}
                                            </span>
                                        </td>
                                        <td>
                                            <div className="flex items-center justify-end gap-1.5">
                                                <button
                                                    onClick={() => handleToggleStatus(boost)}
                                                    className="btn-outline text-[11px] py-1 px-2 flex items-center gap-1"
                                                    title={boost.status === 'active' ? 'Pausar impulso' : 'Activar impulso'}
                                                >
                                                    {boost.status === 'active' ? (
                                                        <>
                                                            <Pause size={12} />
                                                            <span>Pausar</span>
                                                        </>
                                                    ) : (
                                                        <>
                                                            <Play size={12} />
                                                            <span>Activar</span>
                                                        </>
                                                    )}
                                                </button>
                                                <button
                                                    onClick={() => handleDelete(boost.id)}
                                                    className="btn-danger text-[11px] py-1 px-2 flex items-center gap-1"
                                                    title="Eliminar impulso"
                                                >
                                                    <Trash2 size={12} />
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

            {/* Modal Crear Impulso */}
            {isCreateModalOpen && (
                <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
                    <div className="bg-white border border-slate-200 rounded-xl max-w-md w-full p-5 shadow-xl">
                        <div className="flex items-center justify-between border-b border-slate-200 pb-3 mb-4">
                            <h3 className="font-bold text-slate-900 text-sm flex items-center gap-2">
                                <Zap size={16} className="text-[#0094FF]" />
                                Crear Nuevo Impulso
                            </h3>
                            <button
                                onClick={() => setIsCreateModalOpen(false)}
                                className="text-slate-400 hover:text-slate-600 p-1"
                            >
                                <X size={16} />
                            </button>
                        </div>

                        <form onSubmit={handleCreateBoost} className="space-y-3.5">
                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    ID de Publicación <span className="text-red-500">*</span>
                                </label>
                                <input
                                    type="text"
                                    required
                                    value={formPostId}
                                    onChange={(e) => setFormPostId(e.target.value)}
                                    placeholder="Ej: post_12345678"
                                    className="input-clean w-full text-xs font-mono"
                                />
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    Título de Referencia (Opcional)
                                </label>
                                <input
                                    type="text"
                                    value={formPostTitle}
                                    onChange={(e) => setFormPostTitle(e.target.value)}
                                    placeholder="Ej: iPhone 14 Pro 128GB Azul"
                                    className="input-clean w-full text-xs"
                                />
                            </div>

                            <div className="grid grid-cols-2 gap-3">
                                <div>
                                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                                        Presupuesto Diario (COP)
                                    </label>
                                    <input
                                        type="number"
                                        min={1000}
                                        step={1000}
                                        value={formDailyBudget}
                                        onChange={(e) => setFormDailyBudget(Number(e.target.value))}
                                        className="input-clean w-full text-xs font-mono"
                                    />
                                </div>
                                <div>
                                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                                        Duración (Días)
                                    </label>
                                    <input
                                        type="number"
                                        min={1}
                                        max={90}
                                        value={formDurationDays}
                                        onChange={(e) => setFormDurationDays(Number(e.target.value))}
                                        className="input-clean w-full text-xs font-mono"
                                    />
                                </div>
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-slate-700 mb-1">
                                    Audiencia Objetivo
                                </label>
                                <select
                                    value={formGender}
                                    onChange={(e) => setFormGender(e.target.value)}
                                    className="input-clean w-full text-xs"
                                >
                                    <option value="Todos">Todos</option>
                                    <option value="Hombres">Hombres</option>
                                    <option value="Mujeres">Mujeres</option>
                                </select>
                            </div>

                            <div className="bg-slate-50 border border-slate-200 rounded-lg p-3 text-xs">
                                <div className="flex justify-between text-slate-600 mb-1">
                                    <span>Presupuesto calculado:</span>
                                    <span className="font-mono font-bold text-slate-900">
                                        ${(formDailyBudget * formDurationDays).toLocaleString('es-CO')} COP
                                    </span>
                                </div>
                                <div className="text-[11px] text-slate-400">
                                    Este impulso colocará el post con prioridad en el feed del marketplace.
                                </div>
                            </div>

                            <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-200">
                                <button
                                    type="button"
                                    onClick={() => setIsCreateModalOpen(false)}
                                    className="btn-secondary text-xs"
                                >
                                    Cancelar
                                </button>
                                <button
                                    type="submit"
                                    disabled={isSubmitting}
                                    className="btn-primary text-xs flex items-center gap-1.5"
                                >
                                    <Plus size={14} />
                                    <span>{isSubmitting ? 'Creando...' : 'Activar Impulso'}</span>
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
};
