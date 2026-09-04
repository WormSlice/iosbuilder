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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                const Text(
                  'Seguridad y Autenticación',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 14),

                // SECTION 1: Personal Info
                _buildSectionHeader('Información Personal'),
                _buildInfoTile('Nombre verificado', _displayName ?? 'N/A'),
                _buildInfoTile('Correo electrónico', _email ?? 'N/A'),
                _buildPhoneTile(),
                _buildInfoTile('Fecha de nacimiento', _dob ?? 'No especificada'),
                
                const SizedBox(height: 16),

                // SECTION 2: Access Methods
                _buildSectionHeader('Métodos de acceso vinculados'),
                _buildAccessIcons(),
                
                const SizedBox(height: 16),

                // SECTION 3: MFA
                _buildSectionHeader('Autenticación de Dos Factores (2FA)'),
                _buildToggleOption(
                  icon: Icons.security_outlined,
                  title: 'Activar 2FA',
                  value: _twoFactorEnabled,
                  onChanged: _handle2faToggle,
                ),
                if (_twoFactorEnabled) ...[
                  const SizedBox(height: 12),
                  _buildSectionHeader('Método preferido'),
                  _buildMethodSelector(),
                ],

                const SizedBox(height: 16),

                // SECTION 4: Account Actions
                _buildSectionHeader('Ajustes de cuenta'),
                _buildActionOption(
                  icon: Icons.lock_outline,
                  title: 'Cambiar Contraseña',
                  onTap: _handlePasswordReset,
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2, top: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Poppins')),
          const SizedBox(height: 2),
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

  Widget _buildPhoneTile() {
    final hasPhone = _phoneNumber != null && _phoneNumber!.isNotEmpty && _phoneNumber != 'No vinculado';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Número de teléfono',
            style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 4),
          if (!hasPhone)
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: _handlePhoneVerification,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0094FF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0094FF).withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF0094FF)),
                      SizedBox(width: 5),
                      Text(
                        'Agregar Número',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0094FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    _phoneNumber!,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Botón Editar
                GestureDetector(
                  onTap: _handlePhoneVerification,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0094FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 15,
                      color: Color(0xFF0094FF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botón Borrar
                GestureDetector(
                  onTap: _handleUnlinkPhone,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 15,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAccessIcons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
            onTap: () => _linkedProviders.contains('password') ? null : _showLinkEmailDialog(),
          ),
          _buildMethodIcon(
            child: Image.network(
              'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
              width: 18,
              height: 18,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.red),
            ),
            isActive: _linkedProviders.contains('google.com'),
            onTap: () => _linkedProviders.contains('google.com') ? null : _handleLinkProvider('google.com'),
          ),
          _buildMethodIcon(
            child: Icon(
              Icons.apple,
              size: 22,
              color: _linkedProviders.contains('apple.com') ? Colors.black : Colors.grey[700],
            ),
            isActive: _linkedProviders.contains('apple.com'),
            onTap: () => _linkedProviders.contains('apple.com') ? null : _handleLinkProvider('apple.com'),
          ),
        ],
      ),
    );
  }

  void _showLinkEmailDialog() {
    final emailController = TextEditingController(text: _email != 'N/A' ? _email : '');
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Vincular Correo y Contraseña', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa un correo y una contraseña para poder acceder también mediante correo electrónico.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(fontFamily: 'Poppins')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0094FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final email = emailController.text.trim();
                final password = passwordController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor ingresa un correo válido')),
                  );
                  return;
                }
                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await AuthService().linkWithEmailPassword(email, password);
                  await _checkMfaStatus();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Correo y contraseña vinculados con éxito'), backgroundColor: Colors.green),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  if (mounted) {
                    String msg = 'Error al vincular: ${e.message}';
                    if (e.code == 'email-already-in-use') {
                      msg = 'Este correo ya está registrado en otra cuenta.';
                    } else if (e.code == 'weak-password') {
                      msg = 'La contraseña es demasiado débil.';
                    } else if (e.code == 'provider-already-linked') {
                      msg = 'El acceso con correo ya está vinculado.';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg), backgroundColor: Colors.red),
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
              },
              child: const Text('Vincular', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLinkProvider(String providerId) async {
    setState(() => _isLoading = true);
    try {
      if (providerId == 'google.com') {
        await AuthService().linkWithGoogle();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuenta de Google vinculada con éxito'), backgroundColor: Colors.green),
          );
        }
      } else if (providerId == 'apple.com') {
        await AuthService().linkWithApple();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuenta de Apple vinculada con éxito'), backgroundColor: Colors.green),
          );
        }
      }
      await _checkMfaStatus();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Error al vincular: ${e.message}';
        if (e.code == 'credential-already-in-use') {
          msg = 'Esta cuenta ya está vinculada a otro usuario.';
        } else if (e.code == 'provider-already-linked') {
          msg = 'Este método ya está vinculado.';
        } else if (e.code == 'email-already-in-use') {
          msg = 'El correo electrónico ya está en uso.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted && !e.toString().contains('cancelad') && !e.toString().contains('canceled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al vincular: $e'), backgroundColor: Colors.red),
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
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(icon, color: iconColor ?? const Color(0xFF0094FF), size: 20),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: const Text('Mensaje de Texto (SMS)', style: TextStyle(fontSize: 13, fontFamily: 'Poppins')),
            value: 'sms',
            groupValue: _twoFactorMethod,
            onChanged: _handleMethodChange,
            activeColor: const Color(0xFF0094FF),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 1),
          RadioListTile<String>(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: const Text('Correo electrónico (Email)', style: TextStyle(fontSize: 13, fontFamily: 'Poppins')),
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
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        secondary: Icon(icon, color: const Color(0xFF0094FF), size: 20),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')),
        value: value,
        onChanged: onChanged,
        activeTrackColor: const Color(0xFF0094FF).withOpacity(0.5),
        activeColor: const Color(0xFF0094FF),
      ),
    );
  }
}
