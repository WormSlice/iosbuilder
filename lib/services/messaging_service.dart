import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint("FCM Background message received: ${message.messageId}");

    // If notification payload is null but data is provided, show a system notification
    if (message.notification == null && message.data.isNotEmpty) {
      final title = message.data['title']?.toString() ?? 'CONNECT';
      final body = message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          '';
      if (title.isNotEmpty || body.isNotEmpty) {
        await LocalNotificationService.showNotification(
          title: title,
          body: body,
          payload: jsonEncode(message.data),
        );
      }
    }
  } catch (e) {
    debugPrint("Error in background FCM handler: $e");
  }
}

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // 1. Request notification permissions
      final NotificationSettings settings = await _fm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Permission status: ${settings.authorizationStatus}');

      // 2. Set foreground presentation options for iOS / macOS
      await _fm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Listen to foreground messages and show local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message: ${message.messageId}');
        final notification = message.notification;
        if (notification != null) {
          LocalNotificationService.showNotification(
            title: notification.title ?? 'CONNECT',
            body: notification.body ?? '',
            payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
          );
        } else if (message.data.isNotEmpty) {
          final title = message.data['title']?.toString() ?? 'CONNECT';
          final body = message.data['body']?.toString() ??
              message.data['message']?.toString() ??
              '';
          if (title.isNotEmpty || body.isNotEmpty) {
            LocalNotificationService.showNotification(
              title: title,
              body: body,
              payload: jsonEncode(message.data),
            );
          }
        }
      });

      // 5. Handle notification tap when opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM onMessageOpenedApp: ${message.data}');
      });

      // 6. Handle notification tap when opened from terminated state
      final RemoteMessage? initialMessage = await _fm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM getInitialMessage: ${initialMessage.data}');
      }

      // 7. Save initial token if user is already signed in
      await saveTokenToDatabase();

      // 8. Listen to token refresh
      _fm.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        saveTokenToDatabase(newToken);
      });

      // 9. Listen to Auth changes to ensure token is synced with current user
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          saveTokenToDatabase();
        }
      });
    } catch (e) {
      debugPrint('Error initializing MessagingService: $e');
    }
  }

  /// Stores the FCM token in Firestore under `users/{uid}`
  Future<void> saveTokenToDatabase([String? token]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final fcmToken = token ?? await _fm.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      String platformName = 'unknown';
      if (!kIsWeb) {
        if (Platform.isAndroid) platformName = 'android';
        if (Platform.isIOS) platformName = 'ios';
        if (Platform.isMacOS) platformName = 'macos';
      } else {
        platformName = 'web';
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'devicePlatform': platformName,
      }, SetOptions(merge: true));

      debugPrint('FCM Token saved to Firestore for user ${user.uid}: $fcmToken');
    } catch (e) {
      debugPrint('Error saving FCM Token to Firestore: $e');
    }
  }

  /// Removes or invalidates FCM token when user logs out
  Future<void> deleteToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        }).catchError((_) {});
      }
      await _fm.deleteToken();
    } catch (e) {
      debugPrint('Error deleting FCM Token: $e');
    }
  }
}
