import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../app.dart';
import 'package:shared_preferences/shared_preferences.dart';
class TwoFactorScreen extends StatefulWidget {
  final String email;
  final String method; // 'sms' or 'email'

  const TwoFactorScreen({
    super.key,
    required this.email,
    required this.method,
  });

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final _auth = AuthService();
  bool _isLoading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  Future<void> _sendCode() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _auth.send2FACode(userId: userId, method: widget.method);
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _verify();
    }
  }

  Future<void> _verify() async {
    setState(() {
      _isLoading = true;
      _error = false;
    });

    final code = _controllers.map((c) => c.text).join();
    
    bool success = false;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      success = await _auth.verify2FACode(userId, code);
    }

    if (success) {
      if (userId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('2fa_verified_$userId', true);
      }
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate(initial2faVerified: true)),
          (route) => false,
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _error = true;
        for (var c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await FirebaseAuth.instance.signOut();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const Text(
                    'Verificación en dos pasos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'BankGothic',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hemos enviado un código a tu ${widget.method == 'email' ? 'correo' : 'teléfono'}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      6,
                      (index) => SizedBox(
                        width: 45,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          maxLength: 1,
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _error ? Colors.red : Colors.transparent,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF1E88E5)),
                            ),
                          ),
                          onChanged: (v) => _onChanged(v, index),
                        ),
                      ),
                    ),
                  ),
                  if (_error) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Código incorrecto. Inténtalo de nuevo.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 40),
                  if (_isLoading)
                    const CircularProgressIndicator(color: Color(0xFF1E88E5))
                  else
                    TextButton(
                      onPressed: _sendCode,
                      child: const Text(
                        '¿No recibiste el código? Reenviar',
                        style: TextStyle(color: Color(0xFF1E88E5)),
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

