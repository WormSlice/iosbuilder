import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/boost_service.dart';
import '../screens/post/boost_configuration_screen.dart';

/// Botón inteligente de impulso de publicaciones:
/// - Si la publicación NO está impulsada: Muestra "IMPULSAR PUBLICACIÓN" y permite configurar un nuevo impulso.
/// - Si la publicación YA ESTÁ impulsada: Cambia automáticamente a "REVISAR ESTADÍSTICAS", evitando doble cobro
///   y desplegando el panel de métricas 100% reales (alcance exterior en feed/explorar, visitas al detalle, CTR).
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('boosts')
              .where('postId', isEqualTo: widget.postId)
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 320,
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
                remainingTimeStr = '${diff.inDays}d ${diff.inHours % 24}h restantes';
              } else {
                remainingTimeStr = '${diff.inHours}h ${diff.inMinutes % 60}m restantes';
              }
            }

            final totalBudget = boostData?['totalBudget'] ?? 0;
            final dailyBudget = boostData?['dailyBudget'] ?? 0;
            final durationDays = boostData?['durationDays'] ?? 1;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Indicador de arrastre superior
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Encabezado
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0094FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: Color(0xFF0094FF),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rendimiento del Impulso',
                                style: TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Estadísticas 100% reales en tiempo real',
                                style: TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'EN CURSO',
                                style: TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tarjetas métricas principales (Alcance exterior vs Visitas al detalle)
                    Row(
                      children: [
                        // Card 1: Alcance Exterior (Feed / Explorar)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.visibility_outlined,
                                      color: const Color(0xFF0094FF),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Alcance en Feed',
                                      style: TextStyle(
                                        fontFamily: 'CanvaSans',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _formatNumber(impressions),
                                  style: const TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Usuarios que vieron tu tarjeta fuera de ella',
                                  style: TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Card 2: Visitas que entraron a la publicación
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.ads_click_rounded,
                                      color: Color(0xFF10B981),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Visitas al Detalle',
                                      style: TextStyle(
                                        fontFamily: 'CanvaSans',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _formatNumber(detailViews),
                                  style: const TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Usuarios que abrieron tu publicación',
                                  style: TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Card 3: Tasa de Interés / CTR
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.trending_up_rounded,
                                    color: Color(0xFF00D4FF),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Efectividad de Conversión (CTR)',
                                    style: TextStyle(
                                      fontFamily: 'CanvaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${ctr.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00D4FF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (ctr / 100).clamp(0.02, 1.0),
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF00D4FF),
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            impressions > 0
                                ? 'De cada 100 personas que vieron tu anuncio en el feed, ${ctr.toStringAsFixed(1)} entraron a revisarlo.'
                                : 'Tu publicación está activa y se mostrará a los usuarios objetivo en breve.',
                            style: const TextStyle(
                              fontFamily: 'CanvaSans',
                              fontSize: 11.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Card 4: Detalles del Impulso
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    color: Colors.grey.shade700,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tiempo restante',
                                    style: TextStyle(
                                      fontFamily: 'CanvaSans',
                                      fontSize: 12.5,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                remainingTimeStr,
                                style: const TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Divider(color: Colors.grey.shade200, height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    color: Colors.grey.shade700,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Duración total',
                                    style: TextStyle(
                                      fontFamily: 'CanvaSans',
                                      fontSize: 12.5,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$durationDays días',
                                style: const TextStyle(
                                  fontFamily: 'CanvaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          if (totalBudget > 0) ...[
                            Divider(color: Colors.grey.shade200, height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Colors.grey.shade700,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Presupuesto invertido',
                                      style: TextStyle(
                                        fontFamily: 'CanvaSans',
                                        fontSize: 12.5,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  dailyBudget > 0
                                      ? '\$${_formatPrice(totalBudget)} COP (\$${_formatPrice(dailyBudget)}/día)'
                                      : '\$${_formatPrice(totalBudget)} COP',
                                  style: const TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0094FF),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón Cerrar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0094FF),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Cerrar',
                          style: TextStyle(
                            fontFamily: 'CanvaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
              // VISTA 1: PUBLICACIÓN IMPULSADA -> REVISAR ESTADÍSTICAS
              ? GestureDetector(
                  onTap: () => _showStatisticsSheet(context),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00D4FF).withOpacity(0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0094FF).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.insights_rounded,
                            color: Color(0xFF00D4FF),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'REVISAR ESTADÍSTICAS',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CanvaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'ACTIVO',
                                  style: TextStyle(
                                    color: Color(0xFF34D399),
                                    fontFamily: 'CanvaSans',
                                    fontSize: 9.5,
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
                )
              // VISTA 2: PUBLICACIÓN NO IMPULSADA -> IMPULSAR PUBLICACIÓN
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
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
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
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0094FF).withOpacity(
                                0.3 + _glowAnimation.value * 0.3,
                              ),
                              blurRadius: 12 + _glowAnimation.value * 8,
                              spreadRadius: _glowAnimation.value * 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              // Efecto de brillo deslizante
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
                                          Colors.white.withOpacity(0.12),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Contenido del boton
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Transform.rotate(
                                      angle: -math.pi / 4,
                                      child: const Icon(
                                        Icons.rocket_launch_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'IMPULSAR PUBLICACIÓN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'ArchivoBlack',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'PRO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'ArchivoBlack',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
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
