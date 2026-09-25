import 'package:cloud_firestore/cloud_firestore.dart';

class AdCampaign {
  final String id;
  final String title;
  final String client;
  final String imageUrl;
  final String linkUrl;
  final String placement; // 'home_top' | 'feed_interstitial' | 'explore_banner' | 'search_top'
  final String status; // 'active' | 'paused'
  final int clicks;
  final int impressions;
  final DateTime? createdAt;

  const AdCampaign({
    required this.id,
    required this.title,
    required this.client,
    required this.imageUrl,
    required this.linkUrl,
    required this.placement,
    required this.status,
    this.clicks = 0,
    this.impressions = 0,
    this.createdAt,
  });

  bool get isActive => status == 'active';

  factory AdCampaign.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? created;
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    } else if (rawDate is String) {
      created = DateTime.tryParse(rawDate);
    }

    return AdCampaign(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      client: data['client']?.toString() ?? data['sponsor']?.toString() ?? 'Patrocinador',
      imageUrl: data['imageUrl']?.toString() ?? data['image']?.toString() ?? '',
      linkUrl: data['linkUrl']?.toString() ?? data['targetUrl']?.toString() ?? data['link']?.toString() ?? '',
      placement: data['placement']?.toString() ?? 'home_top',
      status: data['status']?.toString() ?? 'active',
      clicks: (data['clicks'] as num?)?.toInt() ?? 0,
      impressions: (data['impressions'] as num?)?.toInt() ?? 0,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'client': client,
      'imageUrl': imageUrl,
      'linkUrl': linkUrl,
      'placement': placement,
      'status': status,
      'clicks': clicks,
      'impressions': impressions,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }
}
