import 'dart:io';

import 'package:flutter/material.dart';
import '../../widgets/circular_reveal_animation.dart';
import '../../widgets/dynamic_island_notification.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:translator/translator.dart';
import '../../app.dart';
import 'call_screen.dart';
import 'chat_info_screen.dart';
import '../../services/signaling_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String? peerId;
  final String? collectionPath; // 'chats', 'conversations', or 'rooms'
  final Map<String, dynamic>? initialData;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    this.peerId,
    this.collectionPath = 'chats',
    this.initialData,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  bool showTools = false;
  bool hasContent = false;
  bool isTranslating = false;
  bool isRecording = false;

  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer(); // For preview if needed

  String? _cachedAudioPath;
  final _translator = GoogleTranslator();
  final Map<String, String> _translations = {};
  String _targetLanguage = 'es';
  late String currentUid;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void toggleTools() {
    if (!showTools) {
      _focusNode.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
    setState(() => showTools = !showTools);
  }

  void _handleTranslate() {
    setState(() {
      isTranslating = !isTranslating;
    });

    DynamicIslandNotification.show(
      title: 'TRADUCCIÓN',
      message: isTranslating ? 'Traductor automático activado' : 'Traductor automático desactivado',
      icon: isTranslating ? Icons.g_translate_rounded : Icons.translate_rounded,
      color: isTranslating ? const Color(0xFF0094FF) : Colors.grey,
    );
  }

  void _translateMessage(String msgId, String text) async {
    if (_translations.containsKey(msgId)) return;
    try {
      final translation = await _translator.translate(text, to: _targetLanguage);
      if (mounted) {
        setState(() {
          _translations[msgId] = translation.text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translations[msgId] = text; // fallback
        });
      }
    }
  }

  Future<void> _handleCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        _uploadAndSendFile(File(photo.path), 'image');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al abrir la cámara: $e')));
    }
  }

  Future<void> _uploadAndSendFile(File file, String type) async {
    try {
      String label = type == 'image' ? 'foto' : 'mensaje de voz';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Enviando $label...')));

      final ext = type == 'image' ? 'jpg' : 'm4a';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_$type')
          .child(
            '${widget.chatId}_${DateTime.now().millisecondsSinceEpoch}.$ext',
          );

      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      _sendMessage(text: url, type: type);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al enviar el archivo: $e')));
    }
  }

  Future<void> _handleVoiceStart(LongPressStartDetails details) async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _cachedAudioPath = path;

        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);

        setState(() => isRecording = true);
        HapticFeedback.mediumImpact();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Permiso de micrófono: $status. Por favor, actívalo en ajustes.',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al solicitar permiso: $e')));
    }
  }

  Future<void> _handleVoiceEnd(LongPressEndDetails details) async {
    try {
      if (!isRecording) return;
      final path = await _audioRecorder.stop();
      setState(() => isRecording = false);

      if (path != null) {
        _uploadAndSendFile(File(path), 'voice');
      }
    } catch (e) {
      print('Error stop recording: $e');
      setState(() => isRecording = false);
    }
  }

  Future<void> _handleGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
      if (photo != null) {
        _uploadAndSendFile(File(photo.path), 'image');
      }
      toggleTools();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al abrir galería: $e')));
    }
  }

  Future<void> _handleFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;

        // Upload file
        try {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Enviando archivo...')));
          final ref = FirebaseStorage.instance
              .ref()
              .child('chat_files')
              .child(
                '${widget.chatId}_${DateTime.now().millisecondsSinceEpoch}_$fileName',
              );

          await ref.putFile(file);
          final url = await ref.getDownloadURL();

          // Send message with file info
          // Constructing a simple JSON-like string or just URL|Name for simplicity?
          // Let's use a separator "|||" to store URL and Name, or just send URL and assume name is not critical for now,
          // BUT for files we usually want the name.
          // Let's modify _sendMessage to accept metadata or just pack it in text if we want to avoid schema changes.
          // We can store: "URL|||FILENAME"
          _sendMessage(text: '$url|||$fileName', type: 'file');
          toggleTools();
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al subir archivo: $e')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al elegir archivo: $e')));
    }
  }

  Future<void> _handleSocials() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      // Send comma-separated list of available keys or a structured string
      // Format: "instagram:user,facebook:user,whatsapp:num"
      List<String> validLinks = [];
      if (data['instagram'] != null &&
          data['instagram'].toString().isNotEmpty) {
        validLinks.add('instagram:${data['instagram']}');
      }
      if (data['facebook'] != null && data['facebook'].toString().isNotEmpty) {
        validLinks.add('facebook:${data['facebook']}');
      }
      if (data['twitter'] != null && data['twitter'].toString().isNotEmpty) {
        validLinks.add('twitter:${data['twitter']}');
      }
      if (data['tiktok'] != null && data['tiktok'].toString().isNotEmpty) {
        validLinks.add('tiktok:${data['tiktok']}');
      }
      if (data['whatsapp'] != null && data['whatsapp'].toString().isNotEmpty) {
        validLinks.add('whatsapp:${data['whatsapp']}');
      }

      if (validLinks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No tienes redes sociales configuradas en tu perfil.',
            ),
          ),
        );
        return;
      }

      String msg = validLinks.join(',');
      _sendMessage(text: msg, type: 'socials');
      toggleTools();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al compartir redes: $e')));
    }
  }

  Future<void> _handleResume() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      final resumeUrl =
          data['resumeUrl'] ?? data['cvUrl'] ?? data['hojaDeVida'];
      final resumeName = data['resumeName'] ?? 'Hoja de vida';

      if (resumeUrl == null || resumeUrl.toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No has subido tu hoja de vida a tu perfil.'),
          ),
        );
        return;
      }

      _sendMessage(text: '$resumeUrl|||$resumeName', type: 'file');
      toggleTools();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir hoja de vida: $e')),
      );
    }
  }

  void _sendMessage({String? text, String type = 'text'}) async {
    final msgText = text ?? _controller.text.trim();
    if (msgText.isEmpty && type == 'text') return;

    if (type == 'text') {
      _controller.clear();
      setState(() => hasContent = false);
    }

    final chatRef = FirebaseFirestore.instance
        .collection(widget.collectionPath!)
        .doc(widget.chatId);

    await chatRef.collection('messages').add({
      'senderId': currentUid,
      'text': msgText,
      'createdAt': FieldValue.serverTimestamp(),
      'type': type,
    });

    String lastMsg = msgText;
    if (type == 'image') lastMsg = '📷 Foto';
    if (type == 'voice') lastMsg = '🎤 Mensaje de voz';

    await chatRef.update({
      'lastMessage': lastMsg,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUid,
      'unreadCount': FieldValue.increment(1),
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(widget.collectionPath!)
          .doc(widget.chatId)
          .snapshots(),
      builder: (context, chatSnap) {
        final Map<String, dynamic> firestoreData =
            chatSnap.data?.data() as Map<String, dynamic>? ?? {};

        final chatData = {...(widget.initialData ?? {}), ...firestoreData};

        // Reset unread count if we are viewing the chat and someone else sent the last message
        if (firestoreData['unreadCount'] != null &&
            (firestoreData['unreadCount'] as num) > 0 &&
            firestoreData['lastSenderId'] != currentUid) {
          FirebaseFirestore.instance
              .collection(widget.collectionPath!)
              .doc(widget.chatId)
              .update({'unreadCount': 0});
        }

        // Extract Publication Data (New Structure)
        final pubData = chatData['publicationData'] as Map<String, dynamic>?;
        final String? postId = pubData?['id'] ?? chatData['postId'];
        final String? postTitle = pubData?['title'] ?? chatData['postTitle'];
        final String? postImage = pubData?['image'] ?? chatData['postImage'];

        String? peerId = widget.peerId;
        if (peerId == null && chatData['participants'] is List) {
          final List parts = chatData['participants'];
          peerId = parts.firstWhere((p) => p != currentUid, orElse: () => null);
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: peerId != null
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(peerId)
                    .snapshots()
              : null,
          builder: (context, userSnap) {
            String? peerName =
                chatData['peerName'] ??
                chatData['title'] ??
                chatData['name'] ??
                chatData['displayName'];
            String? peerAvatar =
                chatData['peerAvatar'] ??
                chatData['avatarUrl'] ??
                chatData['avatar'] ??
                chatData['photoURL'] ??
                chatData['image'];

            bool isPeerVerified = false;
            if (userSnap.hasData && userSnap.data!.exists) {
              final userData = userSnap.data!.data() as Map<String, dynamic>;
              peerName =
                  userData['displayName'] ??
                  userData['name'] ??
                  userData['username'] ??
                  peerName;
              peerAvatar =
                  userData['photoURL'] ??
                  userData['photoUrl'] ??
                  userData['image'] ??
                  userData['avatar'] ??
                  peerAvatar;
              isPeerVerified = userData['isVerified'] == true;
            } else {
              isPeerVerified = chatData['verified'] == true;
            }

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: _buildAppBar(
                context,
                postId,
                postTitle,
                postImage,
                peerId,
                peerName,
                peerAvatar,
                pubData?['category']?.toString(),
                isPeerVerified,
              ),
              body: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(widget.collectionPath!)
                          .doc(widget.chatId)
                          .collection('messages')
                          .snapshots(),
                      builder: (context, msgSnap) {
                        if (msgSnap.hasError) {
                          return const Center(
                            child: Text('Error al cargar mensajes'),
                          );
                        }
                        if (!msgSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final msgs = msgSnap.data!.docs.toList();
                        // Sort descending (newest first)
                        msgs.sort((a, b) {
                          final dataA = a.data() as Map<String, dynamic>;
                          final dataB = b.data() as Map<String, dynamic>;
                          final tsA =
                              dataA['createdAt'] ??
                              dataA['timestamp'] ??
                              dataA['time'] ??
                              dataA['sentAt'];
                          final tsB =
                              dataB['createdAt'] ??
                              dataB['timestamp'] ??
                              dataB['time'] ??
                              dataB['sentAt'];
                          if (tsA is Timestamp && tsB is Timestamp) {
                            return tsB.compareTo(tsA);
                          }
                          return 0;
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: msgs.length,
                          itemBuilder: (context, i) {
                            final doc = msgs[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final isMe = data['senderId'] == currentUid;

                            // Date Header Logic
                            bool showDateHeader = false;
                            DateTime? currentDate;
                            DateTime? nextDate;

                            final tsCurrent =
                                data['createdAt'] ?? data['timestamp'];
                            if (tsCurrent is Timestamp) {
                              currentDate = tsCurrent.toDate();
                            }

                            if (i + 1 < msgs.length) {
                              final nextData =
                                  msgs[i + 1].data() as Map<String, dynamic>;
                              final tsNext =
                                  nextData['createdAt'] ??
                                  nextData['timestamp'];
                              if (tsNext is Timestamp) {
                                nextDate = tsNext.toDate();
                              }
                            }

                            if (currentDate != null) {
                              if (nextDate == null) {
                                // Last message (top of conversation) always gets a header
                                showDateHeader = true;
                              } else {
                                // Check if day changed
                                if (currentDate.day != nextDate.day ||
                                    currentDate.month != nextDate.month ||
                                    currentDate.year != nextDate.year) {
                                  showDateHeader = true;
                                }
                              }
                            }

                            return Column(
                              children: [
                                if (showDateHeader && currentDate != null)
                                  _buildDateHeader(currentDate),
                                _buildMessage(doc, isMe, peerAvatar),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _chatInput(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: showTools ? 320 : 0,
                    curve: Curves.easeOut,
                    child: showTools ? _toolsPanel() : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String? postId,
    String? postTitle,
    String? postImage,
    String? peerId,
    String? peerName,
    String? peerAvatar,
    String? category,
    bool isVerified,
  ) {
    // If it's a publication chat, we show the PUBLICATION info prominently,
    // but allow navigation to the USER profile.
    final bool isPublicationChat = postId != null;

    final String title = isPublicationChat
        ? (postTitle ?? 'Artículo')
        : (peerName ?? 'Chat');

    final String? imageToDisplay = isPublicationChat ? postImage : peerAvatar;

    return AppBar(
      elevation: 1,
      backgroundColor: Colors.white,
      leading: const BackButton(color: Colors.black),
      titleSpacing: 0,
      title: GestureDetector(
        onTap: () {
          if (peerId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatInfoScreen(
                  chatId: widget.chatId,
                  peerId: peerId,
                  peerName: peerName ?? 'Usuario',
                  peerAvatar: peerAvatar,
                  isPublicationChat: isPublicationChat,
                ),
              ),
            );
          }
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              backgroundImage:
                  (imageToDisplay != null && imageToDisplay.isNotEmpty)
                  ? CachedNetworkImageProvider(imageToDisplay)
                  : null,
              child: (imageToDisplay == null || imageToDisplay.isEmpty)
                  ? Icon(
                      isPublicationChat ? Icons.shopping_bag : Icons.person,
                      color: Colors.grey,
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified && !isPublicationChat)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified, color: Color(0xFF0094FF), size: 14),
                        ),
                    ],
                  ),
                  if (category != null)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0094FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF0094FF),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  // If it's a publication chat, show the SELLER name below
                  if (peerName != null)
                    Text(
                      isPublicationChat
                          ? peerName
                          : 'En línea', // Or 'Tap for info'
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call, color: Color(0xFF0094FF)),
          onPressed: () => _initiateCall(
            peerId: peerId,
            peerName: peerName,
            peerAvatar: peerAvatar,
            isVideoCall: false,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.videocam, color: Color(0xFF0094FF)),
          onPressed: () => _initiateCall(
            peerId: peerId,
            peerName: peerName,
            peerAvatar: peerAvatar,
            isVideoCall: true,
          ),
        ),
      ],
    );
  }

  Future<void> _initiateCall({
    required String? peerId,
    required String? peerName,
    required String? peerAvatar,
    required bool isVideoCall,
  }) async {
    if (peerId == null) return;

    // Check if there is an active call minimized
    if (SignalingService().isCallActive &&
        SignalingService().activeCallId != null) {
      if (context.mounted) {
        App.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              channelId: widget.chatId,
              peerName: peerName ?? 'Usuario',
              peerAvatar: peerAvatar,
              callId: SignalingService().activeCallId,
              isVideoCall: SignalingService().isVideoOn,
            ),
          ),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final callerId = currentUser?.uid ?? '';

    // Fetch currentUser name/avatar for the notification
    final callerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(callerId)
        .get();
    final callerData = callerDoc.data();
    final callerName =
        callerData?['name'] ?? callerData?['username'] ?? 'Usuario';
    final callerAvatar = callerData?['photoURL'] ?? callerData?['image'];

    // Create signalling document
    final docRef = await FirebaseFirestore.instance.collection('calls').add({
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'receiverId': peerId,
      'chatId': widget.chatId,
      'status': 'calling',
      'isVideoCall': isVideoCall,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final callId = docRef.id;

    if (context.mounted) {
      App.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            channelId: widget.chatId,
            peerName: peerName ?? 'Usuario',
            peerAvatar: peerAvatar,
            callId: callId,
            isVideoCall: isVideoCall,
          ),
        ),
      );
    }
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String text;
    if (dateOnly == today) {
      text = 'HOY';
    } else if (dateOnly == yesterday) {
      text = 'AYER';
    } else {
      text = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(DocumentSnapshot doc, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Editar'),
                  onTap: () {
                    Navigator.pop(context);
                    _editMessage(doc);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Eliminar'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(doc);
                  },
                ),
              if (!isMe)
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.orange),
                  title: const Text('Reportar'),
                  onTap: () {
                    Navigator.pop(context);
                    _reportMessage(doc);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _deleteMessage(DocumentSnapshot doc) async {
    try {
      await doc.reference.delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mensaje eliminado.')));
    } catch (_) {}
  }

  void _editMessage(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    if (data['type'] != 'text') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se pueden editar mensajes de texto.'),
        ),
      );
      return;
    }
    final text = data['text'];
    final editCtrl = TextEditingController(text: text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Mensaje'),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (editCtrl.text.trim().isNotEmpty) {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pop(); // Pop dialog first
                await doc.reference.update({
                  'text': editCtrl.text.trim(),
                  'isEdited': true,
                });
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _reportMessage(DocumentSnapshot doc) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mensaje reportado. Gracias.')),
    );
    // Logic to add to 'reports' collection can go here
  }

  Widget _buildMessage(DocumentSnapshot doc, bool isMe, String? peerAvatar) {
    final data = doc.data() as Map<String, dynamic>;
    final String type = data['type'] ?? 'text';
    final String text = data['text']?.toString() ?? '';
    final String timestampStr = _formatMessageTime(data);

    Widget content;
    if (type == 'image') {
      content = _buildImageContent(text);
    } else if (type == 'voice') {
      content = AudioMessageWidget(url: text, isMe: isMe);
    } else if (type == 'file') {
      content = _buildFileContent(text, isMe);
    } else if (type == 'location') {
      content = _buildLocationContent(text, isMe);
    } else if (type == 'socials') {
      content = _buildSocialsContent(text, isMe);
    } else {
      if (isTranslating && !isMe) {
        if (_translations.containsKey(doc.id)) {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: Colors.black38,
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _translations[doc.id]!,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        } else {
          _translateMessage(doc.id, text);
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0094FF)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                ),
              ),
            ],
          );
        }
      } else {
        content = Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        );
      }
    }

    final bool isImage = type == 'image';
    // User Blue: 0xFF0094FF, Peer Grey: Colors.grey[200]
    final Color bgColor = isMe ? const Color(0xFF0094FF) : (Colors.grey[200]!);
    final Color timeColor = isMe ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(doc, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isImage ? Colors.transparent : bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: isMe
                  ? const Radius.circular(12)
                  : const Radius.circular(2),
              bottomRight: isMe
                  ? const Radius.circular(2)
                  : const Radius.circular(12),
            ),
          ),
          padding: isImage
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(10, 6, 10, 4),
          child: isImage
              ? Stack(
                  children: [
                    content,
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          timestampStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    content,
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timestampStr,
                            style: TextStyle(fontSize: 10, color: timeColor),
                          ),
                          if (isMe && (data['isEdited'] == true))
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Icon(
                                Icons.edit,
                                size: 8,
                                color: timeColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _formatMessageTime(Map<String, dynamic> data) {
    final timestamp =
        data['createdAt'] ??
        data['timestamp'] ??
        data['time'] ??
        data['sentAt'];
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      // Format: HH:mm
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  Widget _buildImageContent(String url) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _FullScreenImage(imageUrl: url)),
        );
      },
      child: Hero(
        tag: url,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: url,
            placeholder: (context, url) => const SizedBox(
              width: 200,
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildFileContent(String text, bool isMe) {
    final parts = text.split('|||');
    final url = parts[0];
    final name = parts.length > 1 ? parts[1] : 'Archivo adjunto';
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se puede abrir el archivo.')),
          );
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.insert_drive_file,
              color: isMe ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Toca para abrir',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationContent(String text, bool isMe) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(text);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: isMe ? Colors.white : Colors.red),
              const SizedBox(width: 4),
              Text(
                'Ubicación',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ver Mapa',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.open_in_new, size: 12, color: Colors.black87),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialsContent(String text, bool isMe) {
    final items = text.split(',');
    final content = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final parts = item.split(':');
        if (parts.length < 2) return const SizedBox.shrink();
        final network = parts[0];
        final value = parts[1];
        String iconPath = '';
        String url = '';

        if (network == 'instagram') {
          iconPath = 'assets/iconos/instagram.png';
          url = value.startsWith('http')
              ? value
              : 'https://www.instagram.com/$value';
        } else if (network == 'facebook') {
          iconPath = 'assets/iconos/facebook.png';
          url = value.startsWith('http')
              ? value
              : 'https://www.facebook.com/$value';
        } else if (network == 'whatsapp') {
          iconPath = 'assets/iconos/whatsapp.png';
          String phone = value.replaceAll(RegExp(r'[^\d+]'), '');
          url = value.startsWith('http') ? value : 'https://wa.me/$phone';
        } else if (network == 'tiktok') {
          iconPath = 'assets/iconos/tik-tok.png';
          url = value.startsWith('http')
              ? value
              : 'https://www.tiktok.com/@$value';
        } else {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () async {
            try {
              final uri = Uri.parse(url);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No se pudo abrir el enlace. Verifica que esté correcto.',
                    ),
                  ),
                );
              }
            }
          },
          child: Image.asset(iconPath, width: 32, height: 32),
        );
      }).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis Redes:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isMe ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  void _handleLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los servicios de ubicación están desactivados.'),
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos de ubicación denegados.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permisos de ubicación denegados permanentemente.'),
        ),
      );
      return;
    }

    // Show specific message while getting location
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Obteniendo ubicación...')));

    final pos = await Geolocator.getCurrentPosition();
    final link =
        'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';

    // Send as 'location' type!
    _sendMessage(text: link, type: 'location');
    toggleTools();
  }

  Widget _chatInput() {
    return SafeArea(
      bottom: !showTools,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Column(
          children: [
            if (isRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Grabando audio...',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Suelta para enviar',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.black),
                  onPressed: toggleTools,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !isRecording,
                      decoration: const InputDecoration(
                        hintText: 'Aa',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) =>
                          setState(() => hasContent = v.trim().isNotEmpty),
                      onTap: () {
                        if (showTools) setState(() => showTools = false);
                      },
                    ),
                  ),
                ),
                if (hasContent)
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF0094FF)),
                    onPressed: () => _sendMessage(),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onLongPress: () {
                          _showLanguageSelector();
                        },
                        child: IconButton(
                          icon: Icon(
                            Icons.translate,
                            size: 22,
                            color: isTranslating
                                ? const Color(0xFF0094FF)
                                : Colors.black54,
                          ),
                          onPressed: _handleTranslate,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          size: 22,
                          color: Colors.black54,
                        ),
                        onPressed: _handleCamera,
                      ),
                      GestureDetector(
                        onLongPressStart: _handleVoiceStart,
                        onLongPressEnd: _handleVoiceEnd,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4,
                          ),
                          child: Icon(
                            Icons.mic_none,
                            size: 22,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolsPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              crossAxisCount: 3,
              mainAxisSpacing: 24,
              crossAxisSpacing: 16,
              children: [
                _ToolItem(Icons.image_outlined, 'Fotos', onTap: _handleGallery),
                _ToolItem(
                  Icons.camera_alt_outlined,
                  'Cámara',
                  onTap: _handleCamera,
                ),
                _ToolItem(
                  Icons.location_on_outlined,
                  'Ubicación',
                  onTap: _handleLocation,
                ),
                _ToolItem(
                  Icons.insert_drive_file_outlined,
                  'Archivos',
                  onTap: _handleFiles,
                ),
                _ToolItem(Icons.people_outline, 'Redes', onTap: _handleSocials),
                _ToolItem(
                  Icons.assignment_outlined,
                  'Hoja de vida',
                  onTap: _handleResume,
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }

  void _showLanguageSelector() {
    final Map<String, String> languages = {
      'af': 'Afrikaans', 'sq': 'Albanian', 'am': 'Amharic', 'ar': 'Arabic', 'hy': 'Armenian', 'az': 'Azerbaijani',
      'eu': 'Basque', 'be': 'Belarusian', 'bn': 'Bengali', 'bs': 'Bosnian', 'bg': 'Bulgarian', 'ca': 'Catalan',
      'ceb': 'Cebuano', 'ny': 'Chichewa', 'zh-cn': 'Chinese (Simplified)', 'zh-tw': 'Chinese (Traditional)',
      'co': 'Corsican', 'hr': 'Croatian', 'cs': 'Czech', 'da': 'Danish', 'nl': 'Dutch', 'en': 'English',
      'eo': 'Esperanto', 'et': 'Estonian', 'tl': 'Filipino', 'fi': 'Finnish', 'fr': 'French', 'fy': 'Frisian',
      'gl': 'Galician', 'ka': 'Georgian', 'de': 'German', 'el': 'Greek', 'gu': 'Gujarati', 'ht': 'Haitian Creole',
      'ha': 'Hausa', 'haw': 'Hawaiian', 'iw': 'Hebrew', 'hi': 'Hindi', 'hmn': 'Hmong', 'hu': 'Hungarian',
      'is': 'Icelandic', 'ig': 'Igbo', 'id': 'Indonesian', 'ga': 'Irish', 'it': 'Italian', 'ja': 'Japanese',
      'jw': 'Javanese', 'kn': 'Kannada', 'kk': 'Kazakh', 'km': 'Khmer', 'ko': 'Korean', 'ku': 'Kurdish (Kurmanji)',
      'ky': 'Kyrgyz', 'lo': 'Lao', 'la': 'Latin', 'lv': 'Latvian', 'lt': 'Lithuanian', 'lb': 'Luxembourgish',
      'mk': 'Macedonian', 'mg': 'Malagasy', 'ms': 'Malay', 'ml': 'Malayalam', 'mt': 'Maltese', 'mi': 'Maori',
      'mr': 'Marathi', 'mn': 'Mongolian', 'my': 'Myanmar (Burmese)', 'ne': 'Nepali', 'no': 'Norwegian',
      'ps': 'Pashto', 'fa': 'Persian', 'pl': 'Polish', 'pt': 'Portuguese', 'pa': 'Punjabi', 'ro': 'Romanian',
      'ru': 'Russian', 'sm': 'Samoan', 'gd': 'Scots Gaelic', 'sr': 'Serbian', 'st': 'Sesotho', 'sn': 'Shona',
      'sd': 'Sindhi', 'si': 'Sinhala', 'sk': 'Slovak', 'sl': 'Slovenian', 'so': 'Somali', 'es': 'Español',
      'su': 'Sundanese', 'sw': 'Swahili', 'sv': 'Swedish', 'tg': 'Tajik', 'ta': 'Tamil', 'te': 'Telugu',
      'th': 'Thai', 'tr': 'Turkish', 'uk': 'Ukrainian', 'ur': 'Urdu', 'uz': 'Uzbek', 'vi': 'Vietnamese',
      'cy': 'Welsh', 'xh': 'Xhosa', 'yi': 'Yiddish', 'yo': 'Yoruba', 'zu': 'Zulu'
    };

    String searchQuery = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredLanguages = languages.entries.where((e) => 
              e.value.toLowerCase().contains(searchQuery.toLowerCase()) ||
              e.key.toLowerCase().contains(searchQuery.toLowerCase())
            ).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'IDIOMA DE TRADUCCIÓN',
                      style: TextStyle(
                        fontFamily: 'ArchivoBlack',
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      autofocus: false,
                      onChanged: (v) => setModalState(() => searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar idioma...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredLanguages.length,
                      itemBuilder: (context, index) {
                        final entry = filteredLanguages[index];
                        final isSelected = _targetLanguage == entry.key;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          title: Text(
                            entry.value,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF0094FF) : Colors.black87,
                            ),
                          ),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF0094FF)) : null,
                          onTap: () {
                            setState(() {
                              _targetLanguage = entry.key;
                              _translations.clear();
                              if (!isTranslating) isTranslating = true;
                            });
                            Navigator.pop(context);
                            DynamicIslandNotification.show(
                              title: 'IDIOMA',
                              message: 'Traduciendo mensajes a ${entry.value}',
                              icon: Icons.language_rounded,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ToolItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ToolItem(this.icon, this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade100,
            child: Icon(icon, color: const Color(0xFF0094FF), size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'CanvaSans',
            ),
          ),
        ],
      ),
    );
  }
}

class AudioMessageWidget extends StatefulWidget {
  final String url;
  final bool isMe;
  const AudioMessageWidget({super.key, required this.url, required this.isMe});

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) => setState(() => duration = d));
    _player.onPositionChanged.listen((p) => setState(() => position = p));
    _player.onPlayerComplete.listen((_) => setState(() => isPlaying = false));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: widget.isMe ? Colors.white : const Color(0xFF0094FF),
          ),
          onPressed: () async {
            if (isPlaying) {
              await _player.pause();
              setState(() => isPlaying = false);
            } else {
              await _player.play(UrlSource(widget.url));
              setState(() => isPlaying = true);
            }
          },
        ),
        Expanded(
          child: Slider(
            value: position.inMilliseconds.toDouble(),
            max: duration.inMilliseconds.toDouble() > 0
                ? duration.inMilliseconds.toDouble()
                : 1.0,
            activeColor: widget.isMe ? Colors.white : const Color(0xFF0094FF),
            inactiveColor: widget.isMe ? Colors.white24 : Colors.grey.shade300,
            onChanged: (v) async {
              await _player.seek(Duration(milliseconds: v.toInt()));
            },
          ),
        ),
      ],
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const _FullScreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) =>
                const Icon(Icons.error, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
