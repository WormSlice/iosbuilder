import 'package:cloud_firestore/cloud_firestore.dart';
import 'meilisearch_service.dart';

class MeiliSearchSyncService {
  final _meili = MeiliSearchService();
  final _firestore = FirebaseFirestore.instance;

  Future<void> initIndices() async {
    // Configure Posts Index
    final postsIndex = _meili.client.index(MeiliSearchService.postsIndex);
    await postsIndex.updateFilterableAttributes(['city', 'category', 'userId', 'status', 'type']);
    await postsIndex.updateSortableAttributes(['createdAt']);

    // Configure Wants Index
    final wantsIndex = _meili.client.index(MeiliSearchService.wantsIndex);
    await wantsIndex.updateFilterableAttributes(['city', 'category', 'userId', 'status', 'type']);
    await wantsIndex.updateSortableAttributes(['createdAt']);
  }

  Future<void> syncAll() async {
    try {
      print('Meilisearch: Iniciando sincronización completa...');
      final health = await _meili.client.health();
      print('Meilisearch Health: ${health['status']}');
      
      await initIndices();
      await syncPosts();
      await syncWants();
      print('Meilisearch: Sincronización completada con éxito.');
    } catch (e, stack) {
      print('Meilisearch Error en syncAll: $e');
      print('Meilisearch StackTrace: $stack');
      rethrow;
    }
  }

  Future<void> syncPosts() async {
    try {
      print('Meilisearch: Obteniendo posts de Firestore...');
      final snapshot = await _firestore.collection('posts').get();
      print('Meilisearch: Encontrados ${snapshot.docs.length} documentos en Firestore (posts)');
      
      if (snapshot.docs.isEmpty) {
        print('Meilisearch: No hay documentos para sincronizar en posts.');
        return;
      }

      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Normalización de campos para búsqueda
        data['type'] = (data['type'] ?? 'post').toString();
        data['status'] = (data['status'] ?? 'active').toString();
        
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
        }
        return data;
      }).toList();

      const batchSize = 20;
      for (var i = 0; i < docs.length; i += batchSize) {
        final end = (i + batchSize < docs.length) ? i + batchSize : docs.length;
        final batch = docs.sublist(i, end);
        print('Meilisearch: Enviando lote de ${batch.length} posts a Meilisearch...');
        final task = await _meili.client.index(MeiliSearchService.postsIndex).addDocuments(batch);
        print('Meilisearch: Lote de posts ($i - $end) enviado con ID de tarea: ${task.uid}');
      }
    } catch (e, stack) {
      print('Meilisearch Error CRÍTICO en syncPosts: $e');
      print('Meilisearch StackTrace: $stack');
      rethrow;
    }
  }

  Future<void> syncWants() async {
    try {
      print('Meilisearch: Obteniendo wants de Firestore...');
      final snapshot = await _firestore.collection('wants').get();
      print('Meilisearch: Encontrados ${snapshot.docs.length} documentos en Firestore (wants)');
      
      if (snapshot.docs.isEmpty) {
        print('Meilisearch: No hay documentos para sincronizar en wants.');
        return;
      }

      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Normalización de campos
        data['type'] = (data['type'] ?? 'want').toString();
        data['status'] = (data['status'] ?? 'active').toString();
        
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
        }
        return data;
      }).toList();

      const batchSize = 20;
      for (var i = 0; i < docs.length; i += batchSize) {
        final end = (i + batchSize < docs.length) ? i + batchSize : docs.length;
        final batch = docs.sublist(i, end);
        print('Meilisearch: Enviando lote de ${batch.length} wants a Meilisearch...');
        final task = await _meili.client.index(MeiliSearchService.wantsIndex).addDocuments(batch);
        print('Meilisearch: Lote de wants ($i - $end) enviado con ID de tarea: ${task.uid}');
      }
    } catch (e, stack) {
      print('Meilisearch Error CRÍTICO en syncWants: $e');
      print('Meilisearch StackTrace: $stack');
      rethrow;
    }
  }
}
