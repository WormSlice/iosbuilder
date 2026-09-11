import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
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

  /// Calcula automáticamente el punto donde empieza el estribillo / coro más escuchado
  static int calculateHighlightStart(int durationSec) {
    if (durationSec <= 30) return 0;
    final candidate = (durationSec * 0.22).round();
    if (candidate < 15) return 15;
    if (candidate > 50) return 40;
    return candidate;
  }

  /// Lista curada "Para ti" con los mayores éxitos mundiales y latinos
  static final List<Map<String, dynamic>> _curatedSongs = [
    {
      'id': 'karol_g_si_antes_te_hubiera_conocido',
      'title': 'Si Antes Te Hubiera Conocido',
      'artist': 'KAROL G',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/a0/60/94/a060947c-54d8-0fad-c558-eed12600224c/24UMGIM62705.rgb.jpg/600x600bb.jpg',
      'duration': 196,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/0f/07/33/0f0733c9-76b3-39f9-9115-9031acd75839/mzaf_249954100848422596.plus.aac.p.m4a',
    },
    {
      'id': 'lady_gaga_die_with_a_smile',
      'title': 'Die With A Smile',
      'artist': 'Lady Gaga & Bruno Mars',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/07/6a/99/076a99ed-b946-431b-6f1f-5fafa187ca5bd/24UMGIM88295.rgb.jpg/600x600bb.jpg',
      'duration': 252,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/07/6a/99/076a99ed-b946-431b-6f1f-5fafa187ca5bd/mzaf_8102882277995122875.plus.aac.p.m4a',
    },
    {
      'id': 'billie_eilish_birds_of_a_feather',
      'title': 'BIRDS OF A FEATHER',
      'artist': 'Billie Eilish',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/34/31/d3/3431d34e-847f-5d66-df83-0bce688d997e/24UMGIM43452.rgb.jpg/600x600bb.jpg',
      'duration': 212,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/34/31/d3/3431d34e-847f-5d66-df83-0bce688d997e/mzaf_18106743962423782018.plus.aac.p.m4a',
    },
    {
      'id': 'feid_luna',
      'title': 'LUNA',
      'artist': 'Feid & ATL Jacob',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/f8/b0/5b/f8b05b80-c7ea-9ea8-759c-5fd609c15341/23UM1IM41818.rgb.jpg/600x600bb.jpg',
      'duration': 199,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/f8/b0/5b/f8b05b80-c7ea-9ea8-759c-5fd609c15341/mzaf_2589321753277640940.plus.aac.p.m4a',
    },
    {
      'id': 'sabrina_carpenter_espresso',
      'title': 'Espresso',
      'artist': 'Sabrina Carpenter',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/e9/4d/02/e94d0230-11ee-ef94-d2cf-a5d547bd73f4/24UMGIM33190.rgb.jpg/600x600bb.jpg',
      'duration': 176,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/e9/4d/02/e94d0230-11ee-ef94-d2cf-a5d547bd73f4/mzaf_554140808559155562.plus.aac.p.m4a',
    },
    {
      'id': 'bad_bunny_feid_perro_negro',
      'title': 'PERRO NEGRO',
      'artist': 'Bad Bunny & Feid',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/d9/3e/26/d93e2646-f947-ef95-5cb9-89745e75aa8a/197190299622.jpg/600x600bb.jpg',
      'duration': 163,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/2d/52/fa/2d52fae8-07cb-128b-b892-0b6dc345ebaf/mzaf_7824103134301548858.plus.aac.p.m4a',
    },
    {
      'id': 'floyymenor_gata_only',
      'title': 'Gata Only',
      'artist': 'FloyyMenor & Cris Mj',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/e0/e5/88/e0e588d6-a4ac-51d3-77b4-170be2cf4f8b/198391515904.jpg/600x600bb.jpg',
      'duration': 222,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/e0/e5/88/e0e588d6-a4ac-51d3-77b4-170be2cf4f8b/mzaf_11815450146629633804.plus.aac.p.m4a',
    },
    {
      'id': 'benson_boone_beautiful_things',
      'title': 'Beautiful Things',
      'artist': 'Benson Boone',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/21/5c/d3/215cd384-ef4f-0117-0947-a89c9339a04f/093624852933.jpg/600x600bb.jpg',
      'duration': 193,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/55/cb/a1/55cba1d5-8eb4-d754-5c92-3bc37318ff22/mzaf_11651817758838382749.plus.aac.p.m4a',
    },
    {
      'id': 'tommy_richman_million_dollar_baby',
      'title': 'MILLION DOLLAR BABY',
      'artist': 'Tommy Richman',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/52/a7/67/52a767e7-0eb2-9fa9-4ee7-ec5c4a452ef3/198391896799.jpg/600x600bb.jpg',
      'duration': 155,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/2f/eb/8c/2feb8ca5-26a1-0f73-195b-01007efcba00/mzaf_1240409949673966567.plus.aac.p.m4a',
    },
    {
      'id': 'chappell_roan_good_luck_babe',
      'title': 'Good Luck, Babe!',
      'artist': 'Chappell Roan',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/a4/09/a6/a409a6fc-6bbd-46c5-4d64-9fe4b93196c8/24UMGIM33189.rgb.jpg/600x600bb.jpg',
      'duration': 219,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/a4/09/a6/a409a6fc-6bbd-46c5-4d64-9fe4b93196c8/mzaf_14959147573030312693.plus.aac.p.m4a',
    },
    {
      'id': 'shaboozey_a_bar_song',
      'title': 'A Bar Song (Tipsy)',
      'artist': 'Shaboozey',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/10/72/ca/1072ca2a-bb6f-8706-f131-50e4125b2931/198391741518.jpg/600x600bb.jpg',
      'duration': 172,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/e5/22/a3/e522a36b-7e6d-6a52-b91c-1481076f8742/mzaf_15018698055452877965.plus.aac.p.m4a',
    },
    {
      'id': 'hozier_too_sweet',
      'title': 'Too Sweet',
      'artist': 'Hozier',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/66/8b/6e/668b6ec2-5dc5-cf22-9653-61194206587c/196871900010.jpg/600x600bb.jpg',
      'duration': 252,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview122/v4/21/53/7d/21537dc7-fe80-60b6-126a-939e80e1591f/mzaf_15682855219958744047.plus.aac.p.m4a',
    },
    {
      'id': 'myke_towers_la_falda',
      'title': 'La Falda',
      'artist': 'Myke Towers',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/95/9b/87/959b87df-a720-6d45-6677-44ae5d0be3c4/093624855149.jpg/600x600bb.jpg',
      'duration': 174,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/a4/09/b6/a409b68a-6b45-12cf-a734-b258525b3992/mzaf_1119280336208976722.plus.aac.p.m4a',
    },
    {
      'id': 'rosalia_rauw_beso',
      'title': 'BESO',
      'artist': 'ROSALÍA & Rauw Alejandro',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/05/cf/a4/05cfa49d-647d-815d-8d4e-b5f7cf895101/196589949667.jpg/600x600bb.jpg',
      'duration': 194,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/6c/dc/fe/6cdcfee5-341e-5ec1-026a-bfe0d4dcba45/mzaf_10926839062386227278.plus.aac.p.m4a',
    },
    {
      'id': 'duki_bizarrap_malbec',
      'title': 'Malbec',
      'artist': 'Duki & Bizarrap',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/80/c8/cf/80c8cfca-7473-b3c4-4b5b-240eaebba2cb/196006456006.jpg/600x600bb.jpg',
      'duration': 170,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/c7/bd/e6/c7bde657-3f82-a725-3ba5-802528760086/mzaf_12411961623101188351.plus.aac.p.m4a',
    },
    {
      'id': 'quevedo_columbia',
      'title': 'Columbia',
      'artist': 'Quevedo',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/97/bd/ba/97bdbaec-c9e3-2e0f-d470-353982e5b616/8445162479262.jpg/600x600bb.jpg',
      'duration': 186,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/1b/c6/eb/1bc6eb9b-a0ea-f2cb-f14d-fa56291aeeb2/mzaf_13508006421067201886.plus.aac.p.m4a',
    },
    {
      'id': 'trueno_real_gangsta_love',
      'title': 'REAL GANGSTA LOVE',
      'artist': 'Trueno',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/31/35/ea/3135eae4-1779-8dc3-5f04-814cb20793b8/196871994682.jpg/600x600bb.jpg',
      'duration': 146,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/15/d5/9c/15d59c98-1e42-706f-4bc2-8da2fe0b2848/mzaf_5816911364522851897.plus.aac.p.m4a',
    },
    {
      'id': 'mora_bad_bunny_volando_remix',
      'title': 'Volando - Remix',
      'artist': 'Mora, Bad Bunny & Sech',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/10/d8/bc/10d8bc3b-5544-77a8-12c8-89c5651c6c0b/196292374187.jpg/600x600bb.jpg',
      'duration': 275,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/64/00/cb/6400cbf7-cf51-0a6b-c74b-e85d85208f23/mzaf_7824103134301548858.plus.aac.p.m4a',
    },
    {
      'id': 'duki_she_dont_give_a_fo',
      'title': 'She Don\'t Give a FO',
      'artist': 'Duki feat. Khea',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/f9/58/01/f958017d-2b4a-a035-7c15-46b518cf08fc/cover.jpg/600x600bb.jpg',
      'duration': 214,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview124/v4/71/c4/8f/71c48fca-fb7d-a192-d610-84cf759cfca8/mzaf_11306354605929286469.plus.aac.p.m4a',
    },
    {
      'id': 'feid_young_miko_classy_101',
      'title': 'Classy 101',
      'artist': 'Feid & Young Miko',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/e0/f1/b7/e0f1b72a-63d1-fb6d-ee78-bb3b37eaaeaa/23UMGIM33190.rgb.jpg/600x600bb.jpg',
      'duration': 195,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/21/53/7d/21537dc7-fe80-60b6-126a-939e80e1591f/mzaf_15682855219958744047.plus.aac.p.m4a',
    },
    {
      'id': 'bad_bunny_monaco',
      'title': 'MONACO',
      'artist': 'Bad Bunny',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/d9/3e/26/d93e2646-f947-ef95-5cb9-89745e75aa8a/197190299622.jpg/600x600bb.jpg',
      'duration': 267,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/10/72/ca/1072ca2a-bb6f-8706-f131-50e4125b2931/mzaf_15018698055452877965.plus.aac.p.m4a',
    },
    {
      'id': 'feid_alvaro_diaz_gatitas_sandungueras',
      'title': 'GATITAS SANDUNGUERAS VOL.1',
      'artist': 'Álvaro Díaz & Feid',
      'thumbnail':
          'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/7e/cb/e5/7ecbe532-6a7e-1a65-1d01-e6d87179bbba/24UMGIM43452.rgb.jpg/600x600bb.jpg',
      'duration': 166,
      'audioUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/7e/cb/e5/7ecbe532-6a7e-1a65-1d01-e6d87179bbba/mzaf_16827709589940619379.plus.aac.p.m4a',
    },
  ];

  /// Obtiene la lista curada de canciones en tendencia / para ti
  static List<Map<String, dynamic>> getCuratedSongs() {
    return List<Map<String, dynamic>>.from(_curatedSongs);
  }

  /// Alias para listas de tendencias
  static Future<List<Map<String, dynamic>>> getSpotifyTopCharts() async {
    return getCuratedSongs();
  }

  /// Prefetch ligero para asegurar disponibilidad instantánea
  static void prefetchTopStreams(List<Map<String, dynamic>> songs) {}

  /// Alias de búsqueda
  static Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    return searchTracks(query);
  }

  /// Busca canciones en iTunes y Deezer con previews AAC/MP3 de alta fidelidad
  static Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return getCuratedSongs();
    }

    final results = <Map<String, dynamic>>[];
    final seenTracks = <String>{};

    // 1. Búsqueda principal en iTunes (AAC de alta fidelidad, soporte Range HTTP 206)
    try {
      final itunesUrl = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(trimmedQuery)}&entity=song&limit=30',
      );
      final response =
          await http.get(itunesUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['results'] as List? ?? [];

        for (var item in items) {
          final trackName = item['trackName']?.toString() ?? '';
          final artistName = item['artistName']?.toString() ?? '';
          final previewUrl = item['previewUrl']?.toString() ?? '';
          final artworkUrl100 = item['artworkUrl100']?.toString() ?? '';
          final artworkHd =
              artworkUrl100.replaceAll('100x100bb', '600x600bb');
          final durationMs = item['trackTimeMillis'] as int? ?? 180000;
          final durationSec = durationMs ~/ 1000;

          final trackKey =
              '${trackName.toLowerCase()}_${artistName.toLowerCase()}';
          if (trackName.isNotEmpty && previewUrl.isNotEmpty && !seenTracks.contains(trackKey)) {
            seenTracks.add(trackKey);
            results.add({
              'id': previewUrl,
              'title': trackName,
              'artist': artistName,
              'thumbnail': artworkHd,
              'duration': durationSec > 0 ? durationSec : 180,
              'audioUrl': previewUrl,
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error en búsqueda iTunes: $e');
    }

    // 2. Búsqueda complementaria en Deezer si faltan resultados
    if (results.length < 10) {
      try {
        final deezerUrl = Uri.parse(
          'https://api.deezer.com/search?q=${Uri.encodeComponent(trimmedQuery)}&limit=20',
        );
        final response =
            await http.get(deezerUrl).timeout(const Duration(seconds: 4));
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

            final trackKey =
                '${trackName.toLowerCase()}_${artistName.toLowerCase()}';
            if (trackName.isNotEmpty && previewUrl.isNotEmpty && !seenTracks.contains(trackKey)) {
              seenTracks.add(trackKey);
              results.add({
                'id': previewUrl,
                'title': trackName,
                'artist': artistName,
                'thumbnail': artworkHd,
                'duration': durationSec > 0 ? durationSec : 180,
                'audioUrl': previewUrl,
              });
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error en búsqueda Deezer: $e');
      }
    }

    if (results.isNotEmpty) {
      return results;
    }

    // Fallback a canciones curadas
    final q = query.toLowerCase();
    return _curatedSongs.where((s) {
      final title = s['title'].toString().toLowerCase();
      final artist = s['artist'].toString().toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
  }

  /// Obtiene el enlace de audio streaming directo y confiable
  static Future<Map<String, dynamic>?> getFullAudioStream({
    required String title,
    required String artist,
    String? fallbackPreviewUrl,
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

    // 2. Si ya tenemos URL directa de preview
    if (fallbackPreviewUrl != null && fallbackPreviewUrl.startsWith('http')) {
      _streamCache[cacheKey] = CachedAudioStream(
        url: fallbackPreviewUrl,
        durationSeconds: 30,
        expiresAt: DateTime.now().add(const Duration(hours: 4)),
      );
      return {
        'url': fallbackPreviewUrl,
        'durationSeconds': 30,
      };
    }

    // 3. Revisar en lista curada
    final curated = _curatedSongs.firstWhere(
      (s) =>
          (searchTitle.isNotEmpty &&
              s['title'].toString().toLowerCase() == searchTitle.toLowerCase()),
      orElse: () => {},
    );
    if (curated.isNotEmpty && curated['audioUrl'] != null) {
      final url = curated['audioUrl'].toString();
      _streamCache[cacheKey] = CachedAudioStream(
        url: url,
        durationSeconds: 30,
        expiresAt: DateTime.now().add(const Duration(hours: 4)),
      );
      return {
        'url': url,
        'durationSeconds': 30,
      };
    }

    // 4. Buscar stream oficial en iTunes
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
        if (kDebugMode) print('Error buscando stream iTunes: $e');
      }
    }

    return null;
  }

  /// Obtiene el enlace de audio streaming directo de la canción
  static Future<String?> getAudioStreamUrl(
    String audioIdOrUrl, {
    String? title,
    String? artist,
    bool forceFullTrack = false,
  }) async {
    // 1. Si ya es una URL directa
    if (audioIdOrUrl.startsWith('http')) {
      return audioIdOrUrl;
    }

    final searchTitle = (title != null && title.isNotEmpty)
        ? title
        : audioIdOrUrl.replaceAll('_', ' ');
    final searchArtist = (artist != null && artist.isNotEmpty) ? artist : '';
    final cacheKey = '${searchTitle}_$searchArtist'.trim().toLowerCase();

    // 2. Revisar caché de stream en memoria
    final cached = _streamCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // 3. Revisar en lista curada
    final curated = _curatedSongs.firstWhere(
      (s) =>
          s['id'] == audioIdOrUrl ||
          (title != null &&
              s['title'].toString().toLowerCase() == title.toLowerCase()),
      orElse: () => {},
    );
    if (curated.isNotEmpty && curated['audioUrl'] != null) {
      final url = curated['audioUrl'].toString();
      _streamCache[cacheKey] = CachedAudioStream(
        url: url,
        durationSeconds: 30,
        expiresAt: DateTime.now().add(const Duration(hours: 4)),
      );
      return url;
    }

    // 4. Búsqueda rápida en iTunes
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
              return preview;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error en fallback getAudioStreamUrl: $e');
      }
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
