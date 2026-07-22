import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/music_selector_field.dart';

class PublishVehiclePanel extends StatefulWidget {
  final String? postId;
  final Map<String, dynamic>? initialData;

  const PublishVehiclePanel({super.key, this.postId, this.initialData});

  @override
  State<PublishVehiclePanel> createState() => _PublishVehiclePanelState();
}

class _PublishVehiclePanelState extends State<PublishVehiclePanel> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _kmController = TextEditingController();
  final _fuelController = TextEditingController();
  final _colorController = TextEditingController();
  final _traccionController = TextEditingController();
  final _capacidadController = TextEditingController();
  final _motorController = TextEditingController();
  final _transmisionController = TextEditingController();
  final _soatController = TextEditingController();

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

  String _selectedImpuestos = 'Pagos';
  bool _barterMode = false;
  String _selectedLocation = 'Bogotá';

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _titleController.text = (data['title'] ?? '').toString();
      _priceController.text = (data['price'] ?? '').toString();
      _descController.text = (data['description'] ?? '').toString();
      _brandController.text = (data['brand'] ?? '').toString();
      _modelController.text = (data['model'] ?? '').toString();
      _yearController.text = (data['year'] ?? '').toString();
      _kmController.text = (data['kilometraje'] ?? '').toString();
      _fuelController.text = (data['combustible'] ?? '').toString();
      _colorController.text = (data['color'] ?? '').toString();
      _traccionController.text = (data['traccion'] ?? '').toString();
      _capacidadController.text = (data['capacidad'] ?? '').toString();
      _motorController.text = (data['motor'] ?? '').toString();
      _transmisionController.text = (data['transmision'] ?? '').toString();
      _soatController.text = (data['soatHasta'] ?? '').toString();

      _selectedImpuestos = ['Pagos', 'Pendientes'].contains(data['impuestos'])
          ? data['impuestos']
          : 'Pagos';
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
    if (_titleController.text.isEmpty || _descController.text.length < 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa el título y la descripción (mín. 40 caract.)'),
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

      final priceValue =
          double.tryParse(
            _priceController.text.replaceAll('.', '').replaceAll('\$', ''),
          ) ??
          0.0;

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
        'brand': _brandController.text,
        'model': _modelController.text,
        'year': _yearController.text,
        'kilometraje': _kmController.text,
        'combustible': _fuelController.text,
        'color': _colorController.text,
        'traccion': _traccionController.text,
        'capacidad': _capacidadController.text,
        'motor': _motorController.text,
        'transmision': _transmisionController.text,
        'soatHasta': _soatController.text,
        'impuestos': _selectedImpuestos,
        'barterMode': _barterMode,
        'location': _selectedLocation,
        'latitude': coords?['latitude'] ?? LocationService().selectedLat,
        'longitude': coords?['longitude'] ?? LocationService().selectedLng,
        'type': 'vehicle',
        'category': 'vehículos',
        'subCategory': _brandController.text.toLowerCase(),
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
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                      ? 'Actualizar Vehículo'
                      : 'Publicar Vehículo',
                  style: const TextStyle(
                    fontFamily: 'ArchivoBlack',
                    fontSize: 18,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 15),
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
                            style: const TextStyle(
                              color: Colors.grey,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 15),
            _buildLabel('Título'),
            TextField(
              controller: _titleController,
              maxLength: 40,
              decoration: _inputDecoration('Ej: Toyota Prado TXL'),
            ),
            _buildLabel('Precio'),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Ej: 250000000'),
            ),
            _buildLabel('Descripción (mín. 40 caract.)'),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: _inputDecoration('Detalla el estado del vehículo...'),
            ),
            _buildLabel('Marca'),
            TextField(
              controller: _brandController,
              decoration: _inputDecoration('Ej: BMW, Audi, Toyota...'),
            ),
            _buildLabel('Modelo'),
            TextField(
              controller: _modelController,
              decoration: _inputDecoration('Ej: Corolla, Hilux, Prado...'),
            ),
            _buildLabel('Año'),
            TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Ej: 2024'),
            ),
            _buildLabel('Kilometraje'),
            TextField(
              controller: _kmController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Kilómetros recorridos'),
            ),
            _buildLabel('Combustible'),
            TextField(
              controller: _fuelController,
              decoration: _inputDecoration('Gasolina, Diesel, Híbrido...'),
            ),
            _buildLabel('Color'),
            TextField(
              controller: _colorController,
              decoration: _inputDecoration('Ej: Blanco, Gris perlado...'),
            ),
            _buildLabel('Tracción'),
            TextField(
              controller: _traccionController,
              decoration: _inputDecoration('Ej: 4x4, 4x2, 4WD...'),
            ),
            _buildLabel('Capacidad'),
            TextField(
              controller: _capacidadController,
              decoration: _inputDecoration('Ej: 2, 5, 7 pasajeros...'),
            ),
            _buildLabel('Motor'),
            TextField(
              controller: _motorController,
              decoration: _inputDecoration('Ej: 2.0, 3.0...'),
            ),
            _buildLabel('Transmisión'),
            TextField(
              controller: _transmisionController,
              decoration: _inputDecoration('Automática, Manual...'),
            ),
            _buildLabel('SOAT vigente hasta'),
            TextField(
              controller: _soatController,
              decoration: _inputDecoration('Fecha de vencimiento'),
            ),
            _buildLabel('Impuestos'),
            _buildDropdown(
              value: _selectedImpuestos,
              items: ['Pagos', 'Pendientes'],
              onChanged: (v) => setState(() => _selectedImpuestos = v!),
            ),
            const SizedBox(height: 15),
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
            _buildLabel('Ubicación de la publicación'),
            _buildDropdown(
              value: _selectedLocation,
              items: _cities,
              onChanged: (v) => setState(() => _selectedLocation = v!),
            ),

            const SizedBox(height: 25),

            // MUSIC SELECTOR
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
                            ? 'Actualizar Vehículo'
                            : 'Publicar Vehículo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Poppins',
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

  Widget _buildLabel(String text) => Padding(
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

  InputDecoration _inputDecoration(String hint) => InputDecoration(
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

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
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
              child: Text(
                e,
                style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              ),
            ),
          )
          .toList(),
    ),
  );
}
