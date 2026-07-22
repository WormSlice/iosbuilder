import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  final double size;
  final ImageProvider? image;
  const AppAvatar({super.key, this.size = 72, this.image});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      backgroundImage: image,
      child: image == null ? Icon(Icons.person, size: size * 0.6) : null,
    );
  }
}
