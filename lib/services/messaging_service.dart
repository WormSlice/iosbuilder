import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../app.dart';
import '../screens/chats/chat_room_screen.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint("FCM Background message received: ${message.messageId}");

    // Si el mensaje no trae bloque notification nativo (mensaje data puro),
    // despertar plugin local para mostrarlo en la bandeja del sistema.
    if (message.notification == null) {
      String title = message.data['title']?.toString() ?? 'CONNECT';
      String body = message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          '';

      if (title.isNotEmpty || body.isNotEmpty) {
        await LocalNotificationService.init();
        await LocalNotificationService.showNotification(
          title: title,
          body: body,
          payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
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

  /// Currently active chatId in foreground (to avoid notifying when inside the same chat)
  static String? activeChatId;

  /// Cache of recently handled FCM message IDs and signatures to prevent duplicate banners
  final Map<String, DateTime> _recentlyHandledMessages = {};

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

      // 4. Listen to foreground messages and show local notification with deduplication
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message: ${message.messageId}');
        final data = message.data;
        final chatId = data['chatId']?.toString();

        // If user is currently looking at this chat, suppress pop-up notification
        if (chatId != null && chatId == activeChatId) {
          return;
        }

        final notification = message.notification;
        final title = notification?.title ?? data['title']?.toString() ?? 'CONNECT';
        final body = notification?.body ?? data['body']?.toString() ?? data['message']?.toString() ?? '';

        // Deduplication: prevent rapid duplicate alerts within 20 seconds
        final msgKey = message.messageId ?? '${chatId}_${data['senderId']}_${title}_$body';
        final now = DateTime.now();
        _recentlyHandledMessages.removeWhere((_, time) => now.difference(time).inSeconds > 20);
        if (_recentlyHandledMessages.containsKey(msgKey)) {
          debugPrint('FCM Foreground message duplicate suppressed: $msgKey');
          return;
        }
        _recentlyHandledMessages[msgKey] = now;

        if (title.isNotEmpty || body.isNotEmpty) {
          LocalNotificationService.showNotification(
            title: title,
            body: body,
            payload: data.isNotEmpty ? jsonEncode(data) : null,
          );
        }
      });

      // 5. Handle notification tap when opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM onMessageOpenedApp: ${message.data}');
        _handleMessageClick(message.data);
      });

      // 6. Handle notification tap when opened from terminated state
      final RemoteMessage? initialMessage = await _fm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM getInitialMessage: ${initialMessage.data}');
        _handleMessageClick(initialMessage.data);
      }

      // 7. Save initial token if user is already signed in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await saveTokenToDatabase();
      }

      // 8. Listen to token refresh
      _fm.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        saveTokenToDatabase(newToken);
      });

      // 9. Listen to Auth changes to ensure token is synced
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          saveTokenToDatabase();
        }
      });
    } catch (e) {
      debugPrint('Error initializing MessagingService: $e');
    }
  }

  /// Handle click from FCM remote message
  void _handleMessageClick(Map<String, dynamic> data) {
    try {
      final chatId = data['chatId']?.toString();
      final peerId = data['senderId']?.toString() ?? data['peerId']?.toString();
      final collectionPath = data['collectionPath']?.toString() ?? 'chats';

      if (chatId != null && chatId.isNotEmpty) {
        App.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              chatId: chatId,
              peerId: peerId,
              collectionPath: collectionPath,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error routing notification click: $e');
    }
  }

  /// Stores the FCM token and APNs token in Firestore under `users/{uid}`
  Future<void> saveTokenToDatabase([String? token]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? apnsToken;
      if (!kIsWeb && Platform.isIOS) {
        apnsToken = await _fm.getAPNSToken();
        if (apnsToken == null) {
          // Reintentar hasta 10 segundos para dar tiempo al usuario a aceptar permisos
          for (int i = 0; i < 10; i++) {
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await _fm.getAPNSToken();
            if (apnsToken != null) break;
          }
        }
        if (apnsToken != null) {
          debugPrint('APNs Token obtained: $apnsToken');
        }
      }

      String? fcmToken = token;
      if (fcmToken == null || fcmToken.isEmpty) {
        try {
          fcmToken = await _fm.getToken();
        } catch (tokenErr) {
          debugPrint('Initial getToken failed (waiting for APNs): $tokenErr');
          if (!kIsWeb && Platform.isIOS) {
            await Future.delayed(const Duration(seconds: 2));
            fcmToken = await _fm.getToken();
          }
        }
      }
      if (fcmToken == null || fcmToken.isEmpty) return;

      String platformName = 'unknown';
      if (!kIsWeb) {
        if (Platform.isAndroid) platformName = 'android';
        if (Platform.isIOS) platformName = 'ios';
        if (Platform.isMacOS) platformName = 'macos';
      } else {
        platformName = 'web';
      }

      final Map<String, dynamic> tokenData = {
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'devicePlatform': platformName,
      };

      if (apnsToken != null) {
        tokenData['apnsToken'] = apnsToken;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(tokenData, SetOptions(merge: true));

      debugPrint('FCM Token successfully synced for ${user.uid} ($platformName)');
    } catch (e) {
      debugPrint('Error saving FCM Token to Firestore: $e');
    }
  }

  /// Stores a notification document for a user in Firestore (for the in-app notification center).
  /// Backend Cloud Functions automatically handle FCM push delivery.
  static Future<void> sendNotificationToUser({
    required String recipientUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final senderId = currentUser?.uid ?? '';
      if (recipientUid.isEmpty || recipientUid == senderId) return;

      final notificationPayload = {
        'title': title,
        'body': body,
        'senderId': senderId,
        'senderName': title,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': data?['type'] ?? 'system',
        ...?data,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .add(notificationPayload);

      debugPrint('Notification document stored for user $recipientUid');
    } catch (e) {
      debugPrint('Error sending notification to user $recipientUid: $e');
    }
  }

  /// Removes or invalidates FCM token when user logs out
  Future<void> deleteToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
          'apnsToken': FieldValue.delete(),
        }).catchError((_) {});
      }
      await _fm.deleteToken();
    } catch (e) {
      debugPrint('Error deleting FCM Token: $e');
    }
  }
}
