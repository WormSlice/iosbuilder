import 'dart:async';
import 'package:flutter/material.dart';
import 'chat_room_screen.dart';
import '../../widgets/connect_title.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';

import 'package:provider/provider.dart';
import 'package:connect/models/chat_tag.dart';
import 'package:connect/services/chat_filter_service.dart';
import 'widgets/chat_filter_bar.dart';
import 'widgets/chat_options_sheet.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenContentState();
}

class _ChatsScreenContentState extends State<ChatsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final service = FirestoreService();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.black12, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none, size: 30),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                const ConnectTitle(),
                const SizedBox(
                  width: 48,
                ), // Balanced space for notification icon
              ],
            ),
          ),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Inicia sesión'))
          : Column(
              children: [
                SizedBox(
                  height: 60,
                  child: const ChatFilterBar(),
                ),
                Expanded(
                  child:
                      StreamBuilder<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      >(
                        stream: _mergedChatsStream(uid, service),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData && !snapshot.hasError) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          var docs = snapshot.data ?? [];

                          // Sort by last message time (descending)
                          docs.sort((a, b) {
                            final dataA = a.data();
                            final dataB = b.data();

                            final timeA =
                                dataA['lastMessageTime'] ??
                                dataA['lastMessageAt'] ??
                                dataA['updatedAt'] ??
                                dataA['timestamp'] ??
                                dataA['last_at'];
                            final timeB =
                                dataB['lastMessageTime'] ??
                                dataB['lastMessageAt'] ??
                                dataB['updatedAt'] ??
                                dataB['timestamp'] ??
                                dataB['last_at'];

                            if (timeA is Timestamp && timeB is Timestamp) {
                              return timeB.compareTo(timeA);
                            }
                            return 0;
                          });

                          return Consumer<ChatFilterService>(
                            builder: (context, filterService, child) {
                              // APPLY FILTERS
                              final filteredDocs = docs.where((doc) {
                                final data = doc.data();
                                final chatId = doc.id;

                                // 0. Filter Hidden Chats
                                if (filterService.isHidden(chatId)) {
                                  return false;
                                }

                                // 1. Filter by Active Tag
                                final active = filterService.activeFilter;
                                if (active != null) {
                                  if (active.id == ChatFilterService.unreadId) {
                                    final unread =
                                        (data['unreadCount'] ?? 0) > 0 &&
                                        data['lastSenderId'] != uid;
                                    if (!unread) return false;
                                  } else if (active.id ==
                                      ChatFilterService.favoritesId) {
                                    if (!filterService.isFavorite(chatId)) {
                                      return false;
                                    }
                                  } else if (active.type == TagType.custom) {
                                    if (!active.chatIds.contains(chatId)) {
                                      return false;
                                    }
                                  }
                                }
                                return true;
                              }).toList();

                              // ADDITIONAL SORT: Prioritize Pinned Chats
                              filteredDocs.sort((a, b) {
                                final aPinned = filterService.isPinned(a.id);
                                final bPinned = filterService.isPinned(b.id);
                                if (aPinned && !bPinned) return -1;
                                if (!aPinned && bPinned) return 1;
                                return 0; // Maintain Firestore sorting for same pin status
                              });

                              if (filteredDocs.isEmpty) {
                                return const Center(child: Text('Sin chats'));
                              }

                              return _buildChatList(filteredDocs, uid);
                            },
                          );
                        },
                      ),
                ),
              ],
            ),
    );
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _mergedChatsStream(
    String uid,
    FirestoreService service,
  ) {
    // Combine streams without rxdart
    // We create a controller that listens to all 3 and emits combined list
    final controller =
        StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>();

    List<QueryDocumentSnapshot<Map<String, dynamic>>> list1 = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> list2 = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> list3 = [];

    // Helper to emit combined
    void emit() {
      // Use a Map to deduplicate by ID if necessary, or just list
      // Assuming IDs are unique across collections or we treat them as separate
      // Using Map to deduplicate by doc ID just in case
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> unique =
          {};

      for (var d in list1) {
        unique[d.id] = d;
      }
      for (var d in list2) {
        unique[d.id] = d;
      }
      for (var d in list3) {
        unique[d.id] = d;
      }

      if (!controller.isClosed) {
        controller.add(unique.values.toList());
      }
    }

    final sub1 = service.conversationsStream(uid).listen((snap) {
      list1 = snap.docs;
      emit();
    });
    final sub2 = service.chatsStream(uid).listen((snap) {
      list2 = snap.docs;
      emit();
    });
    final sub3 = service.roomsStream(uid).listen((snap) {
      list3 = snap.docs;
      emit();
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
    };

    return controller.stream;
  }

  Widget _buildChatList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String uid,
  ) {
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 0.8, color: Colors.black12),
      itemBuilder: (context, i) {
        final doc = docs[i];
        final data = doc.data();
        final chatId = doc.id;
        final peerId = _peerIdFromData(data, uid);

        return FutureBuilder<Map<String, dynamic>>(
          future: _resolvePeer(peerId, doc.reference),
          builder: (context, snap) {
            // While loading, show a non-interactive empty tile to avoid flickering
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 72);
            }

            final peerData = snap.data;
            if (peerData == null || peerData['exists'] == false) {
              return const SizedBox.shrink(); // Hide if user is gone
            }

            final pubData = data['publicationData'] as Map<String, dynamic>?;
            final pubTitle = pubData?['title']?.toString();
            final pubImage = pubData?['image']?.toString();

            final peerName =
                peerData['name'] ??
                data['title']?.toString() ??
                data['peerName']?.toString() ??
                data['name']?.toString() ??
                'Usuario';

            final peerAvatar =
                peerData['avatar'] ??
                data['avatarUrl']?.toString() ??
                data['peerAvatar']?.toString() ??
                data['avatar']?.toString();

            final resolvedName = pubTitle ?? peerName;
            final resolvedAvatar = pubImage ?? peerAvatar;

            final last =
                data['lastMessage']?.toString() ??
                data['last']?.toString() ??
                '';
            final time = _formatTime(
              data['lastMessageTime'] ??
                  data['lastMessageAt'] ??
                  data['updatedAt'] ??
                  data['timestamp'] ??
                  data['last_at'],
            );
            final verified = (peerData['isVerified'] == true);
            final unread =
                (data['unreadCount'] ?? 0) > 0 && data['lastSenderId'] != uid;

            return GestureDetector(
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(
                      chatId: chatId,
                      peerId: peerId,
                      collectionPath: doc.reference.parent.id,
                      initialData: data,
                    ),
                  ),
                );
              },
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => ChatOptionsSheet(chatId: chatId),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 15,
                ),
                color: Colors.transparent,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (peerId != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: peerId),
                            ),
                          );
                        }
                      },
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.grey[200],
                            backgroundImage:
                                resolvedAvatar != null && resolvedAvatar.isNotEmpty
                                ? NetworkImage(resolvedAvatar)
                                : null,
                            child:
                                (resolvedAvatar == null || resolvedAvatar.isEmpty)
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null,
                          ),
                          if (pubImage != null && peerAvatar != null && peerAvatar.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  radius: 9,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: NetworkImage(peerAvatar),
                                  child: peerAvatar.isEmpty
                                      ? const Icon(Icons.person, size: 10, color: Colors.grey)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  resolvedName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (verified && pubTitle == null)
                                const Padding(
                                  padding: EdgeInsets.only(left: 5),
                                  child: Icon(
                                    Icons.verified,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                                ),
                              if (Provider.of<ChatFilterService>(
                                context,
                                listen: false,
                              ).isPinned(chatId))
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.push_pin,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          if (pubData != null && pubData['category'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pubData['category'].toString().toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0094FF),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          Text(
                            last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'CanvaSans',
                              fontSize: 15,
                              fontWeight: unread ? FontWeight.bold : FontWeight.w400,
                              color: unread ? Colors.black : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (unread)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String? _peerIdFromData(Map<String, dynamic> data, String uid) {
    final ids =
        (data['members'] ?? data['participants'] ?? data['users']) as dynamic;
    if (ids is List && ids.isNotEmpty) {
      for (final id in ids) {
        if (id is String && id != uid) return id;
      }
    }
    final pid = data['peerId'];
    return pid is String ? pid : null;
  }

  Future<Map<String, dynamic>> _resolvePeer(
    String? peerId,
    DocumentReference chatRef,
  ) async {
    if (peerId == null || peerId.isEmpty) return {'exists': false};

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(peerId)
          .get();

      if (!doc.exists) {
        // GHOST CHAT DETECTED: Self-heal by deleting the chat document
        debugPrint(
          'DEBUG: Peer $peerId not found. Deleting ghost chat ${chatRef.id}',
        );
        await chatRef.delete();
        return {'exists': false};
      }

      final d = doc.data();
      final name =
          (d?['displayName'] ?? d?['name'] ?? d?['username'] ?? d?['fullName'])
              ?.toString();
      final avatar =
          (d?['photoURL'] ??
                  d?['photoUrl'] ??
                  d?['image'] ??
                  d?['avatar'] ??
                  d?['profilePic'] ??
                  d?['imageUrl'] ??
                  d?['photo'] ??
                  d?['foto'])
              ?.toString();

      final isVerified = d?['isVerified'] == true;
      
      return {'exists': true, 'name': name, 'avatar': avatar, 'isVerified': isVerified};
    } catch (e) {
      debugPrint('DEBUG: Error resolving peer $peerId: $e');
      return {'exists': false};
    }
  }

  String _formatTime(dynamic ts) {
    try {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        final now = DateTime.now();
        // Calculates difference in days disregarding time to handle "Ayer" precisely
        final startOfToday = DateTime(now.year, now.month, now.day);
        final startOfMessage = DateTime(dt.year, dt.month, dt.day);
        final diffDays = startOfToday.difference(startOfMessage).inDays;

        if (diffDays == 0) {
          int h12 = dt.hour % 12;
          if (h12 == 0) h12 = 12;
          final m = dt.minute.toString().padLeft(2, '0');
          final period = dt.hour >= 12 ? 'p.m.' : 'a.m.';
          return '$h12:$m $period';
        } else if (diffDays == 1) {
          return 'Ayer';
        } else if (diffDays < 7) {
          const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
          return days[dt.weekday - 1];
        } else {
          return '${dt.day}/${dt.month}/${dt.year}';
        }
      }
      return ts?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }
}

//
