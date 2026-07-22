import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../services/ai_search_service.dart';

class AIIndexingScreen extends StatefulWidget {
  const AIIndexingScreen({super.key});

  @override
  State<AIIndexingScreen> createState() => _AIIndexingScreenState();
}

class _AIIndexingScreenState extends State<AIIndexingScreen> {
  final _firestoreService = FirestoreService();
  final _aiSearchService = AISearchService();

  bool _scanning = false;
  int _total = 0;
  int _processed = 0;
  final List<String> _logs = [];

  Future<void> _startScanning() async {
    setState(() {
      _scanning = true;
      _logs.clear();
      _logs.add('Iniciando escaneo...');
    });

    try {
      final snapshot = await _firestoreService.getAllPosts();
      _total = snapshot.docs.length;
      setState(() {
        _logs.add('Total publicaciones encontradas: \$_total');
      });

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Skip if already tagged (optional, for now force update or check existence)
        if (data['aiTags'] != null && (data['aiTags'] as List).isNotEmpty) {
          // setState(() {
          //   _processed++;
          //   _logs.insert(0, 'Skipped: \${doc.id} (Ya tiene tags)');
          // });
          // continue;
        }

        String? imageUrl = (data['imageUrl'] ?? data['image'])?.toString();
        if (imageUrl == null) {
          final images = data['images'];
          if (images is List && images.isNotEmpty) {
            imageUrl = images.first?.toString();
          }
        }

        if (imageUrl != null && imageUrl.isNotEmpty) {
          setState(
            () => _logs.insert(
              0,
              'Analizando: ${data['title'] ?? 'Sin titulo'}...',
            ),
          );

          final tags = await _aiSearchService.analyzeImageUrl(imageUrl);

          if (tags.isNotEmpty) {
            await _firestoreService.updatePostAiTags(doc.id, tags);
            setState(
              () => _logs.insert(0, '✅ Tags generados: \${tags.join(", ")}'),
            );
          } else {
            setState(
              () => _logs.insert(0, '⚠️ Sin tags generados para \${doc.id}'),
            );
          }
        } else {
          setState(() => _logs.insert(0, '⏩ Saltado (Sin imagen): \${doc.id}'));
        }

        setState(() {
          _processed++;
        });
      }

      setState(() => _logs.insert(0, '🎉 ¡Escaneo completado!'));
    } catch (e) {
      setState(() => _logs.insert(0, '❌ Error crítico: $e'));
    } finally {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indexador Inteligente AI'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1E1E1E),
            width: double.infinity,
            child: Column(
              children: [
                const Icon(Icons.auto_awesome, size: 48, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  'Generación de Etiquetas AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Esto escaneará todas las publicaciones, analizará sus imágenes y generará etiquetas de búsqueda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                if (_scanning)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _total == 0 ? 0 : _processed / _total,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$_processed / \$_total',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _startScanning,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar Escaneo Masivo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
