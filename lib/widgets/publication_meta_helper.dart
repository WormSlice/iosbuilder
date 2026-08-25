import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String formatTimeAgo(dynamic rawTimestamp) {
  if (rawTimestamp == null) return '';
  DateTime? dt;
  if (rawTimestamp is Timestamp) {
    dt = rawTimestamp.toDate();
  } else if (rawTimestamp is int) {
    dt = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
  } else if (rawTimestamp is String) {
    dt = DateTime.tryParse(rawTimestamp);
  }
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Hace un momento';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) {
    return 'Hace ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}';
  }
  if (diff.inDays < 7) {
    return 'Hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
  }
  if (diff.inDays < 30) return 'Hace ${(diff.inDays / 7).floor()} sem';
  if (diff.inDays < 365) return 'Hace ${(diff.inDays / 30).floor()} m';
  return 'Hace ${(diff.inDays / 365).floor()} a';
}

String getDepartment(Map<String, dynamic> data) {
  final dep = data['department'] ?? data['departamento'] ?? data['state'];
  if (dep != null && dep.toString().isNotEmpty) {
    return dep.toString();
  }
  final loc = data['location'] ?? data['ubicacion'] ?? data['ubicación'] ?? '';
  if (loc is String && loc.contains(',')) {
    final parts = loc.split(',');
    if (parts.length >= 2) {
      return parts.last.trim();
    }
  }
  return '';
}

Widget buildPriceAndMetaRow({
  required String priceText,
  required Map<String, dynamic> data,
  TextStyle? priceStyle,
}) {
  final dept = getDepartment(data);
  final timeAgo = formatTimeAgo(
    data['createdAt'] ?? data['timestamp'] ?? data['publishedAt'],
  );
  final parts = <String>[];
  if (dept.isNotEmpty) parts.add(dept);
  if (timeAgo.isNotEmpty) parts.add(timeAgo);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          priceText,
          style: priceStyle ??
              const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0094FF),
                fontFamily: 'Arimo',
              ),
        ),
        if (parts.isNotEmpty)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                parts.join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget buildVerifiedAuthorName(
  String name,
  bool isVerified, {
  TextStyle? style,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style ??
              const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'CanvaSans',
              ),
        ),
      ),
      if (isVerified) ...[
        const SizedBox(width: 4),
        const Icon(
          Icons.verified,
          color: Color(0xFF0094FF),
          size: 14,
        ),
      ],
    ],
  );
}
