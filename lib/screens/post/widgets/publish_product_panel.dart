import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/music_selector_field.dart';

class PublishProductPanel extends StatefulWidget {
  final String? postId;
  final Map<String, dynamic>? initialData;

  const PublishProductPanel({super.key, this.postId, this.initialData});

  @override
  State<PublishProductPanel> createState() => _PublishProductPanelState();
}

class _PublishProductPanelState extends State<PublishProductPanel> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  final List<File> _images = [];
  final List<String> _existingImages = [];
  bool _isUploading = false;

  // Estado de música
  String? _musicId;
  String? _musicTitle;
  String? _musicArtist;
  String? _musicThumbnail;
  int _musicStartSeconds = 0;
  int _musicDuration = 30;

  // Form selections
  String _selectedCategory = 'Productos';
  String _selectedState = 'Nuevo';
  int _selectedWarranty = 0; // 0-24 months
  bool _barterMode = false;
  String _selectedLocation = 'Bogotá';

  // Shipping methods
  final List<String> _shippingMethods = [
    'Domicilio',
    'Envío nacional',
    'Contraentrega',
    'Recoger en punto físico',
  ];
  final Set<String> _selectedShipping = {};

  final List<String> _categories = [
    'Productos',
    'Tecnología',
    'Hogar',
    'Moda',
    'Deporte',
    'Juguetes',
    'Libros',
    'Otros',
  ];

  final List<String> _states = ['Nuevo', 'Como nuevo', 'Usado', 'Restaurado'];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _titleController.text = (data['title'] ?? data['name'] ?? '').toString();
      _priceController.text = (data['price'] ?? '').toString();
      _descController.text = (data['description'] ?? data['descripcion'] ?? '')
          .toString();
      _selectedCategory =
          _categories.contains(data['subCategory']?.toString().capitalize())
          ? data['subCategory'].toString().capitalize()
          : _categories.first;
      _selectedState = _states.contains(data['state'])
          ? data['state']
          : _states.first;
      _selectedWarranty = (data['warrantyMonths'] as num?)?.toInt() ?? 0;
      _barterMode = data['barterMode'] ?? false;
      _selectedLocation = _cities.contains(data['location'])
          ? data['location']
          : _cities.first;

      if (data['images'] is List) {
        _existingImages.addAll(List<String>.from(data['images']));
      } else if (data['imageUrl'] != null &&
          data['imageUrl'].toString().isNotEmpty) {
        _existingImages.add(data['imageUrl']);
      }

      if (data['shippingMethods'] is List) {
        _selectedShipping.addAll(List<String>.from(data['shippingMethods']));
      }

      _musicId = data['musicId']?.toString();
      _musicTitle = data['musicTitle']?.toString();
      _musicArtist = data['musicArtist']?.toString();
      _musicThumbnail = data['musicThumbnail']?.toString();
      _musicStartSeconds = (data['musicStartSeconds'] as num?)?.toInt() ?? 0;
    }
  }

  final List<String> _cities = [
    'Bogotá',
    'Medellín',
    'Cali',
    'Barranquilla',
    'Cartagena',
    'Bucaramanga',
    'Pereira',
    'Manizales',
    'Cúcuta',
    'Ibagué',
    'Santa Marta',
    'Villavicencio',
    'Pasto',
    'Armenia',
    'Montería',
    'Popayán',
    'Sincelejo',
    'Valledupar',
    'Quibdó',
    'Tunja',
  ];

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 70);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _images.addAll(
          pickedFiles.take(20 - _images.length).map((f) => File(f.path)),
        );
      });
    }
  }

  Future<void> _publish() async {
    if (_images.isEmpty && _existingImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Al menos una foto es obligatoria')),
      );
      return;
    }
    if (_titleController.text.length > 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El título no puede superar los 40 caracteres'),
        ),
      );
      return;
    }
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El título es obligatorio')));
      return;
    }
    if (_descController.text.length < 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La descripción debe tener al menos 40 caracteres'),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final List<String> imageUrls = [..._existingImages];
      for (var i = 0; i < _images.length; i++) {
        final file = _images[i];
        final filename = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('post_images')
            .child(filename);

        await storageRef.putFile(file);
        final url = await storageRef.getDownloadURL();
        imageUrls.add(url);
      }

      final priceText = _priceController.text;
      final rawPrice = priceText
          .replaceAll('.', '')
          .replaceAll('\$', '')
          .trim();
      final priceValue = double.tryParse(rawPrice) ?? 0.0;

      final coords = await LocationService().getCoordinatesFromAddress(
        _selectedLocation,
      );

      final Map<String, dynamic> postData = {
        'userId': user.uid,
        'title': _titleController.text,
        'description': _descController.text,
        'images': imageUrls,
        'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '',
        'price': priceValue,
        'category': 'productos',
        'subCategory': _selectedCategory.toLowerCase(),
        'state': _selectedState,
        'shippingMethods': _selectedShipping.toList(),
        'warrantyMonths': _selectedWarranty,
        'barterMode': _barterMode,
        'location': _selectedLocation,
        'latitude': coords?['latitude'] ?? LocationService().selectedLat,
        'longitude': coords?['longitude'] ?? LocationService().selectedLng,
        'type': 'product',
        'musicId': _musicId,
        'musicTitle': _musicTitle,
        'musicArtist': _musicArtist,
        'musicThumbnail': _musicThumbnail,
        'musicStartSeconds': _musicStartSeconds,
        'musicDuration': _musicDuration,
      };

      String createdId = widget.postId ?? '';
      if (widget.postId != null) {
        await FirestoreService().updatePost(widget.postId!, postData);
      } else {
        createdId = await FirestoreService().createPost(postData);
      }

      if (mounted) {
        Navigator.pop(context, {
          'success': true,
          'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : null,
          'postId': createdId,
        });
      }
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
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.postId != null
                      ? 'Actualizar Producto'
                      : 'Publicar Producto',
                  style: const TextStyle(
                    fontFamily: 'ArchivoBlack',
                    fontSize: 18,
                    letterSpacing: -0.5,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 1. PHOTOS
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: (_images.isNotEmpty || _existingImages.isNotEmpty)
                    ? ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(8),
                        itemCount:
                            _images.length +
                            _existingImages.length +
                            (_images.length + _existingImages.length < 20
                                ? 1
                                : 0),
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          if (i == _images.length + _existingImages.length) {
                            return GestureDetector(
                              onTap: _pickImages,
                              child: Container(
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add_a_photo,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }

                          if (i < _existingImages.length) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _existingImages[i],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _existingImages.removeAt(i),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          final localIndex = i - _existingImages.length;
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _images[localIndex],
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _images.removeAt(localIndex),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_a_photo_outlined,
                            color: Colors.grey,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fotos (Máx 20) - ${_images.length + _existingImages.length}/20',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 15),

            // 2. TITLE
            _buildLabel('Título'),
            TextField(
              controller: _titleController,
              maxLength: 40,
              decoration: _inputDecoration('Ej: iPhone 15 Pro Max'),
            ),
            const SizedBox(height: 10),

            // 3. PRICE
            _buildLabel('Precio'),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Ej: 2500000'),
            ),
            const SizedBox(height: 15),

            // 4. DESCRIPTION
            _buildLabel('Descripción (mínimo 40 caracteres)'),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: _inputDecoration(
                'Detalla el estado y características del producto...',
              ),
            ),
            const SizedBox(height: 15),

            // 5. CATEGORY
            _buildLabel('Categoría'),
            _buildDropdown(
              value: _selectedCategory,
              items: _categories,
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 15),

            // 6. STATE
            _buildLabel('Estado del producto'),
            _buildDropdown(
              value: _selectedState,
              items: _states,
              onChanged: (v) => setState(() => _selectedState = v!),
            ),
            const SizedBox(height: 15),

            // 7. SHIPPING
            _buildLabel('Métodos de envío'),
            Wrap(
              spacing: 8,
              children: _shippingMethods.map((m) {
                final selected = _selectedShipping.contains(m);
                return FilterChip(
                  label: Text(
                    m,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: selected,
                  selectedColor: const Color(0xFF0094FF),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedShipping.add(m);
                      } else {
                        _selectedShipping.remove(m);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 15),

            // 8. WARRANTY
            _buildLabel(
              'Garantía: $_selectedWarranty ${_selectedWarranty == 1 ? "mes" : "meses"}',
            ),
            Slider(
              value: _selectedWarranty.toDouble(),
              min: 0,
              max: 24,
              divisions: 24,
              label:
                  '$_selectedWarranty ${_selectedWarranty == 1 ? "mes" : "meses"}',
              activeColor: const Color(0xFF0094FF),
              onChanged: (v) => setState(() => _selectedWarranty = v.toInt()),
            ),
            const SizedBox(height: 10),

            // 9. BARTER MODE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('¿Acepta Trueque?'),
                Switch(
                  value: _barterMode,
                  activeThumbColor: const Color(0xFF0094FF),
                  onChanged: (v) => setState(() => _barterMode = v),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 10. LOCATION
            _buildLabel('Ubicación (Colombia)'),
            _buildDropdown(
              value: _selectedLocation,
              items: _cities,
              onChanged: (v) => setState(() => _selectedLocation = v!),
            ),

            // 11. MUSIC SELECTOR
            MusicSelectorField(
              musicId: _musicId,
              musicTitle: _musicTitle,
              musicArtist: _musicArtist,
              musicThumbnail: _musicThumbnail,
              musicStartSeconds: _musicStartSeconds,
              musicDuration: _musicDuration,
              onMusicSelected: (id, title, artist, thumb, startSec, duration) {
                setState(() {
                  _musicId = id;
                  _musicTitle = title;
                  _musicArtist = artist;
                  _musicThumbnail = thumb;
                  _musicStartSeconds = startSec;
                  _musicDuration = duration;});
              },
            ),

            // PUBLISH BUTTON
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
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.postId != null
                            ? 'Actualizar Producto'
                            : 'Publicar Producto',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.grey,
        fontSize: 13,
        fontFamily: 'Poppins',
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0094FF), width: 1.5),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        onChanged: onChanged,
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(fontSize: 14)),
              ),
            )
            .toList(),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
