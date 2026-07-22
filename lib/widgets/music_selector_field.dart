import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/music_service.dart';
import 'music_search_sheet.dart';

class MusicSelectorField extends StatefulWidget {
  final String? musicId;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicThumbnail;
  final int musicStartSeconds;
  final int musicDuration;
  final Function(String? id, String? title, String? artist, String? thumbnail, int startSeconds, int duration) onMusicSelected;

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

class _MusicSelectorFieldState extends State<MusicSelectorField> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingPreview = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Control de bucle para previsualizar (estilo Instagram)
    _audioPlayer.onPositionChanged.listen((pos) {
      if (widget.musicId != null && _isPlaying) {
        final start = Duration(seconds: widget.musicStartSeconds);
        final end = Duration(seconds: widget.musicStartSeconds + widget.musicDuration);
        if (pos >= end) {
          _audioPlayer.seek(start);
        }
      }
    });
  }

  @override
  void dispose() {
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

    final url = await MusicService.getAudioStreamUrl(widget.musicId!);
    
    if (mounted) {
      setState(() => _isLoadingPreview = false);
      
      if (url != null) {
        try {
          await _audioPlayer.play(UrlSource(url));
          await _audioPlayer.seek(Duration(seconds: startSec));
          setState(() => _isPlaying = true);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al reproducir previsualización')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener el audio')),
        );
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

  Future<void> _openMusicSearch(BuildContext context) async {
    await _stopPlayer();
    
    final selectedSong = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MusicSearchSheet(),
    );

    if (selectedSong != null) {
      widget.onMusicSelected(
        selectedSong['id'],
        selectedSong['title'],
        selectedSong['artist'],
        selectedSong['thumbnail'],
        0, // Inicia en 0s
        30, // 30s por defecto
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMusic = widget.musicId != null && widget.musicId!.isNotEmpty;
    final maxStartSec = 30 - widget.musicDuration;

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
        
        if (!hasMusic)
          OutlinedButton(
            onPressed: () => _openMusicSearch(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Color(0xFF0094FF), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFF0094FF).withOpacity(0.04),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note_rounded, color: Color(0xFF0094FF), size: 18),
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
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: widget.musicThumbnail!,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => const Icon(Icons.music_note, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.musicTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'CanvaSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.musicArtist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'CanvaSans',
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                GestureDetector(
                  onTap: () => _playPreview(widget.musicStartSeconds),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isPlaying ? const Color(0xFF0094FF).withOpacity(0.1) : Colors.grey[200],
                    ),
                    child: Center(
                      child: _isLoadingPreview
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0094FF)),
                              ),
                            )
                          : Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: _isPlaying ? const Color(0xFF0094FF) : Colors.black87,
                              size: 18,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                GestureDetector(
                  onTap: () {
                    _stopPlayer();
                    widget.onMusicSelected(null, null, null, null, 0, 30);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red[50],
                    ),
                    child: const Center(
                      child: Icon(Icons.close_rounded, color: Colors.red, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 15),
      ],
    );
  }
}
