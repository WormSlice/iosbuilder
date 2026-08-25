import 'package:flutter/material.dart';

/// Renderiza los logos oficiales auténticos en formato cuadrado/squircle de cada red social
/// (Instagram, Facebook, WhatsApp, TikTok) sin bordes grises artificiales.
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
    final assetLower = asset.toLowerCase();

    Widget iconWidget;
    if (assetLower.contains('instagram')) {
      iconWidget = _buildInstagramSquircle(size);
    } else if (assetLower.contains('facebook')) {
      iconWidget = _buildFacebookSquircle(size);
    } else if (assetLower.contains('whatsapp')) {
      iconWidget = _buildWhatsAppSquircle(size);
    } else if (assetLower.contains('tik') || assetLower.contains('tiktok')) {
      iconWidget = _buildTikTokSquircle(size);
    } else {
      iconWidget = ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(asset, width: size, height: size, fit: BoxFit.cover),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: iconWidget,
    );
  }

  Widget _buildInstagramSquircle(double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(s * 0.24),
        gradient: const RadialGradient(
          center: Alignment(-0.8, 1.0),
          radius: 1.4,
          colors: [
            Color(0xFFFFDC80),
            Color(0xFFFCAF45),
            Color(0xFFF77737),
            Color(0xFFF56040),
            Color(0xFFFD1D1D),
            Color(0xFFE1306C),
            Color(0xFFC13584),
            Color(0xFF833AB4),
            Color(0xFF5851DB),
            Color(0xFF405DE6),
          ],
          stops: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.75, 0.9, 1.0],
        ),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(s * 0.58, s * 0.58),
          painter: _InstagramCameraPainter(),
        ),
      ),
    );
  }

  Widget _buildFacebookSquircle(double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: const Color(0xFF1877F2), // Official Facebook Blue
        borderRadius: BorderRadius.circular(s * 0.24),
      ),
      child: Center(
        child: Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.72,
            fontWeight: FontWeight.w900,
            fontFamily: 'CanvaSans',
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppSquircle(double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: const Color(0xFF25D366), // Official WhatsApp Green
        borderRadius: BorderRadius.circular(s * 0.24),
      ),
      child: Center(
        child: Icon(
          Icons.phone_rounded,
          color: Colors.white,
          size: s * 0.56,
        ),
      ),
    );
  }

  Widget _buildTikTokSquircle(double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: const Color(0xFF010101), // Official TikTok Black
        borderRadius: BorderRadius.circular(s * 0.24),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white,
          size: s * 0.60,
        ),
      ),
    );
  }
}

class _InstagramCameraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.28),
    );
    canvas.drawRRect(rect, paint);

    // Center lens
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.23, paint);

    // Flash dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.24),
      size.width * 0.07,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
