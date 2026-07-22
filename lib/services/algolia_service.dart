import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio central de Algolia para busqueda e indexacion de publicaciones.
/// Utiliza la API REST de Algolia directamente para maxima compatibilidad.
class AlgoliaService {
  static final AlgoliaService _instance = AlgoliaService._internal();
  factory AlgoliaService() => _instance;
  AlgoliaService._internal();

  // Credenciales reales de Algolia (dashboard.algolia.com)
  static const String _appId = 'P2CJMQDDSH';
  static const String _searchApiKey = '6b69cf2f3a3fab9332efc9ee38ea1643';
  static const String _adminApiKey = '57420e6aee69de5647d2b1cb9cd7a182';

  // Indice configurado en la Extension de Firebase
  static const String postsIndex = 'ALGOLIA';
  static const String wantsIndex = 'ALGOLIA';

  // Las credenciales estan configuradas
  bool get isConfigured => true;

  // ─────────────────────────────────────────────────────────────────────────
  // BUSQUEDA
  // ─────────────────────────────────────────────────────────────────────────

  /// Busqueda principal en Algolia con tolerancia a errores de escritura.
  Future<Map<String, dynamic>> searchPosts({
    required String query,
    String? category,
    int hitsPerPage = 50,
    int page = 0,
  }) async {
    if (!isConfigured) {
      return _firestoreFallbackSearch(query: query, category: category);
    }

    try {
      // Busca en el indice de posts
      final postsResponse = await _query(
        indexName: postsIndex,
        query: query,
        hitsPerPage: hitsPerPage,
        page: page,
        filters: category != null ? 'category:"$category"' : null,
      );

      // Tambien busca en wants para resultados unificados
      final wantsResponse = await _query(
        indexName: wantsIndex,
        query: query,
        hitsPerPage: 20,
        page: 0,
        filters: category != null ? 'category:"$category"' : null,
      );

      final postHits = List<Map<String, dynamic>>.from(postsResponse['hits'] ?? []);
      final wantHits = List<Map<String, dynamic>>.from(wantsResponse['hits'] ?? []);

      // Marcar quienes son "wants"
      for (final w in wantHits) {
        w['_isWant'] = true;
      }

      return {
        'hits': [...postHits, ...wantHits],
        'nbHits': (postsResponse['nbHits'] ?? 0) + (wantsResponse['nbHits'] ?? 0),
        'query': query,
      };
    } catch (e) {
      print('AlgoliaService.searchPosts error: $e');
      return _firestoreFallbackSearch(query: query, category: category);
    }
  }

  /// Obtiene recomendaciones basadas en categoria e historial del usuario.
  Future<List<Map<String, dynamic>>> getRecommendations({
    required String category,
    required String currentPostId,
    int limit = 15,
  }) async {
    if (!isConfigured) {
      return _firestoreRecommendations(category: category, currentPostId: currentPostId, limit: limit);
    }

    try {
      // Busca por categoria excluyendo el post actual
      final result = await _query(
        indexName: postsIndex,
        query: '',
        hitsPerPage: limit + 5,
        filters: 'category:"$category" AND NOT objectID:"$currentPostId"',
      );

      List<Map<String, dynamic>> hits = List<Map<String, dynamic>>.from(result['hits'] ?? []);

      // Si faltan resultados, completar con otras categorias
      if (hits.length < limit) {
        final extra = await _query(
          indexName: postsIndex,
          query: '',
          hitsPerPage: limit - hits.length + 5,
          filters: 'NOT objectID:"$currentPostId"',
        );
        final extraHits = List<Map<String, dynamic>>.from(extra['hits'] ?? []);
        final existingIds = hits.map((h) => h['objectID']).toSet();
        for (final h in extraHits) {
          if (!existingIds.contains(h['objectID'])) {
            hits.add(h);
            if (hits.length >= limit) break;
          }
        }
      }

      // Intentar enriquecer con historial del usuario
      final userHits = await _getFromUserHistory(limit: 5);
      final existingIds = hits.map((h) => h['objectID']).toSet();
      for (final h in userHits) {
        if (!existingIds.contains(h['objectID']) && h['objectID'] != currentPostId) {
          hits.insert(0, h);
        }
      }

      return hits.take(limit).toList();
    } catch (e) {
      print('AlgoliaService.getRecommendations error: $e');
      return _firestoreRecommendations(category: category, currentPostId: currentPostId, limit: limit);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SINCRONIZACION (INDEXACION)
  // ─────────────────────────────────────────────────────────────────────────

  /// Indexa o actualiza una publicacion en Algolia.
  Future<void> indexPost(String postId, Map<String, dynamic> data) async {
    if (!isConfigured) return;
    final doc = _prepareDocument(postId, data);
    await _saveObject(indexName: postsIndex, objectId: postId, data: doc);
  }

  /// Indexa o actualiza un "Lo Tienes" (want) en Algolia.
  Future<void> indexWant(String wantId, Map<String, dynamic> data) async {
    if (!isConfigured) return;
    final doc = _prepareDocument(wantId, data);
    doc['_isWant'] = true;
    await _saveObject(indexName: wantsIndex, objectId: wantId, data: doc);
  }

  /// Elimina una publicacion del indice de Algolia.
  Future<void> deletePost(String postId) async {
    if (!isConfigured) return;
    await _deleteObject(indexName: postsIndex, objectId: postId);
  }

  /// Elimina un "want" del indice de Algolia.
  Future<void> deleteWant(String wantId) async {
    if (!isConfigured) return;
    await _deleteObject(indexName: wantsIndex, objectId: wantId);
  }

  /// Sincronizacion masiva: indexa todos los posts y wants de Firestore.
  Future<void> syncAll() async {
    if (!isConfigured) {
      print('AlgoliaService: Credenciales no configuradas, omitiendo sincronizacion.');
      return;
    }
    try {
      print('AlgoliaService: Iniciando sincronizacion completa...');
      await _syncCollection('posts', postsIndex);
      await _syncCollection('wants', wantsIndex);
      print('AlgoliaService: Sincronizacion completa finalizada.');
    } catch (e) {
      print('AlgoliaService.syncAll error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INTERNOS - API REST DE ALGOLIA
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _query({
    required String indexName,
    required String query,
    int hitsPerPage = 20,
    int page = 0,
    String? filters,
  }) async {
    final url = Uri.parse('https://$_appId-dsn.algolia.net/1/indexes/$indexName/query');
    final body = <String, dynamic>{
      'query': query,
      'hitsPerPage': hitsPerPage,
      'page': page,
      'attributesToHighlight': [],
      'typoTolerance': true,
    };
    if (filters != null) body['filters'] = filters;

    final response = await http.post(
      url,
      headers: _searchHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Algolia query failed ${response.statusCode}: ${response.body}');
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

  Future<void> _batchSave({
    required String indexName,
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) return;
    final url = Uri.parse('https://$_appId.algolia.net/1/indexes/$indexName/batch');

    const batchSize = 50;
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);
      final requests = batch.map((item) => {'action': 'updateObject', 'body': item}).toList();

      final response = await http.post(
        url,
        headers: _adminHeaders,
        body: jsonEncode({'requests': requests}),
      );

      if (response.statusCode != 200) {
        print('AlgoliaService._batchSave error (batch $i-$end): ${response.body}');
      } else {
        print('AlgoliaService: Lote $i-$end enviado a "$indexName".');
      }
    }
  }

  Future<void> _syncCollection(String collection, String indexName) async {
    final snapshot = await FirebaseFirestore.instance.collection(collection).get();
    if (snapshot.docs.isEmpty) return;

    final docs = snapshot.docs.map((doc) {
      return _prepareDocument(doc.id, doc.data());
    }).toList();

    await _batchSave(indexName: indexName, items: docs);
    print('AlgoliaService: $collection sincronizado (${docs.length} documentos).');
  }

  Map<String, dynamic> _prepareDocument(String id, Map<String, dynamic> data) {
    final doc = Map<String, dynamic>.from(data);
    doc['objectID'] = id;

    // Convertir Timestamps a milisegundos
    if (doc['createdAt'] is Timestamp) {
      doc['createdAt'] = (doc['createdAt'] as Timestamp).millisecondsSinceEpoch;
    }
    if (doc['updatedAt'] is Timestamp) {
      doc['updatedAt'] = (doc['updatedAt'] as Timestamp).millisecondsSinceEpoch;
    }

    // Campos de busqueda normalizados
    doc['_searchTitle'] = (doc['title'] ?? '').toString().toLowerCase();
    doc['_searchDesc'] = (doc['description'] ?? '').toString().toLowerCase();

    return doc;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FALLBACK - cuando Algolia no esta configurado, usa Firestore directamente
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _firestoreFallbackSearch({
    required String query,
    String? category,
  }) async {
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('posts');
      if (category != null) q = q.where('category', isEqualTo: category);
      final snapshot = await q.limit(50).get();

      final normalizedQuery = query.toLowerCase().trim();
      final hits = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['objectID'] = doc.id;
            return data;
          })
          .where((data) {
            if (normalizedQuery.isEmpty) return true;
            final title = (data['title'] ?? '').toString().toLowerCase();
            final description = (data['description'] ?? '').toString().toLowerCase();
            return title.contains(normalizedQuery) || description.contains(normalizedQuery);
          })
          .toList();

      return {'hits': hits, 'nbHits': hits.length, 'query': query};
    } catch (e) {
      return {'hits': [], 'nbHits': 0, 'query': query};
    }
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

      // Si no hay suficientes por categoria, completar con otros recientes
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

  Future<List<Map<String, dynamic>>> _getFromUserHistory({int limit = 5}) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('visited_posts')
          .orderBy('visitedAt', descending: true)
          .limit(limit)
          .get();

      if (snapshot.docs.isEmpty) return [];

      final postIds = snapshot.docs.map((d) => d.id).toList();
      final List<Map<String, dynamic>> results = [];

      for (final id in postIds) {
        final doc = await FirebaseFirestore.instance.collection('posts').doc(id).get();
        if (doc.exists) {
          final data = doc.data()!;
          data['objectID'] = doc.id;
          results.add(data);
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADERS
  // ─────────────────────────────────────────────────────────────────────────

  Map<String, String> get _searchHeaders => {
        'X-Algolia-Application-Id': _appId,
        'X-Algolia-API-Key': _searchApiKey,
        'Content-Type': 'application/json',
      };

  Map<String, String> get _adminHeaders => {
        'X-Algolia-Application-Id': _appId,
        'X-Algolia-API-Key': _adminApiKey,
        'Content-Type': 'application/json',
      };
}
