import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;
import '../services/music_service.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

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
    this.duration = 240,
  });

  @override
  State<MusicPlayerPill> createState() => _MusicPlayerPillState();
}

class _MusicPlayerPillState extends State<MusicPlayerPill>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;

  // YouTube player controller
  bool _isYouTube = false;
  yt.YoutubePlayerController? _ytController;
  Timer? _ytLoopTimer;
  StreamSubscription? _ytStreamSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _playerPositionSub;

  // Ajustes de música
  bool _isMuted = false;
  bool _isVolumeLimitEnabled = false;
  double _maxVolumeLimit = 0.5;

  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _loadSettingsAndInitAudio();
  }

  @override
  void dispose() {
    _ytLoopTimer?.cancel();
    _ytStreamSub?.cancel();
    _playerStateSub?.cancel();
    _playerPositionSub?.cancel();
    _ytController?.close();
    _rotationController.dispose();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndInitAudio() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isMuted = prefs.getBool('music_muted_globally') ?? false;
        _isVolumeLimitEnabled =
            prefs.getBool('music_volume_limit_enabled') ?? false;
        _maxVolumeLimit = prefs.getDouble('music_max_volume_limit') ?? 0.5;
      });
    }
    await _initAudio();
  }

  Future<void> _initAudio() async {
    final cleanId = widget.musicId.trim();
    final isYt = (cleanId.length == 11 && !cleanId.contains(' ') && !cleanId.startsWith('http'));
    _isYouTube = isYt;

    if (_isYouTube) {
      try {
        _ytController = yt.YoutubePlayerController(
          params: const yt.YoutubePlayerParams(
            showControls: false,
            showFullscreenButton: false,
            mute: false,
            loop: false,
          ),
        );

        _ytStreamSub?.cancel();
        _ytStreamSub = _ytController!.stream.listen((value) {
          if (!mounted) return;
          final state = value.playerState;
          final isPlaying = state == yt.PlayerState.playing;
          if (state == yt.PlayerState.ended) {
            _ytController?.seekTo(
              seconds: widget.startSeconds.toDouble(),
              allowSeekAhead: true,
            );
            _ytController?.playVideo();
          }
          setState(() {
            _isPlaying = isPlaying;
            if (_isPlaying && !_isMuted) {
              if (!_rotationController.isAnimating) {
                _rotationController.repeat();
              }
            } else {
              _rotationController.stop();
            }
          });
        });

        await _ytController!.loadVideoById(
          videoId: cleanId,
          startSeconds: widget.startSeconds.toDouble(),
        );

        if (_isMuted) {
          await _ytController!.mute();
        } else {
          await _ytController!.unMute();
          await _ytController!.setVolume((_calculateVolume() * 100).toInt());
        }

        final playDuration = widget.duration > 0 ? widget.duration : 30;
        final endDurationSec = (widget.startSeconds + playDuration).toDouble();

        _ytLoopTimer?.cancel();
        _ytLoopTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
          if (!mounted || _ytController == null) {
            timer.cancel();
            return;
          }
          if (_isPlaying) {
            final pos = await _ytController!.currentTime;
            if (pos >= endDurationSec) {
              await _ytController!.seekTo(
                seconds: widget.startSeconds.toDouble(),
                allowSeekAhead: true,
              );
            }
          }
        });

        if (mounted) setState(() => _isLoading = false);
        return;
      } catch (ytErr) {
        debugPrint('[MusicPlayerPill] Error iniciando YouTube player: $ytErr');
      }
    }

    try {
      _playerStateSub?.cancel();
      _playerStateSub = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          final totalSec = (_player.duration != null && _player.duration!.inSeconds > 0)
              ? _player.duration!.inSeconds
              : 240;
          final safeStartSec = widget.startSeconds
              .clamp(0, math.max(0, totalSec - 5))
              .toInt();
          _player.seek(Duration(seconds: safeStartSec));
          _player.play();
        }
        if (mounted) {
          setState(() {
            _isPlaying = state.playing && state.processingState != ProcessingState.completed;
            if (_isPlaying && !_isMuted) {
              if (!_rotationController.isAnimating) {
                _rotationController.repeat();
              }
            } else {
              _rotationController.stop();
            }
          });
        }
      });

      final url = await MusicService.getAudioStreamUrl(
        widget.musicId,
        title: widget.musicTitle,
        artist: widget.musicArtist,
        forceFullTrack: true,
      );

      if (url != null && mounted) {
        await _player.setVolume(_calculateVolume());
        try {
          final audioSource = await MusicService.createAudioSource(url,
              cacheKey: widget.musicId);
          final loadedDuration = await _player.setAudioSource(audioSource);
          _setupLoopAndPlay(loadedDuration);
        } catch (srcErr) {
          debugPrint('[MusicPlayerPill] Error cargando audio: $srcErr');
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('[MusicPlayerPill] Error general en _initAudio: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupLoopAndPlay(Duration? loadedDuration) async {
    final totalSec = (loadedDuration != null && loadedDuration.inSeconds > 0)
        ? loadedDuration.inSeconds
        : 240;

    final safeStartSec = widget.startSeconds
        .clamp(0, math.max(0, totalSec - 5))
        .toInt();

    final playDuration = widget.duration > 0 ? widget.duration : 30;
    final endDurationSec = (safeStartSec + playDuration).clamp(5, totalSec);

    _playerPositionSub?.cancel();
    _playerPositionSub = _player.positionStream.listen((pos) {
      final start = Duration(seconds: safeStartSec);
      final end = Duration(seconds: endDurationSec);
      if (pos >= end || (loadedDuration != null && pos >= loadedDuration)) {
        _player.seek(start);
      }
    });

    await _player.seek(Duration(seconds: safeStartSec));
    await _player.play();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });
    }
  }

  void _togglePlayPause() async {
    if (_isYouTube && _ytController != null) {
      if (_isPlaying) {
        await _ytController!.pauseVideo();
      } else {
        await _ytController!.playVideo();
      }
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
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
      if (_isMuted) {
        _rotationController.stop();
      } else if (_isPlaying) {
        _rotationController.repeat();
      }
    });
    if (_isYouTube && _ytController != null) {
      if (muted) {
        await _ytController!.mute();
      } else {
        await _ytController!.unMute();
        await _ytController!.setVolume((_calculateVolume() * 100).toInt());
      }
    } else {
      await _player.setVolume(_calculateVolume());
    }
  }

  Future<void> _updateVolumeLimitEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_volume_limit_enabled', enabled);
    setState(() {
      _isVolumeLimitEnabled = enabled;
    });
    if (_isYouTube && _ytController != null && !_isMuted) {
      await _ytController!.setVolume((_calculateVolume() * 100).toInt());
    } else {
      await _player.setVolume(_calculateVolume());
    }
  }

  Future<void> _updateVolumeLimitValue(double limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('music_max_volume_limit', limit);
    setState(() {
      _maxVolumeLimit = limit;
    });
    if (_isYouTube && _ytController != null && !_isMuted) {
      await _ytController!.setVolume((_calculateVolume() * 100).toInt());
    } else {
      await _player.setVolume(_calculateVolume());
    }
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
                        activeThumbColor: const Color(0xFF0094FF),
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
                        activeThumbColor: const Color(0xFF0094FF),
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
    final activePlaying = _isPlaying && !_isMuted;

    final pillWidget = LiquidGlassLens(
      style: const LiquidGlassStyle(
        shape: LiquidGlassShape.squircle(cornerRadius: 20),
        appearance: LiquidGlassAppearance(
          color: Color(0x33FFFFFF),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activePlaying
                ? const Color(0xFF0094FF).withValues(alpha: 0.7)
                : const Color(0xFF0094FF).withValues(alpha: 0.35),
            width: activePlaying ? 1.2 : 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0094FF)
                  .withValues(alpha: activePlaying ? 0.22 : 0.08),
              blurRadius: activePlaying ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1, 2 y 3: Tocar para pausar/reanudar
            GestureDetector(
              onTap: _togglePlayPause,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Portada con micro-rotación o pulso suave
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: activePlaying
                            ? _rotationController.value * 2 * math.pi
                            : 0.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(activePlaying ? 14 : 5),
                          child: CachedNetworkImage(
                            imageUrl: (widget.musicThumbnail.isNotEmpty && widget.musicThumbnail.startsWith('http'))
                                ? widget.musicThumbnail
                                : (widget.musicId.length == 11 && !widget.musicId.contains(' ')
                                    ? 'https://img.youtube.com/vi/${widget.musicId}/hqdefault.jpg'
                                    : 'https://img.youtube.com/vi/QCZZwZQ4qNs/hqdefault.jpg'),
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF1E293B),
                              child: const Icon(Icons.music_note,
                                  color: Color(0xFF0094FF), size: 14),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF1E293B),
                              child: const Icon(Icons.music_note,
                                  color: Color(0xFF0094FF), size: 14),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),

                  // 2. Título y Artista
                  Container(
                    constraints: const BoxConstraints(maxWidth: 85),
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
                            fontSize: 7.5,
                            color: Color(0xFF0094FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),

                  // 3. Ecualizador animado fluido
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
                    AnimatedEqualizer(isPlaying: activePlaying),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // 4. Botón Silenciar con rebote
            _PillIconButton(
              onTap: _toggleMute,
              child: Icon(
                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: const Color(0xFF0094FF),
                size: 14,
              ),
            ),
            const SizedBox(width: 3),

            // 5. Botón Ajustes con rebote
            _PillIconButton(
              onTap: () => _showSettingsBottomSheet(context),
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF0094FF),
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );

    if (_isYouTube && _ytController != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -9999,
            top: -9999,
            width: 1,
            height: 1,
            child: yt.YoutubePlayer(controller: _ytController!),
          ),
          pillWidget,
        ],
      );
    }

    return pillWidget;
  }
}

class _PillIconButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PillIconButton({required this.child, required this.onTap});

  @override
  State<_PillIconButton> createState() => _PillIconButtonState();
}

class _PillIconButtonState extends State<_PillIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(
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
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(2.5),
          color: Colors.transparent,
          child: widget.child,
        ),
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

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
              value = 0.25 +
                  0.75 *
                      (math.sin((_controller.value * 2 * math.pi) +
                              (index * 1.5))
                          .abs());
            }
            return Container(
              width: 1.8,
              height: (12 * value).clamp(3.0, 12.0),
              margin: const EdgeInsets.symmetric(horizontal: 0.6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0094FF), Color(0xFF00D2FF)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(1.0),
              ),
            );
          },
        );
      }),
    );
  }
}
