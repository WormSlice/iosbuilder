import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/connect_app_bar.dart';
import 'package:timeago/timeago.dart' as timeago;

class ConnectedDevicesScreen extends StatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  State<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends State<ConnectedDevicesScreen> {
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _loadCurrentSession();
    timeago.setLocaleMessages('es', timeago.EsMessages());
  }

  Future<void> _loadCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentSessionId = prefs.getString('device_session_id');
    });
  }

  Future<void> _revokeSession(String sessionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Cerrar sesión remota',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Estás seguro de que deseas cerrar la sesión en ese dispositivo?',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(sessionId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión cerrada en el dispositivo seleccionado'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ConnectAppBar(
        showSearch: false,
        showSettings: false,
        showBack: true,
      ),
      body: user == null
          ? const Center(child: Text('Debes iniciar sesión'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Dispositivos Conectados',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('sessions')
                        .orderBy('lastActive', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Error al cargar dispositivos'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final sessions = snapshot.data!.docs;

                      if (sessions.isEmpty) {
                        return const Center(
                          child: Text(
                            'No hay otras sesiones activas',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.grey,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final doc = sessions[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final deviceId = doc.id;
                          final deviceName =
                              data['deviceName'] ?? 'Dispositivo desconocido';
                          final deviceType =
                              data['deviceType'] ?? 'Desconocido';
                          final location =
                              data['location'] ?? 'Ubicación desconocida';

                          DateTime? lastActive;
                          if (data['lastActive'] is Timestamp) {
                            lastActive = (data['lastActive'] as Timestamp)
                                .toDate();
                          }

                          final isCurrentDevice = deviceId == _currentSessionId;
                          final timeString = lastActive != null
                              ? 'Última conexión: ${timeago.format(lastActive, locale: 'es')}'
                              : 'Conectado recientemente';

                          IconData iconData = Icons.device_unknown;
                          if (deviceType.toLowerCase().contains('iphone') ||
                              deviceType.toLowerCase().contains('android') ||
                              deviceType.toLowerCase().contains('teléfono')) {
                            iconData = Icons.phone_iphone;
                          } else if (deviceType.toLowerCase().contains('mac') ||
                              deviceType.toLowerCase().contains('pc')) {
                            iconData = Icons.laptop_mac;
                          }

                          return _buildDeviceItem(
                            context,
                            icon: iconData,
                            name: deviceName,
                            type: deviceType,
                            location: location,
                            time: isCurrentDevice ? 'Activo ahora' : timeString,
                            isActive: isCurrentDevice,
                            onRevoke: isCurrentDevice
                                ? null
                                : () => _revokeSession(deviceId),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDeviceItem(
    BuildContext context, {
    required IconData icon,
    required String name,
    required String type,
    required String location,
    required String time,
    bool isActive = false,
    VoidCallback? onRevoke,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: Colors.green.shade300, width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.green : Colors.black87,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Este dispositivo',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tipo: $type',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ubicación: $location',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? Colors.green : Colors.grey,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (!isActive && onRevoke != null)
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                tooltip: 'Cerrar sesión',
                onPressed: onRevoke,
              ),
          ],
        ),
      ),
    );
  }
}
