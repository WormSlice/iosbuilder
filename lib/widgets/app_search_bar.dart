import 'package:flutter/material.dart';

class AppSearchBar extends StatelessWidget {
  final String hint;
  const AppSearchBar({super.key, this.hint = 'Buscar'});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Buscar',
          border: InputBorder.none,
          icon: Icon(Icons.search),
        ),
      ),
    );
  }
}
