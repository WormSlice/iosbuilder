import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final IconData icon;
  const EmptyState({super.key, this.title = 'Sin contenido', this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
