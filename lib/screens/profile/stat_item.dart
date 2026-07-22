import 'package:flutter/material.dart';

class StatItem extends StatelessWidget {
  final String title;
  final num value;
  final VoidCallback? onTap;
  const StatItem({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1500),
            tween: Tween<double>(begin: 0, end: value.toDouble()),
            curve: Curves.easeOutExpo,
            builder: (context, animatedValue, child) {
              String displayValue;
              if (animatedValue >= 1000) {
                displayValue = '${(animatedValue / 1000).toStringAsFixed(1)}k';
              } else {
                displayValue = animatedValue.toInt().toString();
              }

              return Text(
                displayValue,
                style: const TextStyle(
                  fontFamily: 'MontserratArabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'MontserratArabic',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
