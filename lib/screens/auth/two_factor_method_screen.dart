import 'package:flutter/material.dart';
import 'two_factor_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TwoFactorMethodScreen extends StatelessWidget {
  final User user;
  
  const TwoFactorMethodScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Al regresar atrás (cancelar), cerramos la sesión y dejamos que AuthGate vuelva al login
        await FirebaseAuth.instance.signOut();
        return false; 
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
            },
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.security, size: 80, color: Color(0xFF1E88E5)),
                const SizedBox(height: 24),
                const Text(
                  'Verificación en dos pasos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'BankGothic',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Para continuar, elige cómo deseas recibir tu código de seguridad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 48),
                _buildMethodCard(
                  context,
                  icon: Icons.sms_outlined,
                  title: 'Mensaje de Texto (SMS)',
                  subtitle: 'Te enviaremos un código al teléfono registrado.',
                  method: 'sms',
                ),
                const SizedBox(height: 16),
                _buildMethodCard(
                  context,
                  icon: Icons.email_outlined,
                  title: 'Correo Electrónico',
                  subtitle: 'Te enviaremos un código a tu correo electrónico.',
                  method: 'email',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required String method}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TwoFactorScreen(
              email: user.email ?? '',
              method: method,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1E88E5), size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}
