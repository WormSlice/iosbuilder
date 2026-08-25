import 'package:flutter/material.dart';

class SocialIconBox extends StatelessWidget {
  final String asset;
  final VoidCallback? onTap;
  final double size;

  const SocialIconBox({
    super.key,
    required this.asset,
    this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
