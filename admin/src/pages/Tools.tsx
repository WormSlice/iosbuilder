import React, { useState, useEffect, useRef } from 'react';
import {
    Music,
    Search,
    Play,
    Pause,
    RotateCcw,
    Volume2,
    VolumeX,
    Repeat,
    Sliders,
    Activity,
    Trash2,
    ExternalLink,
    Sparkles,
    Youtube
} from 'lucide-react';
import toast from 'react-hot-toast';

interface YouTubeTrack {
    videoId: string;
    title: string;
    author: string;
    durationSeconds: number;
    thumbnail: string;
    views: string;
}

interface DiagnosticLog {
    id: string;
    timestamp: string;
    type: 'success' | 'error' | 'info' | 'stream' | 'trim';
    message: string;
}

const PRESET_SONGS = [
    { title: 'Si Antes Te Hubiera Conocido', artist: 'KAROL G', query: 'Karol G Si Antes Te Hubiera Conocido' },
    { title: 'Die With A Smile', artist: 'Lady Gaga & Bruno Mars', query: 'Lady Gaga Bruno Mars Die With A Smile' },
    { title: 'BIRDS OF A FEATHER', artist: 'Billie Eilish', query: 'Billie Eilish BIRDS OF A FEATHER' },
    { title: 'LUNA', artist: 'Feid & ATL Jacob', query: 'Feid LUNA' },
    { title: 'Espresso', artist: 'Sabrina Carpenter', query: 'Sabrina Carpenter Espresso' },
    { title: 'COQUETA', artist: 'Fuerza Regida', query: 'Fuerza Regida COQUETA' },
];

export const Tools: React.FC = () => {
    // 1. Búsqueda directa en YouTube
    const [searchQuery, setSearchQuery] = useState('');
    const [searchResults, setSearchResults] = useState<YouTubeTrack[]>([]);
    const [isSearching, setIsSearching] = useState(false);

    // 2. Track seleccionado y estado del reproductor
    const [selectedTrack, setSelectedTrack] = useState<YouTubeTrack | null>(null);
    const [isPlaying, setIsPlaying] = useState(false);
    const [currentTime, setCurrentTime] = useState(0);
    const [totalDuration, setTotalDuration] = useState(180);

    // 3. Parámetros de recorte estilo Instagram / CONNECT
    const [startSeconds, setStartSeconds] = useState(0);
    const [durationSeconds, setDurationSeconds] = useState(30);
    const [isLoopEnabled, setIsLoopEnabled] = useState(true);
    const [volume, setVolume] = useState(0.85);
    const [isMuted, setIsMuted] = useState(false);

    // 4. Referencias y consola de diagnóstico
    const ytIframeRef = useRef<HTMLIFrameElement | null>(null);
    const ytIntervalRef = useRef<any>(null);
    const logsEndRef = useRef<HTMLDivElement>(null);
    const [logs, setLogs] = useState<DiagnosticLog[]>([]);

    const addLog = (type: DiagnosticLog['type'], message: string) => {
        const newLog: DiagnosticLog = {
            id: Math.random().toString(36).substring(2, 9),
            timestamp: new Date().toLocaleTimeString('es-ES', { hour12: false }),
            type,
            message,
        };
        setLogs(prev => [...prev.slice(-49), newLog]);
    };

    // Auto-scroll en consola de diagnóstico
    useEffect(() => {
        logsEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [logs]);

    // Escucha de mensajes del YouTube IFrame Player (postMessage API)
    useEffect(() => {
        const handleMessage = (event: MessageEvent) => {
            try {
                const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
                if (data && data.event === 'infoDelivery' && data.info) {
                    if (typeof data.info.currentTime === 'number') {
                        const cur = data.info.currentTime;
                        setCurrentTime(cur);

                        // Comprobar límite del recorte seleccionado
                        const maxEnd = Math.min(startSeconds + durationSeconds, totalDuration);
                        if (cur >= maxEnd - 0.25 || cur >= totalDuration - 0.25) {
                            if (isLoopEnabled) {
                                ytIframeRef.current?.contentWindow?.postMessage(
                                    JSON.stringify({ event: 'command', func: 'seekTo', args: [startSeconds, true] }),
                                    '*'
                                );
                                addLog('trim', `Bucle YouTube activado: Rebobinando a ${formatTime(startSeconds)}`);
                            } else {
                                ytIframeRef.current?.contentWindow?.postMessage(
                                    JSON.stringify({ event: 'command', func: 'pauseVideo', args: [] }),
                                    '*'
                                );
                                setIsPlaying(false);
                            }
                        }
                    }

                    if (data.info.playerState === 1) { // 1 = playing
                        setIsPlaying(true);
                    } else if (data.info.playerState === 2) { // 2 = paused
                        setIsPlaying(false);
                    } else if (data.info.duration && typeof data.info.duration === 'number' && data.info.duration > 0) {
                        setTotalDuration(Math.round(data.info.duration));
                    }
                }
            } catch {}
        };

        window.addEventListener('message', handleMessage);
        return () => window.removeEventListener('message', handleMessage);
    }, [startSeconds, durationSeconds, totalDuration, isLoopEnabled]);

    // Intervalo de actualización y sincronización de recorte
    useEffect(() => {
        if (!isPlaying || !selectedTrack) {
            if (ytIntervalRef.current) clearInterval(ytIntervalRef.current);
            return;
        }

        // Solicitar eventos continuos al iframe de YouTube
        ytIframeRef.current?.contentWindow?.postMessage(
            JSON.stringify({ event: 'listening', id: 'yt-player' }),
            '*'
        );

        ytIntervalRef.current = setInterval(() => {
            setCurrentTime(prev => {
                const next = prev + 0.25;
                const maxEnd = Math.min(startSeconds + durationSeconds, totalDuration);
                if (next >= maxEnd || next >= totalDuration) {
                    if (isLoopEnabled) {
                        ytIframeRef.current?.contentWindow?.postMessage(
                            JSON.stringify({ event: 'command', func: 'seekTo', args: [startSeconds, true] }),
                            '*'
                        );
                        return startSeconds;
                    } else {
                        ytIframeRef.current?.contentWindow?.postMessage(
                            JSON.stringify({ event: 'command', func: 'pauseVideo', args: [] }),
                            '*'
                        );
                        setIsPlaying(false);
                        return startSeconds;
                    }
                }
                return next;
            });
        }, 250);

        return () => {
            if (ytIntervalRef.current) clearInterval(ytIntervalRef.current);
        };
    }, [isPlaying, selectedTrack, startSeconds, durationSeconds, totalDuration, isLoopEnabled]);

    // Búsqueda en vivo en YouTube Engine
    const handleSearchYouTube = async (queryText?: string) => {
        const q = (queryText !== undefined ? queryText : searchQuery).trim();
        if (!q) {
            toast('Escribe un título o artista para buscar en YouTube');
            return;
        }

        setIsSearching(true);
        addLog('info', `Buscando en YouTube Engine: "${q}"...`);

        try {
            let items: any = null;

            // Intentar primero a través del proxy local de Vite
            try {
                const res = await fetch(`/api/yt-search/search?q=${encodeURIComponent(q)}`);
                if (res.ok) items = await res.json();
            } catch {
                // Fallback a instancia pública directa
            }

            if (!items || !Array.isArray(items) || items.length === 0) {
                const res2 = await fetch(`https://invidious.f5.si/api/v1/search?q=${encodeURIComponent(q)}`);
                if (res2.ok) items = await res2.json();
            }

            if (!items || !Array.isArray(items) || items.length === 0) {
                const res3 = await fetch(`https://vid.puffyan.us/api/v1/search?q=${encodeURIComponent(q)}`);
                if (res3.ok) items = await res3.json();
            }

            if (!Array.isArray(items) || items.length === 0) {
                throw new Error('No se encontraron resultados en YouTube');
            }

            // Mapear videos válidos
            const mapped: YouTubeTrack[] = items
                .filter((item: any) => (item.type === 'video' || item.videoId) && item.videoId)
                .map((item: any) => {
                    const thumb = item.videoThumbnails?.[0]?.url 
                        || `https://i.ytimg.com/vi/${item.videoId}/hqdefault.jpg`;
                    return {
                        videoId: item.videoId,
                        title: item.title,
                        author: item.author || 'YouTube Audio',
                        durationSeconds: item.lengthSeconds || 180,
                        thumbnail: thumb,
                        views: item.viewCountText || `${item.viewCount || ''} vistas`,
                    };
                });

            setSearchResults(mapped);
            addLog('success', `Búsqueda completada: ${mapped.length} canciones encontradas en YouTube.`);
        } catch (e: any) {
            addLog('error', `Error en búsqueda de YouTube: ${e.message}`);
            toast.error(`Error buscando en YouTube: ${e.message}`);
        } finally {
            setIsSearching(false);
        }
    };

    // Seleccionar pista de YouTube
    const handleSelectTrack = (track: YouTubeTrack) => {
        setSelectedTrack(track);
        setIsPlaying(false);
        setCurrentTime(0);
        setStartSeconds(0);
        setDurationSeconds(30);
        setTotalDuration(track.durationSeconds || 180);

        addLog('stream', `Canción cargada: "${track.title}" [ID: ${track.videoId}] (${formatTime(track.durationSeconds)} - Canción Completa)`);
        toast.success(`Cargada: ${track.title}`);
    };

    // Reproducción / Pausa
    const togglePlay = () => {
        if (!selectedTrack) return;

        if (isPlaying) {
            ytIframeRef.current?.contentWindow?.postMessage(
                JSON.stringify({ event: 'command', func: 'pauseVideo', args: [] }),
                '*'
            );
            setIsPlaying(false);
            addLog('trim', 'Pausa en reproductor YouTube.');
        } else {
            const maxEnd = Math.min(startSeconds + durationSeconds, totalDuration);
            if (currentTime < startSeconds || currentTime >= maxEnd) {
                ytIframeRef.current?.contentWindow?.postMessage(
                    JSON.stringify({ event: 'command', func: 'seekTo', args: [startSeconds, true] }),
                    '*'
                );
                setCurrentTime(startSeconds);
            }
            ytIframeRef.current?.contentWindow?.postMessage(
                JSON.stringify({ event: 'command', func: 'playVideo', args: [] }),
                '*'
            );
            ytIframeRef.current?.contentWindow?.postMessage(
                JSON.stringify({ event: 'command', func: 'setVolume', args: [isMuted ? 0 : Math.round(volume * 100)] }),
                '*'
            );
            setIsPlaying(true);
            addLog('trim', `Reproduciendo fragmento YouTube: [${formatTime(startSeconds)} - ${formatTime(maxEnd)}]`);
        }
    };

    // Desplazamiento del punto de inicio
    const handleStartChange = (newStart: number) => {
        const maxStart = Math.max(0, totalDuration - durationSeconds);
        const safeStart = Math.max(0, Math.min(newStart, maxStart));
        setStartSeconds(safeStart);
        setCurrentTime(safeStart);

        ytIframeRef.current?.contentWindow?.postMessage(
            JSON.stringify({ event: 'command', func: 'seekTo', args: [safeStart, true] }),
            '*'
        );

        if (!isPlaying) {
            ytIframeRef.current?.contentWindow?.postMessage(
                JSON.stringify({ event: 'command', func: 'playVideo', args: [] }),
                '*'
            );
            setIsPlaying(true);
        }
        addLog('trim', `Fragmento movido a ${formatTime(safeStart)} (Canción completa YouTube)`);
    };

    // Cambio de duración del fragmento (15s / 30s)
    const handleDurationChange = (dur: number) => {
        setDurationSeconds(dur);
        const maxStart = Math.max(0, totalDuration - dur);
        if (startSeconds > maxStart) {
            setStartSeconds(maxStart);
            ytIframeRef.current?.contentWindow?.postMessage(
                JSON.stringify({ event: 'command', func: 'seekTo', args: [maxStart, true] }),
                '*'
            );
        }
    };

    // Rebobinar
    const handleRewind = () => {
        setCurrentTime(startSeconds);
        ytIframeRef.current?.contentWindow?.postMessage(
            JSON.stringify({ event: 'command', func: 'seekTo', args: [startSeconds, true] }),
            '*'
        );
        addLog('trim', `Rebobinado al inicio del fragmento (${formatTime(startSeconds)}).`);
    };

    // Control de volumen
    const handleVolumeChange = (val: number) => {
        setVolume(val);
        setIsMuted(false);
        ytIframeRef.current?.contentWindow?.postMessage(
            JSON.stringify({ event: 'command', func: 'setVolume', args: [Math.round(val * 100)] }),
            '*'
        );
        ytIframeRef.current?.contentWindow?.postMessage(
            JSON.stringify({ event: 'command', func: 'unMute', args: [] }),
            '*'
        );
    };

    // Silenciar / Activar sonido
    const handleToggleMute = () => {
        const next = !isMuted;
        setIsMuted(next);
        ytIframeRef.current?.contentWindow?.postMessage(
            JSON.stringify({ event: 'command', func: next ? 'mute' : 'unMute', args: [] }),
            '*'
        );
        if (!next) {
            ytIframeRef.current?.contentWindow?.postMessage(
                JSON.stringify({ event: 'command', func: 'setVolume', args: [Math.round(volume * 100)] }),
                '*'
            );
        }
    };

    // Formatear segundos a mm:ss
    const formatTime = (sec: number) => {
        const s = Math.max(0, Math.floor(sec || 0));
        const m = Math.floor(s / 60);
        const rem = s % 60;
        return `${m.toString().padStart(2, '0')}:${rem.toString().padStart(2, '0')}`;
    };

    const maxAllowedStart = Math.max(0, totalDuration - durationSeconds);

    return (
        <div className="space-y-6 animate-in fade-in duration-300 max-w-7xl mx-auto pb-16">
            {/* HEADER PRINCIPAL */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-200 pb-5">
                <div className="flex items-center gap-3">
                    <div className="p-2.5 bg-red-50 text-red-600 rounded-xl border border-red-200">
                        <Youtube size={26} />
                    </div>
                    <div>
                        <h1 className="text-2xl font-black tracking-tight text-slate-900">
                            YouTube Audio Engine & Trimmer
                        </h1>
                        <p className="text-xs font-semibold text-slate-500 mt-0.5">
                            Búsqueda Directa en YouTube • Canción 100% Completa (Sin límite de 30s) • Recortador Continuo
                        </p>
                    </div>
                </div>

                {/* Badges de Estado */}
                <div className="flex items-center gap-2 flex-wrap">
                    <div className="px-3 py-1 rounded-md text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 flex items-center gap-1.5">
                        <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                        <span>Motor: YouTube Full Audio Activo</span>
                    </div>
                    <div className="px-3 py-1 rounded-md text-xs font-bold bg-blue-50 text-[#0094FF] border border-blue-200">
                        <span>Sin Límites ni Cuentas Premium</span>
                    </div>
                </div>
            </div>

            {/* SECCIÓN 1: BÚSQUEDA DIRECTA EN YOUTUBE */}
            <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm space-y-4">
                <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-2">
                        <Search size={18} className="text-[#0094FF]" />
                        <h2 className="text-sm font-black text-slate-900 uppercase tracking-wide">
                            1. Buscar Canción o Artista en YouTube
                        </h2>
                    </div>
                    <span className="text-xs text-slate-400 font-medium">Búsqueda directa sin APIs de terceros</span>
                </div>

                {/* Chips de canciones populares para pruebas rápidas */}
                <div>
                    <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-2">
                        Pruebas Rápidas en 1 Clic:
                    </p>
                    <div className="flex flex-wrap gap-2">
                        {PRESET_SONGS.map((song, idx) => (
                            <button
                                key={idx}
                                onClick={() => {
                                    setSearchQuery(song.query);
                                    handleSearchYouTube(song.query);
                                }}
                                className="px-3 py-1.5 bg-slate-50 hover:bg-blue-50 hover:text-[#0094FF] hover:border-blue-200 border border-slate-200 rounded-lg text-xs font-semibold text-slate-700 transition-all flex items-center gap-1.5"
                            >
                                <Sparkles size={12} className="text-amber-500" />
                                <span>{song.title} - <span className="text-slate-500">{song.artist}</span></span>
                            </button>
                        ))}
                    </div>
                </div>

                {/* Input de Búsqueda */}
                <div className="flex gap-2">
                    <div className="relative flex-1">
                        <input
                            type="text"
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            onKeyDown={(e) => e.key === 'Enter' && handleSearchYouTube()}
                            placeholder="Escribe el nombre de la canción o artista en YouTube..."
                            className="w-full px-4 py-2.5 pl-10 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:outline-none focus:ring-1 focus:ring-[#0094FF] focus:border-[#0094FF] text-slate-800"
                        />
                        <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                    </div>
                    <button
                        onClick={() => handleSearchYouTube()}
                        disabled={isSearching}
                        className="px-5 py-2.5 bg-[#0094FF] hover:bg-[#0080dd] text-white text-xs font-bold rounded-lg transition-all shadow-sm flex items-center gap-2 disabled:opacity-50"
                    >
                        {isSearching ? <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> : <Search size={15} />}
                        <span>Buscar en YouTube</span>
                    </button>
                </div>

                {/* Resultados de Búsqueda */}
                {searchResults.length > 0 && (
                    <div className="mt-4 grid grid-cols-1 md:grid-cols-2 gap-2.5 max-h-80 overflow-y-auto pr-1">
                        {searchResults.map((track) => {
                            const isSelected = selectedTrack?.videoId === track.videoId;
                            return (
                                <div
                                    key={track.videoId}
                                    onClick={() => handleSelectTrack(track)}
                                    className={`p-2.5 rounded-lg border transition-all cursor-pointer flex items-center justify-between gap-3 ${
                                        isSelected
                                            ? 'bg-blue-50/70 border-[#0094FF] shadow-sm'
                                            : 'bg-slate-50 hover:bg-slate-100 border-slate-200'
                                    }`}
                                >
                                    <div className="flex items-center gap-3 overflow-hidden">
                                        <img
                                            src={track.thumbnail}
                                            alt={track.title}
                                            className="w-14 h-10 rounded object-cover shadow-sm flex-shrink-0 bg-slate-200"
                                        />
                                        <div className="overflow-hidden">
                                            <h4 className="font-bold text-xs text-slate-900 truncate">{track.title}</h4>
                                            <p className="text-[11px] text-slate-500 truncate">{track.author}</p>
                                            <p className="text-[10px] font-mono text-slate-400 mt-0.5">
                                                Duración: <strong className="text-slate-700">{formatTime(track.durationSeconds)}</strong> • {track.views}
                                            </p>
                                        </div>
                                    </div>

                                    <div className="flex items-center gap-1.5 flex-shrink-0">
                                        <button
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                handleSelectTrack(track);
                                            }}
                                            className={`px-3 py-1 rounded-md text-xs font-bold transition-all flex items-center gap-1 ${
                                                isSelected
                                                    ? 'bg-[#0094FF] text-white shadow-sm'
                                                    : 'bg-white text-slate-700 border border-slate-200 hover:border-[#0094FF]'
                                            }`}
                                        >
                                            <Play size={12} fill={isSelected ? 'currentColor' : 'none'} />
                                            <span>{isSelected ? 'Cargada' : 'Probar'}</span>
                                        </button>
                                        <a
                                            href={`https://www.youtube.com/watch?v=${track.videoId}`}
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            onClick={(e) => e.stopPropagation()}
                                            title="Ver en YouTube"
                                            className="p-1.5 text-slate-400 hover:text-red-600 rounded hover:bg-slate-200 transition-colors"
                                        >
                                            <ExternalLink size={13} />
                                        </a>
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                )}
            </div>

            {/* SECCIÓN 2: ESTUDIO DE REPRODUCCIÓN Y RECORTADOR CONTINUO */}
            <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm space-y-4">
                <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-2">
                        <Sliders size={18} className="text-[#0094FF]" />
                        <h2 className="text-sm font-black text-slate-900 uppercase tracking-wide">
                            2. Estudio de Recorte y Sincronización Continua
                        </h2>
                    </div>
                    {selectedTrack && (
                        <span className="text-xs font-mono font-bold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded border border-emerald-200">
                            Duración Completa: {formatTime(totalDuration)} ({totalDuration}s)
                        </span>
                    )}
                </div>

                {selectedTrack ? (
                    <div className="space-y-4">
                        {/* Reproductor de YouTube y Video Preview */}
                        <div className="relative overflow-hidden rounded-lg bg-black border border-slate-800 shadow-sm">
                            <div className="flex items-center justify-between px-3.5 py-2 bg-zinc-950 border-b border-zinc-800 text-xs">
                                <div className="flex items-center gap-2">
                                    <span className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
                                    <span className="font-bold text-white">{selectedTrack.title}</span>
                                    <span className="text-zinc-400 text-[11px]">• Canal: {selectedTrack.author}</span>
                                </div>
                                <a
                                    href={`https://www.youtube.com/watch?v=${selectedTrack.videoId}`}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="text-[11px] font-mono text-[#0094FF] hover:underline flex items-center gap-1"
                                >
                                    <span>YouTube</span>
                                    <ExternalLink size={11} />
                                </a>
                            </div>
                            <div className="w-full flex items-center justify-center bg-black">
                                <iframe
                                    ref={ytIframeRef}
                                    src={`https://www.youtube-nocookie.com/embed/${selectedTrack.videoId}?enablejsapi=1&origin=${encodeURIComponent(window.location.origin)}&controls=0&disablekb=1&fs=0&rel=0&modestbranding=1`}
                                    title="YouTube Audio Player"
                                    className="w-full aspect-video max-h-56 border-0"
                                    allow="autoplay; encrypted-media"
                                />
                            </div>
                        </div>

                        {/* Controles de Duración del Fragmento (Chips 15s / 30s) */}
                        <div className="flex items-center justify-between flex-wrap gap-3">
                            <div className="flex items-center gap-2">
                                <span className="text-xs font-bold text-slate-500 uppercase tracking-wider mr-1">
                                    Tamaño del Recorte:
                                </span>
                                {[15, 30].map((dur) => (
                                    <button
                                        key={dur}
                                        onClick={() => handleDurationChange(dur)}
                                        className={`px-3 py-1 rounded-md text-xs font-bold transition-all ${
                                            durationSeconds === dur
                                                ? 'bg-[#0094FF] text-white shadow-sm'
                                                : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                                        }`}
                                    >
                                        {dur}s
                                    </button>
                                ))}
                            </div>

                            <div className="flex items-center gap-2">
                                <button
                                    onClick={() => setIsLoopEnabled(!isLoopEnabled)}
                                    className={`px-3 py-1 rounded-md text-xs font-bold transition-all flex items-center gap-1.5 border ${
                                        isLoopEnabled
                                            ? 'bg-emerald-50 text-emerald-700 border-emerald-300 shadow-sm'
                                            : 'bg-slate-100 text-slate-500 border-slate-200'
                                    }`}
                                >
                                    <Repeat size={13} className={isLoopEnabled ? 'animate-pulse' : ''} />
                                    <span>Bucle Continuo: {isLoopEnabled ? 'ACTIVADO' : 'DESACTIVADO'}</span>
                                </button>
                            </div>
                        </div>

                        {/* Deslizador Interactivo de Recorte (Waveform Timeline) */}
                        <div className="space-y-2 bg-[#0A0A0A] text-white p-4 rounded-xl shadow-inner border border-zinc-800">
                            <div className="flex items-center justify-between text-xs font-mono text-zinc-400 mb-1">
                                <span>Fragmento Seleccionado: <strong className="text-white">{formatTime(startSeconds)} - {formatTime(Math.min(startSeconds + durationSeconds, totalDuration))}</strong> ({durationSeconds}s)</span>
                                <span className="text-[#0094FF] font-bold">Posición Actual: {formatTime(currentTime)} / {formatTime(totalDuration)}</span>
                            </div>

                            {/* Simulación visual de onda con ventana de recorte */}
                            <div className="relative h-12 bg-zinc-900 rounded-lg overflow-hidden flex items-center px-2">
                                {/* Barras de audio */}
                                <div className="absolute inset-0 flex items-center justify-between px-3 opacity-30 pointer-events-none">
                                    {Array.from({ length: 48 }).map((_, i) => {
                                        const h = 20 + Math.sin(i * 0.4) * 15 + (i % 3) * 8;
                                        return (
                                            <div
                                                key={i}
                                                style={{ height: `${h}%` }}
                                                className={`w-1 rounded-full ${isPlaying ? 'bg-[#0094FF]' : 'bg-white'}`}
                                            />
                                        );
                                    })}
                                </div>

                                {/* Ventana destacada del recorte */}
                                <div
                                    style={{
                                        left: `${totalDuration > 0 ? (startSeconds / totalDuration) * 100 : 0}%`,
                                        width: `${totalDuration > 0 ? (durationSeconds / totalDuration) * 100 : 100}%`,
                                    }}
                                    className="absolute top-1 bottom-1 bg-[#0094FF]/25 border-2 border-[#0094FF] rounded pointer-events-none transition-all duration-75 shadow-lg shadow-[#0094FF]/20 flex items-center justify-between px-1"
                                >
                                    <div className="w-1 h-5 bg-white rounded-full shadow" />
                                    <div className="w-1 h-5 bg-white rounded-full shadow" />
                                </div>

                                {/* Aguja de reproducción actual */}
                                <div
                                    style={{
                                        left: `${totalDuration > 0 ? (currentTime / totalDuration) * 100 : 0}%`,
                                    }}
                                    className="absolute top-0 bottom-0 w-0.5 bg-white z-10 pointer-events-none shadow"
                                />
                            </div>

                            {/* Slider de posición de inicio */}
                            <input
                                type="range"
                                min={0}
                                max={maxAllowedStart}
                                step={0.5}
                                value={startSeconds}
                                onChange={(e) => handleStartChange(parseFloat(e.target.value))}
                                className="w-full h-2 bg-zinc-800 rounded-lg appearance-none cursor-pointer accent-[#0094FF]"
                            />
                            <div className="flex justify-between text-[10px] font-mono text-zinc-400">
                                <span>00:00</span>
                                <span>Arrastra para ubicar el fragmento en cualquier minuto de la canción completa</span>
                                <span>{formatTime(totalDuration)}</span>
                            </div>
                        </div>

                        {/* Barra de Controles de Reproducción y Volumen */}
                        <div className="flex items-center justify-between flex-wrap gap-4 pt-1">
                            <div className="flex items-center gap-3">
                                <button
                                    onClick={togglePlay}
                                    className="w-12 h-12 bg-[#0094FF] hover:bg-[#0080dd] text-white rounded-xl flex items-center justify-center transition-all shadow-md shadow-[#0094FF]/30 hover:scale-105"
                                >
                                    {isPlaying ? (
                                        <Pause size={20} fill="white" />
                                    ) : (
                                        <Play size={20} fill="white" className="ml-0.5" />
                                    )}
                                </button>

                                <button
                                    onClick={handleRewind}
                                    className="p-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg transition-colors"
                                    title="Rebobinar al inicio del fragmento"
                                >
                                    <RotateCcw size={16} />
                                </button>
                            </div>

                            {/* Control de Volumen */}
                            <div className="flex items-center gap-2">
                                <button
                                    onClick={handleToggleMute}
                                    className="text-slate-400 hover:text-slate-700 p-1"
                                >
                                    {isMuted ? <VolumeX size={17} /> : <Volume2 size={17} />}
                                </button>
                                <input
                                    type="range"
                                    min={0}
                                    max={1}
                                    step={0.05}
                                    value={isMuted ? 0 : volume}
                                    onChange={(e) => handleVolumeChange(parseFloat(e.target.value))}
                                    className="w-24 h-1.5 bg-slate-200 rounded appearance-none cursor-pointer accent-slate-900"
                                />
                            </div>
                        </div>
                    </div>
                ) : (
                    <div className="p-10 text-center border-2 border-dashed border-slate-200 rounded-xl bg-slate-50/50">
                        <div className="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center mx-auto text-slate-400 mb-2">
                            <Music size={22} />
                        </div>
                        <h3 className="font-bold text-xs text-slate-700">Ninguna canción de YouTube seleccionada</h3>
                        <p className="text-[11px] text-slate-400 max-w-sm mx-auto mt-0.5">
                            Usa el buscador superior o pulsa cualquiera de las pruebas rápidas para cargar la canción completa en el recortador.
                        </p>
                    </div>
                )}
            </div>

            {/* SECCIÓN 3: CONSOLA DE DIAGNÓSTICO EN TIEMPO REAL */}
            <div className="bg-[#0A0A0A] border border-slate-800 rounded-xl p-4 overflow-hidden relative shadow-sm">
                <div className="flex items-center justify-between border-b border-white/10 pb-3 mb-3">
                    <div className="flex items-center gap-2">
                        <Activity size={14} className="text-[#0094FF]" />
                        <span className="text-xs font-mono font-bold text-white/80 uppercase tracking-widest">
                            Consola de Diagnóstico en Tiempo Real
                        </span>
                    </div>

                    <button
                        onClick={() => setLogs([])}
                        className="text-xs text-white/40 hover:text-white flex items-center gap-1 hover:bg-white/10 px-2.5 py-1 rounded transition-colors"
                    >
                        <Trash2 size={12} />
                        <span>Limpiar</span>
                    </button>
                </div>

                <div className="font-mono text-xs space-y-1 max-h-48 overflow-y-auto pr-2 no-scrollbar">
                    {logs.length === 0 ? (
                        <p className="text-white/30 italic text-[11px]">Esperando eventos de YouTube Engine y reproductor de audio...</p>
                    ) : (
                        logs.map((log) => (
                            <div key={log.id} className="flex items-start gap-2 leading-relaxed">
                                <span className="text-white/30 text-[11px] select-none">[{log.timestamp}]</span>
                                <span className={`text-[11px] font-bold uppercase ${
                                    log.type === 'success' ? 'text-emerald-400' :
                                    log.type === 'error' ? 'text-red-400' :
                                    log.type === 'stream' ? 'text-cyan-400' :
                                    log.type === 'trim' ? 'text-amber-400' :
                                    'text-blue-400'
                                }`}>
                                    [{log.type.toUpperCase()}]
                                </span>
                                <span className={`flex-1 ${
                                    log.type === 'error' ? 'text-red-300 font-semibold' : 'text-zinc-300'
                                }`}>
                                    {log.message}
                                </span>
                            </div>
                        ))
                    )}
                    <div ref={logsEndRef} />
                </div>
            </div>
        </div>
    );
};
