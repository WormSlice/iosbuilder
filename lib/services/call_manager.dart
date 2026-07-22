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

  void init(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _callSubscription?.cancel();
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: uid)
        .where(
          'status',
          whereIn: ['calling', 'ringing', 'ended', 'declined'],
        ) // Escuchar estados relevantes
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            final data = change.doc.data() as Map<String, dynamic>;
            final status = data['status'];
            final callId = change.doc.id;

            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              if (status == 'calling') {
                print('DEBUG: [CallManager] Incoming call detected: $callId');
                // Signal back that we are ringing
                FirebaseFirestore.instance
                    .collection('calls')
                    .doc(callId)
                    .update({'status': 'ringing'});

                _playRingtone();
                _showIncomingCallNotification(context, callId, data);
              } else if (status == 'ended' ||
                  status == 'declined' ||
                  status == 'finished') {
                print(
                  'DEBUG: [CallManager] Call terminated, stopping ringtone',
                );
                _stopRingtone();
                if (_isShowingNotification) {
                  OverlaySupportEntry.of(context)?.dismiss();
                  _isShowingNotification = false;
                }
              }
            }
          }
        });
  }

  void _playRingtone() {
    print('DEBUG: [CallManager] Playing ringtone for receiver');
    FlutterRingtonePlayer().playRingtone(looping: true, asAlarm: true);
  }

  void _stopRingtone() {
    print('DEBUG: [CallManager] Stopping ringtone');
    FlutterRingtonePlayer().stop();
  }

  void dispose() {
    _callSubscription?.cancel();
    _stopRingtone();
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

    showOverlayNotification((context) {
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
                  OverlaySupportEntry.of(context)?.dismiss();
                  _isShowingNotification = false;
                  _stopRingtone();
                  await FirebaseFirestore.instance
                      .collection('calls')
                      .doc(callId)
                      .update({'status': 'declined'});
                },
              ),
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () async {
                  debugPrint('DEBUG: Accept button pressed for call $callId');
                  OverlaySupportEntry.of(context)?.dismiss();
                  _isShowingNotification = false;
                  _stopRingtone();

                  try {
                    debugPrint(
                      'DEBUG: Updating call document to accepted: $callId',
                    );
                    // Use SignalingService update method for consistency if available,
                    // or just direct update.
                    await FirebaseFirestore.instance
                        .collection('calls')
                        .doc(callId)
                        .update({'status': 'accepted'});

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
    }, duration: const Duration(seconds: 30));
  }
}
