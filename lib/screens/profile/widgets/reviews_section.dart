import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../services/firestore_service.dart';

class ReviewsSection extends StatefulWidget {
  final String? userId;
  const ReviewsSection({super.key, this.userId});

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  int _selectedFilter = 0; // 0: Todas, 1: 5 estrellas, 2: 4 estrellas, 3: Fotos
  bool _showAll = false;
  final TextEditingController _reviewController = TextEditingController();
  double _userRating = 5.0;
  bool? _hasInteracted;
  
  List<File> _selectedImages = [];
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _reviewsStream;

  @override
  void initState() {
    super.initState();
    _checkInteraction();
    _focusNode.addListener(() {
      setState(() {});
    });
    if (widget.userId != null) {
      _reviewsStream = FirestoreService().reviewsStream(widget.userId!);
    }
  }

  Future<void> _checkInteraction() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final targetId = widget.userId;

    if (currentUid == null || targetId == null || currentUid == targetId) {
      if (mounted) setState(() => _hasInteracted = false);
      return;
    }

    final hasChat = await FirestoreService().hasChatWithUser(
      currentUid,
      targetId,
    );
    if (mounted) setState(() => _hasInteracted = hasChat);
  }

  Future<void> _pickImages() async {
    final List<XFile> files = await _picker.pickMultiImage();
    if (files.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(files.map((e) => File(e.path)));
        if (_selectedImages.length > 5) {
          _selectedImages = _selectedImages.sublist(0, 5);
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? targetId = widget.userId;
    if (targetId == null) {
      return const Center(child: Text('Usuario no encontrado'));
    }

    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isOwnProfile = targetId == currentUid;

    return Stack(
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _reviewsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs.toList() ?? [];

            // Sort in memory to handle initial null timestamps
            docs.sort((a, b) {
              final ta = a.data()['timestamp'];
              final tb = b.data()['timestamp'];
              if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
              if (ta == null && tb != null) return -1; // Newest first
              if (ta != null && tb == null) return 1;
              return 0;
            });

            final reviews = docs.map((doc) => doc.data()).toList();
            int total = reviews.length;
            double avg = 0;

            for (var r in reviews) {
              avg += (r['rating'] ?? 0).toDouble();
            }
            if (total > 0) avg /= total;

            final filteredDocs = docs.where((doc) {
              if (_selectedFilter == 0) return true;
              double rating = (doc.data()['rating'] ?? 0).toDouble();
              if (_selectedFilter == 1) return rating >= 5;
              if (_selectedFilter == 2) return rating <= 4;
              return true;
            }).toList();

            final displayDocs = _showAll ? filteredDocs : filteredDocs.take(3).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reseñas de clientes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'CanvaSans',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStars(avg, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        avg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($total reseñas)',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('Todas', 0),
                        _filterChip('5 estrellas', 1),
                        _filterChip('4 estrellas', 2),
                        _filterChip('Fotos', 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...displayDocs.map((doc) => _ReviewCard(data: doc.data())),
                  const SizedBox(height: 12),
                  if (!_showAll && filteredDocs.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Center(
                        child: GestureDetector(
                          onTap: () => setState(() => _showAll = true),
                          child: Text(
                            'Ver todas las reseñas',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (isOwnProfile)
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: _buildBuyerRatingsButton(),
          )
        else
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: _buildNewReviewInput(targetId, currentUid),
          ),
      ],
    );
  }

  Widget _filterChip(String label, int index) {
    final bool isActive = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 18}) {
    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.black, size: size);
        } else if (index < rating && rating - index >= 0.5) {
          return Icon(Icons.star_half, color: Colors.black, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.black, size: size);
        }
      }),
    );
  }

  Widget _buildNewReviewInput(String targetId, String? currentUid) {
    if (_hasInteracted == null) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasInteracted!) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Debes interactuar por chat con este usuario para calificarlo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // rating selector
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: Matrix4.identity()..scale(_focusNode.hasFocus ? 1.5 : 1.0),
          transformAlignment: Alignment.center,
          margin: EdgeInsets.only(bottom: _focusNode.hasFocus ? 16 : 8, top: _focusNode.hasFocus ? 8 : 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Reseñar: ',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              ...List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _userRating = index + 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(
                      index < _userRating ? Icons.star : Icons.star_border,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (_selectedImages.isNotEmpty)
          Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8, top: 4),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_selectedImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImages.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          child: const Icon(Icons.close, size: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Botón de más (+)
              GestureDetector(
                onTap: _selectedImages.length >= 5 ? null : _pickImages,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _selectedImages.length >= 5 ? Colors.grey.shade200 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.add_photo_alternate, color: _selectedImages.length >= 5 ? Colors.grey : Colors.black, size: 22),
                  ),
                ),
              ),

              // Campo de texto
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  controller: _reviewController,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  decoration: const InputDecoration(
                    hintText: 'Escribe tu reseña aquí...',
                    hintStyle: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                  ),
                ),
              ),

              // Botón de enviar (avión de papel)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: IconButton(
                  icon: Transform.rotate(
                    angle: -0.785398, // ~45 grados en radianes
                    child: const Icon(
                      Icons.send,
                      color: Color(0xFF00A8E8),
                      size: 22,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                   onPressed: _isUploading ? null : () async {
                    if (_reviewController.text.trim().isEmpty ||
                        currentUid == null) {
                      return;
                    }

                    setState(() => _isUploading = true);
                    String? imageUrl;
                    List<String> imageUrls = [];

                    try {
                      if (_selectedImages.isNotEmpty) {
                        for (var i = 0; i < _selectedImages.length; i++) {
                          final String fileName = '${currentUid}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                          final ref = FirebaseStorage.instance.ref().child('reviews').child(fileName);
                          await ref.putFile(_selectedImages[i]);
                          final url = await ref.getDownloadURL();
                          imageUrls.add(url);
                        }
                        imageUrl = imageUrls.first;
                      }

                      await FirestoreService().addReview(
                        reviewerId: currentUid,
                        targetUserId: targetId,
                        rating: _userRating,
                        text: _reviewController.text.trim(),
                        imageUrl: imageUrl,
                        imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
                      );

                      _reviewController.clear();
                      _focusNode.unfocus();
                      setState(() {
                        _userRating = 5.0;
                        _selectedImages.clear();
                        _isUploading = false;
                      });
                    } catch (e) {
                      setState(() => _isUploading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al enviar reseña: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuyerRatingsButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Tus calificaciones como comprador',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final String reviewerId = data['reviewerId'] ?? '';
    final double rating = (data['rating'] ?? 0).toDouble();
    final String text = data['text'] ?? '';
    final String category = data['category'] ?? 'Producto';
    final String item = data['itemReviewed'] ?? 'Usuario';
    final dynamic ts = data['timestamp'];
    String timeStr = 'Reciente';
    if (ts is Timestamp) {
      final diff = DateTime.now().difference(ts.toDate());
      if (diff.inDays > 7) {
        timeStr = 'Hace ${diff.inDays ~/ 7} sem.';
      } else if (diff.inDays > 0) {
        timeStr = 'Hace ${diff.inDays} d.';
      } else {
        timeStr = 'Hoy';
      }
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(reviewerId)
          .snapshots(),
      builder: (context, userSnap) {
        String name = 'Usuario';
        String photo = '';
        if (userSnap.hasData && userSnap.data!.exists) {
          final uData = userSnap.data!.data() as Map<String, dynamic>;
          String fullName = uData['displayName'] ?? uData['name'] ?? 'Usuario';

          // Truncate to first two names
          final parts = fullName.trim().split(RegExp(r'\s+'));
          if (parts.length > 2) {
            name = '${parts[0]} ${parts[1]}...';
          } else {
            name = fullName;
          }

          photo = uData['photoURL'] ?? uData['photoUrl'] ?? '';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: photo.isNotEmpty
                    ? Image.network(
                        photo,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: Colors.grey,
                          width: 36,
                          height: 36,
                        ),
                      )
                    : Container(color: Colors.grey, width: 36, height: 36),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildExactStars(rating.toInt()),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$category: $item - $timeStr',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                     const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                    if (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (data['imageUrls'] as List).map((url) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => _FullScreenImage(url: url),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    else if (data['imageUrl'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => _FullScreenImage(url: data['imageUrl']),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['imageUrl'],
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExactStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.black,
          size: 13,
        );
      }),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
