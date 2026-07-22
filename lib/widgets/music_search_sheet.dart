import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/music_service.dart';

class MusicSearchSheet extends StatefulWidget {
  const MusicSearchSheet({super.key});

  @override
  State<MusicSearchSheet> createState() => _MusicSearchSheetState();
}

class _MusicSearchSheetState extends State<MusicSearchSheet> {
  final _searchController = TextEditingController();
  final _previewPlayer = AudioPlayer();
  
  List<Map<String, String>> _songs = [];
  bool _isLoading = false;
  
  // Canciones guardadas
  List<Map<String, String>> _savedSongs = [];
  List<Map<String, String>> _filteredSavedSongs = [];
  Set<String> _savedSongIds = {};

  // Estado de la previsualización
  String? _playingId;
  bool _isPlaying = false;
  bool _isLoadingPreview = false;
  
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadInitialSongs();
    _loadSavedSongs();
    
    // Escuchamos cambios en la reproducción para actualizar la UI si termina la pista
    _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
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

  void _loadInitialSongs() async {
    setState(() => _isLoading = true);
    final songs = await MusicService.getCuratedSongs();
    if (mounted) {
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    }
  }

  void _loadSavedSongs() async {
    final songs = await MusicService.getSavedSongs();
    if (mounted) {
      setState(() {
        _savedSongs = songs;
        _savedSongIds = songs.map((s) => s['id']!).toSet();
        _filterSavedSongs(_searchController.text);
      });
    }
  }

  void _filterSavedSongs(String query) {
    if (query.trim().isEmpty) {
      _filteredSavedSongs = _savedSongs;
    } else {
      final q = query.toLowerCase();
      _filteredSavedSongs = _savedSongs
          .where((s) =>
              s['title']!.toLowerCase().contains(q) ||
              s['artist']!.toLowerCase().contains(q))
          .toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filterSavedSongs(query);
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
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

  Future<void> _toggleSaveSong(Map<String, String> song) async {
    final id = song['id']!;
    if (_savedSongIds.contains(id)) {
      await MusicService.unsaveSong(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eliminada de Guardados'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } else {
      await MusicService.saveSong(song);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardada exitosamente'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    }
    _loadSavedSongs();
  }

  Future<void> _togglePreview(Map<String, String> song) async {
    final id = song['id']!;
    
    if (_playingId == id) {
      if (_isPlaying) {
        await _previewPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _previewPlayer.resume();
        setState(() => _isPlaying = true);
      }
    } else {
      setState(() {
        _isLoadingPreview = true;
        _playingId = id;
        _isPlaying = false;
      });
      
      await _previewPlayer.stop();
      
      final url = await MusicService.getAudioStreamUrl(id);
      
      if (mounted) {
        setState(() => _isLoadingPreview = false);
        
        if (url != null) {
          try {
            await _previewPlayer.play(UrlSource(url));
            setState(() => _isPlaying = true);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo reproducir la previsualización')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo obtener el flujo de audio')),
          );
        }
      }
    }
  }

  Widget _buildSongList(List<Map<String, String>> songsList, {required bool isSavedTab}) {
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
          style: const TextStyle(color: Colors.grey, fontFamily: 'CanvaSans', fontSize: 13),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: songsList.length,
      itemBuilder: (context, index) {
        final song = songsList[index];
        final id = song['id']!;
        final isCurrent = _playingId == id;
        final isSaved = _savedSongIds.contains(id);
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _previewPlayer.stop();
              Navigator.pop(context, song);
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                children: [
                  // Carátula de la canción redondeada y más compacta
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: song['thumbnail']!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.music_note, color: Colors.grey, size: 20),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.music_note, color: Colors.grey, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Título y Artista
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song['title']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'CanvaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isCurrent && _isPlaying ? const Color(0xFF0094FF) : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song['artist']!,
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
                  
                  // Botón de guardar estilo marcador de Instagram
                  IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                      color: isSaved ? const Color(0xFF0094FF) : Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: () => _toggleSaveSong(song),
                  ),
                  
                  // Botón de previsualización (Play/Pause)
                  GestureDetector(
                    onTap: () => _togglePreview(song),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent && _isPlaying
                            ? const Color(0xFF0094FF).withOpacity(0.1)
                            : Colors.grey[100],
                      ),
                      child: Center(
                        child: isCurrent && _isLoadingPreview
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0094FF)),
                                ),
                              )
                            : Icon(
                                isCurrent && _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: isCurrent && _isPlaying
                                    ? const Color(0xFF0094FF)
                                    : Colors.black87,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                ],
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
      height: MediaQuery.of(context).size.height * 0.75,
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
            // Barra de arrastre superior (Drag Handle)
            const SizedBox(height: 10),
            Container(
              width: 45,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 15),
            
            // Título de sección
            const Text(
              'Buscar música',
              style: TextStyle(
                fontFamily: 'CanvaSans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            // Caja de búsqueda con colores de CONNECT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Buscar canciones o artistas...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'CanvaSans'),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF0094FF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            // Pestañas deslizantes estilo Instagram
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
            
            // Contenido de cada pestaña
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
