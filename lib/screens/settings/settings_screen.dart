import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../app.dart';
import '../../widgets/connect_app_bar.dart';
import '../../widgets/dynamic_island_notification.dart';
import '../profile/personal_info_screen.dart';
import '../profile/verification_screen.dart';
import './report_problem_screen.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Eliminamos _currentLanguage local ya que usaremos el Provider

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ConnectAppBar(
        showSearch: false,
        showSettings: false,
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Account & Profile Section
          _buildSectionHeader('CUENTA Y PERFIL'),
          _buildSettingsTile(
            icon: Icons.history_rounded,
            title: 'Centro de Actividad',
            onTap: () => Navigator.pushNamed(context, '/activity'),
          ),
          _buildSettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Editar Perfil',
            onTap: () => Navigator.pushNamed(context, '/edit_profile'),
          ),
          _buildSettingsTile(
            icon: Icons.badge_outlined,
            title: 'Información Personal',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PersonalInfoScreen()),
            ),
          ),
          
          // Security Section
          _buildSectionHeader('SEGURIDAD Y ACCESO'),
          _buildSettingsTile(
            icon: Icons.verified_user_outlined,
            title: 'Verificación de Perfil',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VerificationScreen()),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.shield_outlined,
            title: 'Seguridad',
            onTap: () => Navigator.pushNamed(context, '/security'),
          ),
          _buildSettingsTile(
            icon: Icons.devices_rounded,
            title: 'Dispositivos Conectados',
            onTap: () => Navigator.pushNamed(context, '/connected_devices'),
          ),
          _buildSettingsTile(
            icon: Icons.delete_outline_rounded,
            title: 'Eliminar Cuenta',
            onTap: () {
              // Lógica de eliminación
            },
            isDestructive: true,
          ),

          const SizedBox(height: 24),

          // App Settings Section
          _buildSectionHeader(lang.translate('configuracion').toUpperCase()),
          _buildSettingsTile(
            icon: Icons.language_rounded,
            title: lang.translate('idioma'),
            subtitle: lang.currentLanguage,
            onTap: () => _showLanguageSelector(lang),
          ),
          _buildSettingsTile(
            icon: Icons.notifications_none_rounded,
            title: 'Ajustes de Notificaciones',
            onTap: () => Navigator.pushNamed(context, '/notifications_settings'),
          ),

          const SizedBox(height: 24),

          // Information Section
          _buildSectionHeader('INFORMACIÓN LEGAL'),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Acerca de CONNECT',
            onTap: () => _showAboutDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Preguntas Frecuentes (FAQ)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FAQScreen()),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            title: 'Términos y Condiciones',
            onTap: () => _showTermsDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.policy_outlined,
            title: 'Política de Privacidad',
            onTap: () => _showPrivacyPolicyDialog(context),
          ),

          const SizedBox(height: 24),

          // Support Section
          _buildSectionHeader('SOPORTE TÉCNICO'),
          _buildSettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Reportar un Problema',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportProblemScreen()),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.contact_support_outlined,
            title: 'Contactar Soporte',
            onTap: () => _showContactDialog(context),
          ),

          const SizedBox(height: 32),

          // Sign Out Button
          _buildSignOutButton(context),

          const SizedBox(height: 32),

          // Version Info
          Center(
            child: Column(
              children: [
                const Text(
                  'CONNECT',
                  style: TextStyle(
                    fontFamily: 'ArchivoBlack',
                    fontSize: 16,
                    letterSpacing: 2,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Versión 1.1.5',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: Colors.grey[400],
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.grey[400],
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive ? Colors.red.withOpacity(0.05) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
        subtitle: subtitle != null ? Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ) : null,
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey[300],
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return InkWell(
      onTap: () => _handleSignOut(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'CERRAR SESIÓN',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'ArchivoBlack',
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar Sesión', style: TextStyle(fontFamily: 'ArchivoBlack')),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?', style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CERRAR SESIÓN', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService().signOut();
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  void _showLanguageSelector(LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('SELECCIONAR IDIOMA', style: TextStyle(fontFamily: 'ArchivoBlack', fontSize: 16)),
            ),
            ListTile(
              title: const Text('Español', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              trailing: lang.currentLocale.languageCode == 'es' ? const Icon(Icons.check_circle, color: Color(0xFF0094FF)) : null,
              onTap: () {
                lang.setLanguage('Español');
                Navigator.pop(context);
                DynamicIslandNotification.show(
                  title: 'CONFIGURACIÓN',
                  message: 'Idioma cambiado a Español correctamente.',
                  icon: Icons.language_rounded,
                );
              },
            ),
            ListTile(
              title: const Text('English', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              trailing: lang.currentLocale.languageCode == 'en' ? const Icon(Icons.check_circle, color: Color(0xFF0094FF)) : null,
              onTap: () {
                lang.setLanguage('English');
                Navigator.pop(context);
                DynamicIslandNotification.show(
                  title: 'SETTINGS',
                  message: 'Language changed to English successfully.',
                  icon: Icons.language_rounded,
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, _, __) => Center(
        child: Container(
          margin: const EdgeInsets.all(30),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('CONNECT', style: TextStyle(fontFamily: 'ArchivoBlack', fontSize: 24, letterSpacing: 2)),
                  const SizedBox(height: 20),
                  const Text(
                    'Es una plataforma de comercio local diseñada para conectar el mundo de forma segura.\n\n'
                    'Nuestra visión es crear un puente digital donde la seguridad y la oportunidad convergen en un solo ecosistema inteligente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    child: const Text('CERRAR', style: TextStyle(color: Colors.white, fontFamily: 'ArchivoBlack')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    _showLegalDialog(
      context, 
      'TÉRMINOS Y CONDICIONES', 
      'Al usar CONNECT, aceptas participar en un entorno de comercio local responsable. Todas tus publicaciones deben ser veraces y respetar las leyes locales vigentes.'
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    _showLegalDialog(
      context, 
      'POLÍTICA DE PRIVACIDAD', 
      'Tu privacidad es nuestra prioridad. Recopilamos datos de ubicación y multimedia solo para mejorar tu experiencia de usuario y conectar con servicios cercanos.'
    );
  }

  void _showLegalDialog(BuildContext context, String title, String content) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, _, __) => Center(
        child: Container(
          margin: const EdgeInsets.all(30),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'ArchivoBlack', fontSize: 18, letterSpacing: 1)),
                  const SizedBox(height: 20),
                  Text(
                    content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.6, color: Colors.black87),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white, fontFamily: 'ArchivoBlack')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('SOPORTE TÉCNICO', style: TextStyle(fontFamily: 'ArchivoBlack', fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: Colors.black),
              title: const Text('Email de Soporte', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('soporte@connectapp.com.co', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
              onTap: () {
                // Launch email
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_pin_outlined, color: Color(0xFF0094FF)),
              title: const Text('Solicitar un Asesor', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0094FF))),
              subtitle: const Text('Un asesor te contactará a tu correo o número.', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showRequestAdvisorSheet();
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showRequestAdvisorSheet() {
    final TextEditingController _noteController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SOLICITAR ASESOR', style: TextStyle(fontFamily: 'ArchivoBlack', fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Escribe una breve nota sobre lo que necesitas.', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              TextField(
                controller: _noteController,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ej: Tengo un problema con mi verificación...',
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final note = _noteController.text.trim();
                  if (note.isEmpty) return;
                  
                  final user = FirebaseAuth.instance.currentUser;
                  await FirebaseFirestore.instance.collection('support_requests').add({
                    'userId': user?.uid,
                    'userName': user?.displayName,
                    'userEmail': user?.email,
                    'note': note,
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  Navigator.pop(context);
                  DynamicIslandNotification.show(
                    title: 'SOLICITUD ENVIADA',
                    message: 'Un asesor te contactará pronto.',
                    icon: Icons.person_search_rounded,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('ENVIAR SOLICITUD', style: TextStyle(color: Colors.white, fontFamily: 'ArchivoBlack')),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// FAQ Screen remains similar but with new styling
class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ConnectAppBar(showSearch: false, showSettings: false, showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('PREGUNTAS FRECUENTES', style: TextStyle(fontFamily: 'ArchivoBlack', fontSize: 20, letterSpacing: 1)),
          const SizedBox(height: 20),
          _buildFAQItem('¿Cómo publico un producto?', 'Toca el botón "+" en la barra de navegación, selecciona la categoría y completa los detalles de tu publicación.'),
          _buildFAQItem('¿Cómo contacto a un vendedor?', 'Toca en la publicación que te interesa y usa el botón de chat para enviar un mensaje directo.'),
          _buildFAQItem('¿Es seguro usar CONNECT?', 'Sí, verificamos perfiles y moderamos contenido. Siempre recomendamos reunirse en lugares públicos.'),
          _buildFAQItem('¿Cómo elimino mi cuenta?', 'Ve a Configuración > Seguridad y Acceso > Eliminar Cuenta.'),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(q, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13)),
        children: [Padding(padding: const EdgeInsets.all(16), child: Text(a, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, height: 1.5)))],
      ),
    );
  }
}
