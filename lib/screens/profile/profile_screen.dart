import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'content_navigation.dart';
import 'connect_profile_header.dart';
import '../../widgets/connect_app_bar.dart';
import '../../widgets/post_card.dart';
import '../post/post_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/algolia_service.dart';
import 'widgets/reviews_section.dart';

class ProfileScreen extends StatelessWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile =
        userId == null || (currentUid != null && userId == currentUid);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: ConnectAppBar(
          showSearch: false,
          showSettings: isOwnProfile,
          showLeading: false,
          showBack: !isOwnProfile,
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            ConnectProfileHeader(userId: userId),
            const SizedBox(height: 20),
            const ContentNavigation(),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                children: [
                  _PostsGrid(
                    userId: userId ?? currentUid,
                    isOwnProfile: isOwnProfile,
                  ),
                  ReviewsSection(userId: userId ?? currentUid),
                  _InfoSection(userId: userId ?? currentUid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostsGrid extends StatefulWidget {
  final String? userId;
  final bool isOwnProfile;
  const _PostsGrid({this.userId, required this.isOwnProfile});

  @override
  State<_PostsGrid> createState() => _PostsGridState();
}

class _PostsGridState extends State<_PostsGrid> {
  bool isSelectionMode = false;
  List<String> selectedIds = [];

  void toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
        if (selectedIds.isEmpty) isSelectionMode = false;
      } else {
        selectedIds.add(id);
      }
    });
  }

  void exitSelection() {
    setState(() {
      isSelectionMode = false;
      selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar publicaciones'),
        content: Text(
          '¿Seguro que deseas eliminar ${selectedIds.length} publicación(es)? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (String id in selectedIds) {
      try {
        await FirebaseFirestore.instance.collection('posts').doc(id).delete();
        // Sincronizacion automatica con Algolia
        AlgoliaService().deletePost(id);
      } catch (e) {
        debugPrint('Error deleting post $id: $e');
      }
    }

    exitSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicaciones eliminadas exitosamente')),
      );
    }
  }

  Future<void> _toggleVisibilitySelected(bool hide) async {
    for (String id in selectedIds) {
      try {
        await FirebaseFirestore.instance.collection('posts').doc(id).update({
          'status': hide ? 'hidden' : 'active',
        });
      } catch (e) {
        debugPrint('Error updating post visibility $id: $e');
      }
    }
    exitSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hide
                ? 'Publicaciones ocultadas'
                : 'Publicaciones ahora son visibles',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar publicaciones'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList(); // Copy to sort
        docs.sort((a, b) {
          final da = a.data()['createdAt'];
          final db = b.data()['createdAt'];
          if (da is Timestamp && db is Timestamp) {
            return db.compareTo(da);
          }
          return 0;
        });

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay publicaciones aún',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
            ),
          );
        }

        return Column(
          children: [
            if (isSelectionMode)
              Container(
                color: Colors.blue.shade50,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: exitSelection,
                    ),
                    Text(
                      '${selectedIds.length} seleccionados',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Editar publicación',
                      onPressed: () {
                        final String id = selectedIds.first;
                        final postDoc = docs.firstWhere((doc) => doc.id == id);

                        showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'Editar publicación',
                          barrierColor: Colors.black.withOpacity(0.6),
                          transitionDuration: const Duration(milliseconds: 450),
                          pageBuilder: (context, anim1, anim2) =>
                              const SizedBox.shrink(),
                          transitionBuilder:
                              (context, animation, secondary, child) {
                                final curve = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.elasticOut,
                                );
                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 80),
                                    child: ScaleTransition(
                                      scale: curve,
                                      child: PublicationPanel(
                                        postId: id,
                                        initialData: postDoc.data(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                        ).then((_) => exitSelection());
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.visibility),
                      tooltip: 'Visibilidad',
                      onSelected: (val) =>
                          _toggleVisibilitySelected(val == 'hide'),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'hide',
                          child: Text('Ocultar seleccionadas'),
                        ),
                        const PopupMenuItem(
                          value: 'show',
                          child: Text('Mostrar seleccionadas'),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar seleccionadas',
                      onPressed: selectedIds.isNotEmpty
                          ? _deleteSelected
                          : null,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                cacheExtent: 3000,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.68,
                ),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data();

                  final String title =
                      (data['title'] ??
                              data['name'] ??
                              data['nombre'] ??
                              data['titulo'] ??
                              '')
                          .toString();
                  final String price =
                      (data['price'] ?? data['precio'] ?? data['amount'] ?? '')
                          .toString();
                  final String location =
                      (data['location'] ??
                              data['ubicacion'] ??
                              data['ubicación'] ??
                              data['city'] ??
                              data['ciudad'] ??
                              data['address'] ??
                              '')
                          .toString();
                  String? image =
                      (data['imageUrl'] ??
                              data['image'] ??
                              data['coverUrl'] ??
                              data['portada'] ??
                              data['foto'] ??
                              data['thumbnail'])
                          ?.toString();

                  if (image == null || image.isEmpty) {
                    final images = data['images'];
                    if (images is List && images.isNotEmpty) {
                      final first = images.first;
                      if (first is String) image = first;
                    }
                  }

                  final bool isSelected = selectedIds.contains(docs[i].id);
                  final bool isHidden = data['status'] == 'hidden';

                  return GestureDetector(
                    onLongPress: widget.isOwnProfile
                        ? () {
                            if (!isSelectionMode) {
                              setState(() {
                                isSelectionMode = true;
                                selectedIds.add(docs[i].id);
                              });
                            }
                          }
                        : null,
                    onTap: isSelectionMode
                        ? () => toggleSelection(docs[i].id)
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.identity()
                        ..scale(isSelected ? 0.95 : 1.0),
                      transformAlignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF0094FF),
                                width: 3,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          AbsorbPointer(
                            absorbing: isSelectionMode,
                            child: Opacity(
                              opacity: isHidden && !isSelected ? 0.5 : 1.0,
                              child: PostCard(
                                imageUrl: image,
                                title: title,
                                price: price,
                                location: location,
                                postId: docs[i].id,
                                userId:
                                    data['userId'] ??
                                    data['uid'] ??
                                    widget.userId,
                                data: data,
                              ),
                            ),
                          ),
                          if (isHidden && !isSelectionMode)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(4),
                                  ),
                                ),
                                child: const Text(
                                  'Oculto',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (isSelectionMode)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isSelected ? 1.0 : 0.6,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0094FF)
                                        : Colors.black38,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      if (isSelected)
                                        BoxShadow(
                                          color: const Color(
                                            0xFF0094FF,
                                          ).withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.check,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String? userId;
  const _InfoSection({this.userId});

  String _maskData(String? data, {int visibleCount = 5}) {
    if (data == null || data.isEmpty) return 'No verificado';
    if (data.length <= visibleCount) return data;
    return '${data.substring(0, visibleCount)}...';
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() ?? {};
        final isVerified = data['isVerified'] ?? false;

        final String name = data['displayName'] ?? 'Cargando...';
        final String email = data['email'] ?? '';
        final String dob = data['dob'] ?? data['birthday'] ?? '';
        final String website = data['website'] ?? '';
        final String city = data['city'] ?? data['ciudad'] ?? '';
        final String specialties = data['specialties'] ?? '';
        final String experience = data['experience'] ?? '';
        final String education = data['education'] ?? '';
        final String signature = data['signature'] ?? '';
        final List<String> paymentMethods = List<String>.from(
          data['paymentMethods'] ?? [],
        );

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('verifications')
              .doc(userId)
              .get(),
          builder: (context, vSnap) {
            String cc = 'No verificado';
            if (vSnap.hasData && vSnap.data!.exists) {
              cc =
                  (vSnap.data!.data() as Map<String, dynamic>)['idNumber'] ??
                  'Verificado';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Información personal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Archivo',
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 6),

                  _buildDataRow(
                    context,
                    leftIcon: Icons.badge_outlined,
                    leftLabel: 'C.C. ${_maskData(cc)}',
                    leftVerified: isVerified,
                    rightIcon: Icons.phone_outlined,
                    rightLabel: _maskData(data['phone'] ?? data['whatsapp']),
                    rightVerified: isVerified,
                  ),
                  const SizedBox(height: 4),

                  _buildDataRow(
                    context,
                    leftIcon: Icons.mail_outline,
                    leftLabel: email,
                    rightIcon: Icons.calendar_today_outlined,
                    rightLabel: dob.isNotEmpty ? dob : 'No verificado',
                    rightVerified: isVerified,
                  ),
                  const SizedBox(height: 4),

                  _buildDataRow(
                    context,
                    leftIcon: Icons.language,
                    leftLabel: website,
                    rightIcon: Icons.location_on_outlined,
                    rightLabel: city,
                  ),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildSectionBlock(
                          context,
                          'Especialidades',
                          specialties,
                          Icons.star,
                          showVerMas: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSectionBlock(
                          context,
                          'Experiencia',
                          experience,
                          Icons.emoji_events,
                          showVerMas: true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildSectionBlock(
                          context,
                          'Educación',
                          education,
                          Icons.school,
                          showVerMas: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSectionBlock(
                          context,
                          'Métodos de pago',
                          paymentMethods.join('\n'),
                          Icons.attach_money,
                          showVerMas: true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  _buildSectionBlock(
                    context,
                    'Firma personal',
                    signature,
                    Icons.history_edu,
                    isSignature: true,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDataRow(
    BuildContext context, {
    required IconData leftIcon,
    required String leftLabel,
    bool leftVerified = false,
    required IconData rightIcon,
    required String rightLabel,
    bool rightVerified = false,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 10,
          child: Row(
            children: [
              Icon(leftIcon, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        leftLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (leftVerified) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.verified, size: 10, color: Colors.black),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 2), // Espacio mínimo entre columnas
        Expanded(
          flex: 11, // Un poco más de peso a la derecha para desplazarla
          child: Row(
            children: [
              const SizedBox(
                width: 8,
              ), // El desplazamiento hacia la derecha solicitado
              Icon(rightIcon, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        rightLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (rightVerified) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.verified, size: 10, color: Colors.black),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionBlock(
    BuildContext context,
    String title,
    String content,
    IconData icon, {
    bool showVerMas = false,
    bool isSignature = false,
  }) {
    if (content.isEmpty) return const SizedBox();

    List<String> originalLines = content
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    List<String> lines = List.from(originalLines);
    bool isLong = false;
    int limit = isSignature ? 3 : 5;

    if (lines.length > limit) {
      isLong = true;
      lines = lines.take(limit).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13, // Aumento sutil solicitado
                fontWeight: FontWeight.w700,
                fontFamily: 'Archivo',
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.asMap().entries.map((entry) {
            int idx = entry.key;
            String line = entry.value;
            bool isLastLine = idx == lines.length - 1;

            return Padding(
              padding: const EdgeInsets.only(bottom: 0.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: isLong && isLastLine
                          ? () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    title,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: originalLines
                                          .map(
                                            (l) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4.0,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    '• ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      l.trim(),
                                                      style: const TextStyle(
                                                        fontFamily: 'Poppins',
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          : null,
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'Poppins',
                            height: 1.1,
                            color: Colors.black,
                          ),
                          children: [
                            TextSpan(text: line.trim()),
                            if (isLong && isLastLine)
                              const TextSpan(
                                text: '...',
                                style: TextStyle(
                                  color: Color(0xFF0094FF),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
