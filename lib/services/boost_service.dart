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

  // Caché de sesión para evitar duplicar conteos en scrolls rápidos
  final Set<String> _impressionTrackedPosts = {};
  final Set<String> _detailViewTrackedPosts = {};

  /// Registra 100% en tiempo real una impresión externa (el usuario vio la publicación en feed, explorar o búsquedas)
  void trackPostImpression(String? pId, [String? bId]) async {
    if (pId == null || pId.isEmpty) return;
    if (_impressionTrackedPosts.contains(pId)) return;
    _impressionTrackedPosts.add(pId);

    try {
      final isBoosted = isPostBoosted(pId, null);
      if (!isBoosted) return;

      // Incrementar estadísticas en la colección de impulsos
      final boostQuery = await FirebaseFirestore.instance
          .collection('boosts')
          .where('postId', isEqualTo: pId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (boostQuery.docs.isNotEmpty) {
        final bDoc = boostQuery.docs.first.reference;
        await bDoc.update({
          'impressions': FieldValue.increment(1),
          'lastImpressionAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }

      // También registrar en la publicación para redundancia analítica
      await FirebaseFirestore.instance
          .collection('publications')
          .doc(pId)
          .update({
        'boost_impressions': FieldValue.increment(1),
      }).catchError((_) {});
    } catch (e) {
      debugPrint('[BoostService] Error registrando impresión: $e');
    }
  }

  /// Registra 100% en tiempo real una visita al detalle (el usuario entró a ver la publicación)
  void trackPostDetailView(String? pId, [String? bId, String? ownerId]) async {
    if (pId == null || pId.isEmpty) return;
    if (_detailViewTrackedPosts.contains(pId)) return;
    _detailViewTrackedPosts.add(pId);

    try {
      final isBoosted = isPostBoosted(pId, null);
      if (!isBoosted) return;

      // Incrementar estadísticas en la colección de impulsos
      final boostQuery = await FirebaseFirestore.instance
          .collection('boosts')
          .where('postId', isEqualTo: pId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (boostQuery.docs.isNotEmpty) {
        final bDoc = boostQuery.docs.first.reference;
        await bDoc.update({
          'detailViews': FieldValue.increment(1),
          'lastDetailViewAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }

      // También registrar en la publicación para redundancia analítica
      await FirebaseFirestore.instance
          .collection('publications')
          .doc(pId)
          .update({
        'boost_detail_views': FieldValue.increment(1),
      }).catchError((_) {});
    } catch (e) {
      debugPrint('[BoostService] Error registrando visita al detalle: $e');
    }
  }

  /// Obtiene los datos del impulso activo para una publicación
  Future<Map<String, dynamic>?> getActiveBoostData(String pId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('boosts')
          .where('postId', isEqualTo: pId)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data();
      }
    } catch (e) {
      debugPrint('[BoostService] Error obteniendo datos del impulso: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
