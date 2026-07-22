import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  static Future<void> showReportDialog(
    BuildContext context, {
    required String postId,
    required String postTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para reportar.')),
      );
      return;
    }

    final TextEditingController reasonController = TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Reportar publicación',
          style: TextStyle(
            fontFamily: 'CanvaSans',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Por qué reportas esta publicación? (Un administrador revisará el caso urgente)',
              style: TextStyle(fontFamily: 'CanvaSans', fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'CanvaSans', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ej. Fraude, Spam, Contenido inapropiado...',
                hintStyle: const TextStyle(fontSize: 13),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF0094FF)),
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey, fontFamily: 'CanvaSans'),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Enviar Reporte',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'CanvaSans',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && reasonController.text.trim().isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('reports').add({
          'postId': postId,
          'postTitle': postTitle,
          'reporterId': user.uid,
          'reason': reasonController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Reporte enviado correctamente. Equipo CONNECT avisado.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al reportar: $e')));
        }
      }
    } else if (confirm == true && reasonController.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Debes proveer una razón para poder investigar el reporte.',
            ),
          ),
        );
      }
    }
  }
}
