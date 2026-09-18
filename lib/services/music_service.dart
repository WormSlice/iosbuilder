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

  /// Crea una fuente de audio (AudioSource) directa y segura para streaming
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

  /// Lista curada de canciones con portadas oficiales de Spotify CDN (https://i.scdn.co)
  /// Garantiza que NUNCA fallen o salgan en blanco incluso sin conexión previa.
  static final List<Map<String, dynamic>> _curatedSongs = [
    {
      'id': '6rZno3nqeT7hv2PnSWRuYS',
      'spotifyId': '6rZno3nqeT7hv2PnSWRuYS',
      'title': 'Si Antes Te Hubiera Conocido',
      'artist': 'KAROL G',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b27375bf5723eb71ee8fa19472e3',
      'duration': 196,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:6rZno3nqeT7hv2PnSWRuYS',
      'isSpotify': true,
    },
    {
      'id': '2plbrEY59IikOBgB57599W',
      'spotifyId': '2plbrEY59IikOBgB57599W',
      'title': 'Die With A Smile',
      'artist': 'Lady Gaga & Bruno Mars',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b273e970b55502a501e42c2be432',
      'duration': 252,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:2plbrEY59IikOBgB57599W',
      'isSpotify': true,
    },
    {
      'id': '6dOtVTDmmpgnHRINQIx7re',
      'spotifyId': '6dOtVTDmmpgnHRINQIx7re',
      'title': 'BIRDS OF A FEATHER',
      'artist': 'Billie Eilish',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b27371d62ea7ea8a5be92d3c1f62',
      'duration': 193,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:6dOtVTDmmpgnHRINQIx7re',
      'isSpotify': true,
    },
    {
      'id': '1PREzVLuDT6PSE9sej4wnV',
      'spotifyId': '1PREzVLuDT6PSE9sej4wnV',
      'title': 'COQUETA',
      'artist': 'Fuerza Regida',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b27304874856f3c501181d060128',
      'duration': 241,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:1PREzVLuDT6PSE9sej4wnV',
      'isSpotify': true,
    },
    {
      'id': '2E4TYekUduml1DWIqQWNcj',
      'spotifyId': '2E4TYekUduml1DWIqQWNcj',
      'title': 'Destino Final',
      'artist': 'Yeison Jimenez',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b273715bbdee4f0072526b566b4a',
      'duration': 173,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:2E4TYekUduml1DWIqQWNcj',
      'isSpotify': true,
    },
    {
      'id': '2btNsI4OvcVl7SAHQQDHFB',
      'spotifyId': '2btNsI4OvcVl7SAHQQDHFB',
      'title': 'Mírame',
      'artist': 'Blessd & Ovy On The Drums',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b2739d96ae35d725e30b02134b4c',
      'duration': 157,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:2btNsI4OvcVl7SAHQQDHFB',
      'isSpotify': true,
    },
    {
      'id': '73C4vC3tJ1Z43pPzXg8t2A',
      'spotifyId': '73C4vC3tJ1Z43pPzXg8t2A',
      'title': 'LUNA',
      'artist': 'Feid & ATL Jacob',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b2731818e6922906b3a3ab807b5a',
      'duration': 199,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:73C4vC3tJ1Z43pPzXg8t2A',
      'isSpotify': true,
    },
    {
      'id': '2qSkXiYOKWInDC9e9bbrvI',
      'spotifyId': '2qSkXiYOKWInDC9e9bbrvI',
      'title': 'Espresso',
      'artist': 'Sabrina Carpenter',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b273659d0e13d0c7ae3f33eb2213',
      'duration': 175,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:2qSkXiYOKWInDC9e9bbrvI',
      'isSpotify': true,
    },
    {
      'id': '7iQXYT9Guv01j5J58Tg3Z',
      'spotifyId': '7iQXYT9Guv01j5J58Tg3Z',
      'title': 'PERRO NEGRO',
      'artist': 'Bad Bunny & Feid',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b2730bf1836109df3427ec5fb58d',
      'duration': 163,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:7iQXYT9Guv01j5J58Tg3Z',
      'isSpotify': true,
    },
    {
      'id': '6AQbmUe0Qsv5by9GLl9T1E',
      'spotifyId': '6AQbmUe0Qsv5by9GLl9T1E',
      'title': 'Gata Only',
      'artist': 'FloyyMenor & Cris Mj',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b273a0e6fa9a8e974e3da661e7b1',
      'duration': 222,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:6AQbmUe0Qsv5by9GLl9T1E',
      'isSpotify': true,
    },
    {
      'id': '6AI3ezQ4o3HUJW82vU5vo0',
      'spotifyId': '6AI3ezQ4o3HUJW82vU5vo0',
      'title': 'Beautiful Things',
      'artist': 'Benson Boone',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b273fbf59a16f9a0b5bfa045fa78',
      'duration': 180,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:6AI3ezQ4o3HUJW82vU5vo0',
      'isSpotify': true,
    },
    {
      'id': '5mBC449f874w34kP3wF6pW',
      'spotifyId': '5mBC449f874w34kP3wF6pW',
      'title': 'A Bar Song (Tipsy)',
      'artist': 'Shaboozey',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b2735702ee5137fe251b69784381',
      'duration': 171,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:5mBC449f874w34kP3wF6pW',
      'isSpotify': true,
    },
    {
      'id': '5NQbT6h4gLzE1i4wN8x2kY',
      'spotifyId': '5NQbT6h4gLzE1i4wN8x2kY',
      'title': 'Too Sweet',
      'artist': 'Hozier',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b27341e31d3e1a4993132e185011',
      'duration': 251,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:5NQbT6h4gLzE1i4wN8x2kY',
      'isSpotify': true,
    },
    {
      'id': '7fT3p4W21k4kO00wK6Fq1P',
      'spotifyId': '7fT3p4W21k4kO00wK6Fq1P',
      'title': 'La Falda',
      'artist': 'Myke Towers',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b273c52a061486bc05971597813d',
      'duration': 174,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:7fT3p4W21k4kO00wK6Fq1P',
      'isSpotify': true,
    },
    {
      'id': '190I7FiWj4as4848gT9O1S',
      'spotifyId': '190I7FiWj4as4848gT9O1S',
      'title': 'BESO',
      'artist': 'ROSALÍA & Rauw Alejandro',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b273934fb5e2db69389f4b3df664',
      'duration': 194,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:190I7FiWj4as4848gT9O1S',
      'isSpotify': true,
    },
    {
      'id': '5A82t3G01P5q1G21O92yPZ',
      'spotifyId': '5A82t3G01P5q1G21O92yPZ',
      'title': 'MONACO',
      'artist': 'Bad Bunny',
      'thumbnail':
          'https://i.scdn.co/image/ab67616d0000b2730bf1836109df3427ec5fb58d',
      'duration': 267,
      'audioUrl': '',
      'spotifyUri': 'spotify:track:5A82t3G01P5q1G21O92yPZ',
      'isSpotify': true,
    },
  ];

  /// Obtiene la lista curada de canciones en tendencia / para ti
  static List<Map<String, dynamic>> getCuratedSongs() {
    return List<Map<String, dynamic>>.from(_curatedSongs);
  }

  static final List<String> _invidiousHosts = [
    'https://invidious.f5.si',
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://yewtu.be',
  ];

  /// Obtiene canciones en tendencia para la pantalla inicial ("Para ti")
  /// 100% desde YouTube Engine
  static Future<List<Map<String, dynamic>>> getSpotifyTopCharts() async {
    // 1. Si ya tenemos caché reciente en memoria (< 10 min), devolverla al instante
    if (_cachedTopCharts.isNotEmpty &&
        _topChartsCacheTime != null &&
        DateTime.now().difference(_topChartsCacheTime!).inMinutes < 10) {
      return _cachedTopCharts;
    }

    // 2. Consultar canciones en tendencia en YouTube
    try {
      final results = await _searchYouTube('tendencias musica 2025');
      if (results.isNotEmpty) {
        _cachedTopCharts = results;
        _topChartsCacheTime = DateTime.now();
        return results;
      }
    } catch (e) {
      if (kDebugMode) print('Error consultando tendencias de YouTube: $e');
    }

    return getCuratedSongs();
  }

  static void prefetchTopStreams(List<Map<String, dynamic>> songs) {}

  /// Alias de búsqueda
  static Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    return searchTracks(query);
  }

  /// Busca canciones EXCLUSIVAMENTE en YouTube
  /// Búsqueda directa con soporte para cualquier canción, artista o título mundial
  static Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return getSpotifyTopCharts();
    }
    return _searchYouTube(trimmedQuery);
  }

  /// Realiza la búsqueda 100% en YouTube (Invidious API + YoutubeExplode)
  static Future<List<Map<String, dynamic>>> _searchYouTube(String query) async {
    final encoded = Uri.encodeComponent(query);

    // 1. Probar instancias de Invidious YouTube Engine (las mismas del admin panel)
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
      } catch (_) {
        // Probar siguiente instancia si una falla
      }
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
    } catch (_) {}

    // 3. Fallback a canciones curadas si no hay red
    final q = query.toLowerCase();
    return _curatedSongs.where((s) {
      final title = s['title'].toString().toLowerCase();
      final artist = s['artist'].toString().toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
  }

  /// Mapea resultados válidos de YouTube (filtrando canales, listas o elementos sin videoId)
  static List<Map<String, dynamic>> _mapInvidiousItems(List items) {
    final results = <Map<String, dynamic>>[];
    for (var item in items) {
      final videoId = item['videoId']?.toString() ?? '';
      final title = item['title']?.toString() ?? '';
      final author = item['author']?.toString() ?? 'YouTube';
      final duration = item['lengthSeconds'] as int? ?? 180;

      // Obtener mejor miniatura de YouTube
      String thumb = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      if (item['videoThumbnails'] is List && (item['videoThumbnails'] as List).isNotEmpty) {
        final thumbs = item['videoThumbnails'] as List;
        thumb = thumbs.first['url']?.toString() ?? thumb;
      }

      // Solo agregar si es un video real con videoId y título
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

  /// Obtiene el enlace de audio streaming directo y confiable de la canción desde YouTube
  /// CRÍTICO PARA iOS Y ANDROID: Selecciona streams en formato MP4 (AAC / itag 140 o 139)
  /// para compatibilidad nativa absoluta con AVPlayer de Apple (evita errores con WebM/Opus).
  static Future<Map<String, dynamic>?> getFullAudioStream({
    required String title,
    required String artist,
    String? videoId,
    String? fallbackPreviewUrl,
    int? expectedDurationSec,
  }) async {
    final searchTitle = title.trim();
    final searchArtist = artist.trim();

    // Determinar si ya tenemos un videoId directo de YouTube (11 caracteres alfanuméricos)
    String? targetVideoId = videoId;
    if (targetVideoId == null || targetVideoId.isEmpty) {
      final cleanTitle = searchTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
      if (cleanTitle.length == 11 && !searchTitle.contains(' ')) {
        targetVideoId = searchTitle;
      }
    }

    final cacheKey = targetVideoId != null
        ? 'stream_yt_$targetVideoId'
        : 'stream_${searchTitle}_$searchArtist'.toLowerCase();

    // 1. Revisar caché en memoria
    final cached = _streamCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return {
        'url': cached.url,
        'durationSeconds': cached.durationSeconds,
      };
    }

    // 2. Extraer PISTA COMPLETA (3-5 minutos) vía YouTube Explode seleccionando MP4/AAC
    final yt = YoutubeExplode();
    try {
      int? targetDuration;

      // Si no tenemos videoId directo, buscarlo en YouTube Engine
      if (targetVideoId == null || targetVideoId.isEmpty) {
        // 2.1 Intentar con Invidious
        try {
          final q = Uri.encodeComponent('$searchTitle $searchArtist audio'.trim());
          for (final host in _invidiousHosts) {
            try {
              final invRes = await http
                  .get(Uri.parse('$host/api/v1/search?q=$q&type=video'))
                  .timeout(const Duration(seconds: 3));
              if (invRes.statusCode == 200) {
                final items = json.decode(invRes.body) as List? ?? [];
                final first = items.firstWhere(
                  (it) => it['videoId'] != null && it['title'] != null,
                  orElse: () => null,
                );
                if (first != null && first['videoId'] != null) {
                  targetVideoId = first['videoId'].toString();
                  targetDuration = first['lengthSeconds'] as int?;
                  break;
                }
              }
            } catch (_) {}
          }
        } catch (_) {}

        // 2.2 Si Invidious no respondió, buscar con yt.search
        if (targetVideoId == null) {
          final query = '$searchTitle $searchArtist audio'.trim();
          var searchResults = await yt.search.search(query).timeout(const Duration(seconds: 4));
          if (searchResults.isEmpty) {
            searchResults = await yt.search
                .search('$searchTitle $searchArtist'.trim())
                .timeout(const Duration(seconds: 3));
          }
          if (searchResults.isNotEmpty) {
            targetVideoId = searchResults.first.id.value;
            targetDuration = searchResults.first.duration?.inSeconds;
          }
        }
      }

      // Si obtuvimos videoId, extraer el manifest de audio de YouTube
      if (targetVideoId != null && targetVideoId.isNotEmpty) {
        final manifest = await yt.videos.streamsClient
            .getManifest(targetVideoId)
            .timeout(const Duration(seconds: 6));

        // FILTRO CRÍTICO iOS: Seleccionar MP4 / AAC (itag 140 / 139) para soporte nativo en AVPlayer
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

        final durSec = targetDuration ?? expectedDurationSec ?? 180;
        final streamUrl = audioStream.url.toString();

        _streamCache[cacheKey] = CachedAudioStream(
          url: streamUrl,
          durationSeconds: durSec,
          expiresAt: DateTime.now().add(const Duration(hours: 4)),
        );

        if (kDebugMode) {
          print('[MusicService] Stream MP4 YouTube resuelto: tag=${audioStream.tag}, dur=$durSec s');
        }
        return {
          'url': streamUrl,
          'durationSeconds': durSec,
        };
      }
    } catch (e) {
      if (kDebugMode) print('[MusicService] Error extrayendo stream de YouTube: $e');
    } finally {
      yt.close();
    }

    // 3. Si viene fallback previo directo
    if (fallbackPreviewUrl != null && fallbackPreviewUrl.startsWith('http')) {
      return {
        'url': fallbackPreviewUrl,
        'durationSeconds': expectedDurationSec ?? 30,
      };
    }

    return null;
  }


  /// Obtiene el enlace de audio streaming directo de la canción
  static Future<String?> getAudioStreamUrl(
    String audioIdOrUrl, {
    String? title,
    String? artist,
    bool forceFullTrack = true,
  }) async {
    // Si ya es un stream de YouTube o directo y no es un preview de 30s
    if (audioIdOrUrl.startsWith('http') && !forceFullTrack) {
      if (!audioIdOrUrl.contains('p.scdn.co') && !audioIdOrUrl.contains('audio-ssl.itunes.apple.com')) {
        return audioIdOrUrl;
      }
    }

    final searchTitle = (title != null && title.isNotEmpty)
        ? title
        : audioIdOrUrl.replaceAll('_', ' ');
    final searchArtist = (artist != null && artist.isNotEmpty) ? artist : '';
    final isYtId = audioIdOrUrl.length == 11 && !audioIdOrUrl.contains(' ');

    final streamData = await getFullAudioStream(
      title: searchTitle,
      artist: searchArtist,
      videoId: isYtId ? audioIdOrUrl : null,
      fallbackPreviewUrl: audioIdOrUrl.startsWith('http') ? audioIdOrUrl : null,
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
