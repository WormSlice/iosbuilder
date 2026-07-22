import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../widgets/post_card.dart';
import '../../widgets/empty_state.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favoritos')),
        body: const Center(child: Text('Inicia sesión para ver tus favoritos')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text(
          'Mis Favoritos',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService().favoritesStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              title: 'Error al cargar favoritos',
              icon: Icons.error_outline,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const EmptyState(
              title: 'No tienes favoritos aún',
              icon: Icons.favorite_border,
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.76,
            ),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final String postId = d['postId'] ?? docs[i].id;

              return PostCard(
                imageUrl: (d['imageUrl'] ?? d['image'] ?? '').toString(),
                title: (d['title'] ?? d['name'] ?? '').toString(),
                price: (d['price'] ?? d['precio'] ?? '').toString(),
                location: (d['location'] ?? d['ubicacion'] ?? '').toString(),
                postId: postId,
                userId: d['userId'],
                data: d,
              );
            },
          );
        },
      ),
    );
  }
}
