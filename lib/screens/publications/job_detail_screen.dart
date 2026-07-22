import '../../widgets/music_player_pill.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../widgets/location_map.dart';
import '../chats/chat_room_screen.dart';
import 'package:connect/screens/profile/profile_screen.dart';
import '../../widgets/post_card.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/report_service.dart';
import '../../services/boost_service.dart';
import 'package:provider/provider.dart';
import '../../widgets/boost_button.dart';
import '../../services/algolia_service.dart';
import '../../services/user_activity_service.dart';
import '../../widgets/fullscreen_image_viewer.dart';
import '../../services/language_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String postId;

  const JobDetailScreen({
    super.key,
    required this.data,
    required this.postId,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _trackVisit();
  }

  void _trackVisit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    UserActivityService().trackVisit(widget.postId, widget.data);
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

  String _formatPrice(dynamic priceRaw) {
    if (priceRaw == null) return '\$ 0';
    double p = 0.0;
    if (priceRaw is int) p = priceRaw.toDouble();
    if (priceRaw is double) p = priceRaw;
    if (priceRaw is String) p = double.tryParse(priceRaw) ?? 0.0;
    if (p == 0) return '\$ 0';

    String s = p.toStringAsFixed(0);
    List<String> out = [];
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count != 0 && count % 3 == 0) out.add('.');
      out.add(s[i]);
      count++;
    }
    return '\$ ${out.reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    List<String> images = [];
    if (d['images'] is List && (d['images'] as List).isNotEmpty) {
      images = List<String>.from(d['images']);
    } else {
      String? main = d['imageUrl'] ?? d['image'];
      if (main != null && main.isNotEmpty) images.add(main);
    }

    final ownerId = d['userId'] ?? d['ownerId'] ?? d['uid'] ?? '';
    final locationText = _getString(
      d['location'],
      fallback: 'Ubicación desconocida',
    );

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid != null && ownerId == currentUid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
        slivers: [
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
                    final String title = d['title'] ?? 'Empleo';
                    SharePlus.instance.share(ShareParams(
                      text: '💼 $title\n📍 $locationText\n\nMira esta oferta de empleo en CONNECT \n\nhttps://connectapp.com.co/p/${widget.postId}'
                    ));
                  },
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF0094FF), size: 26),
                offset: const Offset(0, 40),
                onSelected: (value) async {
                  if (value == 'report') {
                    await ReportService.showReportDialog(
                      context,
                      postId: widget.postId,
                      postTitle: d['title'] ?? 'Empleo',
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'report',
                    child: Text('Reportar publicación', style: TextStyle(color: Colors.red, fontFamily: 'CanvaSans')),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 380,
                      width: double.infinity,
                      child: images.isNotEmpty
                          ? PageView.builder(
                              controller: _pageController,
                              itemCount: images.length,
                              onPageChanged: (index) => setState(() => _currentImageIndex = index),
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
                                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                    ),
                                  );
                              },
                            )
                          : Container(color: Colors.grey[300], child: const Icon(Icons.work_outline, size: 50, color: Colors.grey)),
                    ),
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
                                width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(shape: BoxShape.circle, color: _currentImageIndex == index ? Colors.white : Colors.white.withOpacity(0.5)),
                              );
                            }),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: StreamBuilder<bool>(
                        stream: FirestoreService().isFavoriteStream(currentUid ?? '', widget.postId),
                        builder: (context, snapshot) {
                          final isFav = snapshot.data ?? false;
                          return GestureDetector(
                            onTap: () {
                              if (currentUid == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inicia sesión para guardar favoritos')));
                                return;
                              }
                              FirestoreService().toggleFavorite(currentUid, widget.postId, widget.data);
                            },
                            child: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.white, size: 32, shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Text(_getString(d['title'], fallback: 'Empleo sin título'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'CanvaSans')),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(_formatPrice(d['price'] ?? d['salary']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0094FF), fontFamily: 'Arimo')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(locationText, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'CanvaSans', fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                if (ownerId.isNotEmpty && !isOwner)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: ElevatedButton(
                      onPressed: () => _showApplicationModal(context, d, ownerId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0094FF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        context.read<LanguageProvider>().translate('postularse').toUpperCase(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Descripción', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800], fontFamily: 'CanvaSans')),
                      const SizedBox(height: 4),
                      Text(_getString(d['description'], fallback: 'Sin descripción detallada.'), style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87, fontFamily: 'CanvaSans')),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, thickness: 1),
                if (ownerId.isNotEmpty) _buildOwnerInfo(ownerId),
                const SizedBox(height: 4),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Características', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800], fontFamily: 'CanvaSans')),
                ),
                const SizedBox(height: 8),

                _buildInfoBox(context, [
                  _buildInfoRow('Tipo de contrato', (d['contractTypes'] as List?)?.join(', ') ?? 'N/A'),
                  _buildInfoRow('Jornada laboral', (d['jornadas'] as List?)?.join(', ') ?? 'N/A'),
                  _buildInfoRow('Auxilio de transporte', (d['transportAux'] == true) ? 'Sí' : 'No'),
                  _buildInfoRow('Comisiones', (d['commissions'] == true) ? 'Sí' : 'No'),
                  _buildInfoRow('Estudios', _getString(d['studiesRequired'])),
                  _buildInfoRow('Experiencia', _getString(d['experienceRequired'])),
                  _buildInfoRow('Idiomas', _getString(d['languages'])),
                ]),
                const SizedBox(height: 8),

                _buildDetailChip('Área / Función', _getString(d['jobArea'])),
                _buildDetailChip('Ubicación laboral', _getString(d['workLocationDetail'])),

                const SizedBox(height: 8),

                if (d['jobRequirements'] != null && d['jobRequirements'].toString().isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Requisitos del Cargo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800], fontFamily: 'CanvaSans')),
                  ),
                  const SizedBox(height: 8),
                  _buildRequirementsBox(_getString(d['jobRequirements'])),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 12),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: LocationMap(data: d, locationText: locationText)),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Podría interesarte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800], fontFamily: 'CanvaSans')),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 165,
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: AlgoliaService().getRecommendations(category: d['category'] ?? 'empleos', currentPostId: widget.postId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            final docs = snapshot.data!;
                            if (docs.isEmpty) return const Text('No hay recomendaciones.');
                            return ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final data = docs[i];
                                return SizedBox(
                                  width: 115,
                                  child: PostCard(imageUrl: data['imageUrl'] ?? data['image'], title: data['title'] ?? '', price: data['price']?.toString() ?? '', location: data['location'] ?? '', postId: data['objectID'] ?? '', userId: data['userId'], data: data),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
          if (d['musicId'] != null && d['musicId'].toString().isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 9,
              left: 50,
              right: 80,
              child: Center(
                child: MusicPlayerPill(
                  musicId: d['musicId'].toString(),
                  musicTitle: d['musicTitle']?.toString() ?? 'Música',
                  musicArtist: d['musicArtist']?.toString() ?? 'Artista',
                  musicThumbnail: d['musicThumbnail']?.toString() ?? '',
                  startSeconds: d['musicStartSeconds'] is int 
                      ? d['musicStartSeconds'] 
                      : (int.tryParse(d['musicStartSeconds']?.toString() ?? '0') ?? 0),
                  duration: d['musicDuration'] is int
                      ? d['musicDuration']
                      : (int.tryParse(d['musicDuration']?.toString() ?? '30') ?? 30),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: isOwner ? SafeArea(child: BoostButton(postId: widget.postId, imageUrl: images.isNotEmpty ? images.first : '')) : null,
    );
  }

  Widget _buildDetailChip(String label, String value) {
    if (value == 'N/A' || value.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 40,
      decoration: BoxDecoration(color: const Color(0xFFE0E0E0).withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Center(child: Text(label.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'CanvaSans')))),
          Container(width: 1.5, height: 24, color: const Color(0xFF0094FF)),
          Expanded(child: Center(child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'CanvaSans')))),
        ],
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, List<Widget> rows) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0094FF), width: 1.5), borderRadius: BorderRadius.circular(16)),
      child: Column(children: rows),
    );
  }

  Widget _buildInfoRow(String key, String value) {
    if (value == 'N/A' || value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 6, child: Text(key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: 'CanvaSans'))),
          const SizedBox(width: 4),
          Expanded(flex: 4, child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87, fontFamily: 'CanvaSans'))),
        ],
      ),
    );
  }

  Widget _buildRequirementsBox(String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF0094FF), width: 1.5), borderRadius: BorderRadius.circular(16)),
      child: Text(content, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87, fontFamily: 'CanvaSans')),
    );
  }

  Widget _buildOwnerInfo(String ownerId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(ownerId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox();

        final photo = userData['photoURL'] ?? userData['photoUrl'] ?? userData['image'];
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: ownerId)));
                },
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0094FF), width: 1.0)),
                  child: CircleAvatar(radius: 20, backgroundColor: Colors.grey[200], backgroundImage: photo != null ? NetworkImage(photo) : null, child: photo == null ? const Icon(Icons.person, color: Colors.grey) : null),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Publicado por', style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'CanvaSans')),
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'CanvaSans')),
                  Text(joinedText, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'CanvaSans')),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: ownerId)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Ver perfil', style: TextStyle(color: Color(0xFF0094FF), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'CanvaSans')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  void _showApplicationModal(BuildContext context, Map<String, dynamic> jobData, String employerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JobApplicationSheet(jobId: widget.postId, jobData: jobData, employerId: employerId),
    );
  }
}

class _JobApplicationSheet extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;
  final String employerId;

  const _JobApplicationSheet({required this.jobId, required this.jobData, required this.employerId});

  @override
  State<_JobApplicationSheet> createState() => _JobApplicationSheetState();
}

class _JobApplicationSheetState extends State<_JobApplicationSheet> {
  bool _isLoading = false;
  String? _selectedResumeUrl;
  String? _selectedResumeName;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final lang = context.watch<LanguageProvider>();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text(lang.translate('postularse').toUpperCase(), style: const TextStyle(fontFamily: 'ArchivoBlack', fontSize: 18)),
          const SizedBox(height: 8),
          Text(widget.jobData['title'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              final profileResume = userData?['resumeUrl'];
              final profileResumeName = userData?['resumeName'] ?? 'Mi Hoja de Vida.pdf';

              return Column(
                children: [
                  if (profileResume != null)
                    _buildOption(
                      icon: Icons.account_circle_outlined,
                      title: 'Usar Hoja de Vida del perfil',
                      subtitle: profileResumeName,
                      isSelected: _selectedResumeUrl == profileResume,
                      onTap: () => setState(() {
                        _selectedResumeUrl = profileResume;
                        _selectedResumeName = profileResumeName;
                      }),
                    ),
                  const SizedBox(height: 12),
                  _buildOption(
                    icon: Icons.upload_file_outlined,
                    title: 'Subir nuevo PDF',
                    subtitle: _selectedResumeUrl != null && _selectedResumeUrl != profileResume ? _selectedResumeName! : 'Selecciona un archivo desde tu dispositivo',
                    isSelected: _selectedResumeUrl != null && _selectedResumeUrl != profileResume,
                    onTap: () => _pickAndUploadResume(uid!),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: (_selectedResumeUrl == null || _isLoading) ? null : _submitApplication,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('ENVIAR POSTULACIÓN', style: TextStyle(color: Colors.white, fontFamily: 'ArchivoBlack', fontSize: 14)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption({required IconData icon, required String title, required String subtitle, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0094FF).withOpacity(0.05) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0094FF) : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF0094FF) : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF0094FF) : Colors.black)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF0094FF), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadResume(String uid) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        File file = File(result.files.single.path!);
        String name = result.files.single.name;
        
        final ref = FirebaseStorage.instance.ref().child('applications_resumes').child('${uid}_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        
        setState(() {
          _selectedResumeUrl = url;
          _selectedResumeName = name;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _submitApplication() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    try {
      await FirebaseFirestore.instance.collection('applications').add({
        'jobId': widget.jobId,
        'jobTitle': widget.jobData['title'],
        'employerId': widget.employerId,
        'applicantId': user?.uid,
        'applicantName': user?.displayName,
        'applicantEmail': user?.email,
        'resumeUrl': _selectedResumeUrl,
        'resumeName': _selectedResumeName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending'
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Postulación enviada con éxito!')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
    }
  }
}
