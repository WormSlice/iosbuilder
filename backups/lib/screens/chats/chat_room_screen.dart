import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isTranslating ? 'Traducción activada' : 'Traducción desactivada',
        ),
      ),
    );
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

  Future<void> _handleLocation() async {
    try {
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

      final pos = await Geolocator.getCurrentPosition();
      final link =
          'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
      _sendMessage(text: link, type: 'text');
      toggleTools();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al obtener ubicación: $e')));
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
      // Assuming social links might be stored in a 'socials' map or separate fields?
      // Based on profile header, we hardcoded icons but didn't see the data.
      // Let's assume common fields or a 'socials' map. If not present, we can't share.
      // Let's check if we can construct a nice string.

      List<String> validLinks = [];
      if (data['instagram'] != null &&
          data['instagram'].toString().isNotEmpty) {
        validLinks.add('Instagram: ${data['instagram']}');
      }
      if (data['facebook'] != null && data['facebook'].toString().isNotEmpty) {
        validLinks.add('Facebook: ${data['facebook']}');
      }
      if (data['twitter'] != null && data['twitter'].toString().isNotEmpty) {
        validLinks.add('Twitter: ${data['twitter']}');
      }
      if (data['tiktok'] != null && data['tiktok'].toString().isNotEmpty) {
        validLinks.add('TikTok: ${data['tiktok']}');
      }
      if (data['whatsapp'] != null && data['whatsapp'].toString().isNotEmpty) {
        validLinks.add('WhatsApp: ${data['whatsapp']}');
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

      String msg = "Mis redes sociales:\n${validLinks.join('\n')}";
      _sendMessage(text: msg, type: 'text');
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
          data['resumeUrl'] ??
          data['cvUrl'] ??
          data['hojaDeVida']; // Guessing field names based on common practices

      if (resumeUrl == null || resumeUrl.toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No has subido tu hoja de vida a tu perfil.'),
          ),
        );
        return;
      }

      _sendMessage(text: '$resumeUrl|||Hoja de vida', type: 'file');
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

        final String? postId = chatData['postId'];
        final String? postTitle = chatData['postTitle'];
        final String? postImage = chatData['postImage'];

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
            }

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: _buildAppBar(
                chatData,
                postId,
                postTitle,
                postImage,
                peerName,
                peerAvatar,
              ),
              body: Column(
                children: [
                  if (postId != null)
                    _buildPostBanner(chatData, peerId, peerName),
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
                          padding: const EdgeInsets.all(16),
                          itemCount: msgs.length,
                          itemBuilder: (context, i) {
                            final data = msgs[i].data() as Map<String, dynamic>;
                            final isMe = data['senderId'] == currentUid;
                            return _buildMessage(data, isMe, peerAvatar);
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
    Map<String, dynamic> chatData,
    String? postId,
    String? postTitle,
    String? postImage,
    String? peerName,
    String? peerAvatar,
  ) {
    final String title = (postId != null && postTitle != null)
        ? postTitle
        : (peerName ?? 'Chat');
    final String? avatar = (postId != null && postImage != null)
        ? postImage
        : peerAvatar;

    return AppBar(
      elevation: 1,
      backgroundColor: Colors.white,
      leading: const BackButton(color: Colors.black),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            backgroundImage: (avatar != null && avatar.isNotEmpty)
                ? CachedNetworkImageProvider(avatar)
                : null,
            child: (avatar == null || avatar.isEmpty)
                ? const Icon(Icons.person, color: Colors.grey, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (postId != null && peerName != null)
                  Text(
                    peerName,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call, color: Color(0xFF0094FF)),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildPostBanner(
    Map<String, dynamic> data,
    String? peerId,
    String? peerName,
  ) {
    final price = data['postPrice']?.toString() ?? '';
    final title = data['postTitle']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, size: 20, color: Colors.black87),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$price - $title',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Vendido',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Calificar',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[200],
              backgroundImage: data['postImage'] != null
                  ? CachedNetworkImageProvider(data['postImage'])
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            child: Text(
              'Ver perfil de ${peerName ?? 'Vendedor'}',
              style: const TextStyle(color: Colors.blue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(
    Map<String, dynamic> data,
    bool isMe,
    String? peerAvatar,
  ) {
    final String type = data['type'] ?? 'text';
    final String text = data['text']?.toString() ?? '';
    final timestamp =
        data['createdAt'] ??
        data['timestamp'] ??
        data['time'] ??
        data['sentAt'];
    String timeStr = '';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      timeStr =
          '${dt.day} ${_getMonth(dt.month)}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    Widget content;
    if (type == 'image') {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: text,
          placeholder: (context, url) => const SizedBox(
            width: 200,
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
          fit: BoxFit.cover,
        ),
      );
    } else if (type == 'voice') {
      content = AudioMessageWidget(url: text, isMe: isMe);
    } else if (type == 'file') {
      final parts = text.split('|||');
      final url = parts[0];
      final name = parts.length > 1 ? parts[1] : 'Archivo adjunto';

      content = GestureDetector(
        onTap: () async {
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: isMe ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      content = Text(
        text,
        style: TextStyle(color: isMe ? Colors.white : Colors.black87),
      );
    }

    // Determine custom styling
    final bool isImage = type == 'image';
    final EdgeInsets padding = isImage
        ? EdgeInsets.zero
        : const EdgeInsets.all(12);
    final Color color = isImage
        ? Colors.transparent
        : (isMe ? const Color(0xFF0094FF) : Colors.grey.shade200);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey[200],
                backgroundImage: (peerAvatar != null && peerAvatar.isNotEmpty)
                    ? CachedNetworkImageProvider(peerAvatar)
                    : null,
                child: (peerAvatar == null || peerAvatar.isEmpty)
                    ? const Icon(Icons.person, size: 16, color: Colors.white)
                    : null,
              ),
            if (!isMe) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: padding,
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14).copyWith(
                        bottomRight: isMe
                            ? Radius.zero
                            : const Radius.circular(14),
                        bottomLeft: isMe
                            ? const Radius.circular(14)
                            : Radius.zero,
                      ),
                    ),
                    child: content,
                  ),
                  if (timeStr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonth(int m) {
    const months = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return months[max(0, min(11, m - 1))];
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
                      IconButton(
                        icon: Icon(
                          Icons.translate,
                          size: 22,
                          color: isTranslating
                              ? const Color(0xFF0094FF)
                              : Colors.black54,
                        ),
                        onPressed: _handleTranslate,
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
