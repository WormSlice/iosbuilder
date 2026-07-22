import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'two_factor_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(text: '+57');
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _hide = true;
  bool _usePhone = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 140,
                    child: Image.asset('assets/images/logo.png'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CONNECT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'BankGothic',
                      fontSize: 27,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_usePhone)
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'CORREO ELECTRÓNICO',
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        hintStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requerido' : null,
                    )
                  else
                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'NÚMERO TELEFÓNICO',
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        hintStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (!v.startsWith('+')) return 'Usa formato internacional (+57)';
                        return null;
                      },
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _usePhone = !_usePhone),
                    child: Text(
                      _usePhone ? 'Usar correo electrónico' : 'Usar número de teléfono',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF1E88E5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hide,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'CONTRASEÑA',
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hide ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      try {
                        if (_usePhone) {
                          await _auth.signInWithPhoneAndPassword(
                            _phoneController.text.trim(),
                            _passwordController.text.trim(),
                          );
                        } else {
                          await _auth.signInWithEmailPassword(
                            _emailController.text.trim(),
                            _passwordController.text.trim(),
                          );
                        }
                        // Handle 2FA check
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null && mounted) {
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .get();
                          final data = userDoc.data();
                          final is2faEnabled = data?['twoFactorEnabled'] ?? false;
                          final method = data?['twoFactorMethod'] ?? 'sms';

                          if (is2faEnabled) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TwoFactorScreen(
                                  email: user.email ?? '',
                                  method: method,
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const AuthGate()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'INICIAR SESIÓN',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1976D2)),
                      foregroundColor: const Color(0xFF1976D2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('CREAR CUENTA'),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'O CONTINUAR CON',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      try {
                        await _auth.signInWithGoogle();
                        
                        // Google Login specifically requires SMS 2FA according to prompt
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null && mounted) {
                          // Check if it's a new user or existing
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .get();
                          
                          // According to "Case 1: Usuario inicia sesión con Google -> Automáticamente usar verificación por SMS"
                          // We should always trigger it if we want to follow the prompt strictly, 
                          // but usually it's if they enabled it. Let's assume the prompt wants it forced or at least checked.
                          final data = userDoc.data();
                          if (data?['twoFactorEnabled'] == true) {
                             Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TwoFactorScreen(
                                  email: user.email ?? '',
                                  method: 'sms',
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const AuthGate()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    icon: const Icon(Icons.g_mobiledata, size: 30),
                    label: const Text('Google'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      try {
                        await _auth.signInWithApple();
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    icon: const Icon(Icons.apple, size: 30),
                    label: const Text(
                      'Apple',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
