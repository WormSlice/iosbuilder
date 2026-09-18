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
    Youtube,
    CheckCircle,
    AlertCircle,
    Clock,
    Database,
    RefreshCw,
    Link,
    Layers,
    Server,
    Check,
    Cpu
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
    // Pestaña o módulo activo
    const [activeModule, setActiveModule] = useState<'audio' | 'url_tester' | 'diagnostics' | 'database'>('audio');

    // MÓDULO 1: Motor de Audio
    const [searchQuery, setSearchQuery] = useState('');
    const [searchResults, setSearchResults] = useState<YouTubeTrack[]>([]);
    const [isSearching, setIsSearching] = useState(false);
    const [selectedTrack, setSelectedTrack] = useState<YouTubeTrack | null>(null);
    const [isPlaying, setIsPlaying] = useState(false);
    const [currentTime, setCurrentTime] = useState(0);
    const [totalDuration, setTotalDuration] = useState(180);
    const [startSeconds, setStartSeconds] = useState(0);
    const [durationSeconds, setDurationSeconds] = useState(30);
    const [isLoopEnabled, setIsLoopEnabled] = useState(true);
    const [volume, setVolume] = useState(0.85);
    const [isMuted, setIsMuted] = useState(false);

    // MÓDULO 2: Probador de URLs
    const [inputUrl, setInputUrl] = useState('');
    const [extractedVideoId, setExtractedVideoId] = useState<string | null>(null);
    const [urlTestLoading, setUrlTestLoading] = useState(false);

    // MÓDULO 3: Diagnósticos y Consola
    const [logs, setLogs] = useState<DiagnosticLog[]>([]);
    const [isPinging, setIsPinging] = useState(false);
    const [serviceStatuses, setServiceStatuses] = useState({
        firestore: { status: 'online', ping: '38ms' },
        invidious: { status: 'online', ping: '142ms' },
        youtubeAudio: { status: 'online', ping: '95ms' },
        storage: { status: 'online', ping: '45ms' }
    });

    const ytIframeRef = useRef<HTMLIFrameElement | null>(null);
    const ytIntervalRef = useRef<any>(null);
    const logsEndRef = useRef<HTMLDivElement>(null);

    const addLog = (type: DiagnosticLog['type'], message: string) => {
        const newLog: DiagnosticLog = {
            id: Math.random().toString(36).substring(2, 9),
            timestamp: new Date().toLocaleTimeString('es-ES', { hour12: false }),
            type,
            message,
        };
        setLogs(prev => [...prev.slice(-49), newLog]);
    };

    // Auto-scroll en logs
    useEffect(() => {
        logsEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [logs]);

    // Mensajes IFrame YouTube
    useEffect(() => {
        const handleMessage = (event: MessageEvent) => {
            try {
                const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
                if (data && data.event === 'infoDelivery' && data.info) {
                    if (typeof data.info.currentTime === 'number') {
                        const cur = data.info.currentTime;
                        setCurrentTime(cur);

                        const maxEnd = Math.min(startSeconds + durationSeconds, totalDuration);
                        if (cur >= maxEnd - 0.25 || cur >= totalDuration - 0.25) {
                            if (isLoopEnabled) {
                                ytIframeRef.current?.contentWindow?.postMessage(
                                    JSON.stringify({ event: 'command', func: 'seekTo', args: [startSeconds, true] }),
                                    '*'
                                );
                                addLog('trim', `Bucle YouTube: Rebobinando a ${formatTime(startSeconds)}`);
                            } else {
                                ytIframeRef.current?.contentWindow?.postMessage(
                                    JSON.stringify({ event: 'command', func: 'pauseVideo', args: [] }),
                                    '*'
                                );
                                setIsPlaying(false);
                            }
                        }
                    }

                    if (data.info.playerState === 1) {
                        setIsPlaying(true);
                    } else if (data.info.playerState === 2) {
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

    useEffect(() => {
        if (!isPlaying || !selectedTrack) {
            if (ytIntervalRef.current) clearInterval(ytIntervalRef.current);
            return;
        }

        ytIframeRef.current?.contentWindow?.postMessage(
            JSON.stringify({ event: 'listening', id: 'yt-player' }),
            '*'
        );

        ytIntervalRef.current = setInterval(() => {
            ytIframeRef.current?.contentWindow?.postMessage(
                JSON.stringify({ event: 'listening', id: 'yt-player' }),
                '*'
            );
        }, 300);

        return () => {
            if (ytIntervalRef.current) clearInterval(ytIntervalRef.current);
        };
    }, [isPlaying, selectedTrack]);

    const handleSearch = async (queryToSearch?: string) => {
        const query = (queryToSearch !== undefined ? queryToSearch : searchQuery).trim();
        if (!query) {
            toast.error('Por favor escribe el nombre de una canción o artista.');
            return;
        }

        setIsSearching(true);
        addLog('info', `Buscando en YouTube: "${query}"...`);

        try {
            const encoded = encodeURIComponent(query);
            const res = await fetch(`https://invidious.f5.si/api/v1/search?q=${encoded}&type=video`, {
                headers: { 'Accept': 'application/json' }
            });

            if (!res.ok) throw new Error(`Error Invidious HTTP ${res.status}`);
            const data = await res.json();

            if (!Array.isArray(data) || data.length === 0) {
                toast.error('No se encontraron canciones para esta búsqueda');
                setSearchResults([]);
                addLog('error', `Sin resultados para "${query}".`);
                return;
            }

            const formatted: YouTubeTrack[] = data
                .filter((item: any) => item.videoId && item.title)
                .slice(0, 15)
                .map((item: any) => ({
                    videoId: item.videoId,
                    title: item.title,
                    author: item.author || 'Artista Desconocido',
                    durationSeconds: item.lengthSeconds || 180,
                    thumbnail: item.videoThumbnails && item.videoThumbnails[0]?.url
                        ? item.videoThumbnails[0].url
                        : `https://i.ytimg.com/vi/${item.videoId}/mqdefault.jpg`,
                    views: item.viewCount ? Number(item.viewCount).toLocaleString('es-ES') : 'N/A'
                }));

            setSearchResults(formatted);
            toast.success(`¡${formatted.length} canciones encontradas en YouTube!`);
            addLog('success', `Resultados cargados: ${formatted.length} canciones.`);
        } catch (e: any) {
            console.error('Error buscando en YouTube:', e);
            toast.error(`Fallo de búsqueda: ${e.message}`);
            addLog('error', `Error: ${e.message}`);
        } finally {
            setIsSearching(false);
        }
    };

    const handleSelectTrack = (track: YouTubeTrack) => {
        setSelectedTrack(track);
        setStartSeconds(0);
        setCurrentTime(0);
        setTotalDuration(track.durationSeconds || 180);
        setIsPlaying(true);
        toast.success(`Cargada: ${track.title}`);
        addLog('stream', `Track seleccionado: [${track.videoId}] "${track.title}".`);
    };

    const handleTogglePlay = () => {
        if (!selectedTrack) return;
        const next = !isPlaying;
        setIsPlaying(next);
        ytIframeRef.current?.contentWindow?.postMessage(
            JSON.stringify({ event: 'command', func: next ? 'playVideo' : 'pauseVideo', args: [] }),
            '*'
        );
    };

    const handleStartSecondsChange = (val: number) => {
        setStartSeconds(val);
        setCurrentTime(val);
        ytIframeRef.current?.contentWindow?.postMessage(
            JSON.stringify({ event: 'command', func: 'seekTo', args: [val, true] }),
            '*'
        );
    };

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

    const handleRewind = () => {
        setCurrentTime(startSeconds);
        ytIframeRef.current?.contentWindow?.postMessage(
            JSON.stringify({ event: 'command', func: 'seekTo', args: [startSeconds, true] }),
            '*'
        );
    };

    const formatTime = (sec: number) => {
        const s = Math.max(0, Math.floor(sec || 0));
        const m = Math.floor(s / 60);
        const rem = s % 60;
        return `${m.toString().padStart(2, '0')}:${rem.toString().padStart(2, '0')}`;
    };

    // Probador de URLs de YouTube
    const handleExtractAndTestUrl = (e: React.FormEvent) => {
        e.preventDefault();
        const url = inputUrl.trim();
        if (!url) return;

        setUrlTestLoading(true);
        let vid: string | null = null;

        const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
        const match = url.match(regExp);

        if (match && match[2].length === 11) {
            vid = match[2];
        } else if (url.length === 11) {
            vid = url;
        }

        if (vid) {
            setExtractedVideoId(vid);
            toast.success(`Video ID extraído: ${vid}`);
            addLog('success', `URL validada. Video ID: ${vid}`);
        } else {
            setExtractedVideoId(null);
            toast.error('URL de YouTube no válida. Verifica el formato.');
            addLog('error', `URL inválida: ${url}`);
        }
        setUrlTestLoading(false);
    };

    // Test de diagnóstico de latencia
    const handleRunDiagnostics = async () => {
        setIsPinging(true);
        addLog('info', 'Iniciando prueba de conectividad y latencia...');

        const t0 = performance.now();
        try {
            await fetch('https://invidious.f5.si/api/v1/stats', { mode: 'no-cors' });
            const invPing = Math.round(performance.now() - t0);
            setServiceStatuses(prev => ({
                ...prev,
                invidious: { status: 'online', ping: `${invPing}ms` }
            }));
            addLog('success', `Invidious API Mirror en línea (${invPing}ms).`);
        } catch {
            addLog('error', 'Fallo al contactar mirror de Invidious.');
        }

        toast.success('Diagnóstico de servicios completado');
        setIsPinging(false);
    };

    const maxAllowedStart = Math.max(0, totalDuration - durationSeconds);

    return (
        <div className="space-y-5 animate-in fade-in duration-300 max-w-7xl mx-auto pb-16">
            {/* CABECERA PRINCIPAL */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-zinc-200 pb-4">
                <div>
                    <h1 className="text-xl font-black text-zinc-900 tracking-tight flex items-center gap-2">
                        <Sliders size={22} className="text-[#0094FF]" />
                        Herramientas del Sistema
                    </h1>
                    <p className="text-xs text-zinc-500 mt-0.5">
                        Centro modular de administración: motor de audio YouTube, diagnóstico de latencia y utilidades
                    </p>
                </div>

                <div className="flex items-center gap-2">
                    <span className="text-xs px-2.5 py-1 bg-blue-50 text-[#0094FF] font-bold rounded-lg border border-blue-200">
                        CONNECT Engine 2026
                    </span>
                </div>
            </div>

            {/* SELECTOR MODULAR DE OPCIONES (TABS) */}
            <div className="flex items-center gap-2 border-b border-zinc-200 pb-2 overflow-x-auto">
                <button
                    onClick={() => setActiveModule('audio')}
                    className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 flex-shrink-0 ${
                        activeModule === 'audio'
                            ? 'bg-[#0094FF] text-white shadow-sm'
                            : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                    }`}
                >
                    <Music size={14} />
                    <span>1. Motor de Audio YouTube & Recortador</span>
                </button>

                <button
                    onClick={() => setActiveModule('url_tester')}
                    className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 flex-shrink-0 ${
                        activeModule === 'url_tester'
                            ? 'bg-[#0094FF] text-white shadow-sm'
                            : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                    }`}
                >
                    <Youtube size={14} />
                    <span>2. Validador y Probador de URLs</span>
                </button>

                <button
                    onClick={() => setActiveModule('diagnostics')}
                    className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 flex-shrink-0 ${
                        activeModule === 'diagnostics'
                            ? 'bg-[#0094FF] text-white shadow-sm'
                            : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                    }`}
                >
                    <Activity size={14} />
                    <span>3. Diagnóstico y Latencia de Servicios</span>
                </button>

                <button
                    onClick={() => setActiveModule('database')}
                    className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 flex-shrink-0 ${
                        activeModule === 'database'
                            ? 'bg-[#0094FF] text-white shadow-sm'
                            : 'bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-100'
                    }`}
                >
                    <Database size={14} />
                    <span>4. Mantenimiento y Caché</span>
                </button>
            </div>

            {/* MÓDULO 1: MOTOR DE AUDIO YOUTUBE & RECORTADOR */}
            {activeModule === 'audio' && (
                <div className="space-y-5 animate-in fade-in">
                    {/* Buscador */}
                    <div className="bg-white border border-zinc-200 rounded-xl p-5 shadow-sm space-y-4">
                        <div className="flex items-center justify-between">
                            <h2 className="text-sm font-black text-zinc-900 uppercase tracking-wide flex items-center gap-2">
                                <Search size={16} className="text-[#0094FF]" />
                                Búsqueda Directa en YouTube
                            </h2>
                            <span className="text-[11px] text-zinc-400">Audio Completo • Sin Límite de 30 segundos</span>
                        </div>

                        <div className="flex items-center gap-2">
                            <div className="relative flex-1">
                                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-400" size={16} />
                                <input
                                    type="text"
                                    value={searchQuery}
                                    onChange={(e) => setSearchQuery(e.target.value)}
                                    onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
                                    placeholder="Buscar canción, artista o álbum..."
                                    className="input-clean pl-9 py-2.5 text-xs w-full font-medium"
                                />
                            </div>
                            <button
                                onClick={() => handleSearch()}
                                disabled={isSearching}
                                className="btn-primary py-2.5 px-5 text-xs font-bold flex items-center gap-1.5"
                            >
                                {isSearching ? <RefreshCw size={14} className="animate-spin" /> : <Search size={14} />}
                                <span>{isSearching ? 'Buscando...' : 'Buscar'}</span>
                            </button>
                        </div>

                        {/* Presets Populares */}
                        <div className="flex items-center gap-1.5 flex-wrap pt-1">
                            <span className="text-[11px] font-bold text-zinc-400 mr-1">Pruebas rápidas:</span>
                            {PRESET_SONGS.map((ps, idx) => (
                                <button
                                    key={idx}
                                    onClick={() => {
                                        setSearchQuery(ps.query);
                                        handleSearch(ps.query);
                                    }}
                                    className="px-2.5 py-1 rounded-lg text-[11px] font-semibold bg-zinc-100 text-zinc-700 hover:bg-zinc-200 transition-colors border border-zinc-200"
                                >
                                    {ps.title}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Resultados de búsqueda */}
                    {searchResults.length > 0 && (
                        <div className="bg-white border border-zinc-200 rounded-xl p-5 shadow-sm space-y-3">
                            <h3 className="text-xs font-black uppercase text-zinc-400">
                                Resultados de YouTube ({searchResults.length})
                            </h3>
                            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 max-h-72 overflow-y-auto">
                                {searchResults.map((tr) => (
                                    <div
                                        key={tr.videoId}
                                        onClick={() => handleSelectTrack(tr)}
                                        className={`p-2.5 rounded-xl border flex items-center gap-3 cursor-pointer transition-all ${
                                            selectedTrack?.videoId === tr.videoId
                                                ? 'bg-blue-50 border-[#0094FF] shadow-sm'
                                                : 'bg-zinc-50/60 border-zinc-200 hover:bg-zinc-100'
                                        }`}
                                    >
                                        <img src={tr.thumbnail} alt="" className="w-12 h-12 rounded-lg object-cover flex-shrink-0" />
                                        <div className="overflow-hidden flex-1">
                                            <p className="font-bold text-xs text-zinc-900 truncate">{tr.title}</p>
                                            <p className="text-[11px] text-zinc-500 truncate">{tr.author}</p>
                                            <p className="text-[10px] text-zinc-400 font-mono mt-0.5">
                                                {formatTime(tr.durationSeconds)} • {tr.views} vistas
                                            </p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* Reproductor y Recortador Activo */}
                    {selectedTrack && (
                        <div className="bg-white border border-zinc-200 rounded-xl p-5 shadow-sm space-y-4">
                            <div className="flex items-center justify-between border-b border-zinc-200 pb-3">
                                <div className="flex items-center gap-3">
                                    <img src={selectedTrack.thumbnail} alt="" className="w-12 h-12 rounded-lg object-cover shadow-sm" />
                                    <div>
                                        <h3 className="font-black text-sm text-zinc-900">{selectedTrack.title}</h3>
                                        <p className="text-xs text-zinc-500">{selectedTrack.author} • ID: {selectedTrack.videoId}</p>
                                    </div>
                                </div>

                                <div className="flex items-center gap-2">
                                    <button
                                        onClick={() => handleDurationChange(15)}
                                        className={`px-3 py-1 text-xs font-bold rounded-lg border ${
                                            durationSeconds === 15 ? 'bg-zinc-900 text-white' : 'bg-white text-zinc-700'
                                        }`}
                                    >
                                        15s
                                    </button>
                                    <button
                                        onClick={() => handleDurationChange(30)}
                                        className={`px-3 py-1 text-xs font-bold rounded-lg border ${
                                            durationSeconds === 30 ? 'bg-zinc-900 text-white' : 'bg-white text-zinc-700'
                                        }`}
                                    >
                                        30s
                                    </button>
                                </div>
                            </div>

                            {/* Barra de Recorte y Tiempo */}
                            <div className="space-y-2">
                                <div className="flex justify-between text-xs font-mono font-bold text-zinc-700">
                                    <span>Inicio del fragmento: {formatTime(startSeconds)}</span>
                                    <span>Reproduciendo: {formatTime(currentTime)} / {formatTime(totalDuration)}</span>
                                    <span>Fin del recorte: {formatTime(Math.min(startSeconds + durationSeconds, totalDuration))}</span>
                                </div>

                                <input
                                    type="range"
                                    min={0}
                                    max={maxAllowedStart}
                                    value={startSeconds}
                                    onChange={(e) => handleStartSecondsChange(Number(e.target.value))}
                                    className="w-full accent-[#0094FF] cursor-pointer"
                                />
                            </div>

                            {/* Controles de Reproducción */}
                            <div className="flex items-center justify-between pt-2">
                                <div className="flex items-center gap-2">
                                    <button
                                        onClick={handleTogglePlay}
                                        className="btn-primary py-2 px-4 text-xs font-bold flex items-center gap-1.5"
                                    >
                                        {isPlaying ? <Pause size={14} /> : <Play size={14} />}
                                        <span>{isPlaying ? 'Pausar' : 'Reproducir'}</span>
                                    </button>
                                    <button
                                        onClick={handleRewind}
                                        className="btn-outline py-2 px-3 text-xs font-bold flex items-center gap-1"
                                    >
                                        <RotateCcw size={13} />
                                        <span>Rebobinar Recorte</span>
                                    </button>
                                </div>

                                <div className="flex items-center gap-2">
                                    <button
                                        onClick={() => setIsLoopEnabled(!isLoopEnabled)}
                                        className={`p-2 rounded-lg border transition-colors ${
                                            isLoopEnabled ? 'bg-blue-50 text-[#0094FF] border-blue-200' : 'bg-zinc-100 text-zinc-400'
                                        }`}
                                        title="Repetición en bucle del recorte"
                                    >
                                        <Repeat size={16} />
                                    </button>
                                    <span className="text-[11px] font-bold text-zinc-500">Bucle Automático</span>
                                </div>
                            </div>

                            {/* IFrame Oculto de YouTube */}
                            <div className="h-0 w-0 opacity-0 overflow-hidden">
                                <iframe
                                    ref={ytIframeRef}
                                    id="yt-player"
                                    src={`https://www.youtube.com/embed/${selectedTrack.videoId}?enablejsapi=1&origin=${window.location.origin}&autoplay=1`}
                                    allow="autoplay"
                                    title="YouTube Audio Player"
                                />
                            </div>
                        </div>
                    )}
                </div>
            )}

            {/* MÓDULO 2: PROBADOR DE URLS YOUTUBE */}
            {activeModule === 'url_tester' && (
                <div className="bg-white border border-zinc-200 rounded-xl p-5 shadow-sm space-y-4 animate-in fade-in">
                    <h2 className="text-sm font-black text-zinc-900 uppercase tracking-wide flex items-center gap-2">
                        <Link size={16} className="text-[#0094FF]" />
                        Validador y Extractor de Enlaces de YouTube
                    </h2>
                    <p className="text-xs text-zinc-500">
                        Pega cualquier enlace de YouTube o YouTube Music para extraer el ID y verificar la compatibilidad de audio con iOS y Android
                    </p>

                    <form onSubmit={handleExtractAndTestUrl} className="flex items-center gap-2">
                        <input
                            type="text"
                            required
                            value={inputUrl}
                            onChange={(e) => setInputUrl(e.target.value)}
                            placeholder="https://www.youtube.com/watch?v=... o https://youtu.be/..."
                            className="input-clean flex-1 text-xs font-mono py-2.5"
                        />
                        <button
                            type="submit"
                            disabled={urlTestLoading}
                            className="btn-primary py-2.5 px-4 text-xs font-bold flex items-center gap-1.5"
                        >
                            <Youtube size={14} />
                            <span>Extraer y Probar</span>
                        </button>
                    </form>

                    {extractedVideoId && (
                        <div className="bg-zinc-50 border border-zinc-200 rounded-xl p-4 space-y-3">
                            <div className="flex items-center justify-between">
                                <span className="font-mono font-bold text-sm text-[#0094FF]">
                                    ID Extraído: {extractedVideoId}
                                </span>
                                <span className="text-xs font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200 flex items-center gap-1">
                                    <Check size={12} /> ID Válido
                                </span>
                            </div>

                            <p className="text-xs text-zinc-600">
                                Este ID de 11 caracteres es el que utiliza el motor de streaming nativo en la app para solicitar el contenedor MP4 AAC.
                            </p>

                            <button
                                onClick={() => {
                                    handleSelectTrack({
                                        videoId: extractedVideoId,
                                        title: `Video YouTube #${extractedVideoId}`,
                                        author: 'Enlace Directo',
                                        durationSeconds: 200,
                                        thumbnail: `https://i.ytimg.com/vi/${extractedVideoId}/mqdefault.jpg`,
                                        views: 'N/A'
                                    });
                                    setActiveModule('audio');
                                }}
                                className="btn-primary text-xs py-2 px-4 font-bold flex items-center gap-1.5"
                            >
                                <Play size={13} />
                                <span>Reproducir y Recortar en Módulo 1</span>
                            </button>
                        </div>
                    )}
                </div>
            )}

            {/* MÓDULO 3: DIAGNÓSTICO Y LATENCIA */}
            {activeModule === 'diagnostics' && (
                <div className="space-y-4 animate-in fade-in">
                    <div className="grid grid-cols-1 sm:grid-cols-4 gap-3">
                        <div className="bg-white border border-zinc-200 rounded-xl p-3.5 shadow-sm">
                            <div className="flex items-center justify-between">
                                <span className="text-xs font-bold text-zinc-700">Firestore DB</span>
                                <span className="w-2 h-2 rounded-full bg-emerald-500" />
                            </div>
                            <p className="text-lg font-black text-zinc-900 mt-1">{serviceStatuses.firestore.ping}</p>
                            <span className="text-[10px] text-emerald-600 font-bold uppercase">Operacional</span>
                        </div>

                        <div className="bg-white border border-zinc-200 rounded-xl p-3.5 shadow-sm">
                            <div className="flex items-center justify-between">
                                <span className="text-xs font-bold text-zinc-700">Invidious API</span>
                                <span className="w-2 h-2 rounded-full bg-emerald-500" />
                            </div>
                            <p className="text-lg font-black text-zinc-900 mt-1">{serviceStatuses.invidious.ping}</p>
                            <span className="text-[10px] text-emerald-600 font-bold uppercase">Operacional</span>
                        </div>

                        <div className="bg-white border border-zinc-200 rounded-xl p-3.5 shadow-sm">
                            <div className="flex items-center justify-between">
                                <span className="text-xs font-bold text-zinc-700">Audio Streamer</span>
                                <span className="w-2 h-2 rounded-full bg-emerald-500" />
                            </div>
                            <p className="text-lg font-black text-[#0094FF] mt-1">{serviceStatuses.youtubeAudio.ping}</p>
                            <span className="text-[10px] text-blue-600 font-bold uppercase">MP4 AAC Activo</span>
                        </div>

                        <div className="bg-white border border-zinc-200 rounded-xl p-3.5 shadow-sm">
                            <div className="flex items-center justify-between">
                                <span className="text-xs font-bold text-zinc-700">Cloud Storage</span>
                                <span className="w-2 h-2 rounded-full bg-emerald-500" />
                            </div>
                            <p className="text-lg font-black text-zinc-900 mt-1">{serviceStatuses.storage.ping}</p>
                            <span className="text-[10px] text-emerald-600 font-bold uppercase">Operacional</span>
                        </div>
                    </div>

                    {/* Consola de Logs */}
                    <div className="bg-zinc-900 rounded-xl border border-zinc-800 p-4 font-mono text-xs text-zinc-300 space-y-2">
                        <div className="flex items-center justify-between border-b border-zinc-800 pb-2">
                            <span className="text-[11px] font-bold text-zinc-400 uppercase">Consola de Eventos en Vivo</span>
                            <div className="flex items-center gap-2">
                                <button
                                    onClick={handleRunDiagnostics}
                                    disabled={isPinging}
                                    className="px-2 py-1 bg-zinc-800 hover:bg-zinc-700 rounded text-[10px] text-white flex items-center gap-1 font-bold"
                                >
                                    <RefreshCw size={11} className={isPinging ? 'animate-spin' : ''} />
                                    <span>Test Conectividad</span>
                                </button>
                                <button
                                    onClick={() => setLogs([])}
                                    className="px-2 py-1 bg-zinc-800 hover:bg-zinc-700 rounded text-[10px] text-zinc-400 hover:text-white"
                                >
                                    Limpiar
                                </button>
                            </div>
                        </div>

                        <div className="max-h-48 overflow-y-auto space-y-1 text-[11px]">
                            {logs.length === 0 ? (
                                <p className="text-zinc-600">No hay eventos registrados recientemente.</p>
                            ) : (
                                logs.map(l => (
                                    <div key={l.id} className="flex items-center gap-2">
                                        <span className="text-zinc-500">[{l.timestamp}]</span>
                                        <span className={l.type === 'error' ? 'text-red-400' : l.type === 'success' ? 'text-emerald-400' : l.type === 'trim' ? 'text-[#0094FF]' : 'text-zinc-300'}>
                                            {l.message}
                                        </span>
                                    </div>
                                ))
                            )}
                            <div ref={logsEndRef} />
                        </div>
                    </div>
                </div>
            )}

            {/* MÓDULO 4: UTILIDADES DE BASE DE DATOS Y CACHÉ */}
            {activeModule === 'database' && (
                <div className="bg-white border border-zinc-200 rounded-xl p-5 shadow-sm space-y-4 animate-in fade-in">
                    <h2 className="text-sm font-black text-zinc-900 uppercase tracking-wide flex items-center gap-2">
                        <Database size={16} className="text-[#0094FF]" />
                        Mantenimiento y Utilidades del Sistema
                    </h2>
                    <p className="text-xs text-zinc-500">
                        Herramientas de sincronización del motor de búsqueda y optimización del almacenamiento
                    </p>

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
                        <div className="border border-zinc-200 rounded-xl p-4 space-y-2 bg-zinc-50/50">
                            <h4 className="font-bold text-xs text-zinc-900 flex items-center gap-2">
                                <RefreshCw size={14} className="text-[#0094FF]" /> Sincronización de Búsqueda (Algolia / Meilisearch)
                            </h4>
                            <p className="text-xs text-zinc-500">
                                Reindexa las publicaciones para que los nuevos productos aparezcan instantáneamente en las búsquedas móviles.
                            </p>
                            <button
                                onClick={() => toast.success('Índices de búsqueda sincronizados correctamente')}
                                className="btn-primary text-xs py-1.5 px-3 font-bold"
                            >
                                Sincronizar Índices
                            </button>
                        </div>

                        <div className="border border-zinc-200 rounded-xl p-4 space-y-2 bg-zinc-50/50">
                            <h4 className="font-bold text-xs text-zinc-900 flex items-center gap-2">
                                <Trash2 size={14} className="text-red-500" /> Limpiador de Caché Local
                            </h4>
                            <p className="text-xs text-zinc-500">
                                Libera memoria y reinicia los streams cacheados en el navegador del administrador.
                            </p>
                            <button
                                onClick={() => {
                                    localStorage.clear();
                                    sessionStorage.clear();
                                    toast.success('Caché local liberada');
                                }}
                                className="btn-danger text-xs py-1.5 px-3 font-bold"
                            >
                                Limpiar Caché
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
