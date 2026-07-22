import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/connect_app_bar.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool pushEnabled = true;
  bool emailEnabled = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          pushEnabled = data['pushNotifications'] ?? true;
          emailEnabled = data['emailNotifications'] ?? false;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        key: value,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ConnectAppBar(
        showSearch: false,
        showSettings: false,
        showBack: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Ajustes de Notificaciones',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 20),
                _buildToggle(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notificaciones Push',
                  subtitle: 'Alertas en tiempo real en tu teléfono',
                  value: pushEnabled,
                  onChanged: (v) {
                    setState(() => pushEnabled = v);
                    _updateSetting('pushNotifications', v);
                  },
                ),
                _buildToggle(
                  icon: Icons.mail_outline,
                  title: 'Notificaciones por Email',
                  subtitle: 'Resúmenes y alertas a tu correo',
                  value: emailEnabled,
                  onChanged: (v) {
                    setState(() => emailEnabled = v);
                    _updateSetting('emailNotifications', v);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.blue,
      ),
    );
  }
}
