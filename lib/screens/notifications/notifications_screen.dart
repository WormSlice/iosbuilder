import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/connect_app_bar.dart';
import '../profile/profile_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const ConnectAppBar(
        showSearch: false,
        showSettings: false,
        showBack: true,
      ),
      body: uid == null
          ? const Center(child: Text('Inicia sesión para ver tus notificaciones'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('broadcasts')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, broadcastSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('notifications')
                      .orderBy('createdAt', descending: true)
                      .limit(30)
                      .snapshots(),
                  builder: (context, personalSnap) {
                    if (broadcastSnap.hasError || personalSnap.hasError) {
                      return const Center(
                        child: Text(
                          "Error cargando notificaciones",
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                        ),
                      );
                    }

                    if (!broadcastSnap.hasData && !personalSnap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0094FF),
                          strokeWidth: 2,
                        ),
                      );
                    }

                    // Combine & sort
                    final List<Map<String, dynamic>> allNotifications = [];

                    if (broadcastSnap.hasData) {
                      for (var doc in broadcastSnap.data!.docs) {
                        allNotifications.add({
                          'id': doc.id,
                          ...doc.data() as Map<String, dynamic>,
                          'isBroadcast': true,
                        });
                      }
                    }

                    if (personalSnap.hasData) {
                      for (var doc in personalSnap.data!.docs) {
                        allNotifications.add({
                          'id': doc.id,
                          ...doc.data() as Map<String, dynamic>,
                          'isBroadcast': false,
                        });
                      }
                    }

                    // Sort by date desc
                    allNotifications.sort((a, b) {
                      Timestamp? tA = a['createdAt'] as Timestamp?;
                      Timestamp? tB = b['createdAt'] as Timestamp?;
                      if (tA == null) return 1;
                      if (tB == null) return -1;
                      return tB.compareTo(tA);
                    });

                    if (allNotifications.isEmpty) {
                      return const EmptyState(
                        title: 'Sin notificaciones',
                        icon: Icons.notifications_none_rounded,
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: allNotifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = allNotifications[index];
                        return _NotificationCard(data: data);
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NotificationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Notificación';
    final body = data['body'] ?? '';
    final isBroadcast = data['isBroadcast'] == true;
    final type = (data['type'] ?? '').toString();
    final senderId = data['senderId']?.toString();
    final senderPhoto = data['senderPhoto']?.toString();
    final isFollow = type == 'follow';

    final timestamp = data['createdAt'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd MMM • HH:mm').format(timestamp.toDate())
        : 'Ahora';

    return InkWell(
      onTap: () {
        if (isFollow && senderId != null && senderId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: senderId),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFollow
                ? const Color(0xFF0094FF).withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar or Type Icon
            if (isFollow && senderPhoto != null && senderPhoto.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: senderPhoto,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _buildDefaultIcon(isFollow, isBroadcast),
                ),
              )
            else
              _buildDefaultIcon(isFollow, isBroadcast),
            const SizedBox(width: 12),

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBroadcast
                            ? 'CONNECT • Oficial'
                            : isFollow
                                ? 'Nuevo seguidor'
                                : 'Notificación',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isBroadcast
                              ? const Color(0xFF0094FF)
                              : isFollow
                                  ? const Color(0xFF0094FF)
                                  : Colors.grey.shade500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        date,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'CanvaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Compact Action Button if follow
            if (isFollow && senderId != null && senderId.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: senderId),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0094FF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0094FF).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Ver perfil',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0094FF),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(bool isFollow, bool isBroadcast) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isBroadcast
            ? const Color(0xFF0094FF)
            : isFollow
                ? const Color(0xFF0094FF).withOpacity(0.12)
                : const Color(0xFFF0F2F5),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          isBroadcast
              ? Icons.campaign_rounded
              : isFollow
                  ? Icons.person_add_rounded
                  : Icons.notifications_rounded,
          size: 20,
          color: isBroadcast
              ? Colors.white
              : isFollow
                  ? const Color(0xFF0094FF)
                  : Colors.black87,
        ),
      ),
    );
  }
}
