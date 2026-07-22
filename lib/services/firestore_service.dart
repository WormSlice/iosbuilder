import 'package:cloud_firestore/cloud_firestore.dart';
import 'algolia_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> marketplaceConfigStream() {
    return _db.collection('settings').doc('marketplace').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> postsStream() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> postsByCategoryStream({
    String? type,
    String? category,
    int limit = 10,
  }) {
    var query = _db.collection('posts').limit(limit);
    if (type != null && type.isNotEmpty) {
      if (type == 'barter') {
        return query
            .where(
              Filter.or(
                Filter('type', isEqualTo: 'barter'),
                Filter('isBarter', isEqualTo: true),
                Filter('barterMode', isEqualTo: true),
                Filter('category', isEqualTo: 'trueques'),
                Filter('trueque', isEqualTo: 'Sí'),
                Filter('trueque', isEqualTo: 'Si'),
                Filter('trueque', isEqualTo: 'si'),
                Filter('trueque', isEqualTo: 'sí'),
              ),
            )
            .snapshots();
      }
      return query.where('type', isEqualTo: type).snapshots();
    }
    if (category != null && category.isNotEmpty) {
      // Special handling for vehicles to support legacy variations
      if (category == 'vehículos' || category == 'vehiculos') {
        return query
            .where(
              'category',
              whereIn: ['vehículos', 'vehiculos', 'vehículo', 'vehiculo'],
            )
            .snapshots();
      }
      if (category == 'propiedades' || category == 'propiedad') {
        return query
            .where(
              'category',
              whereIn: [
                'propiedades',
                'propiedad',
                'inmueble',
                'inmuebles',
                'finca',
                'apto',
                'casa',
              ],
            )
            .snapshots();
      }
      if (category == 'productos' || category == 'producto') {
        return query
            .where(
              'category',
              whereIn: [
                'productos',
                'producto',
                'artículo',
                'articulos',
                'item',
              ],
            )
            .snapshots();
      }
      if (category == 'servicios' || category == 'servicio') {
        return query
            .where(
              'category',
              whereIn: ['servicios', 'servicio', 'prestación', 'handy'],
            )
            .snapshots();
      }
      if (category == 'empleos' || category == 'empleo') {
        return query
            .where(
              'category',
              whereIn: ['empleos', 'empleo', 'vacante', 'trabajo'],
            )
            .snapshots();
      }
      if (category == 'mascotas' || category == 'mascota') {
        return query
            .where(
              'category',
              whereIn: [
                'mascotas',
                'mascota',
                'animal',
                'animales',
                'perro',
                'gato',
              ],
            )
            .snapshots();
      }
      return query.where('category', isEqualTo: category).snapshots();
    }
    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> collectionStream(
    String collection,
  ) {
    return _db.collection(collection).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> conversationsStream(String uid) {
    return _db
        .collection('conversations')
        .where('members', arrayContains: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> chatsStream(String uid) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> roomsStream(String uid) {
    return _db
        .collection('rooms')
        .where('users', arrayContains: uid)
        .snapshots();
  }

  Future<List<String>> recentPreviewImages({int limit = 120}) async {
    final snap = await _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    final urls = <String>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      String? image =
          (d['imageUrl'] ??
                  d['image'] ??
                  d['coverUrl'] ??
                  d['portada'] ??
                  d['foto'] ??
                  d['thumbnail'])
              ?.toString();
      if (image == null || image.isEmpty) {
        final images = d['images'];
        if (images is List && images.isNotEmpty) {
          final first = images.first;
          if (first is String) image = first;
        }
      }
      if (image != null && image.isNotEmpty) urls.add(image);
    }
    return urls;
  }

  Future<void> createWant(Map<String, dynamic> data) async {
    final doc = await _db.collection('wants').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Sincronizacion automatica con Algolia
    AlgoliaService().indexWant(doc.id, {
      ...data,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> wantsStream() {
    return _db
        .collection('wants')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> wantsByCategoryStream(
    String category,
  ) {
    var query = _db.collection('wants');
    if (category != 'Para ti') {
      return query
          .where('category', isEqualTo: category.toLowerCase())
          .snapshots();
    }
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> wantsByUserStream(String userId) {
    return _db
        .collection('wants')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Future<String> createPost(Map<String, dynamic> data) async {
    final doc = await _db.collection('posts').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Sincronizacion automatica con Algolia
    AlgoliaService().indexPost(doc.id, {
      ...data,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return doc.id;
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    await _db.collection('posts').doc(postId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Sincronizacion automatica con Algolia
    AlgoliaService().indexPost(postId, data);
  }

  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
    // Sincronizacion automatica con Algolia
    AlgoliaService().deletePost(postId);
  }

  Future<void> updateWant(String wantId, Map<String, dynamic> data) async {
    await _db.collection('wants').doc(wantId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Sincronizacion automatica con Algolia
    AlgoliaService().indexWant(wantId, data);
  }

  Future<void> deleteWant(String wantId) async {
    await _db.collection('wants').doc(wantId).delete();
    // Sincronizacion automatica con Algolia
    AlgoliaService().deleteWant(wantId);
  }

  Future<void> updatePostAiTags(String postId, List<String> tags) async {
    await _db.collection('posts').doc(postId).update({'aiTags': tags});
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getAllPosts() {
    return _db.collection('posts').get();
  }

  Future<bool> hasChatWithUser(String uid, String peerId) async {
    try {
      final querySnapshot = await _db
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final List<dynamic> participants = data['participants'] ?? [];
        if (participants.contains(peerId)) {
          return true; // Existe un chat
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String> getOrCreateChat(
    String uid,
    String peerId, {
    String? publicationId,
    Map<String, dynamic>? publicationData,
  }) async {
    // 1. Query chats where both users are participants
    final querySnapshot = await _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    // 2. Filter results in memory (Firestore array-contains limitation)
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);

      // Check if peer is in participants
      if (participants.contains(peerId)) {
        // Now check context compatibility
        final chatPubId = data['publicationId'] as String?;

        if (publicationId != null) {
          // We are looking for a SPECIFIC publication chat
          if (chatPubId == publicationId) {
            return doc.id; // Found existing chat for this item
          }
        } else {
          // We are looking for a GENERAL chat
          if (chatPubId == null) {
            return doc.id; // Found existing general chat
          }
        }
      }
    }

    // 3. If no matching chat found, create a new one
    final newChatData = {
      'participants': [uid, peerId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'unreadCount': 0,
    };

    // Add context if it's a publication-specific chat
    if (publicationId != null) {
      newChatData['publicationId'] = publicationId;
      if (publicationData != null) {
        newChatData['publicationData'] = publicationData;
      }
    }

    final ref = await _db.collection('chats').add(newChatData);
    return ref.id;
  }

  // REVIEWS
  Stream<QuerySnapshot<Map<String, dynamic>>> reviewsStream(
    String targetUserId,
  ) {
    return _db
        .collection('reviews')
        .where('targetUserId', isEqualTo: targetUserId)
        .snapshots();
  }

  Future<void> addReview({
    required String reviewerId,
    required String targetUserId,
    required double rating,
    required String text,
    String? category,
    String? itemReviewed,
    String? imageUrl,
    List<String>? imageUrls,
  }) async {
    await _db.collection('reviews').add({
      'reviewerId': reviewerId,
      'targetUserId': targetUserId,
      'rating': rating,
      'text': text,
      'category': category ?? 'General',
      'itemReviewed': itemReviewed ?? 'Usuario',
      'imageUrl': imageUrl,
      if (imageUrls != null) 'imageUrls': imageUrls,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update user's aggregate rating (optional but recommended)
    // For now, we'll calculate it on the fly in the UI.
  }

  // FAVORITES
  Future<void> toggleFavorite(
    String userId,
    String postId,
    Map<String, dynamic> postData,
  ) async {
    final ref = _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(postId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({
        ...postData,
        'postId': postId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> favoritesStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .orderBy('savedAt', descending: true)
        .snapshots();
  }

  Stream<bool> isFavoriteStream(String userId, String postId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(postId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // SOCIAL
  Future<void> toggleFollow(String currentUid, String targetUid) async {
    final followingRef = _db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid);
    final followerRef = _db
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(currentUid);

    final doc = await followingRef.get();
    if (doc.exists) {
      // Unfollow
      await followingRef.delete();
      await followerRef.delete();

      // Decrement counts
      await _db.collection('users').doc(currentUid).update({
        'followingCount': FieldValue.increment(-1),
      });
      await _db.collection('users').doc(targetUid).update({
        'followersCount': FieldValue.increment(-1),
      });
    } else {
      // Follow
      await followingRef.set({'timestamp': FieldValue.serverTimestamp()});
      await followerRef.set({'timestamp': FieldValue.serverTimestamp()});

      // Increment counts
      await _db.collection('users').doc(currentUid).set({
        'followingCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      await _db.collection('users').doc(targetUid).set({
        'followersCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }
  }

  Stream<bool> isFollowingStream(String currentUid, String targetUid) {
    if (currentUid.isEmpty || targetUid.isEmpty) return Stream.value(false);
    return _db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> followersStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> followingStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots();
  }
}
