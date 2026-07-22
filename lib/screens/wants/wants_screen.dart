import 'package:flutter/material.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../services/algolia_service.dart';
import '../../services/location_service.dart';
import '../../models/want.dart';
import 'widgets/want_card.dart';
import 'widgets/publish_want_panel.dart';
import 'want_detail_screen.dart';
import '../../widgets/location_picker/location_bottom_sheet.dart';

class WantsScreen extends StatefulWidget {
  const WantsScreen({super.key});

  @override
  State<WantsScreen> createState() => _WantsScreenState();
}

class _WantsScreenState extends State<WantsScreen>
    with SingleTickerProviderStateMixin {
  late final CategorySelectionModel model;
  final _service = FirestoreService();
  final _algoliaService = AlgoliaService();
  final _locationService = LocationService();

  List<Map<String, dynamic>> _searchHits = [];
  bool _isAlgoliaLoading = false;

  bool _isSearching = false;
  bool _isMyPostsMode = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isSelectionMode = false;
  final List<String> _selectedIds = [];

  @override
  void initState() {
    super.initState();
    model = CategorySelectionModel();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (_locationService.currentCity == null) {
      await _locationService.updateCurrentLocation();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _isSearching = false;
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.unfocus();
      } else {
        _isSearching = true;
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _showLocationPicker() async {
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
        setState(() {});
      }
    }
  }

  void _exitSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar publicaciones'),
        content: Text(
          '¿Seguro que deseas eliminar ${_selectedIds.length} publicación(es)? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (String id in _selectedIds) {
      try {
        await FirebaseFirestore.instance.collection('wants').doc(id).delete();
      } catch (e) {
        debugPrint('Error deleting want $id: $e');
      }
    }

    _exitSelection();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Eliminadas exitosamente')));
    }
  }

  Future<void> _toggleVisibilitySelected(bool hide) async {
    for (String id in _selectedIds) {
      try {
        await FirebaseFirestore.instance.collection('wants').doc(id).update({
          'status': hide ? 'hidden' : 'active',
        });
      } catch (e) {
        debugPrint('Error updating visibility $id: $e');
      }
    }
    _exitSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hide ? 'Publicaciones ocultadas' : 'Publicaciones ahora visibles',
          ),
        ),
      );
    }
  }

  void _showPublishPanel(BuildContext context, {Want? want}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        if (want != null) {
          return PublishWantPanel(
            wantId: want.id,
            initialData: want.toMap(),
            initialCategory: want.category,
          );
        }
        return PublishWantPanel(initialCategory: model.selectedCategory);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CategorySelectionModel>.value(
      value: model,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(0),
            child: AppBar(
              backgroundColor: const Color(0xFFD9D9D9),
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
            ),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFD9D9D9),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: const Text(
                    'Publica lo que necesitas y recibe propuestas',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFEEEEEE),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0094FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => _showPublishPanel(context),
                                      child: const Center(
                                        child: Text(
                                          'Publicar',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _isMyPostsMode = !_isMyPostsMode;
                                  _exitSelection();
                                }),
                                child: Container(
                                  width: 44,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _isMyPostsMode
                                        ? const Color(0xFF0094FF)
                                        : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _isMyPostsMode
                                          ? const Color(0xFF0094FF)
                                          : const Color(0xFFEEEEEE),
                                    ),
                                  ),
                                  child: Icon(
                                    _isMyPostsMode
                                        ? Icons.edit_note
                                        : Icons.person_outline,
                                    color: _isMyPostsMode
                                        ? Colors.white
                                        : Colors.black54,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _toggleSearch,
                                  child: Center(
                                    child: Image.asset(
                                      'imgenes/BUSCAR.png',
                                      width: 32,
                                      height: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_isSearching)
                            TapRegion(
                              onTapOutside: (event) {
                                if (_isSearching &&
                                    _searchController.text.isEmpty) {
                                  _toggleSearch();
                                }
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_back_ios_new,
                                        size: 18,
                                        color: Colors.black54,
                                      ),
                                      onPressed: _toggleSearch,
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        focusNode: _searchFocusNode,
                                        onChanged: (val) async {
                                          setState(() {
                                            _searchQuery = val;
                                          });
                                          if (val.length > 2) {
                                            setState(
                                              () => _isAlgoliaLoading = true,
                                            );
                                            final results = await _algoliaService
                                                .searchWants(
                                                  val,
                                                  city: _locationService
                                                      .currentCity,
                                                );
                                            if (mounted) {
                                              setState(() {
                                                _searchHits = results.hits.map((h) => h.toJson()).toList();
                                                _isAlgoliaLoading = false;
                                              });
                                            }
                                          } else {
                                            setState(() {
                                              _searchHits = [];
                                              _isAlgoliaLoading = false;
                                            });
                                          }
                                        },
                                        decoration: const InputDecoration(
                                          hintText: 'Buscar...',
                                          hintStyle: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                          ),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    if (_searchController.text.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.black54,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                        },
                                      ),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFEEEEEE),
                ),
                const SizedBox(height: 4),
                Consumer<CategorySelectionModel>(
                  builder: (context, categoryModel, _) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: categoryModel.categories.map((category) {
                          final selected =
                              category == categoryModel.selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _CategoriaButton(
                              text: category,
                              selected: selected,
                              onTap: () =>
                                  categoryModel.selectCategory(category),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: Colors.black,
                            ),
                            children: [
                              TextSpan(text: 'ESTOY BUSCANDO, LO TIENES '),
                              TextSpan(
                                text: '?',
                                style: TextStyle(
                                  fontSize: 21,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _showLocationPicker,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFF0094FF),
                              size: 16,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _locationService.currentCity ?? 'Buscando...',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF0094FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Consumer<CategorySelectionModel>(
                    builder: (context, catModel, _) {
                      if (_isMyPostsMode) {
                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: _service.wantsByUserStream(
                            FirebaseAuth.instance.currentUser?.uid ?? '',
                          ),
                          builder: (context, streamSnapshot) {
                            if (!streamSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final docs = streamSnapshot.data!.docs.toList();
                            docs.sort((a, b) {
                              final ta = a.data()['createdAt'];
                              final tb = b.data()['createdAt'];
                              if (ta is Timestamp && tb is Timestamp) {
                                return tb.compareTo(ta);
                              }
                              return 0;
                            });
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text('No hay solicitudes aún'),
                              );
                            }
                            return _buildList(docs);
                          },
                        );
                      }

                      if (_isSearching && _searchQuery.isNotEmpty) {
                        if (_isAlgoliaLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (_searchHits.isEmpty) {
                          return const Center(
                            child: Text('No se encontraron resultados'),
                          );
                        }
                        return _buildList(_searchHits);
                      }

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: catModel.selectedCategory == 'Para ti'
                            ? _service.wantsStream()
                            : _service.wantsByCategoryStream(
                                catModel.selectedCategory.toLowerCase(),
                              ),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text('Error al cargar datos de Firestore'),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data!.docs.toList();
                          docs.sort((a, b) {
                            final ta = a.data()['createdAt'];
                            final tb = b.data()['createdAt'];
                            if (ta is Timestamp && tb is Timestamp) {
                              return tb.compareTo(ta);
                            }
                            return 0;
                          });

                          if (docs.isEmpty) {
                            return const Center(
                              child: Text(
                                'No hay solicitudes aún',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }

                          return _buildList(docs);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(List<dynamic> docs) {
    return Column(
      children: [
        if (_isSelectionMode)
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelection,
                ),
                Text(
                  '${_selectedIds.length} seleccionados',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_selectedIds.length == 1)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    tooltip: 'Editar publicación',
                    onPressed: () {
                      final String id = _selectedIds.first;
                      final wantData = docs.firstWhere(
                        (doc) =>
                            (doc is DocumentSnapshot ? doc.id : doc['id']) ==
                            id,
                      );
                      final want = wantData is DocumentSnapshot
                          ? Want.fromFirestore(
                              wantData
                                  as DocumentSnapshot<Map<String, dynamic>>,
                            )
                          : Want.fromMap(
                              wantData as Map<String, dynamic>,
                              wantData['id'].toString(),
                            );

                      _showPublishPanel(context, want: want);
                      _exitSelection();
                    },
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.visibility),
                  tooltip: 'Visibilidad',
                  onSelected: (val) => _toggleVisibilitySelected(val == 'hide'),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'hide',
                      child: Text('Ocultar seleccionadas'),
                    ),
                    const PopupMenuItem(
                      value: 'show',
                      child: Text('Mostrar seleccionadas'),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Eliminar seleccionadas',
                  onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 0, bottom: 20),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF5F5F5),
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, i) {
              final d = docs[i];
              final want = d is DocumentSnapshot
                  ? Want.fromFirestore(
                      d as DocumentSnapshot<Map<String, dynamic>>,
                    )
                  : Want.fromMap(
                      d is Map<String, dynamic> ? d : (d as dynamic).data(),
                      (d is DocumentSnapshot ? d.id : d['id']).toString(),
                    );

              final bool isSelected = _selectedIds.contains(want.id);
              bool isHidden = false;
              if (d is DocumentSnapshot) {
                final data = d.data() as Map<String, dynamic>?;
                isHidden = data?['status'] == 'hidden';
              } else if (d is Map<String, dynamic>) {
                isHidden = d['status'] == 'hidden';
              }

              return GestureDetector(
                onLongPress: _isMyPostsMode
                    ? () {
                        if (!_isSelectionMode) {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedIds.add(want.id);
                          });
                        }
                      }
                    : null,
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(want.id);
                  } else if (_isMyPostsMode) {
                    _showPublishPanel(context, want: want);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WantDetailScreen(want: want),
                      ),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.identity()..scale(isSelected ? 0.96 : 1.0),
                  decoration: BoxDecoration(
                    border: isSelected
                        ? Border.all(color: const Color(0xFF0094FF), width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      AbsorbPointer(
                        absorbing: _isSelectionMode,
                        child: Opacity(
                          opacity: isHidden && !isSelected ? 0.5 : 1.0,
                          child: WantCard(want: want),
                        ),
                      ),
                      if (isHidden && !_isSelectionMode)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'Oculto',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (_isSelectionMode)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isSelected ? 1.0 : 0.6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0094FF)
                                    : Colors.black38,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CategorySelectionModel extends ChangeNotifier {
  String _selectedCategory = 'Para ti';
  final List<String> _categories = [
    'Para ti',
    'Productos',
    'Servicios',
    'Empleos',
    'Vehículos',
    'Inmuebles',
    'Mascotas',
    'Trueques',
    'Alquiler',
    'Eventos',
  ];

  String get selectedCategory => _selectedCategory;
  List<String> get categories => _categories;
  void selectCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }
}

class _CategoriaButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _CategoriaButton({
    required this.text,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0094FF) : const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class QueryDocumentSnapshotProxy {
  final Map<String, dynamic> hit;
  QueryDocumentSnapshotProxy(this.hit);

  String get id => hit['id'].toString();
  Map<String, dynamic> data() => hit;
  dynamic operator [](String key) => hit[key];
}
