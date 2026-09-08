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

    String title = message.notification?.title ?? message.data['title']?.toString() ?? 'CONNECT';
    String body = message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';

    if (title.isNotEmpty || body.isNotEmpty) {
      await LocalNotificationService.showNotification(
        title: title,
        body: body,
        payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
      );
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

  StreamSubscription<QuerySnapshot>? _firestoreNotificationSub;
  final Set<String> _seenNotificationIds = {};
  DateTime _sessionStartTime = DateTime.now();

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _sessionStartTime = DateTime.now();

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
        final data = message.data;
        final chatId = data['chatId']?.toString();

        // If user is currently looking at this chat, suppress pop-up notification
        if (chatId != null && chatId == activeChatId) {
          return;
        }

        final notification = message.notification;
        final title = notification?.title ?? data['title']?.toString() ?? 'CONNECT';
        final body = notification?.body ?? data['body']?.toString() ?? data['message']?.toString() ?? '';

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
        _listenToUserNotifications(currentUser.uid);
      }

      // 8. Listen to token refresh
      _fm.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        saveTokenToDatabase(newToken);
      });

      // 9. Listen to Auth changes to ensure token and notification listener are synced
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          saveTokenToDatabase();
          _listenToUserNotifications(user.uid);
        } else {
          _firestoreNotificationSub?.cancel();
          _firestoreNotificationSub = null;
        }
      });
    } catch (e) {
      debugPrint('Error initializing MessagingService: $e');
    }
  }

  /// Listens to real-time notification records in Firestore for the authenticated user
  void _listenToUserNotifications(String uid) {
    _firestoreNotificationSub?.cancel();

    try {
      _firestoreNotificationSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(25)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final doc = change.doc;
            final docId = doc.id;
            final data = doc.data();
            if (data == null) continue;

            if (_seenNotificationIds.contains(docId)) continue;
            _seenNotificationIds.add(docId);

            final senderId = data['senderId']?.toString();
            if (senderId != null && senderId == uid) continue;

            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            // If the notification is older than session start and already marked read, skip
            if (createdAt != null &&
                createdAt.isBefore(_sessionStartTime.subtract(const Duration(seconds: 10))) &&
                data['read'] == true) {
              continue;
            }

            final chatId = data['chatId']?.toString();
            // If the user is actively in this chat screen right now, do not show pop-up
            if (chatId != null && chatId == activeChatId) {
              continue;
            }

            final title = data['title']?.toString() ?? 'CONNECT';
            final body = data['body']?.toString() ?? '';

            if (title.isNotEmpty || body.isNotEmpty) {
              LocalNotificationService.showNotification(
                title: title,
                body: body,
                payload: jsonEncode({
                  'chatId': chatId,
                  'senderId': senderId,
                  'type': data['type'],
                  'collectionPath': data['collectionPath'] ?? 'chats',
                  ...data,
                }),
              );
            }
          }
        }
      }, onError: (e) {
        debugPrint('Error listening to user notifications: $e');
      });
    } catch (e) {
      debugPrint('Exception setting up notifications stream: $e');
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
          // Retry for iOS APNs registration handshake
          for (int i = 0; i < 6; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            apnsToken = await _fm.getAPNSToken();
            if (apnsToken != null) break;
          }
        }
        if (apnsToken != null) {
          debugPrint('APNs Token obtained: $apnsToken');
        }
      }

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

  /// Sends a push notification document to a recipient user in Firestore
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
        'type': data?['type'] ?? 'chat_message',
        ...?data,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .add(notificationPayload);

      debugPrint('Push notification dispatched to user $recipientUid: "$title - $body"');
    } catch (e) {
      debugPrint('Error sending notification to user $recipientUid: $e');
    }
  }

  /// Removes or invalidates FCM token when user logs out
  Future<void> deleteToken() async {
    try {
      _firestoreNotificationSub?.cancel();
      _firestoreNotificationSub = null;

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
