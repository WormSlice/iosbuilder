import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/connect_app_bar.dart';
import 'package:intl/intl.dart';

/// Centro de Actividad del usuario.
/// Muestra tres pestanas:
/// - Historial: publicaciones visitadas recientemente.
/// - H. Reseñas: reseñas realizadas por el usuario.
/// - Lo Tienes: solicitudes creadas por el usuario.
class ActivityCenterScreen extends StatefulWidget {
  const ActivityCenterScreen({super.key});

  @override
  State<ActivityCenterScreen> createState() => _ActivityCenterScreenState();
}

class _ActivityCenterScreenState extends State<ActivityCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ConnectAppBar(
        title: 'CENTRO DE ACTIVIDAD',
        showSearch: false,
        showLeading: true,
        showBack: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            height: 48, // Mas delgada
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0094FF),
              unselectedLabelColor: Colors.grey[400],
              indicatorColor: const Color(0xFF0094FF),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 1.5,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                fontSize: 10,
                letterSpacing: 0.5,
              ),
              tabs: const [
                Tab(text: 'HISTORIAL'),
                Tab(text: 'H. RESEÑAS'),
                Tab(text: 'LO TIENES'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryList(),
                _buildReviewHistoryList(),
                _buildOwnList('wants'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HISTORIAL DE VISITAS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHistoryList() {
    if (_currentUid.isEmpty) {
      return const Center(child: Text('Inicia sesion para ver tu historial'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('visited_posts')
          .orderBy('visitedAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0094FF)));
        }
        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            message: 'Error al cargar el historial',
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history_rounded,
            message: 'Aqui aparecen las publicaciones que visites',
            sub: 'Explora el inicio y empieza a ver publicaciones',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final postId = docs[index].id;
            return _buildHistoryItem(postId, data);
          },
        );
      },
    );
  }

  Widget _buildHistoryItem(String postId, Map<String, dynamic> data) {
    final DateTime? visitedAt = (data['visitedAt'] as Timestamp?)?.toDate();
    final String dateStr = visitedAt != null
        ? _formatRelativeDate(visitedAt)
        : '';
    final String title = (data['title'] ?? 'Sin título').toString();
    final String? imageUrl = data['image']?.toString();
    final String category = (data['category'] ?? '').toString();
    final String price = (data['price'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navegar al detalle
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderImage(),
                      )
                    : _placeholderImage(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (price.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        price,
                        style: const TextStyle(
                          color: Color(0xFF0094FF),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 10, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0094FF).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0094FF),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HISTORIAL DE RESEÑAS ENVIADAS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildReviewHistoryList() {
    if (_currentUid.isEmpty) return const Center(child: Text('Inicia sesión'));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('reviewerId', isEqualTo: _currentUid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0094FF)));
        }
        if (snapshot.hasError) return _buildEmptyState(icon: Icons.error_outline, message: 'Error');

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.rate_review_outlined,
            message: 'Aun no has escrito reseñas',
            sub: 'Califica a otros usuarios para ver tu actividad aquí',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildReviewItem(docs[index].data()),
        );
      },
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> data) {
    final double rating = (data['rating'] ?? 0).toDouble();
    final String text = data['text'] ?? '';
    final String targetId = data['targetUserId'] ?? '';
    final DateTime? ts = (data['timestamp'] as Timestamp?)?.toDate();
    final String dateStr = ts != null ? _formatRelativeDate(ts) : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (i) => Icon(
                  i < rating ? Icons.star : Icons.star_border,
                  size: 14,
                  color: const Color(0xFFFFB800),
                )),
              ),
              Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 13, fontFamily: 'Poppins', height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(targetId).get(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final uData = snap.data?.data() as Map<String, dynamic>?;
              final name = uData?['displayName'] ?? uData?['name'] ?? 'Usuario';
              return Row(
                children: [
                  const Text('Para: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0094FF))),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LO TIENES (Wants)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOwnList(String collection) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: _currentUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0094FF)));
        }
        if (snapshot.hasError) return _buildEmptyState(icon: Icons.error_outline, message: 'Error');

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.favorite_rounded,
            message: 'Aun no tienes solicitudes "Lo Tienes"',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final id = docs[index].id;
            return _buildPostItem(collection, id, data);
          },
        );
      },
    );
  }

  Widget _buildPostItem(String collection, String id, Map<String, dynamic> data) {
    final DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final String dateStr = createdAt != null ? _formatRelativeDate(createdAt) : '';
    final String title = (data['title'] ?? data['name'] ?? 'Sin título').toString();
    final String status = data['status'] ?? 'active';
    final String price = (data['price'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF0094FF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.favorite_rounded, color: Color(0xFF0094FF), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (price.isNotEmpty) Text(price, style: const TextStyle(color: Color(0xFF0094FF), fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 10, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Poppins')),
                      const SizedBox(width: 8),
                      _buildStatusChip(status),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
              onSelected: (val) => _handleAction(collection, id, val),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = const Color(0xFF0094FF);
    String label = status.toUpperCase();
    if (status.toLowerCase() == 'active') color = Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _placeholderImage() {
    return Container(width: 54, height: 54, color: const Color(0xFFF0F0F0), child: const Icon(Icons.image_outlined, color: Colors.grey));
  }

  Widget _buildEmptyState({required IconData icon, required String message, String? sub}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 13)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(sub, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'Poppins')),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return DateFormat('dd MMM').format(date);
  }

  void _handleAction(String collection, String id, String action) async {
    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar'),
          content: const Text('Esta accion no se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Eliminar')),
          ],
        ),
      );
      if (confirm == true && mounted) {
        await FirebaseFirestore.instance.collection(collection).doc(id).delete();
      }
    }
  }
}
