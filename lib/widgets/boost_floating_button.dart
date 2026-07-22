import 'package:flutter/material.dart';
import '../screens/post/boost_configuration_screen.dart';

class BoostFloatingButton extends StatelessWidget {
  final String postId;
  final String imageUrl;

  const BoostFloatingButton({
    super.key,
    required this.postId,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BoostConfigurationScreen(
                postId: postId,
                imageUrl: imageUrl,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'IMPULSAR',
                style: TextStyle(
                  fontFamily: 'ArchivoBlack',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Color(0xFF0094FF),
                ),
              ),
              const SizedBox(width: 4),
              Image.asset(
                'imgenes/IMPULSAR.png',
                width: 18,
                height: 18,
                errorBuilder: (context, error, stackTrace) => const Text('🚀', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
