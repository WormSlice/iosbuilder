import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:algolia_client_search/algolia_client_search.dart';
import 'algolia_service.dart';

class AlgoliaSyncService {
  final _algolia = AlgoliaService();
  final _firestore = FirebaseFirestore.instance;

  Future<void> syncAll() async {
    try {
      print('Algolia: Iniciando sincronización completa...');
      
      await syncPosts();
      await syncWants();
      print('Algolia: Sincronización completada con éxito.');
    } catch (e, stack) {
      print('Algolia Error en syncAll: $e');
      print('Algolia StackTrace: $stack');
      rethrow;
    }
  }

  Future<void> syncPosts() async {
    try {
      print('Algolia: Obteniendo posts de Firestore...');
      final snapshot = await _firestore.collection('posts').get();
      print('Algolia: Encontrados ${snapshot.docs.length} documentos en Firestore (posts)');
      
      if (snapshot.docs.isEmpty) {
        print('Algolia: No hay documentos para sincronizar en posts.');
        return;
      }

      final batchRequests = <BatchRequest>[];

      for (var doc in snapshot.docs) {
        var data = Map<String, dynamic>.from(doc.data());
        data['objectID'] = doc.id; // required by Algolia
        data['id'] = doc.id;
        
        // Normalización de campos para búsqueda
        data['type'] = (data['type'] ?? 'post').toString();
        data['status'] = (data['status'] ?? 'active').toString();
        
        data = _sanitizeMap(data);

        batchRequests.add(
          BatchRequest(action: Action.fromJson('addObject'), body: data),
        );
      }

      print('Algolia: Enviando ${batchRequests.length} posts a Algolia...');
      const batchSize = 50;
      for (var i = 0; i < batchRequests.length; i += batchSize) {
        final end = (i + batchSize < batchRequests.length) ? i + batchSize : batchRequests.length;
        final batch = batchRequests.sublist(i, end);
        await _algolia.client.batch(
          indexName: AlgoliaService.postsIndex,
          batchWriteParams: BatchWriteParams(requests: batch),
        );
      }
      print('Algolia: Posts sincronizados correctamente.');
    } catch (e, stack) {
      print('Algolia Error CRÍTICO en syncPosts: $e');
      print('Algolia StackTrace: $stack');
    }
  }

  Future<void> syncWants() async {
    try {
      print('Algolia: Obteniendo wants de Firestore...');
      final snapshot = await _firestore.collection('wants').get();
      print('Algolia: Encontrados ${snapshot.docs.length} documentos en Firestore (wants)');
      
      if (snapshot.docs.isEmpty) {
        print('Algolia: No hay documentos para sincronizar en wants.');
        return;
      }

      final batchRequests = <BatchRequest>[];

      for (var doc in snapshot.docs) {
        var data = Map<String, dynamic>.from(doc.data());
        data['objectID'] = doc.id; // required by Algolia
        data['id'] = doc.id;
        
        // Normalización de campos
        data['type'] = (data['type'] ?? 'want').toString();
        data['status'] = (data['status'] ?? 'active').toString();
        
        data = _sanitizeMap(data);

        batchRequests.add(
          BatchRequest(action: Action.fromJson('addObject'), body: data),
        );
      }

      print('Algolia: Enviando ${batchRequests.length} wants a Algolia...');
      const batchSize = 50;
      for (var i = 0; i < batchRequests.length; i += batchSize) {
        final end = (i + batchSize < batchRequests.length) ? i + batchSize : batchRequests.length;
        final batch = batchRequests.sublist(i, end);
        await _algolia.client.batch(
          indexName: AlgoliaService.wantsIndex,
          batchWriteParams: BatchWriteParams(requests: batch),
        );
      }
      print('Algolia: Wants sincronizados correctamente.');
    } catch (e, stack) {
      print('Algolia Error CRÍTICO en syncWants: $e');
      print('Algolia StackTrace: $stack');
    }
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    for (var entry in data.entries) {
      sanitized[entry.key] = _sanitizeValue(entry.value);
    }
    return sanitized;
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) {
      return value;
    }
    if (value is Iterable) {
      return value.map((e) => _sanitizeValue(e)).toList();
    }
    if (value is Map) {
      return _sanitizeMap(Map<String, dynamic>.from(value));
    }
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }
    // Convertir cualquier otro objeto a string para evitar caídas en jsonEncode
    return value.toString();
  }
}
