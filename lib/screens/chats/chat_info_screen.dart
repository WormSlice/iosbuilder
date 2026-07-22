import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile/profile_screen.dart';

class ChatInfoScreen extends StatefulWidget {
  final String chatId;
  final String peerId;
  final String peerName;
  final String? peerAvatar;
  final bool isPublicationChat;

  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
    this.isPublicationChat = false,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingPath;
  List<FileSystemEntity> _recordings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLocalRecordings();

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingPath = null);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadLocalRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final chatDir = Directory('${dir.path}/connect_calls/${widget.chatId}');
      if (await chatDir.exists()) {
        setState(() {
          _recordings = chatDir
              .listSync()
              .where((item) => item.path.endsWith('.m4a'))
              .toList();
        });
      }
    } catch (e) {
      print('Error cargando grabaciones: $e');
    }
  }

  Future<void> _playPauseAudio(String path) async {
    if (_playingPath == path) {
      await _audioPlayer.pause();
      setState(() => _playingPath = null);
    } else {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _playingPath = path);
    }
  }

  String _getFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Información del chat',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0094FF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0094FF),
            tabs: const [
              Tab(text: 'Multimedia'),
              Tab(text: 'Documentos'),
              Tab(text: 'Llamadas'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMultimediaTab(),
                _buildDocsTab(),
                _buildRecordingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[200],
          backgroundImage:
              (widget.peerAvatar != null && widget.peerAvatar!.isNotEmpty)
              ? CachedNetworkImageProvider(widget.peerAvatar!)
              : null,
          child: (widget.peerAvatar == null || widget.peerAvatar!.isEmpty)
              ? const Icon(Icons.person, size: 50, color: Colors.grey)
              : null,
        ),
        const SizedBox(height: 15),
        Text(
          widget.peerName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (widget.isPublicationChat)
          const Text(
            'Chat de publicación',
            style: TextStyle(color: Colors.grey),
          ),
        const SizedBox(height: 15),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: widget.peerId),
              ),
            );
          },
          icon: const Icon(Icons.person_search, color: Color(0xFF0094FF)),
          label: const Text(
            'Ver perfil completo',
            style: TextStyle(color: Color(0xFF0094FF)),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF0094FF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Divider(),
      ],
    );
  }

  Widget _buildMultimediaTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats') // Change to proper collection if needed
          .doc(widget.chatId)
          .collection('messages')
          .where('type', isEqualTo: 'image')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No hay imágenes compartidas.'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final url = data['text']?.toString() ?? '';
            return GestureDetector(
              onTap: () async {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                }
              },
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('type', isEqualTo: 'file')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No hay documentos compartidos.'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final rawText = data['text']?.toString() ?? '';
            final parts = rawText.split('|||');
            final url = parts[0];
            final name = parts.length > 1 ? parts[1] : 'Archivo';

            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF0F2F5),
                child: Icon(Icons.insert_drive_file, color: Colors.blue),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.download, color: Colors.blue),
              onTap: () async {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRecordingsTab() {
    if (_recordings.isEmpty) {
      return const Center(
        child: Text('No has grabado ninguna llamada localmente.'),
      );
    }

    return ListView.separated(
      itemCount: _recordings.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final file = File(_recordings[index].path);
        final fileName = file.path.split('/').last;
        final bool isPlaying = _playingPath == file.path;
        final size = _getFileSize(file);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isPlaying ? Colors.red : const Color(0xFFF0F2F5),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: isPlaying ? Colors.white : Colors.red,
            ),
          ),
          title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('Grabación local • $size'),
          onTap: () => _playPauseAudio(file.path),
        );
      },
    );
  }
}
