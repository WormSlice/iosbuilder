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

  // Lista curada "Para ti" con los éxitos Top del momento mundiales y latinos
  static final List<Map<String, dynamic>> _curatedSongs = [
    {
      'id': 'QCZZwZQ4qNs',
      'title': 'Si Antes Te Hubiera Conocido',
      'artist': 'KAROL G',
      'thumbnail': 'https://i.ytimg.com/vi/QCZZwZQ4qNs/hqdefault.jpg',
      'duration': 196,
    },
    {
      'id': 'PfH7jq_uSCM',
      'title': 'Die With A Smile',
      'artist': 'Lady Gaga, Bruno Mars',
      'thumbnail': 'https://i.ytimg.com/vi/PfH7jq_uSCM/hqdefault.jpg',
      'duration': 252,
    },
    {
      'id': 'd5gf9dXbPi0',
      'title': 'BIRDS OF A FEATHER',
      'artist': 'Billie Eilish',
      'thumbnail': 'https://i.ytimg.com/vi/d5gf9dXbPi0/hqdefault.jpg',
      'duration': 212,
    },
    {
      'id': '51zjlMhdSTE',
      'title': 'Espresso',
      'artist': 'Sabrina Carpenter',
      'thumbnail': 'https://i.ytimg.com/vi/51zjlMhdSTE/hqdefault.jpg',
      'duration': 176,
    },
    {
      'id': 'z9Q9OzL_wI8',
      'title': 'Taste',
      'artist': 'Sabrina Carpenter',
      'thumbnail': 'https://i.ytimg.com/vi/z9Q9OzL_wI8/hqdefault.jpg',
      'duration': 158,
    },
    {
      'id': 'Yl_thbk40A0',
      'title': 'Please Please Please',
      'artist': 'Sabrina Carpenter',
      'thumbnail': 'https://i.ytimg.com/vi/Yl_thbk40A0/hqdefault.jpg',
      'duration': 187,
    },
    {
      'id': 'x2oUajHp8pg',
      'title': 'LUNA',
      'artist': 'Feid, ATL Jacob',
      'thumbnail': 'https://i.ytimg.com/vi/x2oUajHp8pg/hqdefault.jpg',
      'duration': 199,
    },
    {
      'id': '-r687V8yqKY',
      'title': 'Gata Only',
      'artist': 'FloyyMenor, Cris Mj',
      'thumbnail': 'https://i.ytimg.com/vi/-r687V8yqKY/hqdefault.jpg',
      'duration': 222,
    },
    {
      'id': 'Oa_RSwwpPaA',
      'title': 'Beautiful Things',
      'artist': 'Benson Boone',
      'thumbnail': 'https://i.ytimg.com/vi/Oa_RSwwpPaA/hqdefault.jpg',
      'duration': 193,
    },
    {
      'id': 'Zf1d8SGuxfs',
      'title': 'MILLION DOLLAR BABY',
      'artist': 'Tommy Richman',
      'thumbnail': 'https://i.ytimg.com/vi/Zf1d8SGuxfs/hqdefault.jpg',
      'duration': 155,
    },
    {
      'id': 'xCh1T6fcRo8',
      'title': 'Good Luck, Babe!',
      'artist': 'Chappell Roan',
      'thumbnail': 'https://i.ytimg.com/vi/xCh1T6fcRo8/hqdefault.jpg',
      'duration': 219,
    },
    {
      'id': 'nZjTtuNR3Og',
      'title': 'A Bar Song (Tipsy)',
      'artist': 'Shaboozey',
      'thumbnail': 'https://i.ytimg.com/vi/nZjTtuNR3Og/hqdefault.jpg',
      'duration': 172,
    },
    {
      'id': 'aezstCBHOPQ',
      'title': 'Too Sweet',
      'artist': 'Hozier',
      'thumbnail': 'https://i.ytimg.com/vi/aezstCBHOPQ/hqdefault.jpg',
      'duration': 252,
    },
    {
      'id': '9V_HpS9p4QY',
      'title': 'Santa',
      'artist': 'Rvssian, Rauw Alejandro, Ayra Starr',
      'thumbnail': 'https://i.ytimg.com/vi/9V_HpS9p4QY/hqdefault.jpg',
      'duration': 199,
    },
    {
      'id': 'pyZtr3_dN3E',
      'title': 'La Falda',
      'artist': 'Myke Towers',
      'thumbnail': 'https://i.ytimg.com/vi/pyZtr3_dN3E/hqdefault.jpg',
      'duration': 228,
    },
    {
      'id': 'a6tgD_CsYTQ',
      'title': 'PERRO NEGRO',
      'artist': 'Bad Bunny, Feid',
      'thumbnail': 'https://i.ytimg.com/vi/a6tgD_CsYTQ/hqdefault.jpg',
      'duration': 163,
    },
    {
      'id': 'BeUOBoSPWvA',
      'title': 'QLONA',
      'artist': 'KAROL G, Peso Pluma',
      'thumbnail': 'https://i.ytimg.com/vi/BeUOBoSPWvA/hqdefault.jpg',
      'duration': 173,
    },
    {
      'id': '_PJvpq8uOZM',
      'title': 'MONACO',
      'artist': 'Bad Bunny',
      'thumbnail': 'https://i.ytimg.com/vi/_PJvpq8uOZM/hqdefault.jpg',
      'duration': 267,
    },
    {
      'id': 'BVdngsy95mY',
      'title': 'LALA',
      'artist': 'Myke Towers',
      'thumbnail': 'https://i.ytimg.com/vi/BVdngsy95mY/hqdefault.jpg',
      'duration': 198,
    },
    {
      'id': '8AtiHCDGZ8c',
      'title': 'Greedy',
      'artist': 'Tate McRae',
      'thumbnail': 'https://i.ytimg.com/vi/8AtiHCDGZ8c/hqdefault.jpg',
      'duration': 134,
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

  /// Búsqueda rápida y completa: usa iTunes Search API de alta velocidad con portadas HD
  /// y respaldo con YouTube Data API / YoutubeExplode
  static Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    if (query.trim().isEmpty) {
      return _curatedSongs;
    }

    final trimmedQuery = query.trim();

    // 1. Intentar con iTunes Search API (rápido, sin límites de cuota, portadas en alta definición y nombres oficiales)
    try {
      final itunesUrl = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(trimmedQuery)}&entity=song&limit=25',
      );
      final response = await http.get(itunesUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['results'] as List? ?? [];
        final List<Map<String, dynamic>> results = [];

        for (var item in items) {
          final trackName = item['trackName']?.toString() ?? '';
          final artistName = item['artistName']?.toString() ?? '';
          final artworkUrl100 = item['artworkUrl100']?.toString() ?? '';
          final artworkHd = artworkUrl100.replaceAll('100x100bb', '600x600bb');
          final durationMs = item['trackTimeMillis'] as int? ?? 180000;
          final durationSec = durationMs ~/ 1000;

          if (trackName.isNotEmpty) {
            results.add({
              'id': '${trackName}_$artistName',
              'title': trackName,
              'artist': artistName,
              'thumbnail': artworkHd,
              'duration': durationSec > 0 ? durationSec : 180,
            });
          }
        }

        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (e) {
      if (kDebugMode) print('iTunes Search fallback: $e');
    }

    // 2. Fallback usando YoutubeExplode
    try {
      final searchResults = await _yt.search.search(trimmedQuery).timeout(const Duration(seconds: 5));
      final List<Map<String, dynamic>> parsedResults = [];

      for (var video in searchResults.take(20)) {
        final durationSec = video.duration?.inSeconds ?? 180;
        if (durationSec > 0 && durationSec <= 900) {
          parsedResults.add({
            'id': video.id.value,
            'title': video.title,
            'artist': video.author.replaceAll(' - Topic', '').replaceAll('VEVO', '').trim(),
            'thumbnail': video.thumbnails.highResUrl.isNotEmpty
                ? video.thumbnails.highResUrl
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

  /// Obtiene el flujo directo de audio (AAC/MP4 con soporte nativo en Android ExoPlayer e iOS AVPlayer)
  static Future<String?> getAudioStreamUrl(
    String videoId, {
    String? title,
    String? artist,
  }) async {
    if (videoId.startsWith('http')) {
      return videoId;
    }

    // Clave de caché única
    final cacheKey = (title != null && artist != null) ? '${title}_$artist' : videoId;

    // 1. Verificar si está en caché y aún no expira
    final cached = _streamCache[cacheKey] ?? _streamCache[videoId];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // 2. Si videoId no es un ID compuesto de búsqueda (longitud típica de YouTube es 11 caracteres)
    if (videoId.length == 11 && !videoId.contains('_')) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 6));
        final audioStreams = manifest.audioOnly;
        if (audioStreams.isNotEmpty) {
          final mp4Streams = audioStreams.where(
            (s) => s.container.name.toLowerCase().contains('mp4') || s.container.name.toLowerCase().contains('m4a'),
          );

          final bestAudio = mp4Streams.isNotEmpty
              ? mp4Streams.withHighestBitrate()
              : audioStreams.withHighestBitrate();

          final url = bestAudio.url.toString();

          final cachedStream = CachedAudioStream(
            url: url,
            durationSeconds: 180,
            expiresAt: DateTime.now().add(const Duration(hours: 4)),
          );
          _streamCache[videoId] = cachedStream;
          _streamCache[cacheKey] = cachedStream;

          return url;
        }
      } catch (e) {
        if (kDebugMode) print('Video directo $videoId no disponible ($e). Intentando búsqueda de pista abierta...');
      }
    }

    // 3. Auto-recuperación y resolución de pista por título y artista
    final searchTitle = (title != null && title.isNotEmpty) ? title : videoId.replaceAll('_', ' ');
    final searchArtist = (artist != null && artist.isNotEmpty) ? artist : '';
    final queryTerms = searchArtist.isNotEmpty ? '$searchTitle $searchArtist audio' : '$searchTitle audio';

    try {
      final searchResults = await _yt.search.search(queryTerms).timeout(const Duration(seconds: 5));
      for (var candidate in searchResults.take(4)) {
        try {
          final candidateManifest = await _yt.videos.streamsClient.getManifest(candidate.id).timeout(const Duration(seconds: 5));
          final candidateAudios = candidateManifest.audioOnly;
          if (candidateAudios.isNotEmpty) {
            final mp4Streams = candidateAudios.where(
              (s) => s.container.name.toLowerCase().contains('mp4') || s.container.name.toLowerCase().contains('m4a'),
            );
            final bestAudio = mp4Streams.isNotEmpty
                ? mp4Streams.withHighestBitrate()
                : candidateAudios.withHighestBitrate();

            final url = bestAudio.url.toString();

            final cachedStream = CachedAudioStream(
              url: url,
              durationSeconds: candidate.duration?.inSeconds ?? 180,
              expiresAt: DateTime.now().add(const Duration(hours: 4)),
            );
            _streamCache[videoId] = cachedStream;
            _streamCache[cacheKey] = cachedStream;

            return url;
          }
        } catch (_) {}
      }
    } catch (err) {
      if (kDebugMode) print('Error en resolución de audio para $searchTitle: $err');
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
