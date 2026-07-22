import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MusicService {
  // Lista curada "Para ti" de grandes éxitos del momento (ahora con IDs/URLs de iTunes)
  static final List<Map<String, String>> _curatedSongs = [
    {
      'id': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview116/v4/38/de/cd/38decd71-df2e-8601-c977-7312d9749c6f/mzaf_6325919069028041464.plus.aac.p.m4a',
      'title': '3 TROKAS',
      'artist': 'Fuerza Regida',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/21/e3/b7/21e3b74f-571b-07ce-567b-a2aa8274c7b2/196871548922.jpg/100x100bb.jpg',
    },
    {
      'id': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/0f/07/33/0f0733c9-76b3-39f9-9115-9031acd75839/mzaf_249954100848422596.plus.aac.p.m4a',
      'title': 'Si Antes Te Hubiera Conocido',
      'artist': 'KAROL G',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/a0/60/94/a060947c-54d8-0fad-c558-eed12600224c/24UMGIM62705.rgb.jpg/100x100bb.jpg',
    },
    {
      'id': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/8d/2a/20/8d2a20dd-7391-afd1-c543-009c87414265/mzaf_10873691963030604339.plus.aac.p.m4a',
      'title': 'Ella Baila Sola',
      'artist': 'Eslabon Armado & Peso Pluma',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/b1/9b/95/b19b9506-5696-ad86-1c85-d198503adfbf/816144021906_Cover.jpg/100x100bb.jpg',
    },
    {
      'id': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/62/1b/f9/621bf990-99a5-07bc-27d9-fbc63991f85a/mzaf_12592537868841161765.plus.aac.p.m4a',
      'title': 'LUNA',
      'artist': 'Feid & ATL Jacob',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/7c/54/aa/7c54aa94-9ae3-4b80-7b23-8b23955dc3a2/23UM1IM60703.rgb.jpg/100x100bb.jpg',
    },
    {
      'id': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/40/5b/e7/405be722-3ec9-ba27-7469-002182d57b39/mzaf_14120258742032474456.plus.aac.p.m4a',
      'title': 'Despacito',
      'artist': 'Luis Fonsi & Daddy Yankee',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/e2/ef/f0/e2eff0bc-c51d-7de5-9280-6891ddcee71b/18UMGIM85289.rgb.jpg/100x100bb.jpg',
    },
    {
      'id': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/cf/5f/ef/cf5fef49-8ab0-0d0b-f17a-d820cdca1d88/mzaf_3693019759359818051.plus.aac.p.m4a',
      'title': 'LA CANCIÓN',
      'artist': 'J Balvin & Bad Bunny',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/77/32/74/7732746d-25e5-baae-b921-bad4a07d87b1/19UMGIM55524.rgb.jpg/100x100bb.jpg',
    },
    {
      'id': 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/0a/e1/0e/0ae10eda-19d6-9acb-2dd4-3a8f87c076c9/mzaf_11017736900654766444.plus.aac.p.m4a',
      'title': 'Shakira: Bzrp Music Sessions, Vol. 53',
      'artist': 'Bizarrap & Shakira',
      'thumbnail': 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/55/0e/5e/550e5ecc-3fe4-50df-c5a3-a019b67008c3/196871854894.jpg/100x100bb.jpg',
    },
  ];

  static Future<List<Map<String, String>>> getCuratedSongs() async {
    return _curatedSongs;
  }

  // Realiza búsquedas usando iTunes Search API (Es gratuito y no requiere API Key)
  static Future<List<Map<String, String>>> searchSongs(String query) async {
    if (query.trim().isEmpty) {
      return _curatedSongs;
    }

    try {
      final url = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=${Uri.encodeComponent(query)}'
        '&entity=song'
        '&limit=20'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List? ?? [];
        
        final List<Map<String, String>> parsedResults = [];
        for (var item in results) {
          final previewUrl = item['previewUrl'] as String?;
          final title = item['trackName'] as String?;
          final artist = item['artistName'] as String?;
          final thumbnail = item['artworkUrl100'] as String?;

          if (previewUrl != null && title != null && artist != null) {
            parsedResults.add({
              'id': previewUrl, // Usamos la URL como ID para reproducirlo directamente
              'title': title,
              'artist': artist,
              'thumbnail': thumbnail ?? 'https://via.placeholder.com/100',
            });
          }
        }
        return parsedResults;
      } else {
        throw Exception('Error en API de iTunes: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('Error buscando música: $e');
      
      // Fallback local sobre nuestra lista curada
      final q = query.toLowerCase();
      return _curatedSongs
          .where((s) =>
              s['title']!.toLowerCase().contains(q) ||
              s['artist']!.toLowerCase().contains(q))
          .toList();
    }
  }

  // Ahora el ID es directamente la URL de iTunes, así que la retornamos.
  static Future<String?> getAudioStreamUrl(String videoId) async {
    // Si contiene http, es una URL de iTunes, la usamos directo.
    if (videoId.startsWith('http')) {
      return videoId;
    }
    return null; // En caso de errores raros
  }

  // Clave de almacenamiento
  static const String _savedSongsKey = 'saved_songs_list';

  // Obtener la lista de canciones guardadas
  static Future<List<Map<String, String>>> getSavedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_savedSongsKey);
      if (savedStr == null) return [];
      final List decoded = json.decode(savedStr);
      return decoded.map((item) => Map<String, String>.from(item)).toList();
    } catch (e) {
      if (kDebugMode) print('Error cargando canciones guardadas: $e');
      return [];
    }
  }

  // Guardar una canción
  static Future<void> saveSong(Map<String, String> song) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songs = await getSavedSongs();
      // Evitar duplicados por id
      if (!songs.any((s) => s['id'] == song['id'])) {
        songs.add(song);
        await prefs.setString(_savedSongsKey, json.encode(songs));
      }
    } catch (e) {
      if (kDebugMode) print('Error guardando canción: $e');
    }
  }

  // Eliminar una canción de guardados
  static Future<void> unsaveSong(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songs = await getSavedSongs();
      songs.removeWhere((s) => s['id'] == id);
      await prefs.setString(_savedSongsKey, json.encode(songs));
    } catch (e) {
      if (kDebugMode) print('Error eliminando canción: $e');
    }
  }

  // Verificar si una canción está guardada
  static Future<bool> isSongSaved(String id) async {
    final songs = await getSavedSongs();
    return songs.any((s) => s['id'] == id);
  }
}
