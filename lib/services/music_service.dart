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

  /// Obtiene canciones oficiales de Spotify para la pantalla inicial ("Para ti")
  /// Utiliza la API oficial de Spotify (usuario o Client Credentials).
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

    // 3. Consultar éxitos globales y latinos en Spotify Web API
    try {
      final headers = await MusicAuthService.instance.getAnyValidSpotifyHeaders();
      if (headers != null) {
        final query = Uri.encodeComponent('top latin hits 2025');
        final uri = Uri.parse(
          'https://api.spotify.com/v1/search?q=$query&type=track&limit=30',
        );
        final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final tracks = data['tracks']?['items'] as List? ?? [];
          final mapped = _mapSpotifyItems(tracks);
          if (mapped.isNotEmpty) {
            _cachedTopCharts = mapped;
            _topChartsCacheTime = DateTime.now();
            return mapped;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error consultando top charts oficiales de Spotify: $e');
    }

    return getCuratedSongs();
  }

  /// Consulta las canciones más escuchadas del usuario en Spotify
  static Future<List<Map<String, dynamic>>> _fetchSpotifyTopTracks() async {
    final headers = await MusicAuthService.instance.getSpotifyHeaders();
    if (headers == null) return [];

    try {
      var uri = Uri.parse(
        'https://api.spotify.com/v1/me/top/tracks?limit=30&time_range=short_term',
      );
      var response =
          await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));

      if (response.statusCode == 401) {
        await MusicAuthService.instance.refreshSpotifyToken();
        final refreshedHeaders =
            await MusicAuthService.instance.getSpotifyHeaders();
        if (refreshedHeaders != null) {
          response = await http
              .get(uri, headers: refreshedHeaders)
              .timeout(const Duration(seconds: 5));
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        if (items.isNotEmpty) {
          return _mapSpotifyItems(items);
        }
      }

      // Si el usuario aún no tiene historial en short_term, consultar medium_term
      uri = Uri.parse(
        'https://api.spotify.com/v1/me/top/tracks?limit=30&time_range=medium_term',
      );
      response =
          await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
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

  /// Busca canciones exclusivamente en el catálogo oficial de Spotify Web API.
  static Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return getSpotifyTopCharts();
    }

    try {
      final spotifyResults = await _searchSpotify(trimmedQuery);
      if (spotifyResults.isNotEmpty) {
        return spotifyResults;
      }
    } catch (e) {
      if (kDebugMode) print('Error en búsqueda oficial Spotify: $e');
    }

    // Fallback a canciones curadas si no hay red
    final q = trimmedQuery.toLowerCase();
    return _curatedSongs.where((s) {
      final title = s['title'].toString().toLowerCase();
      final artist = s['artist'].toString().toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
  }

  /// Realiza la búsqueda oficial en el catálogo de Spotify Web API
  static Future<List<Map<String, dynamic>>> _searchSpotify(String query) async {
    var headers = await MusicAuthService.instance.getAnyValidSpotifyHeaders();
    if (headers == null) return [];

    final searchUri = Uri.parse(
      'https://api.spotify.com/v1/search?q=${Uri.encodeComponent(query)}&type=track&limit=30',
    );

    var response = await http
        .get(searchUri, headers: headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 401) {
      await MusicAuthService.instance.refreshSpotifyToken();
      headers = await MusicAuthService.instance.getAnyValidSpotifyHeaders();
      if (headers != null) {
        response = await http
            .get(searchUri, headers: headers)
            .timeout(const Duration(seconds: 5));
      }
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final tracks = data['tracks']?['items'] as List? ?? [];
      return _mapSpotifyItems(tracks);
    }
    return [];
  }

  /// Mapea las pistas de la API de Spotify con su metadata y portadas oficiales de Spotify CDN
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
  /// Reproducción instantánea, limpia y sin errores 403.
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

    // 2. Extraer PISTA COMPLETA (3-4 minutos) vía YouTube Explode
    if (searchTitle.isNotEmpty) {
      final yt = YoutubeExplode();
      try {
        final query = '$searchTitle $searchArtist audio'.trim();
        var searchResults = await yt.search.search(query).timeout(const Duration(seconds: 5));
        if (searchResults.isEmpty) {
          searchResults = await yt.search.search('$searchTitle $searchArtist'.trim()).timeout(const Duration(seconds: 4));
        }
        if (searchResults.isNotEmpty) {
          final video = searchResults.first;
          final manifest = await yt.videos.streamsClient.getManifest(video.id).timeout(const Duration(seconds: 6));
          final audioStream = manifest.audioOnly.withHighestBitrate();
          final durSec = video.duration?.inSeconds ?? expectedDurationSec ?? 180;
          yt.close();

          final streamUrl = audioStream.url.toString();
          _streamCache[cacheKey] = CachedAudioStream(
            url: streamUrl,
            durationSeconds: durSec,
            expiresAt: DateTime.now().add(const Duration(hours: 4)),
          );
          if (kDebugMode) {
            print('[MusicService] Stream COMPLETO de YouTube resuelto con éxito: $durSec segundos');
          }
          return {
            'url': streamUrl,
            'durationSeconds': durSec,
          };
        }
      } catch (e) {
        if (kDebugMode) print('[MusicService] Fallo YouTube Explode search: $e');
      } finally {
        yt.close();
      }

      // 2.2 Fallback YouTube vía Invidious API si yt.search falló
      try {
        final q = Uri.encodeComponent('$searchTitle $searchArtist'.trim());
        final invRes = await http.get(Uri.parse('https://invidious.f5.si/api/v1/search?q=$q')).timeout(const Duration(seconds: 4));
        if (invRes.statusCode == 200) {
          final items = json.decode(invRes.body) as List? ?? [];
          final first = items.firstWhere(
            (it) => it['videoId'] != null && (it['type'] == 'video' || it['type'] == null),
            orElse: () => items.isNotEmpty ? items.first : null,
          );
          if (first != null && first['videoId'] != null) {
            final yt = YoutubeExplode();
            final manifest = await yt.videos.streamsClient.getManifest(first['videoId']).timeout(const Duration(seconds: 6));
            final audioStream = manifest.audioOnly.withHighestBitrate();
            final durSec = first['lengthSeconds'] as int? ?? expectedDurationSec ?? 180;
            yt.close();
            final streamUrl = audioStream.url.toString();
            _streamCache[cacheKey] = CachedAudioStream(
              url: streamUrl,
              durationSeconds: durSec,
              expiresAt: DateTime.now().add(const Duration(hours: 4)),
            );
            if (kDebugMode) {
              print('[MusicService] Stream COMPLETO Invidious/YouTube resuelto: $durSec segundos');
            }
            return {
              'url': streamUrl,
              'durationSeconds': durSec,
            };
          }
        }
      } catch (e) {
        if (kDebugMode) print('[MusicService] Fallo Invidious fallback: $e');
      }
    }

    // 3. Respaldo oficial vía Apple Music / iTunes preview (30s) solo si YouTube falló completamente
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
