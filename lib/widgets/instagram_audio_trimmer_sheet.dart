import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/music_service.dart';

/// Hoja modal estilo Instagram para seleccionar y recortar el fragmento de audio
/// sobre la canción completa con ondas de sonido interactivas y selección automática del fragmento más escuchado.
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

class _InstagramAudioTrimmerSheetState extends State<InstagramAudioTrimmerSheet> {
  final AudioPlayer _player = AudioPlayer();
  late int _startSeconds;
  late int _duration;
  bool _isPlaying = false;
  bool _isLoading = true;
  double _totalTrackDurationSec = 180.0;
  bool _isAutoHighlight = true;
  double _currentPlaybackSec = 0.0;

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

    // Si no se proporcionó un inicio manual, calcular automáticamente el punto más escuchado (estribillo/coro)
    final autoHighlight = MusicService.calculateHighlightStart(_totalTrackDurationSec.toInt());
    if (widget.initialStartSeconds > 0) {
      _startSeconds = widget.initialStartSeconds;
      _isAutoHighlight = (_startSeconds == autoHighlight);
    } else {
      _startSeconds = autoHighlight;
      _isAutoHighlight = true;
    }
    _currentPlaybackSec = _startSeconds.toDouble();

    _initAudio();
  }

  Future<void> _initAudio() async {
    _stateSub = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
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
            _startSeconds = MusicService.calculateHighlightStart(_totalTrackDurationSec.toInt());
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
    _seekDebounce?.cancel();
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  double get _maxStart {
    final effectiveTotal = _totalTrackDurationSec > _duration ? _totalTrackDurationSec : (_duration + 120.0);
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
    _seekDebounce = Timer(const Duration(milliseconds: 150), () {
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
    final auto = MusicService.calculateHighlightStart(_totalTrackDurationSec.toInt());
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
    final effectiveTotal = _totalTrackDurationSec > _duration ? _totalTrackDurationSec : (_duration + 120.0);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16181F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de arrastre superior
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Información de la canción y botón Listo
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: widget.thumbnail,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 52,
                    height: 52,
                    color: Colors.white12,
                    child: const Icon(Icons.music_note, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 2),
                    Text(
                      widget.artist,
                      style: TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _player.stop();
                  Navigator.pop(context, {
                    'startSeconds': _startSeconds,
                    'duration': _duration,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0094FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                ),
                child: const Text(
                  'Listo',
                  style: TextStyle(
                    fontFamily: 'CanvaSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Selector de duración del fragmento y botón de fragmento destacado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chips de duración (15s, 30s, 60s)
              Row(
                children: [15, 30, 60].map((dur) {
                  final isSelected = _duration == dur;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _duration = dur;
                          if (_startSeconds > _maxStart) {
                            _startSeconds = _maxStart.toInt();
                          }
                        });
                        _player.seek(Duration(seconds: _startSeconds));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0094FF) : Colors.white10,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0094FF) : Colors.white12,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${dur}s',
                          style: TextStyle(
                            fontFamily: 'CanvaSans',
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Indicador de "Parte más escuchada" / Botón para restaurar auto highlight
              GestureDetector(
                onTap: _resetToAutoHighlight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isAutoHighlight
                        ? const Color(0xFFFF6B00).withValues(alpha: 0.18)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAutoHighlight ? const Color(0xFFFF6B00) : Colors.white12,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: _isAutoHighlight ? const Color(0xFFFF6B00) : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isAutoHighlight ? 'Parte más escuchada' : 'Auto',
                        style: TextStyle(
                          fontFamily: 'CanvaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isAutoHighlight ? const Color(0xFFFF6B00) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Visualizador de onda de sonido (Waveform) interactivo y deslizable
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) => _handleWaveformDrag(details.localPosition.dx, w),
                onHorizontalDragUpdate: (details) => _handleWaveformDrag(details.localPosition.dx, w),
                onTapDown: (details) => _handleWaveformDrag(details.localPosition.dx, w),
                child: Container(
                  height: 58,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: _WaveformPainter(
                        progress: (_startSeconds / effectiveTotal).clamp(0.0, 1.0),
                        windowRatio: (_duration / effectiveTotal).clamp(0.0, 1.0),
                        playbackProgress: ((_currentPlaybackSec - _startSeconds) / (_duration > 0 ? _duration : 1)).clamp(0.0, 1.0),
                      ),
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
              overlayColor: const Color(0xFF0094FF).withValues(alpha: 0.2),
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

          // Marcadores de tiempo y botón de Play/Pause
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
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0094FF),
                      shape: BoxShape.circle,
                    ),
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
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
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

class _WaveformPainter extends CustomPainter {
  final double progress;
  final double windowRatio;
  final double playbackProgress;

  _WaveformPainter({
    required this.progress,
    required this.windowRatio,
    required this.playbackProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 46;
    final barWidth = size.width / (barCount * 1.5);
    final gap = barWidth * 0.5;

    final windowStart = progress * size.width;
    final windowEnd = (progress + windowRatio).clamp(0.0, 1.0) * size.width;

    // Alturas de ondas dinámicas estéticas
    final heights = [
      0.3, 0.5, 0.8, 0.4, 0.9, 0.6, 0.85, 0.45, 0.65, 0.95,
      0.75, 0.4, 0.8, 0.55, 0.9, 0.6, 0.7, 0.45, 0.6, 0.85,
      0.4, 0.75, 0.95, 0.5, 0.8, 0.65, 0.4, 0.9, 0.7, 0.55,
      0.85, 0.6, 0.9, 0.45, 0.7, 0.5, 0.8, 0.6, 0.4, 0.75,
      0.5, 0.8, 0.6, 0.7, 0.4, 0.85,
    ];

    // 1. Dibujar ventana activa seleccionada
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(windowStart, 4, windowEnd, size.height - 4),
      const Radius.circular(8),
    );
    final windowPaint = Paint()
      ..color = const Color(0xFF0094FF).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(windowRect, windowPaint);

    final windowBorderPaint = Paint()
      ..color = const Color(0xFF0094FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(windowRect, windowBorderPaint);

    // Indicador de cabezal de reproducción
    final playHeadX = windowStart + (windowEnd - windowStart) * playbackProgress;
    if (playHeadX >= windowStart && playHeadX <= windowEnd) {
      final playHeadPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(playHeadX, 6), Offset(playHeadX, size.height - 6), playHeadPaint);
    }

    // 2. Dibujar barras de onda
    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + gap) + gap;
      final h = heights[i % heights.length] * (size.height - 14);
      final y = (size.height - h) / 2;

      final inWindow = x >= windowStart && x <= windowEnd;
      final paint = Paint()
        ..color = inWindow ? const Color(0xFF0094FF) : Colors.white24
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth;

      canvas.drawLine(Offset(x, y), Offset(x, y + h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.windowRatio != windowRatio ||
        oldDelegate.playbackProgress != playbackProgress;
  }
}
