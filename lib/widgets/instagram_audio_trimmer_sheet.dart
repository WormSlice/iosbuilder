import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/music_service.dart';

/// Hoja modal estilo Instagram para seleccionar y recortar el fragmento de audio
/// sobre la canción completa con ondas de sonido interactivas y ultra-fluidas a 60fps.
class InstagramAudioTrimmerSheet extends StatefulWidget {
  final String musicId;
  final String title;
  final String artist;
  final String thumbnail;
  final int totalTrackSeconds;
  final int initialStartSeconds;
  final int initialDuration;

  const InstagramAudioTrimmerSheet({
    super.key,
    required this.musicId,
    required this.title,
    required this.artist,
    required this.thumbnail,
    this.totalTrackSeconds = 180,
    this.initialStartSeconds = 0,
    this.initialDuration = 30,
  });

  static Future<Map<String, int>?> show({
    required BuildContext context,
    required String musicId,
    required String title,
    required String artist,
    required String thumbnail,
    int totalTrackSeconds = 180,
    int initialStartSeconds = 0,
    int initialDuration = 30,
  }) {
    return showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InstagramAudioTrimmerSheet(
        musicId: musicId,
        title: title,
        artist: artist,
        thumbnail: thumbnail,
        totalTrackSeconds: totalTrackSeconds,
        initialStartSeconds: initialStartSeconds,
        initialDuration: initialDuration,
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
  late int _startSeconds;
  late int _duration;
  bool _isPlaying = false;
  bool _isLoading = true;
  double _totalTrackDurationSec = 180.0;
  bool _isAutoHighlight = true;
  double _currentPlaybackSec = 0.0;

  // Controladores de animación fluida
  late AnimationController _waveAnimController;
  late AnimationController _ambientAnimController;
  late AnimationController _discAnimController;
  late AnimationController _pulseAnimController;
  late Animation<double> _pulseAnim;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  Timer? _seekDebounce;

  @override
  void initState() {
    super.initState();
    _totalTrackDurationSec = widget.totalTrackSeconds > 30
        ? widget.totalTrackSeconds.toDouble()
        : 180.0;
    _duration = widget.initialDuration;

    final autoHighlight =
        MusicService.calculateHighlightStart(_totalTrackDurationSec.toInt());
    if (widget.initialStartSeconds > 0) {
      _startSeconds = widget.initialStartSeconds;
      _isAutoHighlight = (_startSeconds == autoHighlight);
    } else {
      _startSeconds = autoHighlight;
      _isAutoHighlight = true;
    }
    _currentPlaybackSec = _startSeconds.toDouble();

    // 1. Animación continua de ondas dinámicas al reproducir (60fps)
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // 2. Animación de brillo ambiental continuo (incluso en pausa)
    _ambientAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    // 3. Animación de disco de vinilo continuo al reproducir
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // 4. Pulso suave para portada y badges
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseAnimController, curve: Curves.easeInOut),
    );

    _initAudio();
  }

  Future<void> _initAudio() async {
    _stateSub = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (_isPlaying) {
            if (!_discAnimController.isAnimating) {
              _discAnimController.repeat();
            }
          } else {
            _discAnimController.stop();
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

        if (_isPlaying && sec >= end) {
          _player.seek(Duration(seconds: _startSeconds));
        }
      }
    });

    try {
      final url = await MusicService.getAudioStreamUrl(
        widget.musicId,
        title: widget.title,
        artist: widget.artist,
        forceFullTrack: true,
      );

      if (url != null && mounted) {
        final loadedDuration = await _player.setUrl(url);
        if (loadedDuration != null && loadedDuration.inSeconds > 30) {
          _totalTrackDurationSec = loadedDuration.inSeconds.toDouble();
          if (_isAutoHighlight) {
            _startSeconds = MusicService.calculateHighlightStart(
                _totalTrackDurationSec.toInt());
          }
        }
        await _player.seek(Duration(seconds: _startSeconds));
        await _player.play();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isPlaying = true;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _ambientAnimController.dispose();
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
    final effectiveTotal = _totalTrackDurationSec > _duration
        ? _totalTrackDurationSec
        : (_duration + 120.0);
    return math.max(1.0, effectiveTotal - _duration);
  }

  void _onStartChanged(double val) {
    final newStart = val.clamp(0.0, _maxStart).toInt();
    setState(() {
      _startSeconds = newStart;
      _currentPlaybackSec = newStart.toDouble();
      _isAutoHighlight = false;
    });

    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 140), () {
      _player.seek(Duration(seconds: _startSeconds));
      if (!_isPlaying) {
        _player.play();
      }
    });
  }

  void _handleWaveformDrag(double localX, double totalWidth) {
    if (totalWidth <= 0) return;
    final ratio = (localX / totalWidth).clamp(0.0, 1.0);
    final targetStart = ratio * _maxStart;
    _onStartChanged(targetStart);
  }

  void _resetToAutoHighlight() {
    final auto =
        MusicService.calculateHighlightStart(_totalTrackDurationSec.toInt());
    setState(() {
      _startSeconds = auto.clamp(0, _maxStart.toInt());
      _currentPlaybackSec = _startSeconds.toDouble();
      _isAutoHighlight = true;
    });
    _player.seek(Duration(seconds: _startSeconds));
    if (!_isPlaying) {
      _player.play();
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.seek(Duration(seconds: _startSeconds));
      _player.play();
    }
  }

  String _formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final maxStart = _maxStart;
    final effectiveTotal = _totalTrackDurationSec > _duration
        ? _totalTrackDurationSec
        : (_duration + 120.0);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12141A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de arrastre superior
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Información de la canción animada, vinilo giratorio y botón Listo
          Row(
            children: [
              // Portada con animación suave de disco vinilo + pulso de brillo
              AnimatedBuilder(
                animation: Listenable.merge([_pulseAnim, _discAnimController]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isPlaying ? _pulseAnim.value : 1.0,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: _isPlaying
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0094FF)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 3,
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Disco de vinilo giratorio
                          Transform.rotate(
                            angle: _discAnimController.value * 2 * math.pi,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(27),
                              child: CachedNetworkImage(
                                imageUrl: widget.thumbnail,
                                width: 54,
                                height: 54,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  width: 54,
                                  height: 54,
                                  color: Colors.white12,
                                  child: const Icon(Icons.music_note,
                                      color: Colors.white),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  width: 54,
                                  height: 54,
                                  color: Colors.white12,
                                  child: const Icon(Icons.music_note,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          // Centro del vinilo
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF12141A),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 1.5,
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

              // Título y Artista con ecualizador animado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
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

              // Botón Listo con micro-animación al presionar
              _BouncingWidget(
                onTap: () {
                  _player.stop();
                  Navigator.pop(context, {
                    'startSeconds': _startSeconds,
                    'duration': _duration,
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0094FF), Color(0xFF00C3FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0094FF).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Listo',
                    style: TextStyle(
                      fontFamily: 'CanvaSans',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Selector de duración del fragmento y botón de fragmento destacado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chips de duración (15s, 30s, 60s) con animación fluida
              Row(
                children: [15, 30, 60].map((dur) {
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
                        });
                        _player.seek(Duration(seconds: _startSeconds));
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF0094FF),
                                    Color(0xFF00B4FF)
                                  ],
                                )
                              : null,
                          color: isSelected ? null : Colors.white10,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0094FF)
                                : Colors.white12,
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF0094FF)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '${dur}s',
                          style: TextStyle(
                            fontFamily: 'CanvaSans',
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Indicador animado de "Parte más escuchada" / Botón Auto
              _BouncingWidget(
                onTap: _resetToAutoHighlight,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _isAutoHighlight
                            ? const Color(0xFFFF6B00).withValues(alpha: 0.18)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isAutoHighlight
                              ? const Color(0xFFFF6B00)
                              : Colors.white12,
                          width: 1,
                        ),
                        boxShadow: _isAutoHighlight
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF6B00)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(
                            scale: _isAutoHighlight ? _pulseAnim.value : 1.0,
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              size: 16,
                              color: _isAutoHighlight
                                  ? const Color(0xFFFF6B00)
                                  : Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isAutoHighlight ? 'Parte más escuchada' : 'Auto',
                            style: TextStyle(
                              fontFamily: 'CanvaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isAutoHighlight
                                  ? const Color(0xFFFF6B00)
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Visualizador de onda de sonido (Waveform) interactivo, deslizable y animado a 60fps
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
                  height: 66,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.09)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          [_waveAnimController, _ambientAnimController]),
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _DynamicWaveformPainter(
                            progress:
                                (_startSeconds / effectiveTotal).clamp(0.0, 1.0),
                            windowRatio:
                                (_duration / effectiveTotal).clamp(0.0, 1.0),
                            playbackProgress: ((_currentPlaybackSec -
                                        _startSeconds) /
                                    (_duration > 0 ? _duration : 1))
                                .clamp(0.0, 1.0),
                            wavePhase: _waveAnimController.value,
                            ambientPhase: _ambientAnimController.value,
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
          const SizedBox(height: 12),

          // Slider / Deslizador de posición a lo largo de TODA la canción
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF0094FF),
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF0094FF).withValues(alpha: 0.25),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              trackHeight: 4,
            ),
            child: Slider(
              value: _startSeconds.toDouble().clamp(0.0, maxStart),
              min: 0.0,
              max: maxStart,
              onChanged: _onStartChanged,
            ),
          ),

          // Marcadores de tiempo y botón de Play/Pause con animación fluida
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fragmento: ${_formatTime(_startSeconds)} - ${_formatTime((_startSeconds + _duration).clamp(0, effectiveTotal.toInt()))} ($_duration seg)',
                      style: const TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0094FF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Canción completa: ${_formatTime(effectiveTotal.toInt())}',
                      style: TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                _BouncingWidget(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0094FF), Color(0xFF00C3FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0094FF)
                              .withValues(alpha: _isPlaying ? 0.5 : 0.25),
                          blurRadius: _isPlaying ? 14 : 6,
                          spreadRadius: _isPlaying ? 2 : 0,
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: child,
                            ),
                            child: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey<bool>(_isPlaying),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Micro-widget interactivo con efecto de rebote elástico suave al presionar
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
      duration: const Duration(milliseconds: 100),
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
          mainAxisSize: MainAxisSize.min,
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

/// Painter de onda de sonido dinámico con modulación continua, gradientes y animaciones 60fps
class _DynamicWaveformPainter extends CustomPainter {
  final double progress;
  final double windowRatio;
  final double playbackProgress;
  final double wavePhase;
  final double ambientPhase;
  final bool isPlaying;

  _DynamicWaveformPainter({
    required this.progress,
    required this.windowRatio,
    required this.playbackProgress,
    required this.wavePhase,
    required this.ambientPhase,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 52;
    final totalSpacing = size.width / barCount;
    final barWidth = totalSpacing * 0.58;

    final windowStart = progress * size.width;
    final windowEnd = (progress + windowRatio).clamp(0.0, 1.0) * size.width;

    // Alturas base de onda de espectro musical armónico
    final baseHeights = [
      0.28, 0.45, 0.75, 0.38, 0.88, 0.58, 0.82, 0.42, 0.65, 0.94,
      0.72, 0.38, 0.78, 0.52, 0.90, 0.58, 0.68, 0.42, 0.60, 0.82,
      0.38, 0.74, 0.95, 0.48, 0.78, 0.62, 0.38, 0.88, 0.68, 0.52,
      0.82, 0.58, 0.88, 0.42, 0.68, 0.48, 0.78, 0.58, 0.38, 0.74,
      0.48, 0.78, 0.58, 0.68, 0.38, 0.82, 0.58, 0.48, 0.68, 0.85,
      0.55, 0.35,
    ];

    // 1. Dibujar ventana activa seleccionada con fondo luminoso y bordes suaves
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(windowStart, 4, windowEnd, size.height - 4),
      const Radius.circular(10),
    );

    // Fondo degradado de la ventana activa
    final windowGradient = LinearGradient(
      colors: [
        const Color(0xFF0094FF).withValues(alpha: 0.22),
        const Color(0xFF00C3FF).withValues(alpha: 0.12),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    final windowPaint = Paint()
      ..shader = windowGradient.createShader(
        Rect.fromLTRB(windowStart, 4, windowEnd, size.height - 4),
      )
      ..style = PaintingStyle.fill;
    canvas.drawRRect(windowRect, windowPaint);

    // Borde de la ventana activa
    final windowBorderPaint = Paint()
      ..color = const Color(0xFF0094FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(windowRect, windowBorderPaint);

    // Asas laterales para el recorte táctil
    final leftHandlePaint = Paint()
      ..color = const Color(0xFF00C3FF)
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
      leftHandlePaint,
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
      leftHandlePaint,
    );

    // 2. Dibujar cabezal de reproducción animado (Láser de reproducción)
    final playHeadX =
        windowStart + (windowEnd - windowStart) * playbackProgress;
    if (playHeadX >= windowStart && playHeadX <= windowEnd) {
      // Halo brillante del playhead
      final laserGlow = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(playHeadX, 6),
        Offset(playHeadX, size.height - 6),
        laserGlow,
      );

      final playHeadPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(playHeadX, 4),
        Offset(playHeadX, size.height - 4),
        playHeadPaint,
      );

      // Pequeño punto brillante superior
      final dotPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(playHeadX, 5), 3.2, dotPaint);
    }

    // 3. Dibujar barras de onda animadas y fluidas
    for (int i = 0; i < barCount; i++) {
      final x = i * totalSpacing + (totalSpacing - barWidth) / 2;
      final inWindow = x >= windowStart && x <= windowEnd;

      double hFactor = baseHeights[i % baseHeights.length];

      // Animación continua viva: brillo ambiental suave siempre activo
      final ambientShimmer =
          math.sin(ambientPhase * 2 * math.pi + i * 0.25) * 0.08;
      hFactor = (hFactor + ambientShimmer).clamp(0.15, 1.0);

      // Si está reproduciendo, sumar dinámica armónica de onda sonora en tiempo real
      if (isPlaying && inWindow) {
        final dynamicWave = math.sin(wavePhase * 2 * math.pi + i * 0.45) * 0.22 +
            math.cos(wavePhase * 4 * math.pi + i * 0.8) * 0.10;
        hFactor = (hFactor + dynamicWave).clamp(0.2, 1.0);
      }

      final h = hFactor * (size.height - 16);
      final y = (size.height - h) / 2;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        Radius.circular(barWidth / 2),
      );

      final barPaint = Paint()..style = PaintingStyle.fill;

      if (inWindow) {
        barPaint.shader = const LinearGradient(
          colors: [Color(0xFF00E5FF), Color(0xFF0094FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(x, y, barWidth, h));
      } else {
        barPaint.color = Colors.white.withValues(alpha: 0.18);
      }

      canvas.drawRRect(barRect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DynamicWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.windowRatio != windowRatio ||
        oldDelegate.playbackProgress != playbackProgress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.ambientPhase != ambientPhase ||
        oldDelegate.isPlaying != isPlaying;
  }
}
