import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/music_service.dart';

class MusicPlayerPill extends StatefulWidget {
  final String musicId;
  final String musicTitle;
  final String musicArtist;
  final String musicThumbnail;
  final int startSeconds;
  final int duration;

  const MusicPlayerPill({
    super.key,
    required this.musicId,
    required this.musicTitle,
    required this.musicArtist,
    required this.musicThumbnail,
    required this.startSeconds,
    this.duration = 30,
  });

  @override
  State<MusicPlayerPill> createState() => _MusicPlayerPillState();
}

class _MusicPlayerPillState extends State<MusicPlayerPill> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  
  // Ajustes de música
  bool _isMuted = false;
  bool _isVolumeLimitEnabled = false;
  double _maxVolumeLimit = 0.5;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndInitAudio();
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndInitAudio() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isMuted = prefs.getBool('music_muted_globally') ?? false;
        _isVolumeLimitEnabled = prefs.getBool('music_volume_limit_enabled') ?? false;
        _maxVolumeLimit = prefs.getDouble('music_max_volume_limit') ?? 0.5;
      });
    }
    await _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      _player.onPositionChanged.listen((pos) {
        final start = Duration(seconds: widget.startSeconds);
        final end = Duration(seconds: widget.startSeconds + widget.duration);
        if (pos >= end) {
          _player.seek(start);
        }
      });

      final url = await MusicService.getAudioStreamUrl(widget.musicId);
      
      if (url != null && mounted) {
        await _player.setVolume(_calculateVolume());
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(UrlSource(url));
        await _player.seek(Duration(seconds: widget.startSeconds));

        if (mounted) {
          setState(() {
            _isLoading = false;
            _isPlaying = true;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _calculateVolume() {
    if (_isMuted) return 0.0;
    if (_isVolumeLimitEnabled) {
      return _maxVolumeLimit;
    }
    return 1.0;
  }

  Future<void> _updateMute(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_muted_globally', muted);
    setState(() {
      _isMuted = muted;
    });
    await _player.setVolume(_calculateVolume());
  }

  Future<void> _updateVolumeLimitEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_volume_limit_enabled', enabled);
    setState(() {
      _isVolumeLimitEnabled = enabled;
    });
    await _player.setVolume(_calculateVolume());
  }

  Future<void> _updateVolumeLimitValue(double limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('music_max_volume_limit', limit);
    setState(() {
      _maxVolumeLimit = limit;
    });
    await _player.setVolume(_calculateVolume());
  }

  Future<void> _toggleMute() async {
    await _updateMute(!_isMuted);
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ajustes de música de fondo',
                    style: TextStyle(
                      fontFamily: 'CanvaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Silenciar todas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Silenciar todas las publicaciones',
                        style: TextStyle(
                          fontFamily: 'CanvaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Switch(
                        value: _isMuted,
                        activeColor: const Color(0xFF0094FF),
                        onChanged: (val) async {
                          setModalState(() => _isMuted = val);
                          await _updateMute(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Protección de volumen alto
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Protección contra volumen alto',
                        style: TextStyle(
                          fontFamily: 'CanvaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Switch(
                        value: _isVolumeLimitEnabled,
                        activeColor: const Color(0xFF0094FF),
                        onChanged: (val) async {
                          setModalState(() => _isVolumeLimitEnabled = val);
                          await _updateVolumeLimitEnabled(val);
                        },
                      ),
                    ],
                  ),
                  
                  if (_isVolumeLimitEnabled) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Límite de volumen:',
                          style: TextStyle(
                            fontFamily: 'CanvaSans',
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          '${(_maxVolumeLimit * 100).toInt()}%',
                          style: const TextStyle(
                            fontFamily: 'Arimo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0094FF),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _maxVolumeLimit,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      activeColor: const Color(0xFF0094FF),
                      inactiveColor: Colors.grey[200],
                      onChanged: (val) async {
                        setModalState(() => _maxVolumeLimit = val);
                        await _updateVolumeLimitValue(val);
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(8), // Diseño más cuadrado y angosto
        border: Border.all(color: const Color(0xFF0094FF), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0094FF).withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Portada/Carátula de la canción completamente cuadrada
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: widget.musicThumbnail,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.music_note, color: Colors.grey, size: 14),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.music_note, color: Colors.grey, size: 14),
              ),
            ),
          ),
          const SizedBox(width: 6),
          
          // 2. Título y Artista con ancho muy ajustado para hacerlo angosto
          Container(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.musicTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'CanvaSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 9.0,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  widget.musicArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'CanvaSans',
                    fontSize: 7.0,
                    color: Color(0xFF0094FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // 3. Ecualizador
          if (_isLoading)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0094FF)),
              ),
            )
          else
            AnimatedEqualizer(isPlaying: _isPlaying && !_isMuted),
          
          const SizedBox(width: 6),
          
          // 4. Botón Silenciar
          GestureDetector(
            onTap: _toggleMute,
            child: Container(
              padding: const EdgeInsets.all(2),
              color: Colors.transparent,
              child: Icon(
                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: const Color(0xFF0094FF),
                size: 13,
              ),
            ),
          ),
          const SizedBox(width: 3),
          
          // 5. Botón Ajustes
          GestureDetector(
            onTap: () => _showSettingsBottomSheet(context),
            child: Container(
              padding: const EdgeInsets.all(2),
              color: Colors.transparent,
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF0094FF),
                size: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedEqualizer extends StatefulWidget {
  final bool isPlaying;
  const AnimatedEqualizer({super.key, required this.isPlaying});

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double value = 0.25;
            if (widget.isPlaying) {
              value = 0.25 + 0.75 * (math.sin((_controller.value * 2 * math.pi) + (index * 1.5)).abs());
            }
            return Container(
              width: 1.6,
              height: 10 * value,
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0094FF),
                borderRadius: BorderRadius.circular(0.5),
              ),
            );
          },
        );
      }),
    );
  }
}
