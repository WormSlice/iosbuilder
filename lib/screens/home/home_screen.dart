import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/section_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/connect_app_bar.dart';
import '../../widgets/post_card.dart';
import '../../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/location_service.dart';
import '../../services/algolia_sync_service.dart';
import '../../widgets/location_picker/location_bottom_sheet.dart';

/// Pantalla principal del Marketplace.
/// 
/// Gestiona el filtrado por categorías y ubicación, y muestra las publicaciones
/// en una cuadrícula o carruseles.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tabs = const [
    'Todo',
    'Productos',
    'Vehículos',
    'Propiedades',
    'Empleos',
    'Servicios',
    'Mascotas',
    'Trueques',
    'Alquiler',
  ];
  int _selected = 0;
  final _service = FirestoreService();
  bool _preloaded = false;
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadPreviewImages();
      _initLocation();
      _syncAlgolia();
    });
  }

  /// Inicializa la ubicación del usuario al cargar la pantalla.
  Future<void> _initLocation() async {
    final loc = LocationService();
    if (loc.currentCity == null) {
      await loc.updateCurrentLocation();
    }
    if (mounted) {
      setState(() {
        _selectedLocation = loc.currentCity;
      });
    }
  }

  Future<void> _syncAlgolia() async {
    try {
      await AlgoliaSyncService().syncAll();
    } catch (e) {
      debugPrint('Error syncing Meilisearch: $e');
    }
  }

  /// Muestra el nuevo panel inferior de selección de ubicación.
  /// 
  /// Reemplaza el diálogo anterior por un BottomSheet moderno que integra
  /// mapa, búsqueda e historial.
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
          child: LocationBottomSheet(currentLocation: _selectedLocation),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (mounted) {
        LocationService().setCurrentCity(result);
        setState(() {
          _selectedLocation = result;
        });
      }
    }
  }

  /// Precarga imágenes de vista previa para mejorar la fluidez de la UI.
  Future<void> _preloadPreviewImages() async {
    if (_preloaded) return;
    try {
      final urls = await _service.recentPreviewImages(limit: 15);
      for (final u in urls) {
        await precacheImage(NetworkImage(u), context);
      }
      _preloaded = true;
    } catch (_) {
      // silencioso
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ConnectAppBar(
        showSearch: true,
      ),
      body: Builder(
        builder: (context) {
          final isFiltered = _selected != 0;
          final categoryLabel = _tabs[_selected].toLowerCase();

          String typeFilter = '';
          bool useType = false;
          if (isFiltered) {
            switch (categoryLabel) {
              case 'productos':
              case 'servicios':
              case 'empleos':
              case 'propiedades':
              case 'mascotas':
                typeFilter = categoryLabel;
                useType = false;
                break;
              case 'vehículos':
              case 'vehiculos':
                typeFilter = 'vehículos';
                useType = false;
                break;
              case 'alquiler':
                typeFilter = 'rental';
                useType = true;
                break;
              case 'trueques':
                typeFilter = 'barter';
                useType = true;
                break;
            }
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _service.marketplaceConfigStream(),
            builder: (context, configSnapshot) {
              final bool isHidden =
                  configSnapshot.hasData &&
                  (configSnapshot.data!.data()?['hideAllPosts'] ?? false);

              if (isHidden) {
                return const Center(
                  child: EmptyState(
                    title: 'Mercado en mantenimiento',
                    icon: Icons.pause_circle_outline,
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    // This forces a rebuild of the widget, re-triggering the StreamBuilder/FutureBuilder
                  });
                  await Future.delayed(const Duration(seconds: 1));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: List.generate(_tabs.length, (i) {
                            final selected = _selected == i;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _selected = i),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFF0094FF)
                                        : const Color(0xFFE5E5E5),
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                  child: Text(
                                    _tabs[i],
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: selected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                  if (!isFiltered) ...[
                    SliverToBoxAdapter(
                      child: _CategoryCarousel(
                        title: 'Productos',
                        showLocation: true,
                        currentLocation: _selectedLocation,
                        onLocationTap: _showLocationPicker,
                        category: 'productos',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _CategoryCarousel(
                        title: 'Vehículos',
                        currentLocation: _selectedLocation,
                        onLocationTap: _showLocationPicker,
                        category: 'vehículos',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _CategoryCarousel(
                        title: 'Propiedades',
                        currentLocation: _selectedLocation,
                        onLocationTap: _showLocationPicker,
                        category: 'propiedades',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _CategoryCarousel(
                        title: 'Empleos',
                        currentLocation: _selectedLocation,
                        onLocationTap: _showLocationPicker,
                        category: 'empleos',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _CategoryCarousel(
                        title: 'Servicios',
                        currentLocation: _selectedLocation,
                        onLocationTap: _showLocationPicker,
                        category: 'servicios',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _CategoryCarousel(
                        title: 'Mascotas',
                        currentLocation: _selectedLocation,
                        onLocationTap: _showLocationPicker,
                        category: 'mascotas',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _CategoryCarousel(
                        title: 'Trueques',
                        currentLocation: _selectedLocation,
                        onLocationTap: _showLocationPicker,
                        type: 'barter',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _CategoryCarousel(
                        title: 'Alquiler',
                        currentLocation: _selectedLocation,
                        onLocationTap: _showLocationPicker,
                        type: 'rental',
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  ],
                  if (!isFiltered)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'Podría interesarte',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: isFiltered
                          ? _service.postsByCategoryStream(
                              type: useType ? typeFilter : null,
                              category: !useType ? typeFilter : null,
                            )
                          : _service.postsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const EmptyState(
                            title: 'Error al cargar datos desde Firestore',
                            icon: Icons.error_outline,
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          return const EmptyState(
                            title: 'Sin publicaciones',
                            icon: Icons.image_not_supported,
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 4,
                                  childAspectRatio: 0.8,
                                ),
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final d = docs[i].data();
                              final String title =
                                  (d['title'] ??
                                          d['name'] ??
                                          d['nombre'] ??
                                          d['titulo'] ??
                                          '')
                                      .toString();
                              final String price =
                                  (d['price'] ?? d['precio'] ?? d['amount'] ?? '')
                                      .toString();
                              final String location =
                                  (d['location'] ??
                                          d['ubicacion'] ??
                                          d['ubicación'] ??
                                          d['city'] ??
                                          d['address'] ??
                                          '')
                                      .toString();
                              String? image =
                                  (d['imageUrl'] ??
                                          d['image'] ??
                                          d['coverUrl'] ??
                                          d['portada'] ??
                                          d['foto'] ??
                                          d['thumbnail'])
                                      ?.toString();
                              if (image == null) {
                                final images = d['images'];
                                if (images is List && images.isNotEmpty) {
                                  final first = images.first;
                                  if (first is String) image = first;
                                }
                              }
                              return PostCard(
                                imageUrl: image,
                                title: title,
                                price: price,
                                location: location,
                                postId: docs[i].id,
                                userId: (d['userId'] ?? d['uid']).toString(),
                                data: d,
                                showCategoryIcons: !isFiltered,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
}

class _CategoryCarousel extends StatefulWidget {
  final String title;
  final String? category;
  final String? type;
  final bool showLocation;
  final String? currentLocation;
  final VoidCallback? onLocationTap;

  const _CategoryCarousel({
    required this.title,
    this.category,
    this.type,
    this.showLocation = false,
    this.currentLocation,
    this.onLocationTap,
  });

  @override
  State<_CategoryCarousel> createState() => _CategoryCarouselState();
}

class _CategoryCarouselState extends State<_CategoryCarousel> {
  int _visibleCount = 6;
  double _currentPull = 0.0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().postsByCategoryStream(
        type: widget.type,
        category: widget.category,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty && !widget.showLocation) {
          return const SizedBox.shrink();
        }

        final List<Map<String, dynamic>> docList = docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();

        return _buildCarouselContent(context, docList);
      },
    );
  }

  Widget _buildCarouselContent(
    BuildContext context,
    List<Map<String, dynamic>> docs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SectionHeader(widget.title),
            if (widget.showLocation)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: widget.onLocationTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Color(0xFF0094FF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.currentLocation?.toLowerCase() == 'todo' ||
                                widget.currentLocation?.toLowerCase().contains(
                                      'todo',
                                    ) ==
                                    true ||
                                widget.currentLocation?.toLowerCase().contains(
                                      'mostrar',
                                    ) ==
                                    true
                            ? 'Todo'
                            : '${widget.currentLocation ?? 'Buscando...'} • ${LocationService().currentRadius.toInt()} KM',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0094FF),
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (docs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Text(
              'No hay publicaciones en esta ubicación',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
          )
        else
          SizedBox(
            height: 170,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      final metrics = notification.metrics;
                      if (metrics.pixels > metrics.maxScrollExtent) {
                        setState(() {
                          _currentPull = metrics.pixels - metrics.maxScrollExtent;
                        });
                        // Si tira más de 60px, cargamos 6 más
                        if (_currentPull > 60) {
                          setState(() {
                            _visibleCount += 6;
                            _currentPull = 0.0;
                          });
                        }
                      } else {
                        if (_currentPull != 0) {
                          setState(() {
                            _currentPull = 0.0;
                          });
                        }
                      }
                    } else if (notification is ScrollEndNotification) {
                      setState(() {
                        _currentPull = 0.0;
                      });
                    }
                    return false;
                  },
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    // Mostramos solo la cantidad visible actual
                    itemCount: docs.isEmpty
                        ? 0
                        : (_visibleCount > docs.length ? docs.length : _visibleCount),
                    cacheExtent: 3000,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (context, i) {
                      final d = docs[i % (docs.length)];
                      final String title =
                          (d['title'] ??
                                  d['name'] ??
                                  d['nombre'] ??
                                  d['titulo'] ??
                                  '')
                              .toString();
                      final String price =
                          (d['price'] ??
                                  d['salary'] ??
                                  d['precio'] ??
                                  d['amount'] ??
                                  '0')
                              .toString();
                      final String location =
                          (d['location'] ??
                                  d['ubicacion'] ??
                                  d['ubicación'] ??
                                  d['city'] ??
                                  d['ciudad'] ??
                                  d['address'] ??
                                  '')
                              .toString();
                      String? image =
                          (d['imageUrl'] ??
                                  d['image'] ??
                                  d['coverUrl'] ??
                                  d['portada'] ??
                                  d['foto'] ??
                                  d['thumbnail'])
                              ?.toString();
                      if (image == null) {
                        final images = d['images'];
                        if (images is List && images.isNotEmpty) {
                          final first = images.first;
                          if (first is String) image = first;
                        }
                      }
                      return SizedBox(
                        width: 110,
                        child: PostCard(
                          imageUrl: image,
                          title: title,
                          price: price,
                          location: location,
                          postId: d['id'].toString(),
                          userId: (d['userId'] ?? d['uid']).toString(),
                          data: d,
                        ),
                      );
                    },
                  ),
                ),
                // Indicador de carga estilo sistema (flotante y dinámico)
                if (_visibleCount < docs.length && _currentPull > 5)
                  Positioned(
                    right: -40 + (_currentPull.clamp(0, 70)),
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: (_currentPull / 60).clamp(0, 1),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: (_currentPull / 60).clamp(0, 0.9),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF0094FF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
