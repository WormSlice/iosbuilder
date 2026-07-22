import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/algolia_service.dart';
import '../../widgets/post_card.dart';
import '../../services/location_service.dart';
import '../../services/search_service.dart';

/// Pantalla de resultados de busqueda basada en Algolia.
/// Soporta busqueda por texto libre, filtros por categoria,
/// tolerancia a errores de escritura y paginacion.
class SearchResultsScreen extends StatefulWidget {
  final String query;
  final String? category;

  const SearchResultsScreen({
    super.key,
    required this.query,
    this.category,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final _algolia = AlgoliaService();
  final _locationService = LocationService();

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  String? _error;
  int _totalHits = 0;
  String _selectedSort = 'relevancia';

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _algolia.searchPosts(
        widget.query,
        filter: widget.category != null ? {'category': widget.category} : null,
        limit: 60,
      );

      List<Map<String, dynamic>> hits = result.hits.map((h) => h.toJson()).toList();

      // Ordenamiento local si se necesita
      if (_selectedSort == 'precio_asc') {
        hits.sort((a, b) => _numVal(a['price']).compareTo(_numVal(b['price'])));
      } else if (_selectedSort == 'precio_desc') {
        hits.sort((a, b) => _numVal(b['price']).compareTo(_numVal(a['price'])));
      } else if (_selectedSort == 'reciente') {
        hits.sort(
          (a, b) => _numVal(b['createdAt']).compareTo(_numVal(a['createdAt'])),
        );
      }

      if (mounted) {
        setState(() {
          _results = hits;
          _totalHits = result.nbHits ?? hits.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  double _numVal(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().replaceAll('.', '').replaceAll(',', '')) ?? 0;
  }

  String _getImageUrl(Map<String, dynamic> d) {
    final img = d['imageUrl'] ?? d['image'];
    if (img != null) return img.toString();
    final imgs = d['images'];
    if (imgs is List && imgs.isNotEmpty) return imgs.first.toString();
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category != null
                  ? 'Categoría: "${widget.category}"'
                  : '"${widget.query}"',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'CanvaSans',
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!_isLoading)
              Text(
                '$_totalHits resultados · ${_locationService.currentCity ?? "Todo"}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontFamily: 'CanvaSans',
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Color(0xFF0094FF)),
            onSelected: (value) {
              setState(() => _selectedSort = value);
              _fetchResults();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'relevancia', child: Text('Por relevancia')),
              const PopupMenuItem(value: 'reciente', child: Text('Más reciente')),
              const PopupMenuItem(value: 'precio_asc', child: Text('Precio: menor a mayor')),
              const PopupMenuItem(value: 'precio_desc', child: Text('Precio: mayor a menor')),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0094FF)));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Error al buscar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'CanvaSans'),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontFamily: 'CanvaSans'),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchResults,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0094FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Sin resultados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'CanvaSans'),
            ),
            const SizedBox(height: 8),
            Text(
              'No encontramos publicaciones para\n"${widget.query}"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontFamily: 'CanvaSans'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.76,
      ),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final d = _results[i];
        return PostCard(
          imageUrl: _getImageUrl(d),
          title: d['title']?.toString() ?? '',
          price: d['price']?.toString() ?? '',
          location: d['location']?.toString() ?? d['city']?.toString() ?? '',
          postId: d['objectID']?.toString() ?? d['id']?.toString() ?? '',
          userId: d['userId']?.toString() ?? '',
          data: d,
        );
      },
    );
  }
}
