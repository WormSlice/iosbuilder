import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../widgets/location_map.dart';
import 'package:connect/screens/profile/profile_screen.dart';
import '../../widgets/post_card.dart';
import '../../models/want.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/report_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chats/chat_room_screen.dart';
import '../../widgets/fullscreen_image_viewer.dart';

class WantDetailScreen extends StatefulWidget {
  final Want want;

  const WantDetailScreen({super.key, required this.want});

  @override
  State<WantDetailScreen> createState() => _WantDetailScreenState();
}

class _WantDetailScreenState extends State<WantDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _getString(dynamic value, {String fallback = 'N/A'}) {
    if (value == null) return fallback;
    return value.toString();
  }

  String _formatPrice(double price) {
    if (price == 0) return '\$ 0';
    final format = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return format.format(price).replaceAll(',', '.');
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.want;
    List<String> images = [];
    if (w.imageUrl.isNotEmpty) images.add(w.imageUrl);

    final ownerId = w.userId;
    final locationText = w.location;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // AppBar (Copied from ProductDetailScreen)
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF0094FF), size: 28),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Transform.translate(
                offset: const Offset(25, 0),
                child: IconButton(
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  icon: Image.asset(
                    'assets/iconos/compartir.png',
                    width: 22,
                    height: 22,
                  ),
                  onPressed: () {
                    final String title = w.title;
                    final String location = w.location.isEmpty
                        ? 'Ubicación Desconocida'
                        : w.location;
                    final String description =
                        'Estoy buscando esto en CONNECT. ¿Lo tienes?';

                    SharePlus.instance.share(
                      ShareParams(
                        text: '📝 $title\n📍 $location\n\n$description \n\nhttps://connectapp.com.co/w/${w.id}',
                      ),
                    );
                  },
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF0094FF),
                  size: 26,
                ),
                offset: const Offset(0, 40),
                onSelected: (value) async {
                  if (value == 'report') {
                    await ReportService.showReportDialog(
                      context,
                      postId: w.id,
                      postTitle: w.title,
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'report',
                    child: Text(
                      'Reportar publicación',
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: 'CanvaSans',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Slider (Height 380 as in ProductDetailScreen)
                Stack(
                  children: [
                    SizedBox(
                      height: 380,
                      width: double.infinity,
                      child: images.isNotEmpty
                          ? PageView.builder(
                              controller: _pageController,
                              itemCount: images.length,
                              onPageChanged: (index) {
                                setState(() => _currentImageIndex = index);
                              },
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FullscreenImageViewer(
                                          images: images,
                                          initialIndex: index,
                                        ),
                                      ),
                                    );
                                  },
                                  child: CachedNetworkImage(
                                    imageUrl: images[index],
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: Colors.grey[200]),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.broken_image,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.broken_image,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    // Indicator
                    if (images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(images.length, (index) {
                              return Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                  ],
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Text(
                    w.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'CanvaSans',
                    ),
                  ),
                ),

                // Price + Time + Location Row (ADAPTED: Single Line Price)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Price Row (Requested Adaptation)
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Dispuesto a pagar  ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0094FF),
                                fontFamily: 'CanvaSans',
                              ),
                            ),
                            TextSpan(
                              text: _formatPrice(w.willingToPay),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0094FF),
                                fontFamily: 'Arimo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Time and Location line (Below Price)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: Text(
                    locationText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'CanvaSans',
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 12),

                // Message Card (Exact copy from product)
                if (ownerId.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.near_me_rounded,
                              color: Color(0xFF0094FF),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '¿Lo tienes? Envíame un mensaje',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontFamily: 'CanvaSans',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: 'Hola, tengo lo que buscas...',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    hintStyle: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'CanvaSans',
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  final currentUid =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  if (currentUid == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Debes iniciar sesión para enviar un mensaje.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (currentUid == ownerId) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No puedes enviarte un mensaje a ti mismo.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  String msg = _messageController.text.trim();
                                  if (msg.isEmpty) {
                                    msg = 'Hola, tengo lo que buscas...';
                                  }

                                  try {
                                    final chatId = await FirestoreService()
                                        .getOrCreateChat(
                                      currentUid,
                                      ownerId,
                                      publicationId: w.id,
                                      publicationData: {
                                        'id': w.id,
                                        'title': w.title,
                                        'image': w.imageUrl,
                                        'price': w.willingToPay,
                                      },
                                    );

                                    // Send the message
                                    await FirebaseFirestore.instance
                                        .collection('chats')
                                        .doc(chatId)
                                        .collection('messages')
                                        .add({
                                      'senderId': currentUid,
                                      'text': msg,
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'type': 'text',
                                    });

                                    // Update last message in chat
                                    await FirebaseFirestore.instance
                                        .collection('chats')
                                        .doc(chatId)
                                        .update({
                                      'lastMessage': msg,
                                      'lastMessageTime':
                                          FieldValue.serverTimestamp(),
                                      'lastSenderId': currentUid,
                                      'unreadCount': FieldValue.increment(1),
                                    });

                                    if (mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatRoomScreen(
                                            chatId: chatId,
                                            peerId: ownerId,
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Error al enviar: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0094FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Enviar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFamily: 'CanvaSans',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                const SizedBox(height: 16),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Descripción',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          fontFamily: 'CanvaSans',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        w.description.isNotEmpty
                            ? w.description
                            : 'Sin descripción detallada.',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.black87,
                          fontFamily: 'CanvaSans',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),
                // OWNER INFO (Exact copy from product)
                const Divider(height: 1, thickness: 1),
                if (ownerId.isNotEmpty) _buildOwnerInfo(ownerId),
                const SizedBox(height: 4),
                const Divider(height: 1, thickness: 1),

                const SizedBox(height: 8),
                // Chips (Adaptation: Category)
                _buildDetailChip('Categoría', _getString(w.category)),

                const SizedBox(height: 12),
                // Location Map (Product Design)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: LocationMap(
                    data: {'location': locationText},
                    locationText: locationText,
                  ),
                ),

                // Recommendations (Added to match product)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Podría interesarte',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                          fontFamily: 'CanvaSans',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 165,
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirestoreService().postsByCategoryStream(
                                category: w.category,
                              ),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return const Text(
                                    'No hay recomendaciones por ahora.',
                                  );
                                }
                                final docs = snapshot.data!.docs;
                                return ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: min(docs.length, 5),
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    final data = docs[i].data();
                                    String? img =
                                        data['imageUrl'] ?? data['image'];
                                    if (img == null &&
                                        data['images'] is List &&
                                        (data['images'] as List).isNotEmpty) {
                                      img = data['images'][0];
                                    }
                                    return SizedBox(
                                      width: 115,
                                      child: PostCard(
                                        imageUrl: img,
                                        title: data['title']?.toString() ?? '',
                                        price: data['price']?.toString() ?? '',
                                        location:
                                            data['location']?.toString() ?? '',
                                        postId: docs[i].id,
                                        userId: data['userId'],
                                        data: data,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Exact Copy of ProductDetailScreen helper
  Widget _buildDetailChip(String label, String value) {
    if (value == 'N/A' || value.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'CanvaSans',
                ),
              ),
            ),
          ),
          Container(width: 1.5, height: 24, color: const Color(0xFF0094FF)),
          Expanded(
            child: Center(
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'CanvaSans',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Exact Copy of ProductDetailScreen helper
  Widget _buildOwnerInfo(String ownerId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox();

        final photo =
            userData['photoURL'] ?? userData['photoUrl'] ?? userData['image'];
        final name = userData['displayName'] ?? userData['name'] ?? 'Usuario';
        final joined = userData['createdAt'];

        String joinedText = 'Miembro desde 2025';
        if (joined != null && joined is Timestamp) {
          joinedText = 'Se unió a Connect en ${joined.toDate().year}';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: ownerId),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0094FF),
                      width: 1.0,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                    child: photo == null
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Publicado por',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontFamily: 'CanvaSans',
                    ),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'CanvaSans',
                    ),
                  ),
                  Text(
                    joinedText,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontFamily: 'CanvaSans',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: ownerId),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Ver perfil',
                    style: TextStyle(
                      color: Color(0xFF0094FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'CanvaSans',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
