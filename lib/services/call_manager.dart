import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../screens/chats/call_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app.dart';

class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  StreamSubscription? _callSubscription;
  bool _isShowingNotification = false;
  OverlaySupportEntry? _currentOverlayEntry;
  Timer? _ringtoneLoopTimer;

  void init(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _callSubscription?.cancel();
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            final data = change.doc.data();
            final status = data?['status']?.toString();
            final callId = change.doc.id;

            if (change.type == DocumentChangeType.removed) {
              print('DEBUG: [CallManager] Call document removed by caller: $callId');
              _dismissNotification();
              continue;
            }

            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (status == 'calling') {
                print('DEBUG: [CallManager] Incoming call detected: $callId');
                // Signal back that we are ringing
                FirebaseFirestore.instance
                    .collection('calls')
                    .doc(callId)
                    .update({'status': 'ringing'}).catchError((_) {});

                _playRingtone();
                if (data != null) {
                  _showIncomingCallNotification(context, callId, data);
                }
              } else if (status == 'ended' ||
                  status == 'declined' ||
                  status == 'cancelled' ||
                  status == 'rejected' ||
                  status == 'finished') {
                print('DEBUG: [CallManager] Call terminated with status $status, dismissing banner');
                _dismissNotification();
              }
            }
          }

          // Si ya no existe ninguna llamada con estado calling o ringing en la colección, limpiar overlay
          final activeCallingDocs = snapshot.docs.where((d) {
            final st = (d.data())['status']?.toString();
            return st == 'calling' || st == 'ringing';
          });
          if (activeCallingDocs.isEmpty && _isShowingNotification) {
            print('DEBUG: [CallManager] No active calling documents, dismissing notification');
            _dismissNotification();
          }
        });
  }

  void _dismissNotification() {
    _currentOverlayEntry?.dismiss();
    _currentOverlayEntry = null;
    _isShowingNotification = false;
    _stopRingtone();
  }

  void _playRingtone() {
    print('DEBUG: [CallManager] Playing looping ringtone for receiver');
    _ringtoneLoopTimer?.cancel();
    FlutterRingtonePlayer().playRingtone(looping: true, asAlarm: true);
    // Timer para asegurar repetición continua tanto en iOS como en Android
    _ringtoneLoopTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      FlutterRingtonePlayer().playRingtone(looping: true, asAlarm: true);
    });
  }

  void _stopRingtone() {
    print('DEBUG: [CallManager] Stopping ringtone');
    _ringtoneLoopTimer?.cancel();
    _ringtoneLoopTimer = null;
    FlutterRingtonePlayer().stop();
  }

  void dispose() {
    _callSubscription?.cancel();
    _dismissNotification();
  }

  void _showIncomingCallNotification(
    BuildContext context,
    String callId,
    Map<String, dynamic> data,
  ) {
    if (_isShowingNotification) return;
    _isShowingNotification = true;

    final String callerName = data['callerName'] ?? 'Usuario';
    final String? callerAvatar = data['callerAvatar'];
    final String channelId = data['chatId'] ?? callId;

    _currentOverlayEntry = showOverlayNotification((overlayContext) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        color: const Color(0xFF1a1a1a),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage:
                    (callerAvatar != null && callerAvatar.isNotEmpty)
                    ? CachedNetworkImageProvider(callerAvatar)
                    : null,
                child: (callerAvatar == null || callerAvatar.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Llamada entrante',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.call_end, color: Colors.red),
                onPressed: () async {
                  _dismissNotification();
                  await FirebaseFirestore.instance
                      .collection('calls')
                      .doc(callId)
                      .update({'status': 'declined'}).catchError((_) {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () async {
                  debugPrint('DEBUG: Accept button pressed for call $callId');
                  _dismissNotification();

                  try {
                    debugPrint(
                      'DEBUG: Updating call document to accepted: $callId',
                    );
                    await FirebaseFirestore.instance
                        .collection('calls')
                        .doc(callId)
                        .update({'status': 'accepted'}).catchError((_) {});

                    debugPrint(
                      'DEBUG: Call document updated. Navigating to CallScreen for $channelId',
                    );

                    App.navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          channelId: channelId,
                          peerName: callerName,
                          peerAvatar: callerAvatar,
                          callId: callId,
                        ),
                      ),
                    );
                  } catch (e) {
                    debugPrint('DEBUG: Error accepting call: $e');
                  }
                },
              ),
            ],
          ),
        ),
      );
    }, duration: const Duration(seconds: 45));
  }
}
