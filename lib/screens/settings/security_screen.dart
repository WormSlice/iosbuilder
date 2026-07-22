import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../profile/phone_code_screen.dart';
import '../../widgets/connect_app_bar.dart';
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _twoFactorEnabled = false;
  String _twoFactorMethod = 'sms'; // 'sms' or 'email'
  bool _isLoading = true;
  String? _phoneNumber;
  String? _displayName;
  String? _email;
  String? _dob;
  List<String> _linkedProviders = [];

  @override
  void initState() {
    super.initState();
    _checkMfaStatus();
  }

  Future<void> _checkMfaStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
        final enrolledFactors = await user.multiFactor.getEnrolledFactors();
        
        // Fetch additional data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();

        if (mounted) {
          setState(() {
            _twoFactorEnabled = userData?['twoFactorEnabled'] ?? false;
            _twoFactorMethod = userData?['twoFactorMethod'] ?? 'sms';
            _phoneNumber = user.phoneNumber;
            _email = user.email;
            _displayName = userData?['verifiedName'] ?? userData?['displayName'] ?? userData?['name'] ?? user.displayName;
            _dob = userData?['dob']?.toString();
            _linkedProviders = user.providerData
                .map((e) => e.providerId)
                .toList();
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _linkedProviders = user.providerData
                .map((e) => e.providerId)
                .toList();
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleUnlinkPhone() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular Teléfono'),
        content: const Text('¿Estás seguro de que deseas desvincular tu número de teléfono? Esto podría afectar la autenticación de dos factores.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await AuthService().unlinkPhone();
        await _checkMfaStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teléfono desvinculado con éxito')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePhoneVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final phoneController = TextEditingController(text: _phoneNumber ?? '+57');

    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Vincular Teléfono Certificado',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu número para recibir un código de verificación por SMS.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Número de Teléfono',
                hintText: '+57 3xx xxx xxxx',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, phoneController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0094FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar SMS'),
          ),
        ],
      ),
    );

    if (phone == null || phone.isEmpty || phone == '+57') return;

    try {
      await AuthService().verifyPhone(
        phoneNumber: phone,
        onCodeSent: (verificationId) async {
          final verified = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PhoneCodeScreen(
                verificationId: verificationId,
                phoneNumber: phone,
              ),
            ),
          );

          if (verified == true) {
            setState(() => _isLoading = true);
            await _checkMfaStatus();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Teléfono verificado y vinculado correctamente',
                  ),
                ),
              );
            }
          }
        },
        onVerificationFailed: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _update2faSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'twoFactorEnabled': _twoFactorEnabled,
        'twoFactorMethod': _twoFactorMethod,
      });
    } catch (e) {
      print('Error updating 2FA settings: $e');
    }
  }

  Future<void> _handle2faToggle(bool value) async {
    if (value && _phoneNumber == null && _twoFactorMethod == 'sms') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vincula un teléfono primero para usar 2FA por SMS.')),
      );
      _handlePhoneVerification();
      return;
    }

    setState(() {
      _twoFactorEnabled = value;
    });
    await _update2faSettings();
  }

  Future<void> _handleMethodChange(String? method) async {
    if (method == null) return;
    
    if (method == 'sms' && _phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vincula un teléfono primero para usar SMS.')),
      );
      _handlePhoneVerification();
      return;
    }

    setState(() {
      _twoFactorMethod = method;
    });
    await _update2faSettings();
  }

  Future<void> _handlePasswordReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Restablecer contraseña',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Se ha enviado un enlace para restablecer tu contraseña al correo:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  user.email!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0094FF),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Revisa tu bandeja de entrada y sigue el enlace para crear una nueva contraseña.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0094FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ConnectAppBar(
          showSearch: false,
          showSettings: false,
          showBack: true,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Seguridad y Autenticación',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 1: Personal Info
                _buildSectionHeader('Información Personal'),
                _buildInfoTile('Nombre verificado', _displayName ?? 'N/A'),
                _buildInfoTile('Correo electrónico', _email ?? 'N/A'),
                _buildInfoTile('Número de teléfono', _phoneNumber ?? 'No vinculado'),
                _buildInfoTile('Fecha de nacimiento', _dob ?? 'No especificada'),
                
                const SizedBox(height: 32),

                // SECTION 2: Access Methods
                _buildSectionHeader('Métodos de acceso vinculados'),
                const SizedBox(height: 12),
                _buildAccessIcons(),
                
                const SizedBox(height: 32),

                // SECTION 3: MFA
                _buildSectionHeader('Autenticación de Dos Factores (2FA)'),
                const SizedBox(height: 12),
                _buildToggleOption(
                  icon: Icons.security_outlined,
                  title: 'Activar 2FA',
                  value: _twoFactorEnabled,
                  onChanged: _handle2faToggle,
                ),
                if (_twoFactorEnabled) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader('Método preferido'),
                  _buildMethodSelector(),
                ],

                const SizedBox(height: 32),

                // SECTION 4: Account Actions
                _buildSectionHeader('Ajustes de cuenta'),
                const SizedBox(height: 12),
                _buildActionOption(
                  icon: Icons.lock_outline,
                  title: 'Cambiar Contraseña',
                  onTap: _handlePasswordReset,
                ),
                _buildActionOption(
                  icon: _phoneNumber != null ? Icons.phone_disabled_outlined : Icons.phone_android_outlined,
                  title: _phoneNumber != null ? 'Desvincular número de teléfono' : 'Vincular número certificado',
                  onTap: _phoneNumber != null ? _handleUnlinkPhone : _handlePhoneVerification,
                  iconColor: _phoneNumber != null ? Colors.red : const Color(0xFF0094FF),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Poppins')),
          const SizedBox(height: 4),
          Text(
            value,
            softWrap: true,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessIcons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMethodIcon(
            child: const Icon(Icons.email_outlined, size: 20, color: Colors.blue),
            isActive: _linkedProviders.contains('password'),
            onTap: () => {},
          ),
          _buildMethodIcon(
            child: Image.network(
              'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
              width: 18,
              height: 18,
            ),
            isActive: _linkedProviders.contains('google.com'),
            onTap: () => _linkedProviders.contains('google.com') ? null : _handleLinkProvider('google.com'),
          ),
          _buildMethodIcon(
            child: Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/200px-Apple_logo_black.svg.png',
              width: 18,
              height: 18,
              color: _linkedProviders.contains('apple.com') ? Colors.black : Colors.grey,
            ),
            isActive: _linkedProviders.contains('apple.com'),
            onTap: () => _linkedProviders.contains('apple.com') ? null : _handleLinkProvider('apple.com'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLinkProvider(String providerId) async {
    setState(() => _isLoading = true);
    try {
      if (providerId == 'google.com') {
        await AuthService().linkWithGoogle();
      } else if (providerId == 'apple.com') {
        await AuthService().linkWithApple();
      }
      await _checkMfaStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al vincular: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMethodIcon({
    required Widget child,
    required bool isActive,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10), // Much smaller
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.grey[100],
              shape: BoxShape.circle,
              boxShadow: isActive ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ] : null,
              border: Border.all(
                color: isActive ? const Color(0xFF0094FF).withOpacity(0.3) : Colors.transparent,
                width: 1,
              ),
            ),
            child: SizedBox(
              width: 18,
              height: 18,
              child: Opacity(
                opacity: isActive ? 1.0 : 0.6,
                child: Center(child: child),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.grey[400],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(
                isActive ? Icons.check : Icons.add,
                size: 8,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? const Color(0xFF0094FF)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins')),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            title: const Text('Mensaje de Texto (SMS)', style: TextStyle(fontSize: 14, fontFamily: 'Poppins')),
            value: 'sms',
            groupValue: _twoFactorMethod,
            onChanged: _handleMethodChange,
            activeColor: const Color(0xFF0094FF),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 1),
          RadioListTile<String>(
            title: const Text('Correo electrónico (Email)', style: TextStyle(fontSize: 14, fontFamily: 'Poppins')),
            value: 'email',
            groupValue: _twoFactorMethod,
            onChanged: _handleMethodChange,
            activeColor: const Color(0xFF0094FF),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: const Color(0xFF0094FF)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins')),
        value: value,
        onChanged: onChanged,
        activeTrackColor: const Color(0xFF0094FF).withOpacity(0.5),
        activeColor: const Color(0xFF0094FF),
      ),
    );
  }
}
