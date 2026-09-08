import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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
  static final YoutubeExplode _yt = YoutubeExplode();
  static final Map<String, CachedAudioStream> _streamCache = {};

  // YouTube API Key from .env with provided default fallback
  static String get _apiKey {
    return dotenv.env['YOUTUBE_API_KEY'] ?? 'AIzaSyB_u-JtPpqJLiWiId2JW74ETNwqdgVCbRQ';
  }

  // Lista curada "Para ti" de éxitos de YouTube Music
  static final List<Map<String, dynamic>> _curatedSongs = [
    {
      'id': 'QCZZwZQ4qNs',
      'title': 'Si Antes Te Hubiera Conocido',
      'artist': 'KAROL G',
      'thumbnail': 'https://i.ytimg.com/vi/QCZZwZQ4qNs/hqdefault.jpg',
      'duration': 196,
    },
    {
      'id': 'x2oUajHp8pg',
      'title': 'LUNA',
      'artist': 'Feid, ATL Jacob',
      'thumbnail': 'https://i.ytimg.com/vi/x2oUajHp8pg/hqdefault.jpg',
      'duration': 200,
    },
    {
      'id': 'lZiaYpff9DY',
      'title': 'Ella Baila Sola',
      'artist': 'Eslabon Armado & Peso Pluma',
      'thumbnail': 'https://i.ytimg.com/vi/lZiaYpff9DY/hqdefault.jpg',
      'duration': 165,
    },
    {
      'id': 'C5_hZ2t9V1A',
      'title': 'MONACO',
      'artist': 'Bad Bunny',
      'thumbnail': 'https://i.ytimg.com/vi/C5_hZ2t9V1A/hqdefault.jpg',
      'duration': 267,
    },
    {
      'id': 'CocEMWJ7948',
      'title': 'Shakira: Bzrp Music Sessions, Vol. 53',
      'artist': 'Bizarrap & Shakira',
      'thumbnail': 'https://i.ytimg.com/vi/CocEMWJ7948/hqdefault.jpg',
      'duration': 213,
    },
    {
      'id': 'Q8jH_b26M7M',
      'title': 'Gata Only',
      'artist': 'FloyyMenor, Cris Mj',
      'thumbnail': 'https://i.ytimg.com/vi/Q8jH_b26M7M/hqdefault.jpg',
      'duration': 222,
    },
    {
      'id': 'mKz8i5uQx58',
      'title': 'LALA',
      'artist': 'Myke Towers',
      'thumbnail': 'https://i.ytimg.com/vi/mKz8i5uQx58/hqdefault.jpg',
      'duration': 198,
    },
    {
      'id': '_r4nBfqJ08M',
      'title': 'Columbia',
      'artist': 'Quevedo',
      'thumbnail': 'https://i.ytimg.com/vi/_r4nBfqJ08M/hqdefault.jpg',
      'duration': 190,
    },
  ];

  static Future<List<Map<String, dynamic>>> getCuratedSongs() async {
    return _curatedSongs;
  }

  /// Categorías estilo Instagram para explorar música
  static final List<String> categories = [
    'Tendencias',
    'Pop',
    'Reggaetón',
    'Urbano Latino',
    'Electrónica',
    'Rock',
    'Salsa',
    'Trap',
    'Bachata',
    'R&B',
  ];

  /// Limpia títulos de videos de YouTube para que parezcan pistas limpias de Instagram
  static String cleanTrackTitle(String title) {
    return title
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\(.*?Official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?Oficial.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?Video.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?Audio.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?Visualizer.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?Lyric.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?Letra.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?HD.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?4K.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\|.*'), '')
        .trim();
  }

  /// Parsea duración ISO 8601 de YouTube (ej. PT3M25S -> 205 segundos)
  static int parseIsoDuration(String isoDuration) {
    try {
      final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
      final match = regex.firstMatch(isoDuration);
      if (match != null) {
        final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
        final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
        return (hours * 3600) + (minutes * 60) + seconds;
      }
    } catch (_) {}
    return 180;
  }

  /// Búsqueda inteligente: Intenta primero YouTube Data API v3 y fallback instantáneo a YoutubeExplode
  static Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    if (query.trim().isEmpty) {
      return _curatedSongs;
    }

    final trimmedQuery = query.trim();

    // 1. Intentar con YouTube Data API v3 si está disponible
    if (_apiKey.isNotEmpty) {
      try {
        final searchUrl = Uri.parse(
          'https://www.googleapis.com/youtube/v3/search'
          '?part=snippet'
          '&type=video'
          '&videoCategoryId=10'
          '&maxResults=20'
          '&q=${Uri.encodeComponent('$trimmedQuery audio song')}'
          '&key=$_apiKey',
        );

        final response = await http.get(searchUrl).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'] as List? ?? [];
          final videoIds = <String>[];
          final List<Map<String, dynamic>> results = [];

          for (var item in items) {
            final videoId = item['id']?['videoId']?.toString();
            final snippet = item['snippet'];
            if (videoId != null && snippet != null) {
              videoIds.add(videoId);
              final rawTitle = snippet['title']?.toString() ?? 'Canción';
              final channelTitle = snippet['channelTitle']?.toString() ?? 'Artista';
              final thumbnails = snippet['thumbnails'];
              final thumbUrl = thumbnails?['medium']?['url']?.toString() ??
                  thumbnails?['high']?['url']?.toString() ??
                  thumbnails?['default']?['url']?.toString() ??
                  'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

              results.add({
                'id': videoId,
                'title': cleanTrackTitle(rawTitle),
                'artist': channelTitle.replaceAll(' - Topic', '').replaceAll('VEVO', '').trim(),
                'thumbnail': thumbUrl,
                'duration': 180, // Valor temporal hasta consultar contentDetails
              });
            }
          }

          // Consultar duraciones exactas con /videos?part=contentDetails
          if (videoIds.isNotEmpty) {
            try {
              final detailsUrl = Uri.parse(
                'https://www.googleapis.com/youtube/v3/videos'
                '?part=contentDetails'
                '&id=${videoIds.join(',')}'
                '&key=$_apiKey',
              );
              final detailsRes = await http.get(detailsUrl).timeout(const Duration(seconds: 3));
              if (detailsRes.statusCode == 200) {
                final dData = json.decode(detailsRes.body);
                final dItems = dData['items'] as List? ?? [];
                final Map<String, int> durationMap = {};
                for (var d in dItems) {
                  final vId = d['id']?.toString();
                  final isoDur = d['contentDetails']?['duration']?.toString();
                  if (vId != null && isoDur != null) {
                    durationMap[vId] = parseIsoDuration(isoDur);
                  }
                }
                for (var r in results) {
                  final vid = r['id'];
                  if (durationMap.containsKey(vid)) {
                    r['duration'] = durationMap[vid];
                  }
                }
              }
            } catch (_) {}
          }

          if (results.isNotEmpty) {
            return results;
          }
        }
      } catch (e) {
        if (kDebugMode) print('YouTube Data API v3 falló o fue bloqueada, usando YoutubeExplode fallback: $e');
      }
    }

    // 2. Fallback de alta resiliencia usando YoutubeExplode
    try {
      final searchResults = await _yt.search.search(trimmedQuery).timeout(const Duration(seconds: 6));
      final List<Map<String, dynamic>> parsedResults = [];

      for (var video in searchResults.take(20)) {
        final durationSec = video.duration?.inSeconds ?? 180;
        // Filtrar transmisiones en vivo o videos excesivamente largos (> 15 mins) para priorizar canciones
        if (durationSec > 0 && durationSec <= 900) {
          parsedResults.add({
            'id': video.id.value,
            'title': cleanTrackTitle(video.title),
            'artist': video.author.replaceAll(' - Topic', '').replaceAll('VEVO', '').trim(),
            'thumbnail': video.thumbnails.mediumResUrl.isNotEmpty
                ? video.thumbnails.mediumResUrl
                : 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg',
            'duration': durationSec,
          });
        }
      }

      if (parsedResults.isNotEmpty) {
        return parsedResults;
      }
    } catch (e) {
      if (kDebugMode) print('Error en búsqueda con YoutubeExplode: $e');
    }

    // 3. Fallback a canciones curadas locales
    final q = query.toLowerCase();
    return _curatedSongs.where((s) {
      final title = s['title'].toString().toLowerCase();
      final artist = s['artist'].toString().toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
  }

  /// Obtiene el flujo directo de audio (AAC/Opus con el mayor bitrate disponible)
  static Future<String?> getAudioStreamUrl(String videoId) async {
    // Si es una URL http legacy de versiones anteriores, retornarla directamente
    if (videoId.startsWith('http')) {
      return videoId;
    }

    // Verificar si está en caché y aún no expira
    final cached = _streamCache[videoId];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 6));
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        final bestAudio = audioStreams.withHighestBitrate();
        final url = bestAudio.url.toString();

        _streamCache[videoId] = CachedAudioStream(
          url: url,
          durationSeconds: 180,
          expiresAt: DateTime.now().add(const Duration(hours: 4)),
        );

        return url;
      }
    } catch (e) {
      if (kDebugMode) print('Error obteniendo flujo de audio de YouTube para $videoId: $e');
    }

    return null;
  }

  /// Obtiene la duración total de un video de YouTube en segundos
  static Future<int> getTrackDuration(String videoId, {int defaultDuration = 180}) async {
    try {
      final video = await _yt.videos.get(videoId).timeout(const Duration(seconds: 4));
      if (video.duration != null && video.duration!.inSeconds > 0) {
        return video.duration!.inSeconds;
      }
    } catch (_) {}
    return defaultDuration;
  }

  // Clave de canciones guardadas
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
    return songs.any((s) => songIdNormalize(s['id'].toString()) == songIdNormalize(id));
  }

  static String songIdNormalize(String id) => id.trim();
}
