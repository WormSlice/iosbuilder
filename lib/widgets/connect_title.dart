import 'package:flutter/material.dart';

class ConnectTitle extends StatelessWidget {
  const ConnectTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'CONNECT',
      style: const TextStyle(
        fontFamily: 'BankGothic',
        fontSize: 27,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
        color: Color(0xFF121212),
      ),
    );
  }
}
