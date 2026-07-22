import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserListScreen extends StatelessWidget {
  final String userId;
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  const UserListScreen({
    super.key,
    required this.userId,
    required this.title,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFFF6F6F6),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Algo salió mal'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Sin usuarios aún',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.grey[600],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final String uid = docs[i].id;
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox.shrink();
                  final data = userSnap.data!.data() ?? {};
                  final name = data['displayName'] ?? data['name'] ?? 'Usuario';
                  final photo = data['photoURL'] ?? data['photoUrl'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photo.isNotEmpty
                          ? CachedNetworkImageProvider(photo)
                          : null,
                      child: photo.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: uid),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
