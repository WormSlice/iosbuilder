import 'package:flutter/material.dart';
import '../../services/music_auth_service.dart';
import '../../widgets/connect_app_bar.dart';

class LinkedMusicAccountsScreen extends StatefulWidget {
  const LinkedMusicAccountsScreen({super.key});

  @override
  State<LinkedMusicAccountsScreen> createState() =>
      _LinkedMusicAccountsScreenState();
}

class _LinkedMusicAccountsScreenState extends State<LinkedMusicAccountsScreen> {
  final MusicAuthService _auth = MusicAuthService.instance;

  @override
  void initState() {
    super.initState();
    _auth.init();
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSpotifyConnect() async {
    final launched = await _auth.startSpotifyAuth();
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el navegador para iniciar sesión en Spotify.'),
        ),
      );
    }
  }

  Future<void> _handleSpotifyDisconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Desvincular Spotify',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: const Text(
          '¿Estás seguro de que deseas desvincular tu cuenta de Spotify?',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Desvincular',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.disconnectSpotify();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta de Spotify desvinculada.')),
        );
      }
    }
  }

  void _showAppleMusicInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Apple Music',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: const Text(
          'La integración con Apple Music requiere configuración previa de claves de MusicKit en Apple Developer. Estará disponible una vez que configures dichas credenciales.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0094FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          color: Colors.grey[600],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSpotify = _auth.isSpotifyConnected;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: ConnectAppBar(
          showSearch: false,
          showSettings: false,
          showBack: true,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const Text(
            'Servicios de Música',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),

          _buildSectionHeader('CUENTAS DISPONIBLES'),

          // Tarjeta Spotify
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFF1DB954),
                    size: 24,
                  ),
                ),
              ),
              title: const Text(
                'Spotify',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                isSpotify
                    ? 'Conectado (${_auth.spotifyUser ?? "Cuenta activa"})'
                    : (_auth.isAuthenticatingSpotify
                        ? 'Esperando autorización en el navegador...'
                        : 'No conectado'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: isSpotify
                      ? const Color(0xFF1DB954)
                      : (_auth.isAuthenticatingSpotify
                          ? const Color(0xFF0094FF)
                          : Colors.grey[600]),
                  fontWeight:
                      isSpotify ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: _auth.isAuthenticatingSpotify
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF0094FF)),
                      ),
                    )
                  : (isSpotify
                      ? TextButton(
                          onPressed: _handleSpotifyDisconnect,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red[600],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                          child: const Text(
                            'Desvincular',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _handleSpotifyConnect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0094FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Conectar',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        )),
            ),
          ),

          const SizedBox(height: 10),

          // Tarjeta Apple Music (Próximamente / No configurado)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.apple,
                    color: Colors.black87,
                    size: 24,
                  ),
                ),
              ),
              title: const Text(
                'Apple Music',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                'No configurado (Próximamente)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              trailing: OutlinedButton(
                onPressed: _showAppleMusicInfo,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Detalles',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          _buildSectionHeader('INFORMACIÓN'),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF0094FF),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Por defecto, CONNECT reproduce fragmentos oficiales de alta calidad para todas las canciones disponibles. Al vincular tu cuenta de Spotify podrás sincronizar tu biblioteca y acceder a reproducción extendida.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
