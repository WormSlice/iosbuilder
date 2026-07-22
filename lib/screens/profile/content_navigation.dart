import 'package:flutter/material.dart';

class ContentNavigation extends StatelessWidget {
  const ContentNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final current = controller.index;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SelectableNavIcon(
                asset: 'assets/iconos/publicaciones.png',
                selected: current == 0,
                onTap: () => controller.animateTo(0),
              ),
              SelectableNavIcon(
                asset: 'assets/iconos/reseñas.png',
                selected: current == 1,
                onTap: () => controller.animateTo(1),
              ),
              SelectableNavIcon(
                asset: 'assets/iconos/info.png',
                selected: current == 2,
                onTap: () => controller.animateTo(2),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SelectableNavIcon extends StatelessWidget {
  final String asset;
  final bool selected;
  final VoidCallback onTap;
  const SelectableNavIcon({
    super.key,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Opacity(
            opacity: selected ? 1.0 : 0.6,
            child: Image.asset(asset, width: 28, height: 28),
          ),
          const SizedBox(height: 4),
          Container(
            height: selected ? 2 : 0,
            width: 30,
            color: selected ? Colors.black87 : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
