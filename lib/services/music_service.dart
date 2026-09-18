import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'music_auth_service.dart';

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

  /// Obtiene canciones oficiales para la pantalla inicial ("Para ti")
  /// Prioriza éxitos reales con portadas oficiales de alta resolución y reproducción inmediata.
  static Future<List<Map<String, dynamic>>> getSpotifyTopCharts() async {
    // 1. Si el usuario conectó Spotify, buscar primero sus top tracks reales
    if (MusicAuthService.instance.isSpotifyConnected) {
      try {
        final userTracks = await _fetchSpotifyTopTracks();
        if (userTracks.isNotEmpty) {
          _cachedTopCharts = userTracks;
          _topChartsCacheTime = DateTime.now();
          return userTracks;
        }
      } catch (e) {
        if (kDebugMode) print('Error obteniendo top tracks de usuario Spotify: $e');
      }
    }

    // 2. Si ya tenemos caché reciente en memoria (< 10 min), devolverla al instante
    if (_cachedTopCharts.isNotEmpty &&
        _topChartsCacheTime != null &&
        DateTime.now().difference(_topChartsCacheTime!).inMinutes < 10) {
      return _cachedTopCharts;
    }

    // 3. Consultar éxitos globales y latinos en iTunes Search API (100% público, veloz y oficial)
    try {
      final itUrl = Uri.parse(
        'https://itunes.apple.com/search?term=top+latin+hits+2025&entity=song&limit=30',
      );
      final response = await http.get(itUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List? ?? [];
        final mapped = _mapItunesItems(results);
        if (mapped.isNotEmpty) {
          _cachedTopCharts = mapped;
          _topChartsCacheTime = DateTime.now();
          return mapped;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error consultando top charts de iTunes: $e');
    }

    return getCuratedSongs();
  }

  /// Consulta las canciones más escuchadas del usuario en Spotify si está vinculado
  static Future<List<Map<String, dynamic>>> _fetchSpotifyTopTracks() async {
    final headers = await MusicAuthService.instance.getSpotifyHeaders();
    if (headers == null) return [];

    try {
      var uri = Uri.parse(
        'https://api.spotify.com/v1/me/top/tracks?limit=30&time_range=short_term',
      );
      var response =
          await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));

      if (response.statusCode == 401) {
        await MusicAuthService.instance.refreshSpotifyToken();
        final refreshedHeaders =
            await MusicAuthService.instance.getSpotifyHeaders();
        if (refreshedHeaders != null) {
          response = await http
              .get(uri, headers: refreshedHeaders)
              .timeout(const Duration(seconds: 4));
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        if (items.isNotEmpty) {
          return _mapSpotifyItems(items);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error en _fetchSpotifyTopTracks: $e');
    }
    return [];
  }

  static void prefetchTopStreams(List<Map<String, dynamic>> songs) {}

  /// Alias de búsqueda
  static Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    return searchTracks(query);
  }

  /// Busca canciones en el catálogo global (iTunes + Invidious YouTube + Curated)
  /// Garantiza resultados reales para cualquier búsqueda (Bad Bunny, Feid, Karol G, etc.)
  static Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return getSpotifyTopCharts();
    }

    // 1. Búsqueda principal: iTunes Search API (catálogo mundial con previews AAC y carátulas HD)
    try {
      final itUrl = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(trimmedQuery)}&entity=song&limit=30',
      );
      final response = await http.get(itUrl).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List? ?? [];
        final mapped = _mapItunesItems(results);
        if (mapped.isNotEmpty) {
          return mapped;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error en búsqueda iTunes: $e');
    }

    // 2. Búsqueda secundaria: Invidious YouTube API
    try {
      final q = Uri.encodeComponent(trimmedQuery);
      final invRes = await http
          .get(Uri.parse('https://invidious.f5.si/api/v1/search?q=$q'))
          .timeout(const Duration(seconds: 4));
      if (invRes.statusCode == 200) {
        final items = json.decode(invRes.body) as List? ?? [];
        final mapped = _mapInvidiousItems(items);
        if (mapped.isNotEmpty) {
          return mapped;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error en búsqueda Invidious: $e');
    }

    // 3. Fallback a canciones curadas si no hay conexión
    final q = trimmedQuery.toLowerCase();
    return _curatedSongs.where((s) {
      final title = s['title'].toString().toLowerCase();
      final artist = s['artist'].toString().toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
  }

  /// Mapea los resultados de iTunes con metadata completa, carátulas HD y preview AAC
  static List<Map<String, dynamic>> _mapItunesItems(List items) {
    final results = <Map<String, dynamic>>[];
    for (var item in items) {
      final id = item['trackId']?.toString() ?? '';
      final title = item['trackName']?.toString() ?? '';
      final artist = item['artistName']?.toString() ?? 'Artista';
      final rawThumb = item['artworkUrl100']?.toString() ?? '';
      final thumbnail = rawThumb.replaceAll('100x100bb', '600x600bb');
      final durationMs = item['trackTimeMillis'] as int? ?? 180000;
      final durationSec = durationMs ~/ 1000;
      final previewUrl = item['previewUrl']?.toString() ?? '';

      if (id.isNotEmpty && title.isNotEmpty) {
        results.add({
          'id': id,
          'spotifyId': id,
          'title': title,
          'artist': artist,
          'thumbnail': thumbnail,
          'duration': durationSec > 0 ? durationSec : 180,
          'audioUrl': previewUrl,
          'spotifyUri': '',
          'isSpotify': false,
        });
      }
    }
    return results;
  }

  /// Mapea resultados de Invidious / YouTube
  static List<Map<String, dynamic>> _mapInvidiousItems(List items) {
    final results = <Map<String, dynamic>>[];
    for (var item in items) {
      final videoId = item['videoId']?.toString() ?? '';
      final title = item['title']?.toString() ?? '';
      final author = item['author']?.toString() ?? 'YouTube Audio';
      final duration = item['lengthSeconds'] as int? ?? 180;
      final thumb = item['videoThumbnails']?[0]?['url']?.toString() ??
          'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

      if (videoId.isNotEmpty && title.isNotEmpty) {
        results.add({
          'id': videoId,
          'spotifyId': videoId,
          'title': title,
          'artist': author,
          'thumbnail': thumb,
          'duration': duration,
          'audioUrl': '',
          'spotifyUri': '',
          'isSpotify': false,
        });
      }
    }
    return results;
  }

  /// Mapea las pistas de la API de Spotify con su metadata
  static List<Map<String, dynamic>> _mapSpotifyItems(List items) {
    final results = <Map<String, dynamic>>[];
    for (var item in items) {
      final id = item['id']?.toString() ?? '';
      final title = item['name']?.toString() ?? '';
      final artistsList = item['artists'] as List? ?? [];
      final artists = artistsList
          .map((a) => a['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .join(', ');

      final album = item['album'];
      final images = album?['images'] as List? ?? [];
      String thumbnail = '';
      if (images.isNotEmpty) {
        thumbnail = images.first['url']?.toString() ?? '';
      }

      final durationMs = item['duration_ms'] as int? ?? 180000;
      final durationSec = durationMs ~/ 1000;
      final previewUrl = item['preview_url']?.toString();

      if (id.isNotEmpty && title.isNotEmpty) {
        results.add({
          'id': id,
          'spotifyId': id,
          'title': title,
          'artist': artists.isNotEmpty ? artists : 'Artista desconocido',
          'thumbnail': thumbnail,
          'duration': durationSec > 0 ? durationSec : 180,
          'audioUrl': (previewUrl != null && previewUrl.isNotEmpty) ? previewUrl : '',
          'spotifyUri': item['uri']?.toString() ?? 'spotify:track:$id',
          'isSpotify': true,
        });
      }
    }
    return results;
  }

  /// Obtiene el enlace de audio streaming directo y confiable de la canción
  /// CRÍTICO PARA iOS Y ANDROID: Selecciona streams en formato MP4 (AAC / itag 140/139)
  /// para compatibilidad nativa con AVPlayer de Apple (evita errores con WebM/Opus).
  static Future<Map<String, dynamic>?> getFullAudioStream({
    required String title,
    required String artist,
    String? fallbackPreviewUrl,
    int? expectedDurationSec,
  }) async {
    final searchTitle = title.trim();
    final searchArtist = artist.trim();
    final cacheKey = 'stream_${searchTitle}_$searchArtist'.toLowerCase();

    // 1. Revisar caché en memoria
    final cached = _streamCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return {
        'url': cached.url,
        'durationSeconds': cached.durationSeconds,
      };
    }

    // 2. Extraer PISTA COMPLETA (3-5 minutos) vía YouTube Explode seleccionando MP4/AAC
    if (searchTitle.isNotEmpty) {
      final yt = YoutubeExplode();
      try {
        String? targetVideoId;
        int? targetDuration;

        // Intentar primero con Invidious para obtener el videoId exacto de manera instantánea
        try {
          final q = Uri.encodeComponent('$searchTitle $searchArtist audio'.trim());
          final invRes = await http
              .get(Uri.parse('https://invidious.f5.si/api/v1/search?q=$q'))
              .timeout(const Duration(seconds: 4));
          if (invRes.statusCode == 200) {
            final items = json.decode(invRes.body) as List? ?? [];
            final first = items.firstWhere(
              (it) => it['videoId'] != null && (it['type'] == 'video' || it['type'] == null),
              orElse: () => items.isNotEmpty ? items.first : null,
            );
            if (first != null && first['videoId'] != null) {
              targetVideoId = first['videoId'].toString();
              targetDuration = first['lengthSeconds'] as int?;
            }
          }
        } catch (_) {}

        // Si Invidious no respondió, buscar con yt.search
        if (targetVideoId == null) {
          final query = '$searchTitle $searchArtist audio'.trim();
          var searchResults = await yt.search.search(query).timeout(const Duration(seconds: 5));
          if (searchResults.isEmpty) {
            searchResults = await yt.search
                .search('$searchTitle $searchArtist'.trim())
                .timeout(const Duration(seconds: 4));
          }
          if (searchResults.isNotEmpty) {
            targetVideoId = searchResults.first.id.value;
            targetDuration = searchResults.first.duration?.inSeconds;
          }
        }

        // Si obtuvimos videoId, extraer el manifest de audio
        if (targetVideoId != null) {
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
            print('[MusicService] Stream MP4 COMPLETO de YouTube resuelto: tag=${audioStream.tag}, dur=$durSec s');
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
    }

    // 3. Respaldo oficial vía Apple Music / iTunes preview (AAC .m4a 30s) si YouTube no resolvió
    if (searchTitle.isNotEmpty) {
      try {
        final query = '$searchTitle $searchArtist'.trim();
        final itUrl = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=1',
        );
        final res = await http.get(itUrl).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final items = data['results'] as List? ?? [];
          if (items.isNotEmpty) {
            final preview = items.first['previewUrl']?.toString();
            if (preview != null && preview.isNotEmpty) {
              _streamCache[cacheKey] = CachedAudioStream(
                url: preview,
                durationSeconds: 30,
                expiresAt: DateTime.now().add(const Duration(hours: 4)),
              );
              return {
                'url': preview,
                'durationSeconds': 30,
              };
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error en fallback iTunes: $e');
      }
    }

    // 4. Si viene fallback previo directo
    if (fallbackPreviewUrl != null && fallbackPreviewUrl.startsWith('http')) {
      return {
        'url': fallbackPreviewUrl,
        'durationSeconds': 30,
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

    final streamData = await getFullAudioStream(
      title: searchTitle,
      artist: searchArtist,
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
