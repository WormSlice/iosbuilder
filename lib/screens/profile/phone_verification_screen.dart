import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String? initialPhone;

  const PhoneVerificationScreen({
    super.key,
    this.initialPhone,
  });

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());

  String _selectedCountryCode = '+57';
  bool _codeSent = false;
  String _verificationId = '';
  int? _resendToken;
  String _fullPhoneNumber = '';

  bool _isLoading = false;
  String _errorMessage = '';
  int _countdownSeconds = 60;
  Timer? _countdownTimer;

  final List<Map<String, String>> _countries = const [
    {'name': 'Colombia', 'code': '+57', 'flag': '🇨🇴'},
    {'name': 'México', 'code': '+52', 'flag': '🇲🇽'},
    {'name': 'Estados Unidos', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'España', 'code': '+34', 'flag': '🇪🇸'},
    {'name': 'Argentina', 'code': '+54', 'flag': '🇦🇷'},
    {'name': 'Chile', 'code': '+56', 'flag': '🇨🇱'},
    {'name': 'Perú', 'code': '+51', 'flag': '🇵🇪'},
    {'name': 'Ecuador', 'code': '+593', 'flag': '🇪🇨'},
    {'name': 'Venezuela', 'code': '+58', 'flag': '🇻🇪'},
    {'name': 'Panamá', 'code': '+507', 'flag': '🇵🇦'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      String clean = widget.initialPhone!.trim();
      for (var country in _countries) {
        if (clean.startsWith(country['code']!)) {
          _selectedCountryCode = country['code']!;
          clean = clean.substring(country['code']!.length).trim();
          break;
        }
      }
      _phoneController.text = clean.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    for (var c in _codeControllers) {
      c.dispose();
    }
    for (var f in _codeFocusNodes) {
      f.dispose();
    }
    super.dispose();
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

  String _formatFriendlyError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'El formato del número es inválido. Verifica los dígitos.';
        case 'too-many-requests':
          return 'Demasiados intentos. Por seguridad, espera unos minutos.';
        case 'quota-exceeded':
          return 'Límite de SMS diarios alcanzado. Intenta de nuevo más tarde.';
        case 'invalid-verification-code':
          return 'El código ingresado es incorrecto.';
        case 'session-expired':
          return 'El código ha expirado. Solicita un nuevo código.';
        case 'credential-already-in-use':
          return 'Este número ya está vinculado a otra cuenta de CONNECT.';
        case 'app-not-authorized':
          return 'Verificación del dispositivo no autorizada. Intenta más tarde.';
        default:
          return e.message ?? 'Ocurrió un error al enviar el código.';
      }
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<void> _sendVerificationCode({bool isResend = false}) async {
    final rawNumber = _phoneController.text.trim();
    if (rawNumber.isEmpty || rawNumber.length < 7) {
      setState(() {
        _errorMessage = 'Por favor ingresa un número de teléfono válido';
      });
      return;
    }

    final formattedPhone = '$_selectedCountryCode$rawNumber';
    _fullPhoneNumber = AuthService.sanitizePhoneNumber(formattedPhone);

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _authService.verifyPhone(
        phoneNumber: _fullPhoneNumber,
        forceResendingToken: isResend ? _resendToken : null,
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          // Instant verification on Android
          try {
            await _authService.linkPhoneCredential(credential);
            if (mounted) {
              setState(() => _isLoading = false);
              Navigator.pop(context, true);
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = _formatFriendlyError(e);
              });
            }
          }
        },
        onCodeSent: (verificationId, resendToken) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _verificationId = verificationId;
              _resendToken = resendToken;
              _codeSent = true;
              _errorMessage = '';
            });
            _startCountdown();
            // Focus on first code input
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _codeFocusNodes[0].requestFocus();
            });
          }
        },
        onVerificationFailed: (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = _formatFriendlyError(e);
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _formatFriendlyError(e);
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeControllers.map((c) => c.text.trim()).join();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Ingresa los 6 dígitos del código');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _authService.linkPhone(_verificationId, code);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _formatFriendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () {
            if (_codeSent) {
              setState(() {
                _codeSent = false;
                _errorMessage = '';
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        centerTitle: true,
        title: Text(
          _codeSent ? 'Confirmar Código' : 'Vincular Teléfono',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'Archivo',
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _codeSent ? _buildCodeStep() : _buildPhoneStep(),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Agrega tu número móvil',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontFamily: 'Archivo',
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Te enviaremos un código seguro por SMS para certificar tu línea de forma 100% directa en la app.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontFamily: 'Poppins',
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        // Input de teléfono con selector de país
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              // Dropdown de código de país
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                  items: _countries.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['code'],
                      child: Row(
                        children: [
                          Text(c['flag'] ?? '', style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            c['code'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCountryCode = val);
                  },
                ),
              ),

              Container(
                height: 24,
                width: 1,
                color: const Color(0xFFCBD5E1),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),

              // Campo de texto del número
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: '300 123 4567',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 36),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _sendVerificationCode(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0094FF),
              disabledBackgroundColor: const Color(0xFF0094FF).withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Verificando dispositivo...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Enviar Código por SMS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Archivo',
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Ingresa el código',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontFamily: 'Archivo',
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enviamos un SMS con un código de 6 dígitos a $_fullPhoneNumber',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontFamily: 'Poppins',
            height: 1.4,
          ),
        ),
        const SizedBox(height: 36),

        // Cajas para los 6 dígitos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 44,
              height: 54,
              child: TextField(
                controller: _codeControllers[index],
                focusNode: _codeFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0094FF), width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _codeFocusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _codeFocusNodes[index - 1].requestFocus();
                  }
                  if (_codeControllers.every((c) => c.text.isNotEmpty)) {
                    _verifyCode();
                  }
                },
              ),
            );
          }),
        ),

        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 28),

        // Temporizador de reenvío
        Center(
          child: _countdownSeconds > 0
              ? Text(
                  'Reenviar código en ${_countdownSeconds}s',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                )
              : TextButton(
                  onPressed: _isLoading ? null : () => _sendVerificationCode(isResend: true),
                  child: const Text(
                    'Reenviar Código por SMS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0094FF),
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0094FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Verificar y Vincular',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Archivo',
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _codeSent = false;
                _errorMessage = '';
                for (var c in _codeControllers) {
                  c.clear();
                }
              });
            },
            child: const Text(
              'Cambiar número de teléfono',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
