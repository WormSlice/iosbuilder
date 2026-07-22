import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/messaging_service.dart';
import 'services/local_notification_service.dart'; // Assuming this import is needed for LocalNotificationService

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // No bloquear el inicio de la interfaz con servicios secundarios
  MessagingService().init();
  LocalNotificationService.init(); // This call is already present and non-blocking

  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // ~200MB
  runApp(const App());
}
