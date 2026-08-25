import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/music_service.dart';

/// Hoja modal estilo Instagram para seleccionar el fragmento de audio
/// con ondas de sonido interactivas, duración y bucle en tiempo real.
class InstagramAudioTrimmerSheet extends StatefulWidget {
  final String musicId;
  final String title;
  final String artist;
  final String thumbnail;
  final int initialStartSeconds;
  final int initialDuration;

  const InstagramAudioTrimmerSheet({
    super.key,
    required this.musicId,
    required this.title,
    required this.artist,
    required this.thumbnail,
    this.initialStartSeconds = 0,
    this.initialDuration = 30,
  });

  static Future<Map<String, int>?> show({
    required BuildContext context,
    required String musicId,
    required String title,
    required String artist,
    required String thumbnail,
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
  double _totalTrackDurationSec = 30.0; // Preview duration standard is 30s

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _startSeconds = widget.initialStartSeconds;
    _duration = widget.initialDuration;
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
      if (_isPlaying) {
        final start = Duration(seconds: _startSeconds);
        final end = Duration(seconds: _startSeconds + _duration);
        if (pos >= end) {
          _player.seek(start);
        }
      }
    });

    final url = await MusicService.getAudioStreamUrl(widget.musicId);
    if (url != null && mounted) {
      try {
        final duration = await _player.setUrl(url);
        if (duration != null) {
          _totalTrackDurationSec = duration.inSeconds.toDouble().clamp(15.0, 300.0);
        }
        await _player.seek(Duration(seconds: _startSeconds));
        await _player.play();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isPlaying = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  void _onStartChanged(double val) {
    setState(() {
      _startSeconds = val.toInt();
    });
    _player.seek(Duration(seconds: _startSeconds));
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
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final maxStart = (_totalTrackDurationSec - _duration).clamp(0.0, _totalTrackDurationSec);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF181A20),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Song info & Done button
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.thumbnail,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white),
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
                        fontSize: 16,
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
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          const SizedBox(height: 24),

          // Duration picker pills (15s, 30s)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [15, 30].map((dur) {
              final isSelected = _duration == dur;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _duration = dur;
                      if (_startSeconds > _totalTrackDurationSec - _duration) {
                        _startSeconds = (_totalTrackDurationSec - _duration).clamp(0, _totalTrackDurationSec).toInt();
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
                        color: isSelected ? const Color(0xFF0094FF) : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${dur}s',
                      style: TextStyle(
                        fontFamily: 'Poppins',
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
          const SizedBox(height: 20),

          // Waveform simulation bar
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              painter: _WaveformPainter(
                progress: _startSeconds / (_totalTrackDurationSec > 0 ? _totalTrackDurationSec : 1),
                windowRatio: _duration / (_totalTrackDurationSec > 0 ? _totalTrackDurationSec : 1),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Draggable Scrubber Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF0094FF),
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF0094FF).withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              trackHeight: 4,
            ),
            child: Slider(
              value: _startSeconds.toDouble().clamp(0.0, maxStart > 0 ? maxStart : 0.0),
              min: 0.0,
              max: maxStart > 0 ? maxStart : 0.0,
              divisions: maxStart > 0 ? maxStart.toInt() : null,
              onChanged: maxStart > 0 ? _onStartChanged : null,
            ),
          ),

          // Time indicator and Play/Pause control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatTime(_startSeconds)} - ${_formatTime((_startSeconds + _duration).clamp(0, _totalTrackDurationSec.toInt()))}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0094FF),
                  ),
                ),
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(8),
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
                            size: 20,
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

  _WaveformPainter({required this.progress, required this.windowRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 40;
    final barWidth = size.width / (barCount * 1.5);
    final gap = barWidth * 0.5;

    final windowStart = progress * size.width;
    final windowEnd = (progress + windowRatio).clamp(0.0, 1.0) * size.width;

    // Simulated waveform heights
    final heights = [
      0.3, 0.5, 0.7, 0.4, 0.9, 0.6, 0.8, 0.4, 0.6, 0.9,
      0.7, 0.4, 0.8, 0.5, 0.9, 0.6, 0.7, 0.4, 0.6, 0.8,
      0.4, 0.7, 0.9, 0.5, 0.8, 0.6, 0.4, 0.9, 0.7, 0.5,
      0.8, 0.6, 0.9, 0.4, 0.7, 0.5, 0.8, 0.6, 0.4, 0.7,
    ];

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + gap) + gap;
      final h = heights[i % heights.length] * size.height * 0.8;
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
    return oldDelegate.progress != progress || oldDelegate.windowRatio != windowRatio;
  }
}
