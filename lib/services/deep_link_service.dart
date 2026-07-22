import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/publications/product_detail_screen.dart';
import '../screens/publications/service_detail_screen.dart';
import '../screens/publications/property_detail_screen.dart';
import '../screens/publications/vehicle_detail_screen.dart';
import '../screens/publications/job_detail_screen.dart';
import '../screens/publications/barter_detail_screen.dart';
import '../screens/publications/pet_detail_screen.dart';
import '../screens/publications/rental_detail_screen.dart';
import '../screens/wants/want_detail_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../models/want.dart';

/// Servicio encargado de interceptar y manejar deep links tanto al inicio
/// de la aplicacion como cuando esta en segundo plano o primer plano.
///
/// Formatos de URL soportados:
///   https://connectapp.com.co/p/{postId}  - Publicacion
///   https://connectapp.com.co/w/{wantId}  - Want
///   https://connectapp.com.co/u/{userId}  - Perfil de usuario
class DeepLinkService {
  late AppLinks _appLinks;

  /// Inicializa la escucha de deep links. Debe llamarse en el widget raiz
  /// que cuente con un [BuildContext] valido y persistente.
  void init(BuildContext context) {
    _appLinks = AppLinks();

    // Captura el enlace si la app fue abierta directamente por el
    _appLinks.getInitialLink().then((uri) {
      if (uri != null && context.mounted) {
        _handleDeepLink(context, uri);
      }
    });

    // Escucha los enlaces entrantes cuando la app esta en segundo
    // plano o en primer plano.
    _appLinks.uriLinkStream.listen(
      (uri) {
        if (context.mounted) {
          _handleDeepLink(context, uri);
        }
      },
      onError: (err) {
        debugPrint('DeepLinkService stream error: $err');
      },
    );
  }

  Future<void> _handleDeepLink(BuildContext context, Uri uri) async {
    final pathSegments = uri.pathSegments;
    if (pathSegments.length < 2) return;

    final type = pathSegments[0]; // 'p', 'w' o 'u'
    final id = pathSegments[1];

    switch (type) {
      case 'p':
        await _openPublication(context, id);
        break;
      case 'w':
        await _openWant(context, id);
        break;
      case 'u':
        await _openProfile(context, id);
        break;
      default:
        debugPrint('DeepLinkService: tipo de enlace no reconocido "$type"');
    }
  }

  /// Navega a la pantalla de detalle de una publicacion segun su categoria.
  Future<void> _openPublication(BuildContext context, String postId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();

      if (!doc.exists || !context.mounted) return;

      final data = doc.data()!;
      final category = data['category']?.toString().toLowerCase() ?? '';

      Widget destination;
      if (category == 'servicios') {
        destination = ServiceDetailScreen(data: data, postId: postId);
      } else if (category == 'inmuebles') {
        destination = PropertyDetailScreen(data: data, postId: postId);
      } else if (category == 'vehiculos' || category == 'vehículos') {
        destination = VehicleDetailScreen(data: data, postId: postId);
      } else if (category == 'empleos') {
        destination = JobDetailScreen(data: data, postId: postId);
      } else if (category == 'trueques') {
        destination = BarterDetailScreen(data: data, postId: postId);
      } else if (category == 'mascotas') {
        destination = PetDetailScreen(data: data, postId: postId);
      } else if (category == 'alquileres' || category == 'arriendo') {
        destination = RentalDetailScreen(data: data, postId: postId);
      } else {
        // Fallback: productos generales
        destination = ProductDetailScreen(data: data, postId: postId);
      }

      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      debugPrint('DeepLinkService._openPublication error: $e');
    }
  }

  /// Navega a la pantalla de detalle de un Want.
  Future<void> _openWant(BuildContext context, String wantId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('wants')
          .doc(wantId)
          .get();

      if (!doc.exists || !context.mounted) return;

      final w = Want.fromFirestore(doc);
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => WantDetailScreen(want: w)),
      );
    } catch (e) {
      debugPrint('DeepLinkService._openWant error: $e');
    }
  }

  /// Navega al perfil publico de un usuario.
  Future<void> _openProfile(BuildContext context, String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists || !context.mounted) return;

      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
      );
    } catch (e) {
      debugPrint('DeepLinkService._openProfile error: $e');
    }
  }
}
