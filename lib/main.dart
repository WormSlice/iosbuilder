import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/messaging_service.dart';
import 'services/local_notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint("Flutter Error: ${details.exception}");
    };

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

    PaintingBinding.instance.imageCache.maximumSize = 200;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;

    runApp(const App());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await LocalNotificationService.init();
      } catch (e) {
        debugPrint("LocalNotificationService init error: $e");
      }
      try {
        await MessagingService().init();
      } catch (e) {
        debugPrint("MessagingService init error: $e");
      }
    });
  }, (Object error, StackTrace stack) {
    debugPrint("Uncaught Zoned Error: $error\n$stack");
  });
}
