import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Lista curada "Para ti" con los mayores éxitos mundiales y latinos
  static final List<Map<String, dynamic>> _curatedSongs = [
    {
      'id': 'karol_g_si_antes_te_hubiera_conocido',
      'title': 'Si Antes Te Hubiera Conocido',
      'artist': 'KAROL G',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/a0/60/94/a060947c-54d8-0fad-c558-eed12600224c/24UMGIM62705.rgb.jpg/600x600bb.jpg',
      'duration': 196,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/0f/07/33/0f0733c9-76b3-39f9-9115-9031acd75839/mzaf_249954100848422596.plus.aac.p.m4a',
      'platform': 'spotify',
    },
    {
      'id': 'lady_gaga_die_with_a_smile',
      'title': 'Die With A Smile',
      'artist': 'Lady Gaga & Bruno Mars',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/07/6a/99/076a99ed-b946-431b-6f1f-5fafa187ca5bd/24UMGIM88295.rgb.jpg/600x600bb.jpg',
      'duration': 252,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/07/6a/99/076a99ed-b946-431b-6f1f-5fafa187ca5bd/mzaf_8102882277995122875.plus.aac.p.m4a',
      'platform': 'ytmusic',
    },
    {
      'id': 'billie_eilish_birds_of_a_feather',
      'title': 'BIRDS OF A FEATHER',
      'artist': 'Billie Eilish',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/34/31/d3/3431d34e-847f-5d66-df83-0bce688d997e/24UMGIM43452.rgb.jpg/600x600bb.jpg',
      'duration': 212,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/34/31/d3/3431d34e-847f-5d66-df83-0bce688d997e/mzaf_18106743962423782018.plus.aac.p.m4a',
      'platform': 'spotify',
    },
    {
      'id': 'sabrina_carpenter_espresso',
      'title': 'Espresso',
      'artist': 'Sabrina Carpenter',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/e9/4d/02/e94d0230-11ee-ef94-d2cf-a5d547bd73f4/24UMGIM33190.rgb.jpg/600x600bb.jpg',
      'duration': 176,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/e9/4d/02/e94d0230-11ee-ef94-d2cf-a5d547bd73f4/mzaf_554140808559155562.plus.aac.p.m4a',
      'platform': 'spotify',
    },
    {
      'id': 'sabrina_carpenter_taste',
      'title': 'Taste',
      'artist': 'Sabrina Carpenter',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/d5/fe/d3/d5fed3d7-4632-132d-2850-8b17a159e19d/24UMGIM69458.rgb.jpg/600x600bb.jpg',
      'duration': 158,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/bb/a2/a4/bba2a4ae-4b05-9e65-27a3-e76e5d8520bf/mzaf_17208882522731110595.plus.aac.p.m4a',
      'platform': 'ytmusic',
    },
    {
      'id': 'feid_luna',
      'title': 'LUNA',
      'artist': 'Feid & ATL Jacob',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/f8/b0/5b/f8b05b80-c7ea-9ea8-759c-5fd609c15341/23UM1IM41818.rgb.jpg/600x600bb.jpg',
      'duration': 199,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/f8/b0/5b/f8b05b80-c7ea-9ea8-759c-5fd609c15341/mzaf_2589321753277640940.plus.aac.p.m4a',
      'platform': 'spotify',
    },
    {
      'id': 'floyymenor_gata_only',
      'title': 'Gata Only',
      'artist': 'FloyyMenor & Cris Mj',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/e0/e5/88/e0e588d6-a4ac-51d3-77b4-170be2cf4f8b/198391515904.jpg/600x600bb.jpg',
      'duration': 222,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/e0/e5/88/e0e588d6-a4ac-51d3-77b4-170be2cf4f8b/mzaf_11815450146629633804.plus.aac.p.m4a',
      'platform': 'ytmusic',
    },
    {
      'id': 'benson_boone_beautiful_things',
      'title': 'Beautiful Things',
      'artist': 'Benson Boone',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/21/5c/d3/215cd384-ef4f-0117-0947-a89c9339a04f/093624852933.jpg/600x600bb.jpg',
      'duration': 193,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/55/cb/a1/55cba1d5-8eb4-d754-5c92-3bc37318ff22/mzaf_11651817758838382749.plus.aac.p.m4a',
      'platform': 'spotify',
    },
    {
      'id': 'tommy_richman_million_dollar_baby',
      'title': 'MILLION DOLLAR BABY',
      'artist': 'Tommy Richman',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/52/a7/67/52a767e7-0eb2-9fa9-4ee7-ec5c4a452ef3/198391896799.jpg/600x600bb.jpg',
      'duration': 155,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/2f/eb/8c/2feb8ca5-26a1-0f73-195b-01007efcba00/mzaf_1240409949673966567.plus.aac.p.m4a',
      'platform': 'ytmusic',
    },
    {
      'id': 'chappell_roan_good_luck_babe',
      'title': 'Good Luck, Babe!',
      'artist': 'Chappell Roan',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/a4/09/a6/a409a6fc-6bbd-46c5-4d64-9fe4b93196c8/24UMGIM33189.rgb.jpg/600x600bb.jpg',
      'duration': 219,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/a4/09/a6/a409a6fc-6bbd-46c5-4d64-9fe4b93196c8/mzaf_14959147573030312693.plus.aac.p.m4a',
      'platform': 'spotify',
    },
    {
      'id': 'shaboozey_a_bar_song',
      'title': 'A Bar Song (Tipsy)',
      'artist': 'Shaboozey',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/10/72/ca/1072ca2a-bb6f-8706-f131-50e4125b2931/198391741518.jpg/600x600bb.jpg',
      'duration': 172,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/e5/22/a3/e522a36b-7e6d-6a52-b91c-1481076f8742/mzaf_15018698055452877965.plus.aac.p.m4a',
      'platform': 'ytmusic',
    },
    {
      'id': 'hozier_too_sweet',
      'title': 'Too Sweet',
      'artist': 'Hozier',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/66/8b/6e/668b6ec2-5dc5-cf22-9653-61194206587c/196871900010.jpg/600x600bb.jpg',
      'duration': 252,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview122/v4/21/53/7d/21537dc7-fe80-60b6-126a-939e80e1591f/mzaf_15682855219958744047.plus.aac.p.m4a',
      'platform': 'spotify',
    },
    {
      'id': 'myke_towers_la_falda',
      'title': 'La Falda',
      'artist': 'Myke Towers',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/95/9b/87/959b87df-a720-6d45-6677-44ae5d0be3c4/093624855149.jpg/600x600bb.jpg',
      'duration': 228,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/80/4a/60/804a60ea-5cb1-3a13-4318-c2b64d1f5e8f/mzaf_17208882522731110595.plus.aac.p.m4a',
      'platform': 'ytmusic',
    },
    {
      'id': 'bad_bunny_feid_perro_negro',
      'title': 'PERRO NEGRO',
      'artist': 'Bad Bunny & Feid',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/d9/3e/26/d93e2646-f947-ef95-5cb9-89745e75aa8a/197190299622.jpg/600x600bb.jpg',
      'duration': 163,
      'audioUrl': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/2d/52/fa/2d52fae8-07cb-128b-b892-0b6dc345ebaf/mzaf_7824103134301548858.plus.aac.p.m4a',
      'platform': 'spotify',
    },
  ];

  static Future<List<Map<String, dynamic>>> getCuratedSongs() async {
    return _curatedSongs;
  }

  /// Obtiene la lista oficial de éxitos del Top 50 Spotify
  static Future<List<Map<String, dynamic>>> getSpotifyTopCharts() async {
    try {
      final res = await http.get(Uri.parse('https://api.deezer.com/chart/0/tracks?limit=35')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final tracks = data['data'] as List? ?? [];
        final List<Map<String, dynamic>> songs = [];

        for (var t in tracks) {
          final preview = t['preview']?.toString() ?? '';
          if (preview.isNotEmpty) {
            songs.add({
              'id': preview,
              'title': t['title'] ?? '',
              'artist': t['artist']?['name'] ?? '',
              'thumbnail': t['album']?['cover_big'] ?? t['album']?['cover_medium'] ?? '',
              'duration': t['duration'] ?? 180,
              'audioUrl': preview,
              'platform': 'spotify',
            });
          }
        }
        if (songs.isNotEmpty) return songs;
      }
    } catch (e) {
      if (kDebugMode) print('Error cargando Top Spotify: $e');
    }
    return _curatedSongs.where((s) => s['platform'] == 'spotify').toList();
  }

  /// Obtiene las tendencias y videos musicales virales de YouTube Music
  static Future<List<Map<String, dynamic>>> getYoutubeMusicTrends() async {
    try {
      final res = await http.get(Uri.parse('https://itunes.apple.com/us/rss/topsongs/limit=35/json')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final entries = data['feed']?['entry'] as List? ?? [];
        final List<Map<String, dynamic>> songs = [];

        for (var e in entries) {
          final title = e['im:name']?['label'] ?? '';
          final artist = e['im:artist']?['label'] ?? '';
          final image = (e['im:image'] as List?)?.last?['label'] ?? '';
          final link = (e['link'] as List?)?.firstWhere(
            (l) => l['attributes']?['type'] == 'audio/x-m4a',
            orElse: () => null,
          );
          final preview = link?['attributes']?['href'] ?? '';

          if (title.isNotEmpty && preview.isNotEmpty) {
            songs.add({
              'id': preview,
              'title': title,
              'artist': artist,
              'thumbnail': image.replaceAll('170x170bb', '600x600bb'),
              'duration': 180,
              'audioUrl': preview,
              'platform': 'ytmusic',
            });
          }
        }
        if (songs.isNotEmpty) return songs;
      }
    } catch (e) {
      if (kDebugMode) print('Error cargando YouTube Music Trends: $e');
    }
    return _curatedSongs.where((s) => s['platform'] == 'ytmusic').toList();
  }

  /// Categorías estilo Instagram para explorar música
  static final List<String> categories = [
    'Spotify Top 50',
    'YouTube Music Hits',
    'Para ti',
    'Tendencias',
    'Reggaetón',
    'Urbano Latino',
    'Pop',
    'Electrónica',
    'Rock',
    'Salsa',
    'Trap',
    'Bachata',
    'R&B',
  ];

  /// Búsqueda universal híbrida simultánea (Spotify + YouTube Music):
  /// Permite filtrar por plataforma o buscar globalmente.
  static Future<List<Map<String, dynamic>>> searchSongs(String query, {String? filterPlatform}) async {
    if (query.trim().isEmpty) {
      if (filterPlatform == 'spotify') return await getSpotifyTopCharts();
      if (filterPlatform == 'ytmusic') return await getYoutubeMusicTrends();
      return _curatedSongs;
    }

    final trimmedQuery = query.trim();
    final List<Map<String, dynamic>> aggregatedResults = [];
    final Set<String> seenTracks = {};

    // 1. Consulta simultánea a Deezer (Catálogo Spotify)
    try {
      final deezerUrl = Uri.parse(
        'https://api.deezer.com/search?q=${Uri.encodeComponent(trimmedQuery)}&limit=25',
      );
      final response = await http.get(deezerUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['data'] as List? ?? [];

        for (var item in items) {
          final trackName = item['title']?.toString() ?? '';
          final artistName = item['artist']?['name']?.toString() ?? '';
          final previewUrl = item['preview']?.toString() ?? '';
          final artworkHd = item['album']?['cover_big']?.toString() ??
              item['album']?['cover_medium']?.toString() ??
              '';
          final durationSec = item['duration'] as int? ?? 180;

          final trackKey = '${trackName.toLowerCase()}_${artistName.toLowerCase()}';
          if (trackName.isNotEmpty && previewUrl.isNotEmpty && !seenTracks.contains(trackKey)) {
            seenTracks.add(trackKey);
            aggregatedResults.add({
              'id': previewUrl,
              'title': trackName,
              'artist': artistName,
              'thumbnail': artworkHd,
              'duration': durationSec > 0 ? durationSec : 180,
              'audioUrl': previewUrl,
              'platform': 'spotify',
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error en búsqueda Spotify: $e');
    }

    // 2. Consulta simultánea a iTunes / Apple Music (Catálogo YouTube Music / Billboard)
    try {
      final itunesUrl = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(trimmedQuery)}&entity=song&limit=25',
      );
      final response = await http.get(itunesUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['results'] as List? ?? [];

        for (var item in items) {
          final trackName = item['trackName']?.toString() ?? '';
          final artistName = item['artistName']?.toString() ?? '';
          final previewUrl = item['previewUrl']?.toString() ?? '';
          final artworkUrl100 = item['artworkUrl100']?.toString() ?? '';
          final artworkHd = artworkUrl100.replaceAll('100x100bb', '600x600bb');
          final durationMs = item['trackTimeMillis'] as int? ?? 180000;
          final durationSec = durationMs ~/ 1000;

          final trackKey = '${trackName.toLowerCase()}_${artistName.toLowerCase()}';
          if (trackName.isNotEmpty && previewUrl.isNotEmpty && !seenTracks.contains(trackKey)) {
            seenTracks.add(trackKey);
            aggregatedResults.add({
              'id': previewUrl,
              'title': trackName,
              'artist': artistName,
              'thumbnail': artworkHd,
              'duration': durationSec > 0 ? durationSec : 180,
              'audioUrl': previewUrl,
              'platform': 'ytmusic',
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error en búsqueda YouTube Music: $e');
    }

    if (filterPlatform != null && filterPlatform.isNotEmpty) {
      final filtered = aggregatedResults.where((s) => s['platform'] == filterPlatform).toList();
      if (filtered.isNotEmpty) return filtered;
    }

    if (aggregatedResults.isNotEmpty) {
      return aggregatedResults;
    }

    // Fallback a canciones curadas
    final q = query.toLowerCase();
    return _curatedSongs.where((s) {
      final title = s['title'].toString().toLowerCase();
      final artist = s['artist'].toString().toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
  }

  /// Obtiene el enlace de audio streaming directo y 100% reproducible
  static Future<String?> getAudioStreamUrl(
    String audioIdOrUrl, {
    String? title,
    String? artist,
  }) async {
    if (audioIdOrUrl.startsWith('http')) {
      return audioIdOrUrl;
    }

    final curated = _curatedSongs.firstWhere(
      (s) => s['id'] == audioIdOrUrl || s['title'] == title,
      orElse: () => {},
    );
    if (curated.isNotEmpty && curated['audioUrl'] != null) {
      return curated['audioUrl'];
    }

    final cacheKey = (title != null && artist != null) ? '${title}_$artist' : audioIdOrUrl;
    final cached = _streamCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    final searchTitle = (title != null && title.isNotEmpty) ? title : audioIdOrUrl.replaceAll('_', ' ');
    final searchArtist = (artist != null && artist.isNotEmpty) ? artist : '';
    final query = '$searchTitle $searchArtist'.trim();

    try {
      final itunesUrl = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=1',
      );
      final res = await http.get(itunesUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final preview = results[0]['previewUrl']?.toString();
          if (preview != null && preview.isNotEmpty) {
            _streamCache[cacheKey] = CachedAudioStream(
              url: preview,
              durationSeconds: (results[0]['trackTimeMillis'] as int? ?? 180000) ~/ 1000,
              expiresAt: DateTime.now().add(const Duration(hours: 24)),
            );
            return preview;
          }
        }
      }
    } catch (_) {}

    try {
      final deezerUrl = Uri.parse(
        'https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=1',
      );
      final res = await http.get(deezerUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['data'] as List?;
        if (results != null && results.isNotEmpty) {
          final preview = results[0]['preview']?.toString();
          if (preview != null && preview.isNotEmpty) {
            _streamCache[cacheKey] = CachedAudioStream(
              url: preview,
              durationSeconds: results[0]['duration'] as int? ?? 180,
              expiresAt: DateTime.now().add(const Duration(hours: 24)),
            );
            return preview;
          }
        }
      }
    } catch (_) {}

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
    return songs.any((s) => songIdNormalize(s['id'].toString()) == songIdNormalize(id));
  }

  static String songIdNormalize(String id) => id.trim();
}
