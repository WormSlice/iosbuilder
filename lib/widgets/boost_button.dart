import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../screens/post/boost_configuration_screen.dart';

/// Boton premium de impulso de publicaciones.
/// Aparece fijo en la parte inferior de la pantalla solo cuando
/// el usuario propietario esta viendo su propia publicacion.
/// Incluye animacion de gradiente y un icono de cohete real.
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: AnimatedBuilder(
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
  }
}
