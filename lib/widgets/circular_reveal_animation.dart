import 'dart:math' as math;
import 'package:flutter/material.dart';

class CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset? center;

  CircularRevealClipper({required this.fraction, this.center});

  @override
  Path getClip(Size size) {
    final path = Path();
    // Start from the provided center or default to bottom-center
    final centerPos = center ?? Offset(size.width / 2, size.height);

    // Calculate the maximum distance to a corner from the center point
    final double dx = math.max(centerPos.dx, size.width - centerPos.dx);
    final double dy = math.max(centerPos.dy, size.height - centerPos.dy);
    final double maxRadius = math.sqrt(dx * dx + dy * dy);

    path.addOval(
      Rect.fromCircle(center: centerPos, radius: maxRadius * fraction),
    );
    return path;
  }

  @override
  bool shouldReclip(CircularRevealClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class CircularRevealPageRoute extends PageRouteBuilder {
  final Widget page;
  final Offset? center;

  CircularRevealPageRoute({required this.page, this.center})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return ClipPath(
                clipper: CircularRevealClipper(
                  fraction: animation.value,
                  center: center,
                ),
                child: child,
              );
            },
            child: child,
          );
        },
      );
}
