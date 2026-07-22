import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore_service.dart';
import '../../../services/location_service.dart'; // Added for LocationService

class PublishWantPanel extends StatefulWidget {
  final String? initialCategory;
  final String? wantId;
  final Map<String, dynamic>? initialData;

  const PublishWantPanel({
    super.key,
    this.initialCategory,
    this.wantId,
    this.initialData,
  });

  @override
  State<PublishWantPanel> createState() => _PublishWantPanelState();
}

class _PublishWantPanelState extends State<PublishWantPanel> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _hashtagsController = TextEditingController();
  final _locationController = TextEditingController(text: 'Medellín');

  File? _image;
  String? _existingImageUrl;
  bool _isUploading = false;
  late String _selectedCategory;

  final List<String> _categories = [
    'Productos',
    'Servicios',
    'Empleos',
    'Vehículos',
    'Inmuebles',
    'Mascotas',
    'Trueques',
    'Alquiler',
    'Eventos',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory == 'Para ti'
        ? 'Productos'
        : widget.initialCategory ?? _categories.first;

    if (widget.initialData != null) {
      final data = widget.initialData!;
      _titleController.text = (data['title'] ?? '').toString();
      _descController.text = (data['description'] ?? '').toString();
      _priceController.text = (data['willingToPay'] ?? '').toString();
      _locationController.text = (data['location'] ?? '').toString();

      final tags = data['hashtags'];
      if (tags is List) {
        _hashtagsController.text = tags.join(', ');
      }

      if (data['category'] != null) {
        String cat = data['category'].toString().toLowerCase();
        if (cat.isNotEmpty) {
          cat = cat[0].toUpperCase() + cat.substring(1);
        }
        _selectedCategory = _categories.contains(cat) ? cat : _selectedCategory;
      }
      _existingImageUrl = data['imageUrl'];
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _publish() async {
    if (_image == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('La foto es obligatoria')));
      return;
    }
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El título es obligatorio')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // 1. Upload image to Storage
      String imageUrl = _existingImageUrl ?? '';
      if (_image != null) {
        final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('want_images')
            .child(filename);

        await storageRef.putFile(_image!);
        imageUrl = await storageRef.getDownloadURL();
      }

      // 2. Save to Firestore
      final rawPrice = _priceController.text
          .replaceAll('.', '')
          .replaceAll('\$', '')
          .trim();
      final priceValue = double.tryParse(rawPrice) ?? 0.0;

      final tags = _hashtagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // Placeholder for coords, assuming it comes from a location picker or service
      // For now, it will use default values from LocationService if not provided.
      final Map<String, dynamic>? coords =
          null; // Replace with actual coords if available

      final Map<String, dynamic> wantData = {
        'userId': user.uid,
        'title': _titleController.text,
        'description': _descController.text,
        'imageUrl': imageUrl,
        'willingToPay': priceValue,
        'location': _locationController.text,
        'hashtags': tags,
        'category': _selectedCategory.toLowerCase(),
        'latitude': coords?['latitude'] ?? LocationService().selectedLat,
        'longitude': coords?['longitude'] ?? LocationService().selectedLng,
      };

      if (widget.wantId != null) {
        await FirestoreService().updateWant(widget.wantId!, wantData);
      } else {
        await FirestoreService().createWant(wantData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al publicar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.wantId != null
                      ? 'Actualizar Necesidad'
                      : 'Publicar lo que buscas',
                  style: const TextStyle(
                    fontFamily: 'ArchivoBlack',
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: (_image != null || _existingImageUrl != null)
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _image != null
                                ? Image.file(
                                    _image!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    _existingImageUrl!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _image = null;
                                _existingImageUrl = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo, color: Colors.grey, size: 40),
                          SizedBox(height: 8),
                          Text(
                            'Añadir foto (Obligatorio)',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 15),
            _buildTextField(
              _titleController,
              '¿Qué buscas?',
              'Ej: Pluma MontBlanc',
            ),
            const SizedBox(height: 10),
            _buildTextField(
              _priceController,
              'Dispuesto a pagar',
              'Ej: 1500000',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              _descController,
              'Descripción',
              'Detalla lo que necesitas...',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              _hashtagsController,
              'Hashtags',
              'Ej: lujo, pluma, regalo (separados por coma)',
            ),
            const SizedBox(height: 10),
            _buildTextField(_locationController, 'Ubicación', 'Ej: Medellín'),
            const SizedBox(height: 15),
            const Text(
              'Categoría',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              underline: const SizedBox(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0094FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.wantId != null ? 'Actualizar' : 'Publicar',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontFamily: 'CanvaSans', fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}
