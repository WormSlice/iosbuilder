import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool privateAccount = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          const ListTile(title: Text('Cuenta')),
          SwitchListTile(
            title: const Text('Notificaciones'),
            value: notifications,
            onChanged: (v) => setState(() => notifications = v),
          ),
          SwitchListTile(
            title: const Text('Cuenta privada'),
            value: privateAccount,
            onChanged: (v) => setState(() => privateAccount = v),
          ),
          const ListTile(title: Text('Apariencia')),
        ],
      ),
    );
  }
}
