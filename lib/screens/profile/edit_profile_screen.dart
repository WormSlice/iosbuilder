import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _tiktokController = TextEditingController();

  String _originalVerifiedName = '';

  String? _currentPhotoUrl;
  File? _imageFile;
  bool _isLoading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _originalVerifiedName =
            data['verifiedName'] ?? data['displayName'] ?? data['name'] ?? '';

        // If verifiedName doesn't exist yet, we initialize it
        if (data['verifiedName'] == null && _originalVerifiedName.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'verifiedName': _originalVerifiedName});
        }

        final currentName = data['displayName'] ?? data['name'] ?? '';

        bool isValid(String n, String original) {
          if (n.trim().isEmpty) return false;
          final origWords = original
              .toLowerCase()
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toList();
          final newWords = n
              .toLowerCase()
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toList();
          for (var word in newWords) {
            if (!origWords.contains(word)) return false;
          }
          return true;
        }

        _nameController.text = isValid(currentName, _originalVerifiedName)
            ? currentName
            : _originalVerifiedName;
        _currentPhotoUrl =
            data['photoURL'] ?? data['photoUrl'] ?? data['image'];

        _instagramController.text = data['instagram'] ?? '';
        _facebookController.text = data['facebook'] ?? '';
        _whatsappController.text = data['whatsapp'] ?? '';
        _tiktokController.text = data['tiktok'] ?? '';
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  bool _isNameValid(String newName) {
    if (newName.trim().isEmpty) return false;

    final originalWords = _originalVerifiedName
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final newWords = newName
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    for (var word in newWords) {
      if (!originalWords.contains(word)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    if (!_isNameValid(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El nombre solo puede contener palabras de tu nombre original verificado.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? photoUrl = _currentPhotoUrl;

      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_photos')
            .child('${user.uid}.jpg');
        await ref.putFile(_imageFile!);
        photoUrl = await ref.getDownloadURL();
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'displayName': newName,
            'name': newName,
            'photoURL': photoUrl,
            'photoUrl': photoUrl,
            'instagram': _instagramController.text.trim(),
            'facebook': _facebookController.text.trim(),
            'whatsapp': _whatsappController.text.trim(),
            'tiktok': _tiktokController.text.trim(),
          });

      // Update Firebase Auth profile
      await user.updateDisplayName(newName);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Editar perfil',
          style: TextStyle(
            fontFamily: 'MontserratArabic',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: Color(0xFF0094FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Photo Selection
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0094FF),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _imageFile != null
                                ? Image.file(_imageFile!, fit: BoxFit.cover)
                                : (_currentPhotoUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: _currentPhotoUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                                color: Colors.grey[100],
                                              ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.grey,
                                              ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey,
                                        )),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0094FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Name Field
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre Completo',
                      hintText: 'Ej: Duvan Conde',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0094FF)),
                      ),
                    ),
                    style: const TextStyle(fontFamily: 'MontserratArabic'),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Nota: Solo puedes usar las palabras de tu nombre registrado originalmente.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'MontserratArabic',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.verified, color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Nombre Verificado:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _originalVerifiedName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Social Networks Section
                  _buildSectionTitle('Redes Sociales'),
                  const SizedBox(height: 12),
                  _buildSocialField(
                    controller: _instagramController,
                    label: 'Instagram',
                    hint: 'Usuario sin @',
                    prefix: '@',
                    icon: Icons.camera_alt_outlined,
                  ),
                  _buildSocialField(
                    controller: _facebookController,
                    label: 'Facebook',
                    hint: 'Link o usuario',
                    icon: Icons.facebook_outlined,
                  ),
                  _buildSocialField(
                    controller: _whatsappController,
                    label: 'WhatsApp',
                    hint: 'Número con código de país',
                    prefix: '+',
                    icon: Icons.chat_outlined,
                  ),
                  _buildSocialField(
                    controller: _tiktokController,
                    label: 'TikTok',
                    hint: 'Usuario sin @',
                    prefix: '@',
                    icon: Icons.music_note_outlined,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontFamily: 'MontserratArabic',
        ),
      ),
    );
  }

  Widget _buildSocialField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefix,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: const TextStyle(fontSize: 14, fontFamily: 'MontserratArabic'),
      ),
    );
  }

  Widget _buildLongField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    int maxLines = 5,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          alignLabelWithHint: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: const TextStyle(fontSize: 14, fontFamily: 'MontserratArabic'),
      ),
    );
  }
}
