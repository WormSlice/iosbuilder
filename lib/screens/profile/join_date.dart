import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinDate extends StatelessWidget {
  final DateTime? date;
  final bool isOwnProfile;
  const JoinDate({super.key, this.date, this.isOwnProfile = true});

  @override
  Widget build(BuildContext context) {
    DateTime? created = date;
    if (created == null && isOwnProfile) {
      created = FirebaseAuth.instance.currentUser?.metadata.creationTime;
    }

    String formatted = '';
    if (created != null) {
      final d = created.day.toString().padLeft(2, '0');
      final m = created.month.toString().padLeft(2, '0');
      final y = created.year.toString();
      final label = isOwnProfile ? 'Te uniste' : 'Se unió';
      formatted = '$label el $d/$m/$y';
    }

    return Text(
      formatted.isEmpty ? '' : formatted,
      style: const TextStyle(
        fontFamily: 'CanvaSans',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Colors.black54,
      ),
    );
  }
}
