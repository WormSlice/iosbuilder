import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';

class FaceCaptureScreen extends StatefulWidget {
  final Function(File front, File left, File right) onCaptured;

  const FaceCaptureScreen({super.key, required this.onCaptured});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  bool _isBusy = false;
  String _instruction = 'Coloca tu rostro de frente';

  File? _frontImage;
  File? _leftImage;
  File? _rightImage;

  int _step = 0; // 0: Front, 1: Left, 2: Right

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});

    _startDetection();
  }

  void _startDetection() {
    _controller!.startImageStream((CameraImage image) {
      if (_isBusy) return;
      _isBusy = true;
      _processImage(image);
    });
  }

  Future<void> _processImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: InputImageRotation.rotation270deg,
        format:
            InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    final faces = await _faceDetector!.processImage(inputImage);

    if (faces.isNotEmpty) {
      final face = faces.first;
      _evaluateFacePosition(face);
    }

    _isBusy = false;
  }

  void _evaluateFacePosition(Face face) {
    // rotationY: > 0 is left, < 0 is right (relative to camera)
    final double? rotY = face.headEulerAngleY;

    if (!mounted) return;

    setState(() {
      if (_step == 0) {
        if (rotY != null && rotY.abs() < 10) {
          _instruction = '¡Excelente! Mantente así...';
          _takeScreenshot();
        } else {
          _instruction = 'Coloca tu rostro de frente';
        }
      } else if (_step == 1) {
        if (rotY != null && rotY > 20) {
          _instruction = '¡Bien! Capturando lado izquierdo...';
          _takeScreenshot();
        } else {
          _instruction = 'Gira tu cabeza a la IZQUIERDA';
        }
      } else if (_step == 2) {
        if (rotY != null && rotY < -20) {
          _instruction = '¡Bien! Capturando lado derecho...';
          _takeScreenshot();
        } else {
          _instruction = 'Gira tu cabeza a la DERECHA';
        }
      }
    });
  }

  Future<void> _takeScreenshot() async {
    if (_isBusy) return;
    _isBusy = true;

    await _controller!.stopImageStream();
    final XFile file = await _controller!.takePicture();

    setState(() {
      if (_step == 0) {
        _frontImage = File(file.path);
        _step = 1;
      } else if (_step == 1) {
        _leftImage = File(file.path);
        _step = 2;
      } else if (_step == 2) {
        _rightImage = File(file.path);
        _step = 3;
      }
    });

    if (_step < 3) {
      _isBusy = false;
      _startDetection();
    } else {
      widget.onCaptured(_frontImage!, _leftImage!, _rightImage!);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          // Overlay mask
          Center(
            child: Container(
              width: 250,
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _instruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_stepCircle(0), _stepCircle(1), _stepCircle(2)],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _takeScreenshot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'CAPTURAR FOTO',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCircle(int step) {
    bool active = _step == step;
    bool completed = _step > step;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: completed
            ? Colors.green
            : (active ? Colors.white : Colors.white24),
        shape: BoxShape.circle,
      ),
    );
  }
}
