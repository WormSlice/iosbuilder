import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;
import '../services/music_service.dart';

/// Hoja modal estilo Instagram para seleccionar y recortar cualquier fragmento
/// de audio con diseño limpio CONNECT (fondo blanco, azul vibrante, CanvaSans)
/// y reproducción fluida, instantánea y continua sin cortes.
class InstagramAudioTrimmerSheet extends StatefulWidget {
  final String musicId;
  final String title;
  final String artist;
  final String thumbnail;
  final int totalTrackSeconds;
  final int initialStartSeconds;
  final int initialDuration;
  final String? audioUrl;

  const InstagramAudioTrimmerSheet({
    super.key,
    required this.musicId,
    required this.title,
    required this.artist,
    required this.thumbnail,
    this.totalTrackSeconds = 240,
    this.initialStartSeconds = 0,
    this.initialDuration = 240,
    this.audioUrl,
  });

  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required String musicId,
    required String title,
    required String artist,
    required String thumbnail,
    int totalTrackSeconds = 240,
    int initialStartSeconds = 0,
    int initialDuration = 240,
    String? audioUrl,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InstagramAudioTrimmerSheet(
        musicId: musicId,
        title: title,
        artist: artist,
        thumbnail: thumbnail,
        totalTrackSeconds: totalTrackSeconds > 0 ? totalTrackSeconds : 240,
        initialStartSeconds: initialStartSeconds,
        initialDuration: initialDuration,
        audioUrl: audioUrl,
      ),
    );
  }

  @override
  State<InstagramAudioTrimmerSheet> createState() =>
      _InstagramAudioTrimmerSheetState();
}

class _InstagramAudioTrimmerSheetState extends State<InstagramAudioTrimmerSheet>
    with TickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  yt.YoutubePlayerController? _ytController;
  Timer? _ytLoopTimer;
  StreamSubscription? _ytStateSub;

  late int _startSeconds;
  late int _duration;
  bool _isPlaying = false;
  bool _isLoading = true;
  double _totalTrackDurationSec = 240.0;
  bool _isAutoHighlight = true;
  double _currentPlaybackSec = 0.0;
  String? _resolvedAudioUrl;

  bool get _isYouTube =>
      widget.musicId.length == 11 &&
      !widget.musicId.contains(' ') &&
      !widget.musicId.startsWith('http');

  // Controladores de animación
  late AnimationController _waveAnimController;
  late AnimationController _discAnimController;
  late AnimationController _pulseAnimController;
  late Animation<double> _pulseAnim;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  Timer? _seekDebounce;

  @override
  void initState() {
    super.initState();
    _totalTrackDurationSec = (widget.totalTrackSeconds > 0)
        ? widget.totalTrackSeconds.toDouble()
        : 240.0;
    _duration = (widget.initialDuration > 0)
        ? widget.initialDuration.clamp(5, _totalTrackDurationSec.toInt())
        : 30;

    final maxStart = math.max(0.0, _totalTrackDurationSec - _duration);
    _startSeconds = widget.initialStartSeconds.clamp(0, maxStart.toInt());
    _isAutoHighlight = false;
    _currentPlaybackSec = _startSeconds.toDouble();

    // 1. Animación suave de ondas al reproducir (60fps)
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // 2. Animación de disco giratorio continuo al reproducir
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // 3. Pulso suave para portada y badges
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseAnimController, curve: Curves.easeInOut),
    );

    _initAudio();
  }

  Future<void> _initAudio() async {
    if (_isYouTube) {
      await _initYouTubePlayer();
      return;
    }
    await _initJustAudioPlayer();
  }

  Future<void> _initYouTubePlayer() async {
    try {
      _ytController = yt.YoutubePlayerController(
        params: const yt.YoutubePlayerParams(
          showControls: false,
          showFullscreenButton: false,
          mute: false,
          loop: false,
          playsInline: true,
        ),
      );

      await _ytController!.loadVideoById(
        videoId: widget.musicId,
        startSeconds: _startSeconds.toDouble(),
      );

      _ytStateSub = _ytController!.stream.listen((value) {
        if (mounted) {
          final state = value.playerState;
          final isBuffering = state == yt.PlayerState.buffering || state == yt.PlayerState.unStarted;
          final playing = state == yt.PlayerState.playing;
          setState(() {
            _isLoading = isBuffering;
            _isPlaying = playing;
            if (_isPlaying) {
              if (!_discAnimController.isAnimating) _discAnimController.repeat();
              if (!_waveAnimController.isAnimating) _waveAnimController.repeat();
            } else {
              _discAnimController.stop();
              _waveAnimController.stop();
            }
          });
        }
      });

      _ytLoopTimer?.cancel();
      _ytLoopTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) async {
        if (!mounted || _ytController == null) return;
        try {
          final cur = await _ytController!.currentTime;
          final dur = await _ytController!.duration;
          if (dur > 30.0 && dur != _totalTrackDurationSec) {
            if (mounted) {
              setState(() {
                _totalTrackDurationSec = dur;
              });
            }
          }

          final start = _startSeconds.toDouble();
          final end = start + _duration;

          if (mounted) {
            setState(() {
              _currentPlaybackSec = cur;
            });
          }

          // Bucle perfecto dentro del rango recortado [start, start + duration]
          if (_isPlaying && (cur >= end || cur >= _totalTrackDurationSec - 0.25)) {
            _ytController!.seekTo(seconds: start, allowSeekAhead: true);
          }
        } catch (_) {}
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('[Trimmer] Error iniciando YouTube player: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initJustAudioPlayer() async {
    _stateSub = _player.playerStateStream.listen((state) {
      if (mounted) {
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration(seconds: _startSeconds));
          _player.play();
          return;
        }
        final playing = state.playing &&
            state.processingState != ProcessingState.completed;
        setState(() {
          _isPlaying = playing;
          if (_isPlaying) {
            if (!_discAnimController.isAnimating) {
              _discAnimController.repeat();
            }
            if (!_waveAnimController.isAnimating) {
              _waveAnimController.repeat();
            }
          } else {
            _discAnimController.stop();
            _waveAnimController.stop();
          }
        });
      }
    });

    _posSub = _player.positionStream.listen((pos) {
      if (mounted) {
        final sec = pos.inMilliseconds / 1000.0;
        final start = _startSeconds.toDouble();
        final end = start + _duration;

        setState(() {
          _currentPlaybackSec = sec;
        });

        // Bucle perfecto dentro del rango recortado [start, start + duration]
        if (_isPlaying && (sec >= end || sec >= _totalTrackDurationSec - 0.15)) {
          _player.seek(Duration(seconds: _startSeconds));
        }
      }
    });

    try {
      String? streamUrl;

      // 1. Si viene audioUrl directa
      if (widget.audioUrl != null && widget.audioUrl!.startsWith('http')) {
        streamUrl = widget.audioUrl;
      }

      // 2. Si no viene o no es directa, resolver stream completo con fallback
      if (streamUrl == null || streamUrl.isEmpty) {
        final streamData = await MusicService.getFullAudioStream(
          title: widget.title,
          artist: widget.artist,
          videoId: (widget.musicId.length == 11 && !widget.musicId.contains(' ')) ? widget.musicId : null,
          fallbackPreviewUrl: widget.audioUrl,
          expectedDurationSec: widget.totalTrackSeconds,
        );

        if (streamData != null && streamData['url'] != null) {
          streamUrl = streamData['url'].toString();
          if (streamData['durationSeconds'] is int && streamData['durationSeconds'] > 0) {
            _totalTrackDurationSec = (streamData['durationSeconds'] as int).toDouble();
          }
        }
      }

      if (streamUrl != null && streamUrl.isNotEmpty && mounted) {
        _resolvedAudioUrl = streamUrl;
        try {
          final audioSource = await MusicService.createAudioSource(
            streamUrl,
            cacheKey: '${widget.title}_${widget.artist}'.trim(),
          );
          final loadedDuration = await _player.setAudioSource(audioSource);
          _finishTrimmerInit(loadedDuration);
        } catch (err) {
          debugPrint('[Trimmer] Error cargando stream de audio: $err');
          try {
            final fallbackSource = AudioSource.uri(Uri.parse(streamUrl));
            final loadedDuration = await _player.setAudioSource(fallbackSource);
            _finishTrimmerInit(loadedDuration);
          } catch (e2) {
            debugPrint('[Trimmer] Fallback de audio también falló: $e2');
            if (mounted) setState(() => _isLoading = false);
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) print('Error en trimmer audio: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _finishTrimmerInit(Duration? loadedDuration) async {
    if (loadedDuration != null && loadedDuration.inSeconds > 0) {
      _totalTrackDurationSec = loadedDuration.inSeconds.toDouble();
    }

    if (widget.initialDuration <= 0 || widget.initialDuration >= _totalTrackDurationSec.toInt()) {
      _duration = _totalTrackDurationSec.toInt();
    } else {
      _duration = widget.initialDuration.clamp(5, _totalTrackDurationSec.toInt());
    }
    final maxStart = math.max(0.0, _totalTrackDurationSec - _duration);
    _startSeconds = _startSeconds.clamp(0, maxStart.toInt());

    await _player.seek(Duration(seconds: _startSeconds));
    await _player.play();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });
    }
  }

  @override
  void dispose() {
    _ytLoopTimer?.cancel();
    _ytStateSub?.cancel();
    _ytController?.close();
    _waveAnimController.dispose();
    _discAnimController.dispose();
    _pulseAnimController.dispose();
    _seekDebounce?.cancel();
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  double get _maxStart {
    return math.max(0.0, _totalTrackDurationSec - _duration);
  }

  void _onStartChanged(double val) {
    final newStart = val.clamp(0.0, _maxStart).toInt();
    setState(() {
      _startSeconds = newStart;
      _currentPlaybackSec = newStart.toDouble();
      final autoSec =
          MusicService.calculateHighlightStart(_totalTrackDurationSec.toInt());
      _isAutoHighlight = (newStart == 0 || newStart == autoSec);
    });

    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 30), () async {
      if (_isYouTube && _ytController != null) {
        await _ytController!.seekTo(seconds: _startSeconds.toDouble(), allowSeekAhead: true);
        if (!_isPlaying) {
          await _ytController!.playVideo();
        }
      } else {
        await _player.seek(Duration(seconds: _startSeconds));
        if (!_isPlaying) {
          await _player.play();
        }
      }
    });
  }

  void _handleWaveformDrag(double localX, double totalWidth) {
    if (totalWidth <= 0 || _maxStart <= 0) return;
    final ratio = (localX / totalWidth).clamp(0.0, 1.0);
    final targetStart = ratio * _maxStart;
    _onStartChanged(targetStart);
  }

  void _resetToAutoHighlight() {
    final highlightStart =
        MusicService.calculateHighlightStart(_totalTrackDurationSec.toInt());
    final safeStart = highlightStart.clamp(0, _maxStart.toInt());

    setState(() {
      _startSeconds = safeStart;
      _currentPlaybackSec = safeStart.toDouble();
      _isAutoHighlight = true;
    });

    if (_isYouTube && _ytController != null) {
      _ytController!.seekTo(seconds: safeStart.toDouble(), allowSeekAhead: true);
      if (!_isPlaying) {
        _ytController!.playVideo();
      }
    } else {
      _player.seek(Duration(seconds: safeStart));
      if (!_isPlaying) {
        _player.play();
      }
    }
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      if (_isYouTube && _ytController != null) {
        await _ytController!.pauseVideo();
      } else {
        await _player.pause();
      }
    } else {
      if (_isYouTube && _ytController != null) {
        if (_currentPlaybackSec < _startSeconds ||
            _currentPlaybackSec >= _startSeconds + _duration) {
          await _ytController!.seekTo(seconds: _startSeconds.toDouble(), allowSeekAhead: true);
        }
        await _ytController!.playVideo();
      } else {
        if (_currentPlaybackSec < _startSeconds ||
            _currentPlaybackSec >= _startSeconds + _duration) {
          await _player.seek(Duration(seconds: _startSeconds));
        }
        await _player.play();
      }
    }
  }

  String _formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  List<int> get _availableDurations {
    final total = _totalTrackDurationSec.toInt();
    if (total <= 30) {
      return [total];
    } else if (total <= 60) {
      return [15, 30, total];
    } else if (total <= 90) {
      return [15, 30, 60, total];
    } else {
      return [15, 30, 60, 90, total];
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxStart = _maxStart;
    final effectiveTotal = _totalTrackDurationSec;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 25,
            spreadRadius: 2,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_isYouTube && _ytController != null)
            Positioned(
              left: -9999,
              top: -9999,
              width: 1,
              height: 1,
              child: yt.YoutubePlayer(
                controller: _ytController!,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre superior
              Center(
                child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Portada con disco giratorio, info de canción y botón Listo
          Row(
            children: [
              // Portada de disco giratoria limpia
              AnimatedBuilder(
                animation: Listenable.merge([_pulseAnim, _discAnimController]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isPlaying ? _pulseAnim.value : 1.0,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _isPlaying
                                ? const Color(0xFF0094FF).withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: _isPlaying ? 12 : 6,
                            spreadRadius: _isPlaying ? 1 : 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: _discAnimController.value * 2 * math.pi,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: CachedNetworkImage(
                                imageUrl: MusicService.getCleanThumbnail(
                                  widget.musicId,
                                  widget.thumbnail,
                                ),
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  width: 52,
                                  height: 52,
                                  color: const Color(0xFF1E293B),
                                  child: const Icon(Icons.music_note,
                                      color: Color(0xFF0094FF)),
                                ),
                                errorWidget: (_, url, _) {
                                  final cleanId = widget.musicId.trim();
                                  final fallbackUrl = 'https://i.ytimg.com/vi/$cleanId/mqdefault.jpg';
                                  if (url != fallbackUrl && cleanId.length == 11) {
                                    return CachedNetworkImage(
                                      imageUrl: fallbackUrl,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        width: 52,
                                        height: 52,
                                        color: const Color(0xFF1E293B),
                                        child: const Icon(Icons.music_note,
                                            color: Color(0xFF0094FF)),
                                      ),
                                    );
                                  }
                                  return Container(
                                    width: 52,
                                    height: 52,
                                    color: const Color(0xFF1E293B),
                                    child: const Icon(Icons.music_note,
                                        color: Color(0xFF0094FF)),
                                  );
                                },
                              ),
                            ),
                          ),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFF0094FF),
                                width: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),

              // Título y Artista con tipografía CanvaSans
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (_isPlaying) ...[
                          _AnimatedEqualizerDots(),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            widget.artist,
                            style: TextStyle(
                              fontFamily: 'CanvaSans',
                              fontSize: 12.5,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Botón Listo
              _BouncingWidget(
                onTap: () {
                  if (_isYouTube && _ytController != null) {
                    _ytController!.pauseVideo();
                  } else {
                    _player.stop();
                  }
                  Navigator.pop(context, {
                    'startSeconds': _startSeconds,
                    'duration': _duration,
                    'totalDuration': _totalTrackDurationSec.toInt(),
                    'audioUrl': _resolvedAudioUrl ?? widget.audioUrl ?? '',
                    'resolvedAudioUrl': _resolvedAudioUrl,
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0094FF), Color(0xFF00B4FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0094FF).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Listo',
                    style: TextStyle(
                      fontFamily: 'CanvaSans',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Selector de duración del fragmento y botón de Parte más destacada
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chips de duración dinámica
              Row(
                children: _availableDurations.map((dur) {
                  final isSelected = _duration == dur;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _BouncingWidget(
                      onTap: () {
                        setState(() {
                          _duration = dur;
                          if (_startSeconds > _maxStart) {
                            _startSeconds = _maxStart.toInt();
                          }
                          _currentPlaybackSec = _startSeconds.toDouble();
                        });
                        if (_isYouTube && _ytController != null) {
                          _ytController!.seekTo(seconds: _startSeconds.toDouble(), allowSeekAhead: true);
                        } else {
                          _player.seek(Duration(seconds: _startSeconds));
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6.5),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF0094FF),
                                    Color(0xFF00B4FF)
                                  ],
                                )
                              : null,
                          color: isSelected ? null : const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0094FF)
                                : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF0094FF)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          dur == _totalTrackDurationSec.toInt()
                              ? 'Completa'
                              : '${dur}s',
                          style: TextStyle(
                            fontFamily: 'CanvaSans',
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Botón "Parte destacada / Auto"
              _BouncingWidget(
                onTap: _resetToAutoHighlight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6.5),
                  decoration: BoxDecoration(
                    color: _isAutoHighlight
                        ? const Color(0xFFFF6B00).withValues(alpha: 0.12)
                        : const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAutoHighlight
                          ? const Color(0xFFFF6B00).withValues(alpha: 0.5)
                          : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 15,
                        color: _isAutoHighlight
                            ? const Color(0xFFFF6B00)
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Destacada',
                        style: TextStyle(
                          fontFamily: 'CanvaSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _isAutoHighlight
                              ? const Color(0xFFFF6B00)
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visualizador de onda de sonido (Waveform) interactivo
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) =>
                    _handleWaveformDrag(details.localPosition.dx, w),
                onHorizontalDragUpdate: (details) =>
                    _handleWaveformDrag(details.localPosition.dx, w),
                onTapDown: (details) =>
                    _handleWaveformDrag(details.localPosition.dx, w),
                child: Container(
                  height: 72,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedBuilder(
                      animation: _waveAnimController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _CleanWaveformPainter(
                            progress:
                                (_startSeconds / effectiveTotal).clamp(0.0, 1.0),
                            windowRatio:
                                (_duration / effectiveTotal).clamp(0.0, 1.0),
                            playbackProgress: ((_currentPlaybackSec -
                                        _startSeconds) /
                                    (_duration > 0 ? _duration : 1))
                                .clamp(0.0, 1.0),
                            wavePhase: _waveAnimController.value,
                            isPlaying: _isPlaying,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Slider / Deslizador de posición fluido
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF0094FF),
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: const Color(0xFF0094FF),
              overlayColor: const Color(0xFF0094FF).withValues(alpha: 0.18),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 4,
            ),
            child: Slider(
              value: _startSeconds
                  .toDouble()
                  .clamp(0.0, math.max(0.001, maxStart)),
              min: 0.0,
              max: math.max(0.001, maxStart),
              onChanged: maxStart > 0 ? _onStartChanged : null,
            ),
          ),

          // Marcadores de tiempo y botón de Play/Pause
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fragmento: ${_formatTime(_startSeconds)} - ${_formatTime((_startSeconds + _duration).clamp(0, effectiveTotal.toInt()))} ($_duration s)',
                      style: const TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0094FF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Duración de la canción: ${_formatTime(effectiveTotal.toInt())}',
                      style: TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 11.5,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                _BouncingWidget(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0094FF), Color(0xFF00B4FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0094FF)
                              .withValues(alpha: _isPlaying ? 0.45 : 0.25),
                          blurRadius: _isPlaying ? 12 : 6,
                          spreadRadius: _isPlaying ? 1 : 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }
}

/// Mini indicador animado de ecualizador de 3 barras ultra-suave
class _AnimatedEqualizerDots extends StatefulWidget {
  @override
  State<_AnimatedEqualizerDots> createState() => _AnimatedEqualizerDotsState();
}

class _AnimatedEqualizerDotsState extends State<_AnimatedEqualizerDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: dynamicCrossAxisAlignment(t),
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(4 + t * 7),
            const SizedBox(width: 2.2),
            _bar(11 - t * 7),
            const SizedBox(width: 2.2),
            _bar(5 + t * 5),
          ],
        );
      },
    );
  }

  MainAxisSize dynamicCrossAxisAlignment(double t) => MainAxisSize.min;

  Widget _bar(double h) {
    return Container(
      width: 2.4,
      height: h.clamp(3.0, 14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0094FF),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Widget interactivo con micro-rebote al presionar
class _BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncingWidget({required this.child, required this.onTap});

  @override
  State<_BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<_BouncingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Painter de onda de sonido profesional y nítido para CONNECT
/// - Estático cuando está pausado (sin bailes falsos)
/// - Reacciona dinámicamente en el fragmento activo solo al reproducir
class _CleanWaveformPainter extends CustomPainter {
  final double progress;
  final double windowRatio;
  final double playbackProgress;
  final double wavePhase;
  final bool isPlaying;

  _CleanWaveformPainter({
    required this.progress,
    required this.windowRatio,
    required this.playbackProgress,
    required this.wavePhase,
    required this.isPlaying,
  });

  // Perfil de amplitud armónico realista para 52 barras
  static const List<double> _waveformHeights = [
    0.28, 0.35, 0.52, 0.68, 0.82, 0.55, 0.42, 0.72, 0.90, 0.84,
    0.62, 0.48, 0.78, 0.92, 0.96, 0.75, 0.58, 0.40, 0.65, 0.88,
    0.78, 0.52, 0.44, 0.70, 0.86, 0.95, 0.80, 0.60, 0.45, 0.68,
    0.85, 0.92, 0.76, 0.54, 0.42, 0.64, 0.80, 0.90, 0.78, 0.50,
    0.38, 0.62, 0.82, 0.88, 0.70, 0.52, 0.40, 0.60, 0.75, 0.58,
    0.42, 0.30
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _waveformHeights.length;
    final totalSpacing = size.width / barCount;
    final barWidth = totalSpacing * 0.55;

    final windowStart = progress * size.width;
    final windowEnd = (progress + windowRatio).clamp(0.0, 1.0) * size.width;

    // 1. Fondo de la ventana seleccionada
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(windowStart, 4, windowEnd, size.height - 4),
      const Radius.circular(10),
    );

    final windowPaint = Paint()
      ..color = const Color(0xFF0094FF).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(windowRect, windowPaint);

    final windowBorderPaint = Paint()
      ..color = const Color(0xFF0094FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(windowRect, windowBorderPaint);

    // Asas laterales
    final handlePaint = Paint()
      ..color = const Color(0xFF0094FF)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(windowStart, size.height / 2),
          width: 3.5,
          height: 18,
        ),
        const Radius.circular(2),
      ),
      handlePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(windowEnd, size.height / 2),
          width: 3.5,
          height: 18,
        ),
        const Radius.circular(2),
      ),
      handlePaint,
    );

    // 2. Playhead indicador de posición
    final playHeadX =
        windowStart + (windowEnd - windowStart) * playbackProgress;
    if (playHeadX >= windowStart && playHeadX <= windowEnd) {
      final playHeadPaint = Paint()
        ..color = const Color(0xFF0094FF)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(playHeadX, 4),
        Offset(playHeadX, size.height - 4),
        playHeadPaint,
      );

      final dotPaint = Paint()
        ..color = const Color(0xFF0094FF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(playHeadX, 5), 3.2, dotPaint);
    }

    // 3. Barras de onda
    for (int i = 0; i < barCount; i++) {
      final x = i * totalSpacing + (totalSpacing - barWidth) / 2;
      final inWindow = x >= windowStart && x <= windowEnd;

      double hFactor = _waveformHeights[i];

      // Si está reproduciendo y está dentro de la ventana activa, micro-onda sutil
      if (isPlaying && inWindow) {
        final dynamicWave = math.sin(wavePhase * 2 * math.pi + i * 0.5) * 0.12;
        hFactor = (hFactor + dynamicWave).clamp(0.2, 1.0);
      }

      final h = hFactor * (size.height - 20);
      final y = (size.height - h) / 2;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        Radius.circular(barWidth / 2),
      );

      final barPaint = Paint()..style = PaintingStyle.fill;
      if (inWindow) {
        barPaint.shader = const LinearGradient(
          colors: [Color(0xFF00C3FF), Color(0xFF0094FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(x, y, barWidth, h));
      } else {
        barPaint.color = const Color(0xFFCBD5E1);
      }

      canvas.drawRRect(barRect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CleanWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.windowRatio != windowRatio ||
        oldDelegate.playbackProgress != playbackProgress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.isPlaying != isPlaying;
  }
}
