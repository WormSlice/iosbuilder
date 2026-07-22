import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserActivityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> trackVisit(String postId, Map<String, dynamic> postData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).collection('visited_posts').doc(postId).set({
        'postId': postId,
        'title': postData['title'],
        'price': postData['price'],
        'image': (postData['images'] as List?)?.first ?? postData['imageUrl'] ?? postData['image'],
        'visitedAt': FieldValue.serverTimestamp(),
        'category': postData['category'],
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error tracking visit: $e');
    }
  }

  Future<void> trackWantVisit(String wantId, Map<String, dynamic> wantData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).collection('visited_wants').doc(wantId).set({
        'wantId': wantId,
        'title': wantData['title'],
        'price': wantData['price'],
        'image': (wantData['images'] as List?)?.first ?? wantData['imageUrl'] ?? wantData['image'],
        'visitedAt': FieldValue.serverTimestamp(),
        'type': 'want',
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error tracking want visit: $e');
    }
  }

  Future<void> trackReviewSent(String targetUserId, Map<String, dynamic> reviewData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).collection('sent_reviews').add({
        'targetUserId': targetUserId,
        'rating': reviewData['rating'],
        'comment': reviewData['text'] ?? reviewData['comment'],
        'timestamp': FieldValue.serverTimestamp(),
        'category': reviewData['category'],
        'itemReviewed': reviewData['itemReviewed'],
      });
    } catch (e) {
      print('Error tracking review sent: $e');
    }
  }
}
