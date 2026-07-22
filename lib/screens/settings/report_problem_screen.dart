import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../widgets/connect_app_bar.dart';
import '../../widgets/dynamic_island_notification.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSending = false;

  Future<void> _pickImage() async {
    if (_images.length >= 5) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _images.add(File(image.path));
      });
    }
  }

  Future<void> _sendReport() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      DynamicIslandNotification.show(
        title: 'ERROR',
        message: 'Por favor describe el problema.',
        icon: Icons.error_outline,
        color: Colors.red,
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final List<String> imageUrls = [];

      for (var file in _images) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('reports')
            .child('${user?.uid}_${DateTime.now().millisecondsSinceEpoch}_${_images.indexOf(file)}.jpg');
        await ref.putFile(file);
        imageUrls.add(await ref.getDownloadURL());
      }

      await FirebaseFirestore.instance.collection('reports').add({
        'userId': user?.uid,
        'userEmail': user?.email,
        'description': text,
        'images': imageUrls,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        DynamicIslandNotification.show(
          title: 'REPORTADO',
          message: 'Tu reporte ha sido enviado con éxito.',
          icon: Icons.check_circle_outline,
          color: Colors.green,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      DynamicIslandNotification.show(
        title: 'ERROR',
        message: 'No se pudo enviar el reporte.',
        icon: Icons.error_outline,
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const ConnectAppBar(
        title: 'REPORTAR UN PROBLEMA',
        showSearch: false,
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DESCRIPCIÓN DEL PROBLEMA',
              style: TextStyle(fontFamily: 'ArchivoBlack', fontSize: 12, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Describe lo que sucedió...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'EVIDENCIAS VISUALES (MÁX. 5)',
              style: TextStyle(fontFamily: 'ArchivoBlack', fontSize: 12, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ..._images.map((file) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.remove(file)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                )),
                if (_images.length < 5)
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 48),
            _isSending
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : ElevatedButton(
                    onPressed: _sendReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 10,
                    ),
                    child: const Text(
                      'ENVIAR REPORTE',
                      style: TextStyle(color: Colors.white, fontFamily: 'ArchivoBlack', letterSpacing: 2),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
