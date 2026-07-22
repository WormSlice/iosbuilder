import 'package:flutter/material.dart';

class FollowButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isFollowing;
  const FollowButton({super.key, this.onTap, this.isFollowing = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: isFollowing ? const Color(0xFFE0E0E0) : const Color(0xFF0496FF),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          isFollowing ? 'Siguiendo' : 'Seguir',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isFollowing ? Colors.black87 : Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class MessageButton extends StatelessWidget {
  final VoidCallback? onTap;
  const MessageButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Mensaje',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
