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
    'https://invidious.f5.si',
    'https://inv.nadeko.net',
  ];

  /// Crea una fuente de audio (AudioSource) directa y segura para streaming
  /// Si es una URL de YouTube / googlevideo.com, inyecta los headers requeridos
  /// para evitar que Google devuelva HTTP 403 Forbidden a ExoPlayer / AVPlayer.
  static Future<AudioSource> createAudioSource(String url, {String? cacheKey}) async {
    final uri = Uri.parse(url);
    final isYouTube = url.contains('googlevideo.com') || url.contains('youtube.com');
    if (isYouTube) {
      return AudioSource.uri(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://www.youtube.com/',
        },
      );
    }
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
      'thumbnail': 'https://i.ytimg.com/vi/QCZZwZQ4qNs/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/kPa7bsKwL-c/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/V9PVRfjEBTI/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/x2oUajHp8pg/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/eVli-tstM5E/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/L7H_b_U98E4/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/c30C583N9d4/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/O2Z4r1vS2S0/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/mCDz4wUoI5U/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/Oa_RSwwpPaA/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/t7bQwwqW-Hc/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/UBhlqeX4844/hqdefault.jpg',
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
      'thumbnail': 'https://i.ytimg.com/vi/9Qz8jFf0mN0/hqdefault.jpg',
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
        DateTime.now().difference(_topChartsCacheTime!).inMinutes < 15) {
      return _cachedTopCharts;
    }

    try {
      final results = await _searchYouTube('tendencias musica 2025');
      if (results.isNotEmpty) {
        _cachedTopCharts = results;
        _topChartsCacheTime = DateTime.now();
        return results;
      }
    } catch (e) {
      if (kDebugMode) print('[MusicService] Error cargando tendencias de YouTube: $e');
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

  /// Búsqueda 100% directa en YouTube (Invidious API + YoutubeExplode)
  /// Devuelve pistas completas de 3 a 5 minutos sin límites de 30 segundos
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

    // 2. Búsqueda en YouTube Engine (Invidious Mirror + YoutubeExplode)
    return await _searchYouTube(trimmedQuery);
  }

  /// Busca canciones completas en YouTube
  static Future<List<Map<String, dynamic>>> _searchYouTube(String query) async {
    final encoded = Uri.encodeComponent(query);

    // 1. Probar instancias de Invidious YouTube Engine (las mismas del panel de administración)
    for (final host in _invidiousHosts) {
      try {
        final uri = Uri.parse('$host/api/v1/search?q=$encoded&type=video');
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final items = json.decode(res.body) as List? ?? [];
          final mapped = _mapInvidiousItems(items);
          if (mapped.isNotEmpty) {
            return mapped;
          }
        }
      } catch (_) {}
    }

    // 2. Respaldo directo vía YoutubeExplode scraper
    try {
      final yt = YoutubeExplode();
      final results = await yt.search.search(query).timeout(const Duration(seconds: 5));
      yt.close();
      if (results.isNotEmpty) {
        return results.map((v) {
          final videoId = v.id.value;
          final thumb = v.thumbnails.mediumResUrl.isNotEmpty
              ? v.thumbnails.mediumResUrl
              : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
          return {
            'id': videoId,
            'spotifyId': videoId,
            'title': v.title,
            'artist': v.author,
            'thumbnail': thumb,
            'duration': v.duration?.inSeconds ?? 180,
            'audioUrl': '',
            'spotifyUri': '',
            'isSpotify': false,
          };
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[MusicService] Error en búsqueda de YoutubeExplode: $e');
    }

    // 3. Fallback a canciones curadas si no hay conexión
    final q = query.toLowerCase();
    final matches = _curatedSongs.where((s) {
      final title = s['title'].toString().toLowerCase();
      final artist = s['artist'].toString().toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
    if (matches.isNotEmpty) return matches;

    return getCuratedSongs();
  }

  /// Mapea resultados válidos de YouTube con su duración completa
  static List<Map<String, dynamic>> _mapInvidiousItems(List items) {
    final results = <Map<String, dynamic>>[];
    for (var item in items) {
      final videoId = item['videoId']?.toString() ?? '';
      final title = item['title']?.toString() ?? '';
      final author = item['author']?.toString() ?? 'YouTube';
      final duration = item['lengthSeconds'] as int? ?? 180;

      String thumb = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      if (item['videoThumbnails'] is List && (item['videoThumbnails'] as List).isNotEmpty) {
        final thumbs = item['videoThumbnails'] as List;
        thumb = thumbs.first['url']?.toString() ?? thumb;
      }

      if (videoId.isNotEmpty && title.isNotEmpty) {
        results.add({
          'id': videoId,
          'spotifyId': videoId,
          'title': title,
          'artist': author,
          'thumbnail': thumb,
          'duration': duration > 0 ? duration : 180,
          'audioUrl': '',
          'spotifyUri': '',
          'isSpotify': false,
        });
      }
    }
    return results;
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
        'thumbnail': video.thumbnails.highResUrl.isNotEmpty
            ? video.thumbnails.highResUrl
            : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
        'duration': video.duration?.inSeconds ?? 180,
        'audioUrl': '',
        'spotifyUri': '',
        'isSpotify': false,
      };
    } catch (e) {
      if (kDebugMode) print('[MusicService] Error resolviendo video de YouTube: $e');
      return null;
    } finally {
      yt.close();
    }
  }

  /// Busca el Video ID de YouTube correspondiente para un título y artista
  static Future<String?> _findYouTubeVideoId(String query) async {
    final encoded = Uri.encodeComponent(query);
    for (final host in _invidiousHosts) {
      try {
        final uri = Uri.parse('$host/api/v1/search?q=$encoded&type=video');
        final res = await http.get(uri).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final items = json.decode(res.body) as List? ?? [];
          final first = items.firstWhere(
            (it) => it['videoId'] != null && it['title'] != null,
            orElse: () => null,
          );
          if (first != null && first['videoId'] != null) {
            return first['videoId'].toString();
          }
        }
      } catch (_) {}
    }

    try {
      final yt = YoutubeExplode();
      final results = await yt.search.search(query).timeout(const Duration(seconds: 4));
      yt.close();
      if (results.isNotEmpty) {
        return results.first.id.value;
      }
    } catch (_) {}

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

    // Si aún no tenemos Video ID, buscarlo directamente en YouTube
    if (targetVideoId == null || targetVideoId.isEmpty) {
      final q = '$searchTitle $searchArtist audio'.trim();
      targetVideoId = await _findYouTubeVideoId(q);
      targetVideoId ??= await _findYouTubeVideoId('$searchTitle $searchArtist'.trim());
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
      };
    }

    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient
          .getManifest(targetVideoId)
          .timeout(const Duration(seconds: 6));

      // Seleccionar MP4 / AAC (itag 140 o 139) para compatibilidad nativa absoluta
      final mp4Streams = manifest.audioOnly.where(
        (s) =>
            s.container == StreamContainer.mp4 ||
            s.codec.mimeType.contains('mp4') ||
            s.tag == 140 ||
            s.tag == 139,
      ).toList();

      final audioStream = mp4Streams.isNotEmpty
          ? mp4Streams.withHighestBitrate()
          : manifest.audioOnly.withHighestBitrate();

      final durSec = expectedDurationSec ?? 180;
      final streamUrl = audioStream.url.toString();

      _streamCache[cacheKey] = CachedAudioStream(
        url: streamUrl,
        durationSeconds: durSec,
        expiresAt: DateTime.now().add(const Duration(hours: 4)),
      );

      return {
        'url': streamUrl,
        'durationSeconds': durSec,
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

    // 1. Si ya es un stream de YouTube fresco o directo
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
      expectedDurationSec: 180,
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
