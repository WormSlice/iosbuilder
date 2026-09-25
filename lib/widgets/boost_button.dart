import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/boost_service.dart';
import '../screens/post/boost_configuration_screen.dart';

/// Botón de impulso para publicaciones:
/// - Si no está impulsada: muestra botón de impulso para configurar campaña.
/// - Si ya está impulsada: muestra botón directo de "REVISAR ESTADÍSTICAS" para ver métricas reales.
class BoostButton extends StatefulWidget {
  final String postId;
  final String imageUrl;

  const BoostButton({
    super.key,
    required this.postId,
    required this.imageUrl,
  });

  @override
  State<BoostButton> createState() => _BoostButtonState();
}

class _BoostButtonState extends State<BoostButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _shineAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _shineAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(num n) {
    final s = n.toInt().toString();
    final out = <String>[];
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count != 0 && count % 3 == 0) out.add('.');
      out.add(s[i]);
      count++;
    }
    return out.reversed.join();
  }

  String _formatPrice(dynamic priceRaw) {
    if (priceRaw == null) return '0';
    double p = 0.0;
    if (priceRaw is int) p = priceRaw.toDouble();
    if (priceRaw is double) p = priceRaw;
    if (priceRaw is String) {
      p = double.tryParse(priceRaw.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }
    return _formatNumber(p);
  }

  void _showStatisticsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('boosts')
                  .where('postId', isEqualTo: widget.postId)
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF0094FF)),
                    ),
                  );
                }

                Map<String, dynamic>? boostData;
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  boostData = snapshot.data!.docs.first.data();
                }

                final int impressions = boostData?['impressions'] ?? 0;
                final int detailViews = boostData?['detailViews'] ?? 0;
                final double ctr = impressions > 0
                    ? ((detailViews / impressions) * 100).clamp(0.0, 100.0)
                    : 0.0;

                String remainingTimeStr = 'Activo';
                final expiresAt = boostData?['expiresAt'];
                if (expiresAt is Timestamp) {
                  final expDate = expiresAt.toDate();
                  final diff = expDate.difference(DateTime.now());
                  if (diff.isNegative) {
                    remainingTimeStr = 'Finalizado';
                  } else if (diff.inDays > 0) {
                    remainingTimeStr = '${diff.inDays} días';
                  } else {
                    remainingTimeStr = '${diff.inHours} horas';
                  }
                }

                final totalBudget = boostData?['totalBudget'] ?? 0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Manija superior
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Encabezado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estadísticas de la publicación',
                          style: TextStyle(
                            fontFamily: 'CanvaSans',
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.black54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Cuadrícula compacta de 2 columnas para métricas
                    Row(
                      children: [
                        // Columna 1: Alcance en feed
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200, width: 0.8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.visibility_outlined,
                                      size: 15,
                                      color: Color(0xFF0094FF),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Alcance',
                                      style: TextStyle(
                                        fontFamily: 'CanvaSans',
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatNumber(impressions),
                                  style: const TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Visualizaciones en feed',
                                  style: TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Columna 2: Visitas que entraron al post
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200, width: 0.8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.touch_app_outlined,
                                      size: 15,
                                      color: Color(0xFF0094FF),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Visitas',
                                      style: TextStyle(
                                        fontFamily: 'CanvaSans',
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatNumber(detailViews),
                                  style: const TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Entraron a la publicación',
                                  style: TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Fila CTR
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200, width: 0.8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Interacción (CTR)',
                                style: TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Porcentaje de usuarios que entraron a verla',
                                style: TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${ctr.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontFamily: 'CanvaSans',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0094FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Fila de información adicional de campaña
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200, width: 0.8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tiempo restante',
                                style: TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                remainingTimeStr,
                                style: const TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          if (totalBudget > 0) ...[
                            Divider(color: Colors.grey.shade200, height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Inversión',
                                  style: TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '\$${_formatPrice(totalBudget)} COP',
                                  style: const TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: BoostService().activeBoostedPostIds,
      builder: (context, activeIds, _) {
        final bool isBoosted = BoostService().isPostBoosted(widget.postId, null);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
          ),
          child: isBoosted
              // Publicación impulsada: Botón sobrio y directo para revisar estadísticas
              ? GestureDetector(
                  onTap: () => _showStatisticsSheet(context),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0094FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'REVISAR ESTADÍSTICAS',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'CanvaSans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              // Publicación no impulsada: Botón original de impulsar
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BoostConfigurationScreen(
                              postId: widget.postId,
                              imageUrl: widget.imageUrl,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              const Color(0xFF0055FF),
                              Color.lerp(
                                const Color(0xFF0094FF),
                                const Color(0xFF00D4FF),
                                _glowAnimation.value,
                              )!,
                              const Color(0xFF0055FF),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Transform.translate(
                                  offset: Offset(
                                    _shineAnimation.value *
                                        MediaQuery.of(context).size.width,
                                    0,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withValues(alpha: 0.12),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Transform.rotate(
                                      angle: -math.pi / 4,
                                      child: const Icon(
                                        Icons.rocket_launch_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'IMPULSAR PUBLICACIÓN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'CanvaSans',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
