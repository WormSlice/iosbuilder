import 'package:flutter/material.dart';
import '../../services/music_auth_service.dart';

/// Pantalla moderna para gestionar la vinculación de cuentas de música oficial (Spotify y Apple Music)
class LinkedMusicAccountsScreen extends StatefulWidget {
  const LinkedMusicAccountsScreen({super.key});

  @override
  State<LinkedMusicAccountsScreen> createState() =>
      _LinkedMusicAccountsScreenState();
}

class _LinkedMusicAccountsScreenState extends State<LinkedMusicAccountsScreen> {
  final MusicAuthService _auth = MusicAuthService.instance;
  bool _isLoadingSpotify = false;
  bool _isLoadingApple = false;

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

  Future<void> _handleSpotifyAction() async {
    if (_auth.isSpotifyConnected) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Desvincular Spotify',
            style: TextStyle(
              fontFamily: 'CanvaSans',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            '¿Seguro que deseas desvincular tu cuenta de Spotify de CONNECT?',
            style: TextStyle(fontFamily: 'CanvaSans', fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(fontFamily: 'CanvaSans', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Desvincular',
                  style: TextStyle(
                      fontFamily: 'CanvaSans',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _auth.disconnectSpotify();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuenta de Spotify desvinculada')),
          );
        }
      }
    } else {
      setState(() => _isLoadingSpotify = true);
      await Future.delayed(const Duration(milliseconds: 600));
      final success = await _auth.connectSpotify(
        customDisplayName: 'Spotify User',
      );
      if (mounted) {
        setState(() => _isLoadingSpotify = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF1DB954),
              content: Text('¡Cuenta de Spotify vinculada exitosamente!'),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleAppleMusicAction() async {
    if (_auth.isAppleMusicConnected) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Desvincular Apple Music',
            style: TextStyle(
              fontFamily: 'CanvaSans',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            '¿Seguro que deseas desvincular tu cuenta de Apple Music de CONNECT?',
            style: TextStyle(fontFamily: 'CanvaSans', fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(fontFamily: 'CanvaSans', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Desvincular',
                  style: TextStyle(
                      fontFamily: 'CanvaSans',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _auth.disconnectAppleMusic();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuenta de Apple Music desvinculada')),
          );
        }
      }
    } else {
      setState(() => _isLoadingApple = true);
      await Future.delayed(const Duration(milliseconds: 600));
      final success = await _auth.connectAppleMusic(
        customDisplayName: 'Apple Music User',
      );
      if (mounted) {
        setState(() => _isLoadingApple = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFFC3C44),
              content: Text('¡Cuenta de Apple Music vinculada exitosamente!'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLinked = _auth.hasAnyLinkedAccount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Música y Cuentas Vinculadas',
          style: TextStyle(
            fontFamily: 'CanvaSans',
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // Banner de beneficio principal
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0094FF), Color(0xFF0057FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0094FF).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Canciones Completas',
                        style: TextStyle(
                          fontFamily: 'CanvaSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (hasLinked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Color(0xFF0094FF), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Activo',
                              style: TextStyle(
                                fontFamily: 'CanvaSans',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Color(0xFF0094FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Vincula tu cuenta de Spotify o Apple Music para reproducir las canciones completas (3 a 5 minutos), sincronizar tus listas personales y recortar cualquier segundo sin límites.',
                  style: TextStyle(
                    fontFamily: 'CanvaSans',
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Título de sección de servicios
          const Text(
            'SERVICIOS DISPONIBLES',
            style: TextStyle(
              fontFamily: 'CanvaSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Tarjeta de Spotify
          _buildServiceCard(
            serviceName: 'Spotify',
            serviceColor: const Color(0xFF1DB954),
            iconWidget: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF1DB954),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.graphic_eq_rounded,
                  color: Colors.white, size: 24),
            ),
            description: 'Conecta tu cuenta de Spotify para reproducir canciones completas y tus listas.',
            isConnected: _auth.isSpotifyConnected,
            connectedSubtitle: _auth.spotifyUser ?? 'Spotify Premium',
            isLoading: _isLoadingSpotify,
            onAction: _handleSpotifyAction,
          ),
          const SizedBox(height: 16),

          // Tarjeta de Apple Music
          _buildServiceCard(
            serviceName: 'Apple Music',
            serviceColor: const Color(0xFFFC3C44),
            iconWidget: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFC3C44), Color(0xFFF94C57)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.apple_rounded,
                  color: Colors.white, size: 26),
            ),
            description: 'Conecta con Apple MusicKit para sincronizar tu catálogo y favoritos.',
            isConnected: _auth.isAppleMusicConnected,
            connectedSubtitle: _auth.appleMusicUser ?? 'Apple Music',
            isLoading: _isLoadingApple,
            onAction: _handleAppleMusicAction,
          ),
          const SizedBox(height: 28),

          // Beneficios incluidos
          const Text(
            'VENTAJAS DE VINCULAR',
            style: TextStyle(
              fontFamily: 'CanvaSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          _buildBenefitRow(
            icon: Icons.all_inclusive_rounded,
            title: 'Sin límite de 30 segundos',
            subtitle: 'Desplázate libremente por cualquier minuto de la pista.',
          ),
          const SizedBox(height: 10),
          _buildBenefitRow(
            icon: Icons.queue_music_rounded,
            title: 'Tus listas y biblioteca',
            subtitle: 'Elige temas directamente desde tus canciones guardadas.',
          ),
          const SizedBox(height: 10),
          _buildBenefitRow(
            icon: Icons.high_quality_rounded,
            title: 'Audio en calidad de estudio',
            subtitle: 'Calidad original de transmisión oficial sin compresión.',
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String serviceName,
    required Color serviceColor,
    required Widget iconWidget,
    required String description,
    required bool isConnected,
    required String connectedSubtitle,
    required bool isLoading,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected
              ? serviceColor.withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
          width: isConnected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isConnected
                ? serviceColor.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          serviceName,
                          style: const TextStyle(
                            fontFamily: 'CanvaSans',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: serviceColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: serviceColor, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  'Conectado',
                                  style: TextStyle(
                                    fontFamily: 'CanvaSans',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                    color: serviceColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected ? connectedSubtitle : 'No vinculado',
                      style: TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 12.5,
                        color: isConnected ? serviceColor : Colors.grey[500],
                        fontWeight:
                            isConnected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'CanvaSans',
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: isLoading ? null : onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected
                    ? const Color(0xFFF1F5F9)
                    : serviceColor,
                foregroundColor:
                    isConnected ? Colors.red[600] : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: isConnected
                      ? BorderSide(color: Colors.red.withValues(alpha: 0.2))
                      : BorderSide.none,
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isConnected
                          ? 'Desvincular $serviceName'
                          : 'Vincular $serviceName',
                      style: TextStyle(
                        fontFamily: 'CanvaSans',
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isConnected ? Colors.red[600] : Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0094FF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0094FF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'CanvaSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'CanvaSans',
                    fontSize: 11.5,
                    color: Colors.grey[600],
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
