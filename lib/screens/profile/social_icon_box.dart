import 'package:flutter/material.dart';

class SocialIconBox extends StatelessWidget {
  final String asset;
  final VoidCallback? onTap;
  const SocialIconBox({super.key, required this.asset, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 22,
        height: 22,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}
