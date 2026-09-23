import 'dart:async';
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
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (index) => FocusNode());
  final _auth = AuthService();

  late String _activeMethod;
  String? _phoneNumber;
  String? _verificationId;
  int? _resendToken;

  bool _isLoading = false;
  String? _errorMessage;
  int _countdownSeconds = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _activeMethod = widget.method;
    _initAndSend();
  }

  Future<void> _initAndSend() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final phone = await _auth.getUserPhone(userId);
      if (mounted) {
        setState(() {
          _phoneNumber = phone;
        });
      }
    }
    await _sendCode();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdownSeconds = 0);
      } else {
        if (mounted) setState(() => _countdownSeconds--);
      }
    });
  }

  Future<void> _sendCode({bool isResend = false}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_activeMethod == 'sms') {
      final phone = _phoneNumber ?? await _auth.getUserPhone(userId);
      if (phone == null || phone.trim().isEmpty) {
        setState(() {
          _isLoading = false;
          _activeMethod = 'email';
          _errorMessage =
              'No tienes un teléfono registrado. Hemos cambiado a verificación por correo.';
        });
        await _auth.send2FACode(
          userId: userId,
          method: 'email',
          targetEmail: widget.email,
        );
        _startCountdown();
        return;
      }

      try {
        await _auth.send2FASms(
          phoneNumber: phone,
          forceResendingToken: isResend ? _resendToken : null,
          onCodeSent: (verificationId, resendToken) {
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
                _resendToken = resendToken;
                _isLoading = false;
              });
              _startCountdown();
              _focusNodes[0].requestFocus();
            }
          },
          onVerificationFailed: (e) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                if (e.code == 'quota-exceeded') {
                  _errorMessage =
                      'Límite de SMS alcanzado. Puedes verificar por correo.';
                } else if (e.code == 'invalid-phone-number') {
                  _errorMessage =
                      'El teléfono registrado tiene formato inválido.';
                } else {
                  _errorMessage =
                      e.message ?? 'No se pudo enviar el SMS de seguridad.';
                }
              });
            }
          },
          onVerificationCompleted: (credential) async {
            // Auto-retrieval en Android
            if (credential.smsCode != null && credential.smsCode!.length == 6) {
              for (int i = 0; i < 6; i++) {
                _controllers[i].text = credential.smsCode![i];
              }
              await _verify();
            }
          },
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error al enviar código SMS: $e';
          });
        }
      }
    } else {
      // Email method
      try {
        await _auth.send2FACode(
          userId: userId,
          method: 'email',
          targetEmail: widget.email,
        );
        if (mounted) {
          setState(() => _isLoading = false);
          _startCountdown();
          _focusNodes[0].requestFocus();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error enviando correo de seguridad.';
          });
        }
      }
    }
  }

  void _switchMethod() {
    setState(() {
      _activeMethod = _activeMethod == 'sms' ? 'email' : 'sms';
      _errorMessage = null;
      for (var c in _controllers) {
        c.clear();
      }
    });
    _sendCode();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
    final code = _controllers.map((c) => c.text.trim()).join();
    if (code.length < 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    bool success = false;

    try {
      if (_activeMethod == 'sms') {
        if (_verificationId == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Solicita un nuevo código SMS para continuar.';
          });
          return;
        }
        success = await _auth.verify2FASms(
          verificationId: _verificationId!,
          smsCode: code,
        );
      } else {
        success = await _auth.verify2FACode(userId, code);
      }
    } on FirebaseAuthException catch (e) {
      success = false;
      if (e.code == 'invalid-verification-code') {
        _errorMessage = 'Código SMS incorrecto. Verifica los 6 dígitos.';
      } else if (e.code == 'session-expired') {
        _errorMessage = 'El código ha expirado. Solicita uno nuevo.';
      } else {
        _errorMessage = e.message ?? 'Error al verificar el código.';
      }
    } catch (e) {
      success = false;
      _errorMessage = 'Código de verificación incorrecto.';
    }

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('2fa_verified_$userId', true);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const AuthGate(initial2faVerified: true),
          ),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage ??= 'Código incorrecto. Inténtalo de nuevo.';
          for (var c in _controllers) {
            c.clear();
          }
          _focusNodes[0].requestFocus();
        });
      }
    }
  }

  String _getDestinationLabel() {
    if (_activeMethod == 'sms') {
      if (_phoneNumber != null && _phoneNumber!.length >= 4) {
        final lastDigits = _phoneNumber!.substring(_phoneNumber!.length - 4);
        return 'tu teléfono terminado en •••• $lastDigits';
      }
      return 'tu teléfono registrado';
    } else {
      if (widget.email.isNotEmpty && widget.email.contains('@')) {
        final parts = widget.email.split('@');
        final name = parts[0];
        final maskedName = name.length > 2
            ? '${name.substring(0, 2)}••••'
            : '$name••••';
        return 'tu correo $maskedName@${parts[1]}';
      }
      return 'tu correo electrónico';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await FirebaseAuth.instance.signOut();
        }
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 110,
                    child: Image.asset('assets/images/logo.png'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CONNECT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'BankGothic',
                      fontSize: 26,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _activeMethod == 'sms' ? Icons.sms_outlined : Icons.email_outlined,
                        color: const Color(0xFF1E88E5),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Verificación en dos pasos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'BankGothic',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hemos enviado un código de 6 dígitos a ${_getDestinationLabel()}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLength: 1,
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFF141414),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _errorMessage != null
                                    ? Colors.red
                                    : Colors.white12,
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
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const CircularProgressIndicator(color: Color(0xFF1E88E5))
                  else
                    Column(
                      children: [
                        TextButton(
                          onPressed: _countdownSeconds == 0
                              ? () => _sendCode(isResend: true)
                              : null,
                          child: Text(
                            _countdownSeconds > 0
                                ? 'Reenviar código en ${_countdownSeconds}s'
                                : '¿No recibiste el código? Reenviar',
                            style: TextStyle(
                              color: _countdownSeconds == 0
                                  ? const Color(0xFF1E88E5)
                                  : Colors.white38,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _switchMethod,
                          child: Text(
                            _activeMethod == 'sms'
                                ? 'Probar con Correo Electrónico'
                                : 'Probar con Mensaje de Texto (SMS)',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
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
