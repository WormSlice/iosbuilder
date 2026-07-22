import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AlgoliaSyncService {
  // Reemplazar con credenciales reales
  static const String _appId = 'YOUR_APP_ID';
  static const String _adminApiKey = 'YOUR_ADMIN_API_KEY';

  final _firestore = FirebaseFirestore.instance;

  Future<void> syncAll() async {
    print('Algolia: Iniciando sincronización completa...');
    await syncPosts();
    await syncWants();
    print('Algolia: Sincronización completada.');
  }

  Future<void> syncPosts() async {
    try {
      final snapshot = await _firestore.collection('posts').get();
      if (snapshot.docs.isEmpty) return;

      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id; // Algolia requires objectID
        
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
        }
        return data;
      }).toList();

      await _batchSaveItems('posts', docs);
    } catch (e) {
      print('Algolia Sync Error (Posts): $e');
    }
  }

  Future<void> syncWants() async {
    try {
      final snapshot = await _firestore.collection('wants').get();
      if (snapshot.docs.isEmpty) return;

      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['objectID'] = doc.id;
        
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
        }
        return data;
      }).toList();

      await _batchSaveItems('wants', docs);
    } catch (e) {
      print('Algolia Sync Error (Wants): $e');
    }
  }

  Future<void> savePost(String id, Map<String, dynamic> data) async {
    data['objectID'] = id;
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
    }
    await saveItem('posts', id, data);
  }

  Future<void> deletePost(String id) async {
    await deleteItem('posts', id);
  }

  Future<void> saveItem(String indexName, String objectID, Map<String, dynamic> data) async {
    final url = Uri.parse('https://$_appId.algolia.net/1/indexes/$indexName/$objectID');
    final response = await http.put(
      url,
      headers: {
        'X-Algolia-Application-Id': _appId,
        'X-Algolia-API-Key': _adminApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      print('Algolia Save Error: ${response.body}');
    }
  }

  Future<void> deleteItem(String indexName, String objectID) async {
    final url = Uri.parse('https://$_appId.algolia.net/1/indexes/$indexName/$objectID');
    final response = await http.delete(
      url,
      headers: {
        'X-Algolia-Application-Id': _appId,
        'X-Algolia-API-Key': _adminApiKey,
      },
    );
    if (response.statusCode != 200) {
      print('Algolia Delete Error: ${response.body}');
    }
  }

  Future<void> _batchSaveItems(String indexName, List<Map<String, dynamic>> items) async {
    final url = Uri.parse('https://$_appId.algolia.net/1/indexes/$indexName/batch');
    
    final requests = items.map((item) => {
      'action': 'updateObject',
      'body': item,
    }).toList();

    const batchSize = 50;
    for (var i = 0; i < requests.length; i += batchSize) {
      final end = (i + batchSize < requests.length) ? i + batchSize : requests.length;
      final batch = requests.sublist(i, end);

      final response = await http.post(
        url,
        headers: {
          'X-Algolia-Application-Id': _appId,
          'X-Algolia-API-Key': _adminApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'requests': batch}),
      );
      
      if (response.statusCode != 200) {
        print('Algolia Batch Error: ${response.body}');
      }
    }
  }
}
