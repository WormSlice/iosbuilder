import 'dart:convert';
import 'package:algolia_client_search/algolia_client_search.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AlgoliaService {
  static final AlgoliaService _instance = AlgoliaService._internal();
  factory AlgoliaService() => _instance;
  AlgoliaService._internal();

  final String _appId = 'P2CJMQDDSH';
  final String _apiKey = '6b69cf2f3a3fab9332efc9ee38ea1643';
  static const String _adminApiKey = '4aa72340abeb49d79d888cc3271c23b1';

  late SearchClient _client;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    print('DEBUG: Inicializando Algolia...');
    _client = SearchClient(appId: _appId, apiKey: _apiKey);
    _initialized = true;
  }

  SearchClient get client {
    if (!_initialized) init();
    return _client;
  }

  static const String postsIndex = 'ALGOLIA';
  static const String wantsIndex = 'wants';

  // ─────────────────────────────────────────────────────────────────────────
  // BÚSQUEDAS (Usando SDK)
  // ─────────────────────────────────────────────────────────────────────────

  Future<SearchResponse> searchPosts(
    String query, {
    String? city,
    Map<String, dynamic>? filter,
    int limit = 60,
  }) async {
    List<String> filters = [];

    if (city != null && city.isNotEmpty && city.toLowerCase() != 'todo') {
      filters.add('(city:"$city" OR location:"$city")');
    }

    if (filter != null) {
      filter.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          filters.add('$key:"$value"');
        }
      });
    }

    try {
      final result = await client.searchIndex(
        request: SearchForHits(
          indexName: postsIndex,
          query: query,
          hitsPerPage: limit,
          filters: filters.isNotEmpty ? filters.join(' AND ') : null,
        ),
      );

      // Si la búsqueda con filtro de ciudad no dio resultados, buscar sin filtro de ciudad
      if (result.hits.isEmpty && city != null && city.isNotEmpty && city.toLowerCase() != 'todo') {
        List<String> fallbackFilters = [];
        if (filter != null) {
          filter.forEach((key, value) {
            if (value != null && value.toString().isNotEmpty) {
              fallbackFilters.add('$key:"$value"');
            }
          });
        }
        final fallbackResult = await client.searchIndex(
          request: SearchForHits(
            indexName: postsIndex,
            query: query,
            hitsPerPage: limit,
            filters: fallbackFilters.isNotEmpty ? fallbackFilters.join(' AND ') : null,
          ),
        );
        if (fallbackResult.hits.isNotEmpty) {
          return fallbackResult;
        }
      }

      return result;
    } catch (e) {
      print('AlgoliaService.searchPosts error: $e');
      if (filters.isNotEmpty) {
        try {
          return await client.searchIndex(
            request: SearchForHits(
              indexName: postsIndex,
              query: query,
              hitsPerPage: limit,
            ),
          );
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<SearchResponse> searchWants(
    String query, {
    String? city,
    int limit = 20,
  }) async {
    List<String> filters = [];
    if (city != null && city.isNotEmpty && city.toLowerCase() != 'todo') {
      filters.add('(city:"$city" OR location:"$city")');
    }

    try {
      final result = await client.searchIndex(
        request: SearchForHits(
          indexName: wantsIndex,
          query: query,
          hitsPerPage: limit,
          filters: filters.isNotEmpty ? filters.join(' AND ') : null,
        ),
      );

      if (result.hits.isEmpty && city != null && city.isNotEmpty && city.toLowerCase() != 'todo') {
        final fallbackResult = await client.searchIndex(
          request: SearchForHits(
            indexName: wantsIndex,
            query: query,
            hitsPerPage: limit,
          ),
        );
        if (fallbackResult.hits.isNotEmpty) {
          return fallbackResult;
        }
      }

      return result;
    } catch (e) {
      print('AlgoliaService.searchWants error: $e');
      if (filters.isNotEmpty) {
        try {
          return await client.searchIndex(
            request: SearchForHits(
              indexName: wantsIndex,
              query: query,
              hitsPerPage: limit,
            ),
          );
        } catch (_) {}
      }
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ESCRITURA (Restaurados mediante peticiones HTTP para asegurar su funcionamiento)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> indexPost(String id, Map<String, dynamic> data) async {
    await _saveObject(
      indexName: postsIndex,
      objectId: id,
      data: _prepareDocument(id, data),
    );
  }

  Future<void> deletePost(String id) async {
    await _deleteObject(indexName: postsIndex, objectId: id);
  }

  Future<void> indexWant(String id, Map<String, dynamic> data) async {
    await _saveObject(
      indexName: wantsIndex,
      objectId: id,
      data: _prepareDocument(id, data),
    );
  }

  Future<void> deleteWant(String id) async {
    await _deleteObject(indexName: wantsIndex, objectId: id);
  }

  Future<void> _saveObject({
    required String indexName,
    required String objectId,
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse('https://$_appId.algolia.net/1/indexes/$indexName/$objectId');
    final response = await http.put(
      url,
      headers: _adminHeaders,
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      print('AlgoliaService._saveObject error: ${response.body}');
    }
  }

  Future<void> _deleteObject({
    required String indexName,
    required String objectId,
  }) async {
    final url = Uri.parse('https://$_appId.algolia.net/1/indexes/$indexName/$objectId');
    final response = await http.delete(url, headers: _adminHeaders);
    if (response.statusCode != 200) {
      print('AlgoliaService._deleteObject error: ${response.body}');
    }
  }

  Map<String, dynamic> _prepareDocument(String id, Map<String, dynamic> data) {
    final doc = Map<String, dynamic>.from(data);
    doc['objectID'] = id;

    if (doc['createdAt'] is Timestamp) {
      doc['createdAt'] = (doc['createdAt'] as Timestamp).millisecondsSinceEpoch;
    }
    if (doc['updatedAt'] is Timestamp) {
      doc['updatedAt'] = (doc['updatedAt'] as Timestamp).millisecondsSinceEpoch;
    }

    final loc = doc['location'] ?? doc['city'] ?? doc['ubicacion'] ?? doc['ciudad'];
    if (loc != null) {
      doc['city'] = loc;
      doc['location'] = loc;
    }

    doc['_searchTitle'] = (doc['title'] ?? '').toString().toLowerCase();
    doc['_searchDesc'] = (doc['description'] ?? '').toString().toLowerCase();

    return doc;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECOMENDACIONES (Restaurado para FirebaseFallback)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecommendations({
    required String category,
    required String currentPostId,
    int limit = 10,
  }) async {
    return _firestoreRecommendations(
      category: category,
      currentPostId: currentPostId,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> _firestoreRecommendations({
    required String category,
    required String currentPostId,
    required int limit,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('category', isEqualTo: category)
          .limit(limit + 5)
          .get();

      final posts = snapshot.docs
          .where((doc) => doc.id != currentPostId)
          .take(limit)
          .map((doc) {
            final data = doc.data();
            data['objectID'] = doc.id;
            return data;
          })
          .toList();

      if (posts.length < limit) {
        final extra = await FirebaseFirestore.instance
            .collection('posts')
            .limit(limit)
            .get();

        final existingIds = posts.map((p) => p['objectID']).toSet();
        for (final doc in extra.docs) {
          if (!existingIds.contains(doc.id) && doc.id != currentPostId) {
            final data = doc.data();
            data['objectID'] = doc.id;
            posts.add(data);
            if (posts.length >= limit) break;
          }
        }
      }

      return posts.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, String> get _adminHeaders => {
        'X-Algolia-Application-Id': _appId,
        'X-Algolia-API-Key': _adminApiKey,
        'Content-Type': 'application/json',
      };
}
