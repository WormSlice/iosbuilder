import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FaceCaptureScreen extends StatefulWidget {
  final Function(File front, File left, File right) onCaptured;

  const FaceCaptureScreen({super.key, required this.onCaptured});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _frontImage;
  File? _leftImage;
  File? _rightImage;

  int _step = 0; // 0: Front, 1: Left, 2: Right

  String get _currentTitle {
    switch (_step) {
      case 0:
        return 'Paso 1: Foto Frontal';
      case 1:
        return 'Paso 2: Rostro Perfil Izquierdo';
      case 2:
        return 'Paso 3: Rostro Perfil Derecho';
      default:
        return 'Completado';
    }
  }

  String get _instruction {
    switch (_step) {
      case 0:
        return 'Toma una foto mirando directamente a la cámara frontal con buena iluminación.';
      case 1:
        return 'Gira tu cabeza ligeramente hacia la izquierda y toma la foto.';
      case 2:
        return 'Gira tu cabeza ligeramente hacia la derecha y toma la foto final.';
      default:
        return 'Verificación facial lista para enviar.';
    }
  }

  File? get _currentImage {
    switch (_step) {
      case 0:
        return _frontImage;
      case 1:
        return _leftImage;
      case 2:
        return _rightImage;
      default:
        return null;
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (photo == null) return;

      setState(() {
        if (_step == 0) {
          _frontImage = File(photo.path);
        } else if (_step == 1) {
          _leftImage = File(photo.path);
        } else if (_step == 2) {
          _rightImage = File(photo.path);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al acceder a la cámara: $e')),
      );
    }
  }

  void _nextStep() {
    if (_currentImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor toma la foto antes de continuar.')),
      );
      return;
    }

    if (_step < 2) {
      setState(() => _step++);
    } else {
      if (_frontImage != null && _leftImage != null && _rightImage != null) {
        widget.onCaptured(_frontImage!, _leftImage!, _rightImage!);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'VERIFICACIÓN FACIAL',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stepIndicator(0, 'Frontal', _frontImage != null),
                  _stepDivider(),
                  _stepIndicator(1, 'Izquierda', _leftImage != null),
                  _stepDivider(),
                  _stepIndicator(2, 'Derecha', _rightImage != null),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                _currentTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _instruction,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Preview or Camera Placeholder
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _currentImage != null ? Colors.green : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _currentImage != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    _currentImage!,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.refresh, color: Colors.white, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            'Repetir',
                                            style: TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Toca aquí para abrir la cámara',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Usa la cámara frontal',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _step--),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Anterior',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _currentImage == null ? _capturePhoto : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentImage == null
                            ? 'TOMAR FOTO'
                            : (_step == 2 ? 'FINALIZAR' : 'CONTINUAR'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepIndicator(int step, String label, bool isDone) {
    final isCurrent = _step == step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone
                ? Colors.green
                : (isCurrent ? Colors.white : const Color(0xFF2A2A2A)),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isCurrent ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCurrent ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _stepDivider() {
    return Container(
      width: 28,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      color: Colors.white24,
    );
  }
}
