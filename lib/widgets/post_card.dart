import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/publications/vehicle_detail_screen.dart';
import '../screens/publications/product_detail_screen.dart';
import '../screens/publications/service_detail_screen.dart';
import '../screens/publications/job_detail_screen.dart';
import '../screens/publications/property_detail_screen.dart';
import '../screens/publications/pet_detail_screen.dart';
import '../screens/publications/rental_detail_screen.dart';
import '../screens/publications/barter_detail_screen.dart';

class PostCard extends StatelessWidget {
  final String? imageUrl;
  final List<dynamic>? images;
  final String title;
  final String price;
  final String location;
  final String? postId;
  final String? userId;
  final Map<String, dynamic>? data;
  final bool showCategoryIcons; // NEW

  const PostCard({
    super.key,
    this.imageUrl,
    this.images,
    required this.title,
    required this.price,
    required this.location,
    this.postId,
    this.userId,
    this.data,
    this.showCategoryIcons = false, // Default false
  });

  String _formatCop(String raw) {
    // If raw is "1000.0", take only "1000" to avoid adding an extra zero
    String processed = raw;
    if (raw.contains('.')) {
      processed = raw.split('.').first;
    } else if (raw.contains(',')) {
      processed = raw.split(',').first;
    }

    final digits = processed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return raw;
    final rev = digits.split('').reversed.toList();
    final out = <String>[];
    for (int i = 0; i < rev.length; i++) {
      out.add(rev[i]);
      if ((i + 1) % 3 == 0 && i + 1 != rev.length) {
        out.add('.');
      }
    }
    return out.reversed.join();
  }

  String _getDisplayPrice() {
    if (data == null) return '\$${_formatCop(price)}';

    final category = data!['category']?.toString().toLowerCase() ?? '';
    final type =
        data!['publicationType']?.toString().toLowerCase() ??
        data!['type']?.toString().toLowerCase() ??
        '';

    if (category.contains('masc')) {
      if (type.contains('adop')) return 'Adopción';
      if (type.contains('busca') || type.contains('perd')) return 'Se Busca';
      if (type.contains('encontr')) return 'Encontrado';
    }

    return '\$${_formatCop(price)}';
  }

  Widget? _buildCategoryIcons() {
    if (data == null) return null;

    final bool isBarterMode =
        data!['isBarter'] == true || data!['barterMode'] == true;

    if (!isBarterMode) return null;

    return Positioned(
      top: 5,
      right: 5,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Image.asset(
          'assets/iconos/AssetsCPu/trueques.png',
          width: 14,
          height: 14,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (data == null || postId == null) return;
        final category = data!['category']?.toString().toLowerCase() ?? '';

        Widget destinationScreen;
        if (category.contains('veh')) {
          destinationScreen = VehicleDetailScreen(data: data!, postId: postId!);
        } else if (category.contains('prod')) {
          destinationScreen = ProductDetailScreen(data: data!, postId: postId!);
        } else if (category.contains('serv')) {
          destinationScreen = ServiceDetailScreen(data: data!, postId: postId!);
        } else if (category.contains('empl')) {
          destinationScreen = JobDetailScreen(data: data!, postId: postId!);
        } else if (category.contains('prop')) {
          destinationScreen = PropertyDetailScreen(
            data: data!,
            postId: postId!,
          );
        } else if (category.contains('masc')) {
          destinationScreen = PetDetailScreen(data: data!, postId: postId!);
        } else if (category.contains('alq') || category.contains('rent')) {
          destinationScreen = RentalDetailScreen(data: data!, postId: postId!);
        } else if (category.contains('true') || category.contains('bart')) {
          destinationScreen = BarterDetailScreen(data: data!, postId: postId!);
        } else {
          // Defaultfallback
          destinationScreen = VehicleDetailScreen(data: data!, postId: postId!);
        }

        Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => destinationScreen));
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Builder(
                        builder: (context) {
                          String? displayUrl = imageUrl;
                          
                          // Prioridad 1: Lista de imágenes pasada por parámetro
                          if (images != null && images!.isNotEmpty) {
                            displayUrl = images!.first.toString();
                          }
                          
                          // Prioridad 2: Buscar en el mapa de datos si aún no hay URL
                          if (displayUrl == null || displayUrl.isEmpty) {
                            if (data != null) {
                              displayUrl = (data!['imageUrl'] ?? 
                                           data!['image'] ?? 
                                           data!['coverUrl'] ?? 
                                           data!['portada'] ?? 
                                           data!['foto'] ?? 
                                           data!['thumbnail'])?.toString();
                              
                              if (displayUrl == null || displayUrl.isEmpty) {
                                final dImages = data!['images'];
                                if (dImages is List && dImages.isNotEmpty) {
                                  displayUrl = dImages.first.toString();
                                }
                              }
                            }
                          }

                          if (displayUrl != null && displayUrl.isNotEmpty) {
                            return CachedNetworkImage(
                              imageUrl: displayUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: const Color(0xFFE0E0E0)),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            );
                          }
                          return Container(color: const Color(0xFFE0E0E0));
                        },
                      ),
                    ),
                  ),
                  if (_buildCategoryIcons() != null) _buildCategoryIcons()!,
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 4,
                  right: 4,
                  top: 0,
                  bottom: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      _getDisplayPrice(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      data?['category']?.toString().toUpperCase() ??
                          location.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//
