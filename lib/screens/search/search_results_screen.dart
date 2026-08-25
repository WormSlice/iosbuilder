import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/algolia_service.dart';
import '../../widgets/post_card.dart';
import '../../services/location_service.dart';
import '../../widgets/liquid_glass_filter_modal.dart';
import '../../widgets/location_picker/location_bottom_sheet.dart';

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
  late final TextEditingController _searchController;
  late String _currentQuery;

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  String? _error;
  int _totalHits = 0;
  String _selectedSort = 'relevancia';

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.query;
    _searchController = TextEditingController(text: widget.query);
    _fetchResults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final city = _locationService.currentCity;
      final isBarterCategory = widget.category != null &&
          (widget.category!.toLowerCase() == 'trueques' ||
              widget.category!.toLowerCase() == 'barter' ||
              widget.category!.toLowerCase() == 'trueque');

      final result = await _algolia.searchPosts(
        _currentQuery,
        city: city != null && city != 'Todo' && !city.toLowerCase().contains('todo') ? city : null,
        filter: widget.category != null
            ? (isBarterCategory ? {'category': 'trueques'} : {'category': widget.category})
            : null,
        limit: 60,
      );

      List<Map<String, dynamic>> hits = result.hits.map((h) => h.toJson()).toList();

      if (hits.isEmpty) {
        hits = await _firestoreFallback(_currentQuery, widget.category);
      }

      // Strict location filter fallback if present
      if (city != null && city != 'Todo' && !city.toLowerCase().contains('todo')) {
        final targetCity = city.toLowerCase().trim();
        hits = hits.where((h) {
          final loc = (h['location'] ?? h['city'] ?? h['ubicacion'] ?? h['ubicación'] ?? '').toString().toLowerCase();
          return loc.contains(targetCity);
        }).toList();
      }

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
          _totalHits = hits.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      try {
        final fallbackHits = await _firestoreFallback(_currentQuery, widget.category);
        if (mounted) {
          setState(() {
            _results = fallbackHits;
            _totalHits = fallbackHits.length;
            _isLoading = false;
          });
        }
      } catch (fallbackErr) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _firestoreFallback(String query, String? category) async {
    try {
      Query<Map<String, dynamic>> dbQuery = FirebaseFirestore.instance.collection('posts');
      final isBarter = category != null &&
          (category.toLowerCase() == 'trueques' ||
              category.toLowerCase() == 'barter' ||
              category.toLowerCase() == 'trueque');

      if (category != null && category.isNotEmpty && !isBarter) {
        dbQuery = dbQuery.where('category', isEqualTo: category.toLowerCase());
      }
      final snap = await dbQuery.limit(80).get();
      final qLower = query.toLowerCase().trim();
      final city = _locationService.currentCity;

      return snap.docs
          .map((doc) {
            final data = doc.data();
            data['objectID'] = doc.id;
            data['id'] = doc.id;
            return data;
          })
          .where((data) {
            if (isBarter) {
              final isBarterPost = data['isBarter'] == true ||
                  data['barterMode'] == true ||
                  data['acceptsTrade'] == true ||
                  data['type'] == 'barter' ||
                  data['category'] == 'trueques' ||
                  (data['trueque']?.toString().toLowerCase().startsWith('s') ?? false);
              if (!isBarterPost) return false;
            }

            if (city != null && city != 'Todo' && !city.toLowerCase().contains('todo')) {
              final loc = (data['location'] ?? data['city'] ?? data['ubicacion'] ?? '').toString().toLowerCase();
              if (!loc.contains(city.toLowerCase().trim())) return false;
            }

            if (qLower.isEmpty) return true;
            final title = (data['title'] ?? '').toString().toLowerCase();
            final desc = (data['description'] ?? '').toString().toLowerCase();
            final loc = (data['location'] ?? data['city'] ?? '').toString().toLowerCase();
            final cat = (data['category'] ?? '').toString().toLowerCase();
            return title.contains(qLower) || desc.contains(qLower) || loc.contains(qLower) || cat.contains(qLower);
          })
          .toList();
    } catch (e) {
      return [];
    }
  }

  double _numVal(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().replaceAll('.', '').replaceAll(',', '')) ?? 0;
  }

  String _getImageUrl(Map<String, dynamic> d) {
    final direct = d['imageUrl'] ??
        d['image'] ??
        d['coverUrl'] ??
        d['coverImage'] ??
        d['portada'] ??
        d['foto'] ??
        d['thumbnail'];
    if (direct != null && direct.toString().isNotEmpty) return direct.toString();

    final dImages = d['images'] ?? d['imageUrls'] ?? d['media'] ?? d['photos'] ?? d['pictures'];
    if (dImages is List && dImages.isNotEmpty) {
      final first = dImages.first;
      if (first != null && first.toString().isNotEmpty) return first.toString();
    } else if (dImages is Map && dImages.isNotEmpty) {
      final first = dImages.values.first;
      if (first != null && first.toString().isNotEmpty) return first.toString();
    }
    return '';
  }

  void _openLocationPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: LocationBottomSheet(currentLocation: _locationService.currentCity),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (mounted) {
        _locationService.setCurrentCity(result);
        _fetchResults();
      }
    }
  }

  void _openFilterModal() {
    LiquidGlassFilterModal.show(
      context: context,
      currentSort: _selectedSort,
      currentCity: _locationService.currentCity ?? 'Todo',
      onApply: (selectedSort, selectedCity) {
        setState(() {
          _selectedSort = selectedSort;
        });
        _fetchResults();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCity = _locationService.currentCity ?? 'Todo';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 38,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFEFEF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              setState(() {
                _currentQuery = value.trim();
              });
              _fetchResults();
            },
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.black,
            ),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: widget.category != null ? 'Buscar en ${widget.category}...' : '¿Qué estás buscando?',
              hintStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.grey,
              ),
              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0094FF)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _currentQuery = '';
                        });
                        _fetchResults();
                      },
                    )
                  : null,
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFF0094FF)),
            onPressed: _openFilterModal,
            tooltip: 'Filtros',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _openLocationPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF90CAF9), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 13, color: Color(0xFF0094FF)),
                        const SizedBox(width: 4),
                        Text(
                          currentCity,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0094FF),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF0094FF)),
                      ],
                    ),
                  ),
                ),
                if (!_isLoading)
                  Text(
                    '$_totalHits resultados',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontFamily: 'Poppins',
                    ),
                  ),
              ],
            ),
          ),
        ),
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
