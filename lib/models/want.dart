import 'package:cloud_firestore/cloud_firestore.dart';

class Want {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String imageUrl;
  final double willingToPay;
  final String location;
  final List<String> hashtags;
  final String category;
  final DateTime createdAt;

  Want({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.willingToPay,
    required this.location,
    required this.hashtags,
    required this.category, // Added
    required this.createdAt,
  });

  factory Want.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Want.fromMap(data, doc.id);
  }

  factory Want.fromMap(Map<String, dynamic> data, String id) {
    return Want(
      id: id,
      userId: data['userId'] ?? '',
      title: (data['title'] ?? data['name'] ?? '').toString(),
      description: data['description'] ?? '',
      imageUrl: (data['imageUrl'] ?? data['image'] ?? '').toString(),
      willingToPay: (data['willingToPay'] ?? data['price'] ?? 0).toDouble(),
      location: (data['location'] ?? 'Medellín').toString(),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      category: (data['category'] ?? 'Para ti').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : data['createdAt'] is String
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'willingToPay': willingToPay,
      'location': location,
      'hashtags': hashtags,
      'category': category,
      'createdAt': createdAt,
    };
  }
}
