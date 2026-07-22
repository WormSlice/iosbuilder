import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/connect_app_bar.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const ConnectAppBar(
        showSearch: false,
        showSettings: false,
        showBack: true,
      ),
      body: uid == null
          ? const SizedBox()
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
                      .limit(20)
                      .snapshots(),
                  builder: (context, personalSnap) {
                    if (broadcastSnap.hasError || personalSnap.hasError) {
                      return const Center(
                        child: Text("Error cargando notificaciones"),
                      );
                    }

                    if (!broadcastSnap.hasData && !personalSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Combine and sort
                    List<Map<String, dynamic>> allNotifications = [];

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
                        icon: Icons.notifications_none,
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: allNotifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
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
    final timestamp = data['createdAt'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd MMM, HH:mm').format(timestamp.toDate())
        : 'Ahora';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isBroadcast ? Colors.black : const Color(0xFFF5F5F7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBroadcast
                  ? Icons.campaign_rounded
                  : Icons.notifications_rounded,
              size: 20,
              color: isBroadcast ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isBroadcast ? 'CONNECT • Oficial' : 'Notificación',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade400,
                        letterSpacing: 0.5,
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
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
