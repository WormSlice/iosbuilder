import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../widgets/connect_app_bar.dart';
import 'face_capture_screen.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _idNumberController = TextEditingController();

  File? _frontId;
  File? _backId;
  File? _faceFront;
  File? _faceLeft;
  File? _faceRight;

  bool _isLoading = true;
  bool _isSuccess = false;
  String _currentStatus = 'none'; // none, pending, approved, rejected

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('verifications')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final status = data?['status'] ?? 'pending';
        
        if (status == 'approved') {
          final String firstName = data?['firstName'] ?? '';
          final String lastName = data?['lastName'] ?? '';
          if (firstName.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'name': firstName.trim(),
              'lastName': lastName.trim(),
              'isVerified': true,
            });
          }
        }

        setState(() {
          _currentStatus = status;
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentStatus = 'none';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(bool isFront) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isFront) {
          _frontId = File(image.path);
        } else {
          _backId = File(image.path);
        }
      });
    }
  }

  void _openFaceCapture() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceCaptureScreen(
          onCaptured: (front, left, right) {
            setState(() {
              _faceFront = front;
              _faceLeft = left;
              _faceRight = right;
            });
          },
        ),
      ),
    );
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_frontId == null || _backId == null || _faceFront == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todas las fotos requeridas.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado.');

      final uid = user.uid;

      // Upload ID Images
      final frontRef = FirebaseStorage.instance.ref().child(
        'verifications/$uid/front_id.jpg',
      );
      await frontRef.putFile(_frontId!);
      final frontUrl = await frontRef.getDownloadURL();

      final backRef = FirebaseStorage.instance.ref().child(
        'verifications/$uid/back_id.jpg',
      );
      await backRef.putFile(_backId!);
      final backUrl = await backRef.getDownloadURL();

      // Upload Face Images
      final faceFrontRef = FirebaseStorage.instance.ref().child(
        'verifications/$uid/face_front.jpg',
      );
      await faceFrontRef.putFile(_faceFront!);
      final faceFrontUrl = await faceFrontRef.getDownloadURL();

      final faceLeftRef = FirebaseStorage.instance.ref().child(
        'verifications/$uid/face_left.jpg',
      );
      await faceLeftRef.putFile(_faceLeft!);
      final faceLeftUrl = await faceLeftRef.getDownloadURL();

      final faceRightRef = FirebaseStorage.instance.ref().child(
        'verifications/$uid/face_right.jpg',
      );
      await faceRightRef.putFile(_faceRight!);
      final faceRightUrl = await faceRightRef.getDownloadURL();

      // Save to Firestore verifications collection
      await FirebaseFirestore.instance
          .collection('verifications')
          .doc(uid)
          .set({
            'uid': uid,
            'firstName': _nameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'dob': _dobController.text.trim(),
            'frontIdUrl': frontUrl,
            'backIdUrl': backUrl,
            'faceFrontUrl': faceFrontUrl,
            'faceLeftUrl': faceLeftUrl,
            'faceRightUrl': faceRightUrl,
            'idNumber': _idNumberController.text.trim(),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'email': user.email,
          });

      // Update user document with dob since verification takes the dob
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'dob': _dobController.text.trim(),
      }, SetOptions(merge: true));

      // Send confirmation email
      if (user.email != null) {
        await FirebaseFirestore.instance.collection('mail').add({
          'to': user.email,
          'message': {
            'subject': 'Recibimos tu solicitud de verificación en CONNECT 📩',
            'html':
                'Hola ${_nameController.text.trim()},<br><br>Hemos recibido tus documentos correctamente. Nuestro equipo los revisará en las próximas 24-48 horas hábiles.<br><br>Te notificaremos por este medio una vez tengamos una respuesta.<br><br>Saludos,<br>El equipo de CONNECT.',
          },
        });
      }

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _currentStatus = 'pending';
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hubo un error al enviar la solicitud: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ConnectAppBar(
        showSearch: false,
        showSettings: false,
        showBack: true,
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _isSuccess || _currentStatus == 'pending'
          ? _buildPendingView()
          : _currentStatus == 'approved'
          ? _buildVerifiedSuccessView()
          : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const Icon(Icons.verified_user, size: 60, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Solicitud de Verificación',
              style: TextStyle(
                fontFamily: 'Archivo',
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para obtener tu insignia de perfil verificado, necesitamos validar tu identidad oficial. Tus datos están asegurados.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nombres',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Apellidos',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                DateTime? pickedDate = await showModalBottomSheet<DateTime>(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) {
                    DateTime tempDate = DateTime(2000);
                    return Container(
                      height: 300,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, tempDate),
                                child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                CupertinoDatePicker(
                                  mode: CupertinoDatePickerMode.date,
                                  initialDateTime: DateTime(2000),
                                  maximumDate: DateTime.now(),
                                  onDateTimeChanged: (date) {
                                    tempDate = date;
                                  },
                                ),
                                // Transparency masks
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withOpacity(0.9),
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(0.9),
                                          ],
                                          stops: const [0.0, 0.15, 0.85, 1.0],
                                        ),
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
                if (pickedDate != null) {
                  setState(() {
                    _dobController.text = "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}";
                  });
                }
              },
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _dobController,
                  decoration: InputDecoration(
                    labelText: 'Fecha de Nacimiento',
                    hintText: 'Selecciona tu fecha',
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _idNumberController,
              decoration: InputDecoration(
                labelText: 'Número de Documento (C.C.)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildIdPicker(
                    'ID Frontal',
                    _frontId,
                    () => _pickImage(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildIdPicker(
                    'ID Trasero',
                    _backId,
                    () => _pickImage(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Fotos de Rostro',
              style: TextStyle(
                fontFamily: 'Archivo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Necesitamos 3 fotos: Frente, Izquierda y Derecha. Pulsa el botón para iniciar la captura automática.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _openFaceCapture,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _faceFront != null
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: _faceFront != null
                      ? Border.all(color: Colors.blue)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _faceFront != null
                          ? Icons.face_retouching_natural
                          : Icons.camera_front,
                      color: _faceFront != null ? Colors.blue : Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _faceFront != null
                          ? 'FOTOS CAPTURADAS'
                          : 'INICIAR CAPTURA DE ROSTRO',
                      style: TextStyle(
                        color: _faceFront != null ? Colors.blue : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_faceFront != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMiniAvatar('Frente', _faceFront!),
                  _buildMiniAvatar('Izq', _faceLeft!),
                  _buildMiniAvatar('Der', _faceRight!),
                ],
              ),
            ],
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'ENVIAR VERIFICACIÓN',
                  style: TextStyle(
                    fontFamily: 'Archivo',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildIdPicker(String label, File? image, VoidCallback onTap) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              image: image != null
                  ? DecorationImage(image: FileImage(image), fit: BoxFit.cover)
                  : null,
            ),
            child: image == null
                ? const Icon(Icons.add_a_photo, color: Colors.grey)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniAvatar(String label, File image) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundImage: FileImage(image),
          backgroundColor: Colors.grey[300],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.black),
          SizedBox(height: 16),
          Text('Procesando...'),
        ],
      ),
    );
  }

  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'Verificación en curso',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tus datos han sido enviados correctamente. Nuestro equipo los revisará en breve. Te notificaremos por correo electrónico.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'ENTENDIDO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              '¡Todo Bien por aquí!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Eres un usuario verificado y eres una persona confiable en nuestra plataforma.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'GENIAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
