import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/messaging_service.dart';
import 'services/local_notification_service.dart'; // Assuming this import is needed for LocalNotificationService

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (_) {
    try {
      await dotenv.load(fileName: ".env", isOptional: true);
    } catch (_) {}
  }

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  try {
    MessagingService().init();
  } catch (e) {
    debugPrint("MessagingService init error: $e");
  }

  try {
    LocalNotificationService.init();
  } catch (e) {
    debugPrint("LocalNotificationService init error: $e");
  }

  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // ~200MB

  runApp(const App());
}
