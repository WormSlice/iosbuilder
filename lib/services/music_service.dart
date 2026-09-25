import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class CachedAudioStream {
  final String url;
  final int durationSeconds;
  final DateTime expiresAt;

  CachedAudioStream({
    required this.url,
    required this.durationSeconds,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class MusicService {
  static final Map<String, CachedAudioStream> _streamCache = {};
  static List<Map<String, dynamic>> _cachedTopCharts = [];
  static DateTime? _topChartsCacheTime;

  static const List<String> categories = [
    'Para ti',
    'Tendencias',
    'Reggaeton',
    'Pop',
    'Trap Latino',
    'R&B',
    'Hip-Hop',
    'Electrónica',
    'Rock',
  ];

  static final List<String> _invidiousHosts = [
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://yt.artemislena.eu',
  ];

  /// Crea una fuente de audio (AudioSource) directa y segura para streaming
  /// Compatible al 100% tanto con iOS (AVPlayer) como con Android (ExoPlayer)
  static Future<AudioSource> createAudioSource(String url, {String? cacheKey}) async {
    final uri = Uri.parse(url);
    return AudioSource.uri(uri);
  }

  /// Calcula automáticamente el punto donde empieza el fragmento más destacado (estribillo / coro)
  static int calculateHighlightStart(int durationSec) {
    if (durationSec <= 30) return 0;
    final candidate = (durationSec * 0.22).round();
    if (candidate < 15) return 15;
    if (candidate > 50) return 40;
    return candidate;
  }

  /// Lista curada de canciones COMPLETAS con duración real de 3 a 5 minutos y Video IDs de YouTube
  static final List<Map<String, dynamic>> _curatedSongs = [
    {
      'id': 'QCZZwZQ4qNs',
      'spotifyId': 'QCZZwZQ4qNs',
      'title': 'Si Antes Te Hubiera Conocido',
      'artist': 'KAROL G',
      'thumbnail': 'https://img.youtube.com/vi/QCZZwZQ4qNs/hqdefault.jpg',
      'duration': 196,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 'kPa7bsKwL-c',
      'spotifyId': 'kPa7bsKwL-c',
      'title': 'Die With A Smile',
      'artist': 'Lady Gaga & Bruno Mars',
      'thumbnail': 'https://img.youtube.com/vi/kPa7bsKwL-c/hqdefault.jpg',
      'duration': 253,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 'V9PVRfjEBTI',
      'spotifyId': 'V9PVRfjEBTI',
      'title': 'BIRDS OF A FEATHER',
      'artist': 'Billie Eilish',
      'thumbnail': 'https://img.youtube.com/vi/V9PVRfjEBTI/hqdefault.jpg',
      'duration': 231,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 'x2oUajHp8pg',
      'spotifyId': 'x2oUajHp8pg',
      'title': 'LUNA',
      'artist': 'Feid & ATL Jacob',
      'thumbnail': 'https://img.youtube.com/vi/x2oUajHp8pg/hqdefault.jpg',
      'duration': 200,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 'eVli-tstM5E',
      'spotifyId': 'eVli-tstM5E',
      'title': 'Espresso',
      'artist': 'Sabrina Carpenter',
      'thumbnail': 'https://img.youtube.com/vi/eVli-tstM5E/hqdefault.jpg',
      'duration': 201,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 'L7H_b_U98E4',
      'spotifyId': 'L7H_b_U98E4',
      'title': 'COQUETA',
      'artist': 'Fuerza Regida',
      'thumbnail': 'https://img.youtube.com/vi/L7H_b_U98E4/hqdefault.jpg',
      'duration': 241,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 'c30C583N9d4',
      'spotifyId': 'c30C583N9d4',
      'title': 'Destino Final',
      'artist': 'Yeison Jimenez',
      'thumbnail': 'https://img.youtube.com/vi/c30C583N9d4/hqdefault.jpg',
      'duration': 173,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 'O2Z4r1vS2S0',
      'spotifyId': 'O2Z4r1vS2S0',
      'title': 'Mírame',
      'artist': 'Blessd & Ovy On The Drums',
      'thumbnail': 'https://img.youtube.com/vi/O2Z4r1vS2S0/hqdefault.jpg',
      'duration': 157,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 'mCDz4wUoI5U',
      'spotifyId': 'mCDz4wUoI5U',
      'title': 'Neverita',
      'artist': 'Bad Bunny',
      'thumbnail': 'https://img.youtube.com/vi/mCDz4wUoI5U/hqdefault.jpg',
      'duration': 173,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 'Oa_RSwwpPaA',
      'spotifyId': 'Oa_RSwwpPaA',
      'title': 'Beautiful Things',
      'artist': 'Benson Boone',
      'thumbnail': 'https://img.youtube.com/vi/Oa_RSwwpPaA/hqdefault.jpg',
      'duration': 180,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 't7bQwwqW-Hc',
      'spotifyId': 't7bQwwqW-Hc',
      'title': 'A Bar Song (Tipsy)',
      'artist': 'Shaboozey',
      'thumbnail': 'https://img.youtube.com/vi/t7bQwwqW-Hc/hqdefault.jpg',
      'duration': 171,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': 'UBhlqeX4844',
      'spotifyId': 'UBhlqeX4844',
      'title': 'Too Sweet',
      'artist': 'Hozier',
      'thumbnail': 'https://img.youtube.com/vi/UBhlqeX4844/hqdefault.jpg',
      'duration': 251,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
    {
      'id': '9Qz8jFf0mN0',
      'spotifyId': '9Qz8jFf0mN0',
      'title': 'BESO',
      'artist': 'ROSALÍA & Rauw Alejandro',
      'thumbnail': 'https://img.youtube.com/vi/9Qz8jFf0mN0/hqdefault.jpg',
      'duration': 195,
      'audioUrl': '',
      'spotifyUri': '',
      'isSpotify': false,
    },
  ];

  /// Obtiene la lista curada de canciones en tendencia
  static List<Map<String, dynamic>> getCuratedSongs() {
    return List<Map<String, dynamic>>.from(_curatedSongs);
  }

  /// Obtiene canciones en tendencia para la pantalla inicial ("Para ti")
  static Future<List<Map<String, dynamic>>> getSpotifyTopCharts() async {
    if (_cachedTopCharts.isNotEmpty &&
        _topChartsCacheTime != null &&
        DateTime.now().difference(_topChartsCacheTime!).inMinutes < 20) {
      return _cachedTopCharts;
    }

    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=tendencias+musica+top+latino&entity=song&limit=35',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final list = <Map<String, dynamic>>[];
          // Priorizar las canciones curadas con ID ya garantizado
          for (var c in _curatedSongs) {
            list.add(Map<String, dynamic>.from(c));
          }

          for (var item in results) {
            final trackName = item['trackName']?.toString() ?? '';
            final artistName = item['artistName']?.toString() ?? '';
            final rawMillis = item['trackTimeMillis'] as num? ?? 180000;
            final durSec = (rawMillis / 1000).round();
            final rawArt = item['artworkUrl100']?.toString() ?? '';
            final thumb = rawArt.isNotEmpty
                ? rawArt.replaceAll('100x100bb', '600x600bb')
                : 'https://img.youtube.com/vi/QCZZwZQ4qNs/hqdefault.jpg';

            final exists = list.any((s) =>
                s['title'].toString().toLowerCase() == trackName.toLowerCase());
            if (!exists && trackName.isNotEmpty) {
              list.add({
                'id': '${trackName}_$artistName'.toLowerCase().replaceAll(' ', '_'),
                'spotifyId': '${trackName}_$artistName',
                'title': trackName,
                'artist': artistName,
                'thumbnail': thumb,
                'duration': durSec > 30 ? durSec : 205,
                'audioUrl': '',
                'spotifyUri': '',
                'isSpotify': false,
              });
            }
          }

          _cachedTopCharts = list;
          _topChartsCacheTime = DateTime.now();
          return list;
        }
      }
    } catch (e) {
      if (kDebugMode) print('[MusicService] Error cargando tendencias: $e');
    }

    _cachedTopCharts = getCuratedSongs();
    _topChartsCacheTime = DateTime.now();
    return _cachedTopCharts;
  }

  static void prefetchTopStreams(List<Map<String, dynamic>> songs) {}

  /// Alias de búsqueda
  static Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    return searchTracks(query);
  }

  /// Búsqueda inteligente de pistas completas (3 a 5 minutos) con portadas oficiales HD
  static Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return getSpotifyTopCharts();
    }

    // 1. Detectar si el usuario pegó un enlace de YouTube o un videoId de 11 caracteres
    final ytId = _extractYouTubeId(trimmedQuery);
    if (ytId != null) {
      final ytItem = await _resolveDirectYouTubeItem(ytId);
      if (ytItem != null) {
        return [ytItem];
      }
    }

    // 2. Búsqueda en el catálogo oficial de Apple iTunes (carátulas HD 600x600 y duración real)
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(trimmedQuery)}&entity=song&limit=30',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final list = <Map<String, dynamic>>[];
          for (var item in results) {
            final trackName = item['trackName']?.toString() ?? '';
            final artistName = item['artistName']?.toString() ?? '';
            final rawMillis = item['trackTimeMillis'] as num? ?? 180000;
            final durSec = (rawMillis / 1000).round();
            final rawArt = item['artworkUrl100']?.toString() ?? '';
            final thumb = rawArt.isNotEmpty
                ? rawArt.replaceAll('100x100bb', '600x600bb')
                : 'https://img.youtube.com/vi/QCZZwZQ4qNs/hqdefault.jpg';

            if (trackName.isNotEmpty) {
              list.add({
                'id': '${trackName}_$artistName'.toLowerCase().replaceAll(' ', '_'),
                'spotifyId': '${trackName}_$artistName',
                'title': trackName,
                'artist': artistName,
                'thumbnail': thumb,
                'duration': durSec > 30 ? durSec : 210,
                'audioUrl': '',
                'spotifyUri': '',
                'isSpotify': false,
              });
            }
          }
          if (list.isNotEmpty) return list;
        }
      }
    } catch (e) {
      if (kDebugMode) print('[MusicService] Error buscando canciones: $e');
    }

    // 3. Fallback a canciones curadas si no hay respuesta de red
    final q = trimmedQuery.toLowerCase();
    final matches = _curatedSongs.where((s) {
      final title = s['title'].toString().toLowerCase();
      final artist = s['artist'].toString().toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
    if (matches.isNotEmpty) return matches;

    return getCuratedSongs();
  }

  /// Extrae el ID de YouTube si es un enlace o un código de 11 caracteres
  static String? _extractYouTubeId(String input) {
    final clean = input.trim();
    if (clean.length == 11 && !clean.contains(' ') && !clean.contains('/') && !clean.contains('.')) {
      return clean;
    }
    final regExp = RegExp(
      r'^(?:https?:\/\/)?(?:www\.|m\.)?(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(clean);
    return match?.group(1);
  }

  /// Resuelve un video individual de YouTube por su ID
  static Future<Map<String, dynamic>?> _resolveDirectYouTubeItem(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(videoId).timeout(const Duration(seconds: 4));
      return {
        'id': videoId,
        'spotifyId': videoId,
        'title': video.title,
        'artist': video.author,
        'thumbnail': 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
        'duration': video.duration?.inSeconds ?? 210,
        'audioUrl': '',
        'spotifyUri': '',
        'isSpotify': false,
      };
    } catch (e) {
      if (kDebugMode) print('[MusicService] Error resolviendo video de YouTube: $e');
      return {
        'id': videoId,
        'spotifyId': videoId,
        'title': 'Canción seleccionada',
        'artist': 'YouTube',
        'thumbnail': 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
        'duration': 210,
        'audioUrl': '',
        'spotifyUri': '',
        'isSpotify': false,
      };
    } finally {
      yt.close();
    }
  }

  /// Busca el Video ID de YouTube correspondiente para un título y artista (Extracción directa ultrarrápida)
  static Future<String?> _findYouTubeVideoId(String query) async {
    final clean = query.replaceAll(' - ', ' ').replaceAll('&', ' ').trim();

    // 1. Scraping directo de YouTube Web Results (rápido, ~200ms)
    try {
      final uri = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$clean audio')}',
      );
      final res = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final regExp = RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"');
        final match = regExp.firstMatch(res.body);
        if (match != null) {
          final id = match.group(1);
          if (id != null && id.isNotEmpty) {
            return id;
          }
        }
      }
    } catch (_) {}

    // 2. Respaldo en instancias Invidious
    for (final host in _invidiousHosts) {
      try {
        final uri = Uri.parse('$host/api/v1/search?q=${Uri.encodeComponent(clean)}&type=video');
        final res = await http.get(uri).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final items = json.decode(res.body) as List? ?? [];
          final first = items.firstWhere(
            (it) => it['videoId'] != null && it['videoId'].toString().length == 11,
            orElse: () => null,
          );
          if (first != null && first['videoId'] != null) {
            return first['videoId'].toString();
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Extrae la pista de audio COMPLETA (3-5 minutos) desde YouTube
  /// Selecciona MP4/AAC (itag 140 / 139) para soporte nativo en iOS (AVPlayer) y Android (ExoPlayer)
  static Future<Map<String, dynamic>?> getFullAudioStream({
    required String title,
    required String artist,
    String? videoId,
    String? fallbackPreviewUrl,
    int? expectedDurationSec,
  }) async {
    final searchTitle = title.trim();
    final searchArtist = artist.trim();

    String? targetVideoId = videoId;
    if (targetVideoId == null || targetVideoId.isEmpty) {
      final cleanTitle = searchTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
      if (cleanTitle.length == 11 && !searchTitle.contains(' ')) {
        targetVideoId = searchTitle;
      }
    }

    // Si aún no tenemos Video ID, buscarlo
    if (targetVideoId == null || targetVideoId.isEmpty || targetVideoId.length != 11 || targetVideoId.contains('_')) {
      final q = '$searchTitle $searchArtist'.trim();
      targetVideoId = await _findYouTubeVideoId(q);
      targetVideoId ??= await _findYouTubeVideoId(searchTitle);
    }

    if (targetVideoId == null || targetVideoId.isEmpty) {
      return null;
    }

    final cacheKey = 'yt_stream_$targetVideoId';
    final cached = _streamCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return {
        'url': cached.url,
        'durationSeconds': cached.durationSeconds,
        'videoId': targetVideoId,
      };
    }

    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient
          .getManifest(targetVideoId)
          .timeout(const Duration(seconds: 12));

      // Seleccionar MP4 / AAC (itag 140 o 139) para compatibilidad nativa absoluta en iOS y Android
      final aac140 = manifest.audioOnly.where((s) => s.tag == 140).toList();
      final aac139 = manifest.audioOnly.where((s) => s.tag == 139).toList();
      final mp4Streams = manifest.audioOnly.where(
        (s) =>
            s.container == StreamContainer.mp4 ||
            s.codec.mimeType.contains('mp4') ||
            s.audioCodec.toLowerCase().contains('mp4a') ||
            s.audioCodec.toLowerCase().contains('aac'),
      ).toList();

      final audioStream = aac140.isNotEmpty
          ? aac140.first
          : (aac139.isNotEmpty
              ? aac139.first
              : (mp4Streams.isNotEmpty
                  ? mp4Streams.first
                  : manifest.audioOnly.first));

      final durSec = expectedDurationSec ?? 210;
      final streamUrl = audioStream.url.toString();

      _streamCache[cacheKey] = CachedAudioStream(
        url: streamUrl,
        durationSeconds: durSec,
        expiresAt: DateTime.now().add(const Duration(hours: 4)),
      );

      return {
        'url': streamUrl,
        'durationSeconds': durSec,
        'videoId': targetVideoId,
      };
    } catch (e) {
      if (kDebugMode) print('[MusicService] Error extrayendo stream completo de YouTube: $e');
      return null;
    } finally {
      yt.close();
    }
  }

  /// Obtiene el enlace de audio streaming de la canción completa
  static Future<String?> getAudioStreamUrl(
    String audioIdOrUrl, {
    String? title,
    String? artist,
    bool forceFullTrack = true,
  }) async {
    final cleanInput = audioIdOrUrl.trim();

    // 1. Si ya es un stream de audio directo fresco
    if (cleanInput.startsWith('http') && !cleanInput.contains('expire=')) {
      return cleanInput;
    }

    final searchTitle = (title != null && title.isNotEmpty)
        ? title
        : cleanInput.replaceAll('_', ' ');
    final searchArtist = (artist != null && artist.isNotEmpty) ? artist : '';

    // 2. Verificar si es un Video ID directo de YouTube (11 caracteres alfanuméricos)
    final isYtId = cleanInput.length == 11 && !cleanInput.contains(' ') && !cleanInput.startsWith('http');

    final streamData = await getFullAudioStream(
      title: searchTitle,
      artist: searchArtist,
      videoId: isYtId ? cleanInput : null,
      expectedDurationSec: 210,
    );

    if (streamData != null && streamData['url'] != null) {
      return streamData['url'].toString();
    }

    return null;
  }

  static const String _savedSongsKey = 'saved_songs_list';

  static Future<List<Map<String, dynamic>>> getSavedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_savedSongsKey);
      if (savedStr == null) return [];
      final List decoded = json.decode(savedStr);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      if (kDebugMode) print('Error cargando canciones guardadas: $e');
      return [];
    }
  }

  static Future<void> saveSong(Map<String, dynamic> song) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songs = await getSavedSongs();
      if (!songs.any((s) => s['id'] == song['id'])) {
        songs.add(song);
        await prefs.setString(_savedSongsKey, json.encode(songs));
      }
    } catch (e) {
      if (kDebugMode) print('Error guardando canción: $e');
    }
  }

  static Future<void> unsaveSong(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songs = await getSavedSongs();
      songs.removeWhere((s) => s['id'] == songIdNormalize(id));
      await prefs.setString(_savedSongsKey, json.encode(songs));
    } catch (e) {
      if (kDebugMode) print('Error eliminando canción: $e');
    }
  }

  static Future<bool> isSongSaved(String id) async {
    final songs = await getSavedSongs();
    return songs
        .any((s) => songIdNormalize(s['id'].toString()) == songIdNormalize(id));
  }

  static String songIdNormalize(String id) => id.trim();
}
