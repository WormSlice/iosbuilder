import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/music_service.dart';
import 'instagram_audio_trimmer_sheet.dart';

class MusicSearchSheet extends StatefulWidget {
  const MusicSearchSheet({super.key});

  @override
  State<MusicSearchSheet> createState() => _MusicSearchSheetState();
}

class _MusicSearchSheetState extends State<MusicSearchSheet>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _previewPlayer = AudioPlayer();

  List<Map<String, dynamic>> _songs = [];
  bool _isLoading = false;

  // Canciones guardadas
  List<Map<String, dynamic>> _savedSongs = [];
  List<Map<String, dynamic>> _filteredSavedSongs = [];
  Set<String> _savedSongIds = {};

  // Estado de la previsualización
  String? _playingId;
  bool _isPlaying = false;
  bool _isLoadingPreview = false;

  String _selectedFilter = 'Para ti';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadInitialSongs();
    _loadSavedSongs();

    _previewPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing &&
              state.processingState != ProcessingState.completed;
          if (state.processingState == ProcessingState.completed) {
            _playingId = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _previewPlayer.stop();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSongs() async {
    setState(() => _isLoading = true);
    final results = await MusicService.getSpotifyTopCharts();

    if (mounted) {
      setState(() {
        _songs = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedSongs() async {
    final saved = await MusicService.getSavedSongs();
    if (mounted) {
      setState(() {
        _savedSongs = saved;
        _filteredSavedSongs = saved;
        _savedSongIds = saved.map((s) => s['id']!.toString()).toSet();
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (mounted) {
        setState(() {
          _filteredSavedSongs = _savedSongs.where((s) {
            final title = s['title']?.toString().toLowerCase() ?? '';
            final artist = s['artist']?.toString() ?? '';
            final q = query.toLowerCase();
            return title.contains(q) || artist.toLowerCase().contains(q);
          }).toList();
        });
      }

      if (query.trim().isEmpty) {
        _loadInitialSongs();
        return;
      }

      setState(() => _isLoading = true);
      final results = await MusicService.searchSongs(query);
      if (mounted) {
        setState(() {
          _songs = results;
          _isLoading = false;
        });
      }
    });
  }

  void _selectFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });

    if (filter == 'Para ti' || filter == 'Tendencias') {
      _searchController.clear();
      _loadInitialSongs();
    } else {
      _searchController.text = filter;
      _onSearchChanged(filter);
    }
  }

  Future<void> _toggleSaveSong(Map<String, dynamic> song) async {
    final id = song['id'].toString();
    if (_savedSongIds.contains(id)) {
      await MusicService.unsaveSong(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eliminada de guardados'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } else {
      await MusicService.saveSong(song);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardada en tu colección'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    }
    _loadSavedSongs();
  }

  Future<void> _togglePreview(Map<String, dynamic> song) async {
    final id = song['id'].toString();
    final title = song['title']?.toString() ?? '';
    final artist = song['artist']?.toString() ?? '';
    final directAudioUrl = song['audioUrl']?.toString();

    if (_playingId == id) {
      if (_isPlaying) {
        await _previewPlayer.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        await _previewPlayer.play();
        if (mounted) setState(() => _isPlaying = true);
      }
      return;
    }

    setState(() {
      _isLoadingPreview = true;
      _playingId = id;
      _isPlaying = false;
    });

    try {
      await _previewPlayer.stop();

      final url = (directAudioUrl != null && directAudioUrl.isNotEmpty)
          ? directAudioUrl
          : await MusicService.getAudioStreamUrl(
              id,
              title: title,
              artist: artist,
              forceFullTrack: false,
            );

      if (url != null && url.isNotEmpty && mounted) {
        await _previewPlayer.setUrl(url);
        await _previewPlayer.seek(Duration.zero);
        await _previewPlayer.play();

        if (mounted) {
          setState(() {
            _isLoadingPreview = false;
            _isPlaying = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingPreview = false;
            _playingId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No se pudo obtener el audio de esta canción')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPreview = false;
          _playingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reproducir: $e')),
        );
      }
    }
  }

  String _formatDuration(dynamic durationSec) {
    if (durationSec == null) return '';
    final sec = int.tryParse(durationSec.toString()) ?? 0;
    if (sec <= 0) return '';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _onSongSelected(Map<String, dynamic> song) async {
    await _previewPlayer.stop();

    if (!mounted) return;

    final audioKey =
        (song['audioUrl'] != null && song['audioUrl'].toString().isNotEmpty)
            ? song['audioUrl'].toString()
            : song['id'].toString();

    final totalSec =
        int.tryParse(song['duration']?.toString() ?? '180') ?? 180;
    final autoHighlight = MusicService.calculateHighlightStart(totalSec);

    final trimmed = await InstagramAudioTrimmerSheet.show(
      context: context,
      musicId: audioKey,
      title: song['title'].toString(),
      artist: song['artist'].toString(),
      thumbnail: song['thumbnail'].toString(),
      totalTrackSeconds: totalSec,
      initialStartSeconds: autoHighlight,
      initialDuration: 30,
    );

    if (trimmed != null && mounted) {
      Navigator.pop(context, {
        'id': audioKey,
        'title': song['title'].toString(),
        'artist': song['artist'].toString(),
        'thumbnail': song['thumbnail'].toString(),
        'startSeconds': trimmed['startSeconds'] ?? autoHighlight,
        'duration': trimmed['duration'] ?? 30,
      });
    }
  }

  Widget _buildSongList(List<Map<String, dynamic>> songsList,
      {required bool isSavedTab}) {
    if (_isLoading && !isSavedTab) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0094FF)),
        ),
      );
    }
    if (songsList.isEmpty) {
      return Center(
        child: Text(
          isSavedTab
              ? 'No tienes canciones guardadas'
              : 'No se encontraron canciones',
          style: const TextStyle(
            color: Colors.grey,
            fontFamily: 'CanvaSans',
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: songsList.length,
      itemBuilder: (context, index) {
        final song = songsList[index];
        final id = song['id'].toString();
        final isCurrent = _playingId == id;
        final isPlayingSong = isCurrent && _isPlaying;
        final isSaved = _savedSongIds.contains(id);
        final durStr = _formatDuration(song['duration']);

        // Entrada animada escalonada y suave para cada canción
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 220 + (index.clamp(0, 10) * 35)),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, val, child) {
            return Transform.translate(
              offset: Offset(0, (1.0 - val) * 16),
              child: Opacity(
                opacity: val,
                child: child,
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: isPlayingSong
                  ? const Color(0xFF0094FF).withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPlayingSong
                    ? const Color(0xFF0094FF).withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onSongSelected(song),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                  child: Row(
                    children: [
                      // Portada cuadrada con ecualizador animado superpuesto
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isPlayingSong
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF0094FF)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: song['thumbnail']?.toString() ?? '',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.music_note,
                                      color: Colors.grey, size: 22),
                                ),
                                errorWidget: (context, url, error) =>
                                    Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.music_note,
                                      color: Colors.grey, size: 22),
                                ),
                              ),
                            ),
                          ),
                          if (isPlayingSong)
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.52),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: _DancingWaveEqualizer(),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Título, Artista y Duración
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song['title']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'CanvaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isPlayingSong
                                    ? const Color(0xFF0094FF)
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    song['artist']?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'CanvaSans',
                                      fontSize: 12,
                                      color: isPlayingSong
                                          ? const Color(0xFF0094FF)
                                              .withValues(alpha: 0.8)
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                if (durStr.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '•  $durStr',
                                    style: TextStyle(
                                      fontFamily: 'CanvaSans',
                                      fontSize: 11,
                                      color: isPlayingSong
                                          ? const Color(0xFF0094FF)
                                              .withValues(alpha: 0.7)
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Botón de guardar animado con rebote elástico
                      _BouncingMicroWidget(
                        onTap: () => _toggleSaveSong(song),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_outline_rounded,
                              key: ValueKey<bool>(isSaved),
                              color: isSaved
                                  ? const Color(0xFF0094FF)
                                  : Colors.grey[400],
                              size: 22,
                            ),
                          ),
                        ),
                      ),

                      // Botón de Play/Pause circular con micro-animación elástica
                      _BouncingMicroWidget(
                        onTap: () => _togglePreview(song),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isPlayingSong
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF0094FF),
                                      Color(0xFF00C3FF)
                                    ],
                                  )
                                : null,
                            color: isPlayingSong
                                ? null
                                : const Color(0xFFF0F2F5),
                            boxShadow: isPlayingSong
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
                            child: isCurrent && _isLoadingPreview
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Color(0xFF0094FF)),
                                    ),
                                  )
                                : AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      isPlayingSong
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      key: ValueKey<bool>(isPlayingSong),
                                      color: isPlayingSong
                                          ? Colors.white
                                          : Colors.black87,
                                      size: 22,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Barra de arrastre superior
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),

            // Encabezado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Elegir música',
                    style: TextStyle(
                      fontFamily: 'CanvaSans',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  _BouncingMicroWidget(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.black87, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Barra de búsqueda estilo Instagram / Spotify
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar canciones o artistas...',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontFamily: 'CanvaSans',
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.grey, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: const Icon(Icons.cancel_rounded,
                                color: Colors.grey, size: 18),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Chips de Categorías y Géneros con transición animada fluida
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: MusicService.categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = MusicService.categories[index];
                  final isSelected = _selectedFilter == cat;

                  return _BouncingMicroWidget(
                    onTap: () => _selectFilter(cat),
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
                        color: isSelected ? null : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: Colors.grey.withValues(alpha: 0.2),
                                width: 0.8),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0094FF)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontFamily: 'CanvaSans',
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Pestañas "Para ti" / "Guardado"
            TabBar(
              labelColor: const Color(0xFF0094FF),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF0094FF),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontFamily: 'CanvaSans',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'CanvaSans',
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Para ti'),
                Tab(text: 'Guardado'),
              ],
            ),

            // Listas
            Expanded(
              child: TabBarView(
                children: [
                  _buildSongList(_songs, isSavedTab: false),
                  _buildSongList(_filteredSavedSongs, isSavedTab: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Micro-widget interactivo con efecto de rebote elástico suave al presionar
class _BouncingMicroWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncingMicroWidget({required this.child, required this.onTap});

  @override
  State<_BouncingMicroWidget> createState() => _BouncingMicroWidgetState();
}

class _BouncingMicroWidgetState extends State<_BouncingMicroWidget>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
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

/// Mini ecualizador animado fluido de 4 barras sobre la portada de la canción en reproducción
class _DancingWaveEqualizer extends StatefulWidget {
  const _DancingWaveEqualizer();

  @override
  State<_DancingWaveEqualizer> createState() => _DancingWaveEqualizerState();
}

class _DancingWaveEqualizerState extends State<_DancingWaveEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(6 + t * 14),
            const SizedBox(width: 2.5),
            _bar(18 - t * 12),
            const SizedBox(width: 2.5),
            _bar(10 + t * 10),
            const SizedBox(width: 2.5),
            _bar(16 - t * 8),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3.2,
      height: height.clamp(4.0, 22.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
