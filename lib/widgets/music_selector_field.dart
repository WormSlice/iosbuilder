import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/music_service.dart';
import 'music_search_sheet.dart';
import 'instagram_audio_trimmer_sheet.dart';

class MusicSelectorField extends StatefulWidget {
  final String? musicId;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicThumbnail;
  final int musicStartSeconds;
  final int musicDuration;
  final Function(String? id, String? title, String? artist, String? thumbnail,
      int startSeconds, int duration) onMusicSelected;

  const MusicSelectorField({
    super.key,
    required this.musicId,
    required this.musicTitle,
    required this.musicArtist,
    required this.musicThumbnail,
    required this.musicStartSeconds,
    required this.musicDuration,
    required this.onMusicSelected,
  });

  @override
  State<MusicSelectorField> createState() => _MusicSelectorFieldState();
}

class _MusicSelectorFieldState extends State<MusicSelectorField>
    with SingleTickerProviderStateMixin {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingPreview = false;
  late AnimationController _equalizerController;

  @override
  void initState() {
    super.initState();
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing &&
              state.processingState != ProcessingState.completed;
          if (_isPlaying) {
            _equalizerController.repeat();
          } else {
            _equalizerController.stop();
          }
        });
      }
    });

    // Control de bucle para previsualizar (estilo Instagram)
    _audioPlayer.positionStream.listen((pos) {
      if (widget.musicId != null && _isPlaying) {
        final start = Duration(seconds: widget.musicStartSeconds);
        final end = Duration(
            seconds: widget.musicStartSeconds + widget.musicDuration);
        if (pos >= end) {
          _audioPlayer.seek(start);
        }
      }
    });
  }

  @override
  void dispose() {
    _equalizerController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _playPreview(int startSec) async {
    if (widget.musicId == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() {
      _isLoadingPreview = true;
      _isPlaying = false;
    });

    final url = await MusicService.getAudioStreamUrl(
      widget.musicId!,
      title: widget.musicTitle,
      artist: widget.musicArtist,
    );

    if (mounted) {
      setState(() => _isLoadingPreview = false);

      if (url != null) {
        try {
          await _audioPlayer.setUrl(url);
          await _audioPlayer.seek(Duration(seconds: startSec));
          await _audioPlayer.play();
          setState(() => _isPlaying = true);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Error al reproducir previsualización')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo obtener el audio')),
          );
        }
      }
    }
  }

  Future<void> _stopPlayer() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _openMusicSearch() async {
    await _stopPlayer();
    if (!mounted) return;

    final selectedSong = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => const MusicSearchSheet(),
    );

    if (selectedSong != null && mounted) {
      final startSec =
          int.tryParse(selectedSong['startSeconds']?.toString() ?? '0') ?? 0;
      final duration =
          int.tryParse(selectedSong['duration']?.toString() ?? '30') ?? 30;

      widget.onMusicSelected(
        selectedSong['id']?.toString(),
        selectedSong['title']?.toString(),
        selectedSong['artist']?.toString(),
        selectedSong['thumbnail']?.toString(),
        startSec,
        duration,
      );
    }
  }

  Future<void> _openTrimmer() async {
    if (widget.musicId == null) return;
    await _stopPlayer();
    if (!mounted) return;

    final trimResult = await InstagramAudioTrimmerSheet.show(
      context: context,
      musicId: widget.musicId!,
      title: widget.musicTitle ?? 'Canción',
      artist: widget.musicArtist ?? '',
      thumbnail: widget.musicThumbnail ?? '',
      initialStartSeconds: widget.musicStartSeconds,
      initialDuration: widget.musicDuration,
    );

    if (trimResult != null && mounted) {
      widget.onMusicSelected(
        widget.musicId,
        widget.musicTitle,
        widget.musicArtist,
        widget.musicThumbnail,
        trimResult['startSeconds'] ?? 0,
        trimResult['duration'] ?? 30,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMusic = widget.musicId != null && widget.musicId!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Música de fondo (Opcional)',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey[800],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: !hasMusic
                ? _BouncingSelectorButton(
                    key: const ValueKey('add_music_btn'),
                    onTap: _openMusicSearch,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0094FF).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              const Color(0xFF0094FF).withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_note_rounded,
                              color: Color(0xFF0094FF), size: 19),
                          SizedBox(width: 8),
                          Text(
                            'Agregar música a tu publicación',
                            style: TextStyle(
                              color: Color(0xFF0094FF),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'CanvaSans',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    key: const ValueKey('selected_music_card'),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF0094FF).withValues(alpha: 0.25),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0094FF).withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Portada
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: widget.musicThumbnail ?? '',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.music_note, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Info de canción
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.musicTitle ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.musicArtist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 11.5,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0094FF)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Fragmento: ${_formatDuration(widget.musicStartSeconds)} - ${_formatDuration(widget.musicStartSeconds + widget.musicDuration)} (${widget.musicDuration}s)',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0094FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Botón de Play/Pause con micro-ecualizador animado
                        _BouncingSelectorButton(
                          onTap: () =>
                              _playPreview(widget.musicStartSeconds),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _isPlaying
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF0094FF),
                                        Color(0xFF00C3FF)
                                      ],
                                    )
                                  : null,
                              color: _isPlaying ? null : Colors.grey[200],
                              boxShadow: _isPlaying
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF0094FF)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: _isLoadingPreview
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Color(0xFF0094FF)),
                                      ),
                                    )
                                  : Icon(
                                      _isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: _isPlaying
                                          ? Colors.white
                                          : Colors.black87,
                                      size: 20,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Botón de Recorte (Trimmer)
                        _BouncingSelectorButton(
                          onTap: _openTrimmer,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE3F2FD),
                            ),
                            child: const Center(
                              child: Icon(Icons.tune_rounded,
                                  color: Color(0xFF0094FF), size: 17),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Botón Eliminar
                        _BouncingSelectorButton(
                          onTap: () {
                            _stopPlayer();
                            widget.onMusicSelected(
                                null, null, null, null, 0, 30);
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red[50],
                            ),
                            child: const Center(
                              child: Icon(Icons.close_rounded,
                                  color: Colors.red, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}

class _BouncingSelectorButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncingSelectorButton(
      {super.key, required this.child, required this.onTap});

  @override
  State<_BouncingSelectorButton> createState() =>
      _BouncingSelectorButtonState();
}

class _BouncingSelectorButtonState extends State<_BouncingSelectorButton>
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
