import 'package:flutter/material.dart';
import '../../widgets/connect_app_bar.dart';
import 'widgets/publish_product_panel.dart';
import 'widgets/publish_service_panel.dart';
import 'widgets/publish_job_panel.dart';
import 'widgets/publish_vehicle_panel.dart';
import 'widgets/publish_property_panel.dart';
import 'widgets/publish_pet_panel.dart';
import 'widgets/publish_rental_panel.dart';
import 'widgets/publish_barter_panel.dart';

Future<void> showPublicationPanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Crear publicación',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (context, anim1, anim2) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (context, animation, secondary, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.elasticOut,
      );
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80), // Lower position
          child: ScaleTransition(scale: curve, child: const PublicationPanel()),
        ),
      );
    },
  );
}

class PostScreen extends StatelessWidget {
  const PostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ConnectAppBar(showSearch: false, showLeading: false),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80), // Lower position
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const PublicationPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PublicationPanel extends StatelessWidget {
  final String? postId;
  final Map<String, dynamic>? initialData;
  final void Function(String? imageUrl, String? postId)? onSuccess;

  const PublicationPanel({
    super.key,
    this.postId,
    this.initialData,
    this.onSuccess,
  });

  Future<void> _showPanel(BuildContext context, Widget panel) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => panel,
    );

    if (result != null && result is Map && result['success'] == true) {
      final String? imageUrl = result['imageUrl'];
      final String? createdPostId = result['postId'];
      if (onSuccess != null) {
        onSuccess!(imageUrl, createdPostId);
      } else {
        // If no callback, we assume it's in a dialog or needs a pop
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Exact width 210px as requested (Phase 5)
    const finalWidth = 210.0;

    final String? category = initialData?['category']?.toString().toLowerCase();
    final String? type = initialData?['type']?.toString().toLowerCase();

    // Mapping logic to jump straight to the correct panel during edit
    if (postId != null && initialData != null) {
      Widget? targetPanel;

      if (category != null) {
        if (category.contains('producto')) {
          targetPanel = PublishProductPanel(
            postId: postId,
            initialData: initialData,
          );
        } else if (category.contains('servicio')) {
          targetPanel = PublishServicePanel(
            postId: postId,
            initialData: initialData,
          );
        } else if (category.contains('empleo') ||
            category.contains('trabajo')) {
          targetPanel = PublishJobPanel(
            postId: postId,
            initialData: initialData,
          );
        } else if (category.contains('vehiculo')) {
          targetPanel = PublishVehiclePanel(
            postId: postId,
            initialData: initialData,
          );
        } else if (category.contains('propiedad') ||
            category.contains('inmueble')) {
          targetPanel = PublishPropertyPanel(
            postId: postId,
            initialData: initialData,
          );
        } else if (category.contains('mascota') ||
            category.contains('animal')) {
          targetPanel = PublishPetPanel(
            postId: postId,
            initialData: initialData,
          );
        } else if (category.contains('alquiler') || type == 'rental') {
          targetPanel = PublishRentalPanel(
            postId: postId,
            initialData: initialData,
          );
        } else if (category.contains('trueque') || type == 'barter') {
          targetPanel = PublishBarterPanel(
            postId: postId,
            initialData: initialData,
          );
        }
      }

      if (targetPanel != null) {
        // Return the specific panel wrapped in a Scaffold with a transparent background
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                  child: Container(color: Colors.black.withOpacity(0.6)),
                ),
              ),
              Align(alignment: Alignment.bottomCenter, child: targetPanel),
            ],
          ),
        );
      }
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: finalWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.48, // Limit height
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              postId != null ? 'Actualizar publicación' : 'Crear publicación',
              style: const TextStyle(
                fontFamily: 'Alexandria',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                const cellDim = 85.0; // Fixed square size for the frame
                return Center(
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FixedColumnWidth(cellDim),
                      1: FixedColumnWidth(cellDim),
                    },
                    children: [
                      TableRow(
                        children: [
                          _categoryCell(
                            cellDim,
                            'assets/iconos/AssetsCPu/productos.png',
                            'Productos',
                            () => _showPanel(
                              context,
                              PublishProductPanel(
                                postId: postId,
                                initialData: initialData,
                              ),
                            ),
                          ),
                          _categoryCell(
                            cellDim,
                            'assets/iconos/AssetsCPu/servicios.png',
                            'Servicios',
                            () => _showPanel(
                              context,
                              PublishServicePanel(
                                postId: postId,
                                initialData: initialData,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          _categoryCell(
                            cellDim,
                            'assets/iconos/AssetsCPu/empleos.png',
                            'Empleos',
                            () => _showPanel(
                              context,
                              PublishJobPanel(
                                postId: postId,
                                initialData: initialData,
                              ),
                            ),
                          ),
                          _categoryCell(
                            cellDim,
                            'assets/iconos/AssetsCPu/vehiculos.png',
                            'Vehículos',
                            () => _showPanel(
                              context,
                              PublishVehiclePanel(
                                postId: postId,
                                initialData: initialData,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          _categoryCell(
                            cellDim,
                            'assets/iconos/AssetsCPu/propiedades.png',
                            'Propiedades',
                            () => _showPanel(
                              context,
                              PublishPropertyPanel(
                                postId: postId,
                                initialData: initialData,
                              ),
                            ),
                          ),
                          _categoryCell(
                            cellDim,
                            'assets/iconos/AssetsCPu/mascotas.png',
                            'Mascotas',
                            () => _showPanel(
                              context,
                              PublishPetPanel(
                                postId: postId,
                                initialData: initialData,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          _categoryCell(
                            cellDim,
                            'assets/iconos/AssetsCPu/alquiler.png',
                            'Alquiler',
                            () => _showPanel(
                              context,
                              PublishRentalPanel(
                                postId: postId,
                                initialData: initialData,
                              ),
                            ),
                          ),
                          _categoryCell(
                            cellDim,
                            'assets/iconos/AssetsCPu/trueques.png',
                            'Trueques',
                            () => _showPanel(
                              context,
                              PublishBarterPanel(
                                postId: postId,
                                initialData: initialData,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryCell(
    double dim,
    String assetPath,
    String label,
    VoidCallback onTap,
  ) {
    // Reduced proportions to stay strictly within the square
    final iconBox = dim * 0.40;
    final iconSize = dim * 0.28;
    final borderRadius = 12.0; // Restored rounding for blue border
    final inset = 4.0;

    return Center(
      child: SizedBox(
        width: dim,
        height: dim,
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF4DD0E1),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(
                          10,
                        ), // Rounded square icon bg
                      ),
                      child: Center(
                        child: Image.asset(
                          assetPath,
                          width: iconSize,
                          height: iconSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
