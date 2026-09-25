import 'dart:io';

import 'package:flutter/material.dart';
import '../../widgets/dynamic_island_notification.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/audio_recorder_helper.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:translator/translator.dart';
import '../../app.dart';
import 'call_screen.dart';
import 'chat_info_screen.dart';
import '../../services/signaling_service.dart';
import '../profile/social_icon_box.dart';
import '../../services/messaging_service.dart';
import '../../services/firestore_service.dart';
import '../profile/profile_screen.dart';

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
  bool _checkedPostOwnership = false;
  bool _isPostOwner = false;

  void _checkPostOwnership(String pid) async {
    if (_checkedPostOwnership) return;
    _checkedPostOwnership = true;
    try {
      final doc = await FirebaseFirestore.instance.collection('publications').doc(pid).get();
      if (doc.exists) {
        final d = doc.data();
        final uid = d?['userId'] ?? d?['ownerId'] ?? d?['uid'];
        if (uid == currentUid && mounted) {
          setState(() => _isPostOwner = true);
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    MessagingService.activeChatId = widget.chatId;
  }

  @override
  void dispose() {
    if (MessagingService.activeChatId == widget.chatId) {
      MessagingService.activeChatId = null;
    }
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
    if (type == 'file') lastMsg = '📎 Archivo';
    if (type == 'socials') lastMsg = '🔗 Redes sociales';

    await chatRef.update({
      'lastMessage': lastMsg,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUid,
      'unreadCount': FieldValue.increment(1),
    });

    _scrollToBottom();

    // Note: Push notification is automatically and reliably dispatched by
    // the Cloud Function `sendPushOnNewChatMessage` on message creation.
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

            final bool isSeller = (pubData?['ownerId'] == currentUid) ||
                (pubData?['userId'] == currentUid) ||
                (chatData['sellerId'] == currentUid) ||
                (chatData['ownerId'] == currentUid) ||
                (chatData['participants'] is List &&
                    (chatData['participants'] as List).length >= 2 &&
                    (chatData['participants'] as List)[1] == currentUid) ||
                _isPostOwner;

            if (!_checkedPostOwnership && postId != null) {
              _checkPostOwnership(postId);
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
                pubData?['category']?.toString() ?? pubData?['type']?.toString(),
                isPeerVerified,
              ),
              body: Column(
                children: [
                  if (postId != null)
                    _buildPublicationSubBar(
                      context,
                      postId: postId,
                      postTitle: postTitle,
                      postImage: postImage,
                      price: pubData?['price'],
                      category: pubData?['category']?.toString() ?? pubData?['type']?.toString(),
                      isSeller: isSeller,
                      peerId: peerId,
                      peerName: peerName,
                    ),
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

                        final bool hasHeroHeader = (postId != null);
                        final int totalCount = msgs.length + (hasHeroHeader ? 1 : 0);

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          itemCount: totalCount,
                          itemBuilder: (context, i) {
                            if (hasHeroHeader && i == msgs.length) {
                              return _buildHeroHeader(
                                postImage ?? peerAvatar,
                                postTitle,
                                peerId,
                              );
                            }

                            final doc = msgs[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final isMe = data['senderId'] == currentUid;

                            DateTime? currentDate;
                            final tsCurrent =
                                data['createdAt'] ?? data['timestamp'];
                            if (tsCurrent is Timestamp) {
                              currentDate = tsCurrent.toDate();
                            }

                            DateTime? prevDate;
                            String? prevSenderId;
                            if (i + 1 < msgs.length) {
                              final prevData =
                                  msgs[i + 1].data() as Map<String, dynamic>;
                              final tsPrev =
                                  prevData['createdAt'] ??
                                  prevData['timestamp'];
                              if (tsPrev is Timestamp) {
                                prevDate = tsPrev.toDate();
                              }
                              prevSenderId = prevData['senderId']?.toString();
                            }

                            // Centered separator header logic:
                            // Appears if first message ever, or >= 2 hours break, or day changed
                            bool showDateHeader = false;
                            if (currentDate != null) {
                              if (prevDate == null) {
                                showDateHeader = true;
                              } else {
                                final diff = currentDate.difference(prevDate).abs();
                                if (currentDate.day != prevDate.day ||
                                    currentDate.month != prevDate.month ||
                                    currentDate.year != prevDate.year ||
                                    diff.inMinutes >= 120) {
                                  showDateHeader = true;
                                }
                              }
                            }

                            // Avatar logic:
                            // Display avatar only on the first message of a consecutive run
                            final bool showAvatar = (!isMe) && (prevSenderId != data['senderId'] || showDateHeader);

                            return Column(
                              children: [
                                if (showDateHeader && currentDate != null)
                                  _buildDateHeader(currentDate),
                                _buildMessage(doc, isMe, peerAvatar, showAvatar),
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
    final bool isPublicationChat = postId != null;
    final String subtitleText = isPublicationChat ? (postTitle ?? '') : 'En línea';
    final String? avatarToDisplay = isPublicationChat
        ? (postImage != null && postImage.isNotEmpty ? postImage : peerAvatar)
        : peerAvatar;

    return AppBar(
      elevation: 0.5,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0094FF), size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      leadingWidth: 36,
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
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0094FF), width: 1.5),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage: (avatarToDisplay != null && avatarToDisplay.isNotEmpty)
                    ? CachedNetworkImageProvider(avatarToDisplay)
                    : null,
                child: (avatarToDisplay == null || avatarToDisplay.isEmpty)
                    ? Icon(
                        isPublicationChat ? Icons.shopping_bag_outlined : Icons.person,
                        color: Colors.grey,
                        size: 20,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          peerName ?? 'Usuario',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            fontFamily: 'CanvaSans',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified, color: Color(0xFF0094FF), size: 15),
                        ),
                    ],
                  ),
                  if (subtitleText.isNotEmpty)
                    Text(
                      subtitleText,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontFamily: 'CanvaSans',
                        fontWeight: FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call, color: Color(0xFF0094FF), size: 22),
          onPressed: () => _initiateCall(
            peerId: peerId,
            peerName: peerName,
            peerAvatar: peerAvatar,
            isVideoCall: false,
          ),
        ),
      ],
    );
  }

  Widget _buildPublicationSubBar(
    BuildContext context, {
    required String? postId,
    required String? postTitle,
    required String? postImage,
    required dynamic price,
    required String? category,
    required bool isSeller,
    required String? peerId,
    required String? peerName,
  }) {
    final formattedPrice = _formatPrice(price);
    final displayTitle = postTitle ?? 'Publicación';
    final fullHeader = price != null ? '$formattedPrice – $displayTitle' : displayTitle;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF0F0F2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              _getCategoryAsset(category),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fullHeader,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: 'CanvaSans',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                if (isSeller)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _handleMarkAsSold(postId),
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300, width: 0.8),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Vendido',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Colors.black,
                                fontFamily: 'CanvaSans',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showReviewDialog(
                            context,
                            peerId,
                            peerName,
                            postTitle,
                            category: category,
                          ),
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300, width: 0.8),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Calificar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Colors.black,
                                fontFamily: 'CanvaSans',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showReviewDialog(
                            context,
                            peerId,
                            peerName,
                            postTitle,
                            category: category,
                          ),
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300, width: 0.8),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Calificar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Colors.black,
                                fontFamily: 'CanvaSans',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(String? avatar, String? title, String? peerId) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0094FF), width: 2),
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.grey[200],
              backgroundImage: (avatar != null && avatar.isNotEmpty)
                  ? CachedNetworkImageProvider(avatar)
                  : null,
              child: (avatar == null || avatar.isEmpty)
                  ? const Icon(Icons.person, size: 40, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          if (title != null && title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'CanvaSans',
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              if (peerId != null && peerId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(userId: peerId)),
                );
              }
            },
            child: const Text(
              'Ver perfil del connect',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0094FF),
                fontFamily: 'CanvaSans',
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getCategoryAsset(String? category) {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('vehic') || cat.contains('car') || cat.contains('moto') || cat.contains('auto')) {
      return 'assets/iconos/AssetsCPu/vehiculos.png';
    }
    if (cat.contains('alquiler') || cat.contains('rent')) {
      return 'assets/iconos/AssetsCPu/alquiler.png';
    }
    if (cat.contains('prop') || cat.contains('inmueble') || cat.contains('casa') || cat.contains('apto') || cat.contains('terreno')) {
      return 'assets/iconos/AssetsCPu/propiedades.png';
    }
    if (cat.contains('serv')) {
      return 'assets/iconos/AssetsCPu/servicios.png';
    }
    if (cat.contains('pet') || cat.contains('masc')) {
      return 'assets/iconos/AssetsCPu/mascotas.png';
    }
    if (cat.contains('empleo') || cat.contains('job') || cat.contains('trabaj')) {
      return 'assets/iconos/AssetsCPu/empleos.png';
    }
    if (cat.contains('trueque') || cat.contains('barter') || cat.contains('cambio')) {
      return 'assets/iconos/AssetsCPu/trueques.png';
    }
    return 'assets/iconos/AssetsCPu/productos.png';
  }

  String _formatPrice(dynamic priceRaw) {
    if (priceRaw == null) return '\$0';
    double p = 0.0;
    if (priceRaw is int) p = priceRaw.toDouble();
    if (priceRaw is double) p = priceRaw;
    if (priceRaw is String) p = double.tryParse(priceRaw.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    if (p == 0) return '\$0';

    String s = p.toStringAsFixed(0);
    List<String> out = [];
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count != 0 && count % 3 == 0) out.add('.');
      out.add(s[i]);
      count++;
    }
    return '\$${out.reversed.join()}';
  }

  void _showReviewDialog(
    BuildContext context,
    String? peerId,
    String? peerName,
    String? postTitle, {
    String? category,
  }) {
    if (peerId == null || peerId.isEmpty) return;
    double userRating = 5.0;
    List<File> selectedImages = [];
    final reviewController = TextEditingController();
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 12,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calificar a ${peerName ?? "usuario"}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: 'CanvaSans',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (postTitle != null && postTitle.isNotEmpty)
                              Text(
                                postTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontFamily: 'CanvaSans',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Rating stars selector (exact same as profile reviews)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Reseñar: ',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'CanvaSans'),
                      ),
                      ...List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setSheetState(() => userRating = index + 1.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              index < userRating ? Icons.star : Icons.star_border,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Attached images horizontal preview
                  if (selectedImages.isNotEmpty)
                    Container(
                      height: 50,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8, top: 4),
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(selectedImages[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setSheetState(() => selectedImages.removeAt(index)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black54,
                                    ),
                                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  // Input bar container (matches reviews_section.dart)
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Botón de más (+) / galería
                        GestureDetector(
                          onTap: (isUploading || selectedImages.length >= 5)
                              ? null
                              : () async {
                                  try {
                                    final List<XFile> files = await _picker.pickMultiImage();
                                    if (files.isNotEmpty) {
                                      setSheetState(() {
                                        selectedImages.addAll(files.map((e) => File(e.path)));
                                        if (selectedImages.length > 5) {
                                          selectedImages = selectedImages.sublist(0, 5);
                                        }
                                      });
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error al seleccionar fotos: $e')),
                                      );
                                    }
                                  }
                                },
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: selectedImages.length >= 5 ? Colors.grey.shade200 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.add_photo_alternate,
                                color: selectedImages.length >= 5 ? Colors.grey : Colors.black,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        // Campo de texto
                        Expanded(
                          child: TextField(
                            controller: reviewController,
                            enabled: !isUploading,
                            style: const TextStyle(fontSize: 14, color: Colors.black, fontFamily: 'CanvaSans'),
                            decoration: const InputDecoration(
                              hintText: 'Escribe tu reseña aquí...',
                              hintStyle: TextStyle(
                                color: Color(0xFFAAAAAA),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'CanvaSans',
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            ),
                          ),
                        ),
                        // Botón de enviar (avión de papel celeste #00A8E8)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: isUploading
                              ? const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A8E8)),
                                  ),
                                )
                              : IconButton(
                                  icon: Transform.rotate(
                                    angle: -0.785398, // ~45 grados en radianes
                                    child: const Icon(
                                      Icons.send,
                                      color: Color(0xFF00A8E8),
                                      size: 22,
                                    ),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  onPressed: () async {
                                    if (reviewController.text.trim().isEmpty || currentUid.isEmpty) {
                                      return;
                                    }
                                    setSheetState(() => isUploading = true);
                                    String? imageUrl;
                                    List<String> imageUrls = [];

                                    try {
                                      if (selectedImages.isNotEmpty) {
                                        for (var i = 0; i < selectedImages.length; i++) {
                                          final String fileName =
                                              '${currentUid}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                                          final ref = FirebaseStorage.instance
                                              .ref()
                                              .child('reviews')
                                              .child(fileName);
                                          await ref.putFile(selectedImages[i]);
                                          final url = await ref.getDownloadURL();
                                          imageUrls.add(url);
                                        }
                                        imageUrl = imageUrls.first;
                                      }

                                      await FirestoreService().addReview(
                                        reviewerId: currentUid,
                                        targetUserId: peerId,
                                        rating: userRating,
                                        text: reviewController.text.trim(),
                                        category: category ?? 'General',
                                        itemReviewed: postTitle ?? 'Publicación',
                                        imageUrl: imageUrl,
                                        imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
                                      );

                                      if (bottomSheetContext.mounted) {
                                        Navigator.pop(bottomSheetContext);
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('¡Reseña publicada con éxito!')),
                                        );
                                      }
                                    } catch (e) {
                                      setSheetState(() => isUploading = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error al enviar reseña: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                        ),
                      ],
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

  void _handleMarkAsSold(String? postId) {
    if (postId == null || postId.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Marcar como vendido?', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'CanvaSans', fontSize: 16)),
        content: const Text(
          'La publicación se marcará como vendida y dejará de aparecer disponible para otros usuarios.',
          style: TextStyle(fontSize: 13, fontFamily: 'CanvaSans'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontFamily: 'CanvaSans')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0094FF),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('publications').doc(postId).update({
                  'isSold': true,
                  'status': 'sold',
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Publicación marcada como vendida')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'CanvaSans')),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          _formatHeaderDate(date),
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'CanvaSans',
          ),
        ),
      ),
    );
  }

  String _formatHeaderDate(DateTime dt) {
    const months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
    final monthStr = months[dt.month - 1];
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'P.M.' : 'A.M.';
    return '${dt.day} $monthStr, $hour12:$minuteStr $ampm';
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

  Widget _buildMessage(
    DocumentSnapshot doc,
    bool isMe,
    String? peerAvatar,
    bool showAvatar,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final String type = data['type'] ?? 'text';
    final String text = data['text']?.toString() ?? '';

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
                  fontFamily: 'CanvaSans',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _translations[doc.id]!,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'CanvaSans',
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
                  style: const TextStyle(color: Colors.black87, fontSize: 14.5, fontFamily: 'CanvaSans'),
                ),
              ),
            ],
          );
        }
      } else {
        content = Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black,
            fontSize: 14.5,
            fontFamily: 'CanvaSans',
            height: 1.25,
          ),
        );
      }
    }

    final bool isImage = type == 'image';

    if (isMe) {
      return GestureDetector(
        onLongPress: () => _showMessageOptions(doc, isMe),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2.5),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: isImage ? Colors.transparent : const Color(0xFF0094FF),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: isImage
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
            child: content,
          ),
        ),
      );
    } else {
      return GestureDetector(
        onLongPress: () => _showMessageOptions(doc, isMe),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (showAvatar)
                Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0094FF), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: (peerAvatar != null && peerAvatar.isNotEmpty)
                        ? CachedNetworkImageProvider(peerAvatar)
                        : null,
                    child: (peerAvatar == null || peerAvatar.isEmpty)
                        ? const Icon(Icons.person, size: 14, color: Colors.grey)
                        : null,
                  ),
                )
              else
                const SizedBox(width: 32 + 8),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isImage ? Colors.transparent : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: isImage
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      );
    }
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
          borderRadius: BorderRadius.circular(10),
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

        return SocialIconBox(
          asset: iconPath,
          size: 36,
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
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
    _player.durationStream.listen((d) {
      if (d != null && mounted) setState(() => duration = d);
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => position = p);
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => isPlaying = false);
      }
    });
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
              try {
                if (widget.url.startsWith('http')) {
                  await _player.setUrl(widget.url);
                } else {
                  await _player.setFilePath(widget.url);
                }
                await _player.play();
                setState(() => isPlaying = true);
              } catch (_) {}
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
