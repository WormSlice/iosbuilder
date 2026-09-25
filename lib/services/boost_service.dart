import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Servicio para gestionar impulsos (Boosts):
/// 1. ChangeNotifier para el prompt modal en app.dart (show / hide / showPrompt / imageUrl / postId)
/// 2. Singleton reactivo para rastrear en tiempo real las publicaciones impulsadas (Boosts)
///    Garantiza que si un impulso se elimina o pausa desde el panel de administración,
///    el distintivo de impulsada (puntito azul) desaparezca de inmediato en la app móvil.
class BoostService extends ChangeNotifier {
  static final BoostService _instance = BoostService._internal();
  factory BoostService() => _instance;

  // Estado del prompt modal tras publicar
  bool _showPrompt = false;
  String? _imageUrl;
  String? _postId;

  bool get showPrompt => _showPrompt;
  String? get imageUrl => _imageUrl;
  String? get postId => _postId;

  void show({required String imageUrl, required String postId}) {
    _showPrompt = true;
    _imageUrl = imageUrl;
    _postId = postId;
    notifyListeners();
  }

  void hide() {
    _showPrompt = false;
    _imageUrl = null;
    _postId = null;
    notifyListeners();
  }

  // Estado de sincronización en tiempo real de publicaciones impulsadas
  final ValueNotifier<Set<String>> activeBoostedPostIds = ValueNotifier<Set<String>>({});
  bool _hasInitialData = false;
  StreamSubscription? _subscription;

  BoostService._internal() {
    _startListening();
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('boosts')
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now();
      final activeIds = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase() ?? 'active';
        if (status != 'active') continue;

        // Validar expiración si existe fecha
        final expiresAt = data['expiresAt'];
        if (expiresAt is Timestamp) {
          if (expiresAt.toDate().isBefore(now)) continue;
        }

        final pId = data['postId']?.toString().trim();
        if (pId != null && pId.isNotEmpty) {
          activeIds.add(pId);
        }
        // También agregar el doc.id por compatibilidad
        activeIds.add(doc.id);
      }

      _hasInitialData = true;
      activeBoostedPostIds.value = activeIds;
      notifyListeners();
    }, onError: (e) {
      debugPrint('[BoostService] Error escuchando impulsos activos: $e');
    });
  }

  /// Verifica si una publicación específica se encuentra actualmente impulsada
  bool isPostBoosted(String? pId, Map<String, dynamic>? data) {
    if (pId != null && pId.isNotEmpty) {
      if (activeBoostedPostIds.value.contains(pId)) {
        return true;
      }
    }

    // Si ya cargamos la colección de impulsos del servidor y este post no está allí,
    // significa que el impulso fue eliminado o pausado en el panel.
    if (_hasInitialData) {
      return false;
    }

    // Fallback preliminar mientras conecta Firestore
    final rawIsBoosted = data?['is_boosted'] == true;
    if (rawIsBoosted) {
      final exp = data?['boost_expires_at'];
      if (exp is Timestamp && exp.toDate().isBefore(DateTime.now())) {
        return false;
      }
      return true;
    }

    return false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
