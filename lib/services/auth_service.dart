import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();

  Stream<User?> get userChanges => _auth.userChanges();

  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user != null) {
      await registerSession(credential.user!);
    }
    return credential;
  }

  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
    required String name,
    String? phone,
    File? image,
  }) async {
    // 1. Create User (This authenticates the session)
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    String? photoUrl;
    if (image != null && userCredential.user != null) {
      try {
        // 2. Upload Image (Now authenticated)
        final uid = userCredential.user!.uid;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pics')
            .child('$uid.jpg');
        await storageRef.putFile(image);
        photoUrl = await storageRef.getDownloadURL();
      } catch (e) {
        print('Error uploading profile pic: $e');
      }
    }

    if (userCredential.user != null) {
      final user = userCredential.user!;
      await user.updateDisplayName(name);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': name,
        'email': email,
        'phone': phone,
        'photoURL': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSignIn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await registerSession(user);
    }

    return userCredential;
  }

  Future<UserCredential> signInWithPhoneAndPassword(
    String phone,
    String password,
  ) async {
    // 1. Find the email associated with this phone number
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (userSnapshot.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No existe un usuario con este número de teléfono.',
      );
    }

    final email = userSnapshot.docs.first.get('email') as String;

    // 2. Sign in with email and password
    return signInWithEmailPassword(email, password);
  }

  // --- 2FA SYSTEM ---

  Future<void> send2FACode({required String userId, required String method}) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!userDoc.exists) return;
    
    final email = userDoc.get('email');
    final phone = userDoc.get('phone');
    final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();

    // Store code in Firestore temp collection
    await FirebaseFirestore.instance.collection('temp_2fa_codes').doc(userId).set({
      'code': code,
      'method': method,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
    });

    if (method == 'email') {
      try {
        final auth = base64Encode(utf8.encode('api:0b7c4497295d2319888303bd9120f5f9-ccbfdc2c-c034af37'));
        final response = await http.post(
          Uri.parse('https://api.mailgun.net/v3/connectapp.com.co/messages'),
          headers: {
            'Authorization': 'Basic $auth',
          },
          body: {
            'from': 'CONNECT <contacto@connectapp.com.co>',
            'to': email,
            'subject': 'Código de Verificación 2FA - CONNECT',
            'text': 'Tu código de verificación es: $code\nEste código expira en 5 minutos.',
            'html': '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px; text-align: center; background-color: #f9f9f9;"><h2 style="color: #1E88E5; margin-bottom: 20px; font-weight: bold; letter-spacing: 2px;">CONNECT</h2><p style="font-size: 16px; color: #333;">Hola,</p><p style="font-size: 16px; color: #333;">Tu código de verificación seguro de dos pasos es:</p><div style="font-size: 32px; font-weight: bold; color: #fff; background-color: #1E88E5; padding: 15px 30px; margin: 20px auto; width: fit-content; border-radius: 8px; letter-spacing: 4px;">$code</div><p style="font-size: 14px; color: #777;">Este código expira en 5 minutos. No compartas esto con nadie.</p></div>',
          },
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('DEBUG: 2FA Code sent to Email ($email) via MailGun API: $code');
        } else {
          print('Error en MailGun 2FA: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Error de conexión MailGun 2FA: $e');
      }
    } else if (method == 'sms') {
      // Logic to send SMS (Firebase Auth verification could be used or external provider)
      print('DEBUG: 2FA Code sent to SMS ($phone): $code');
    }
  }

  Future<bool> verify2FACode(String userId, String code) async {
    final doc = await FirebaseFirestore.instance.collection('temp_2fa_codes').doc(userId).get();
    if (!doc.exists) return false;
    
    final data = doc.data()!;
    final storedCode = data['code'];
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    
    if (DateTime.now().isAfter(expiresAt)) {
      await doc.reference.delete();
      return false;
    }
    
    if (storedCode == code) {
      await doc.reference.delete();
      return true;
    }
    
    return false;
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    final googleAuth = await googleUser?.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);

    // Save user data to Firestore
    if (userCredential.user != null) {
      final user = userCredential.user!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // Only set name and photo if it's the first time
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': user.displayName,
          'email': user.email,
          'photoURL': user.photoURL,
          'lastSignIn': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // If user exists, only update last sign in to preserve custom profile data
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'lastSignIn': FieldValue.serverTimestamp()});

        // Restore Firebase Auth photo/name matching Firestore, so UI isn't overridden
        final data = userDoc.data()!;
        final verifiedName = data['verifiedName']?.toString();
        final storedName = data['displayName']?.toString();

        // Priority to verifiedName if it exists and differs from stored, or just stored
        final dbName = (verifiedName != null && verifiedName.isNotEmpty)
            ? verifiedName
            : storedName;

        final dbPhoto =
            data['photoURL']?.toString() ??
            data['photoUrl']?.toString() ??
            data['image']?.toString() ??
            data['avatar']?.toString() ??
            data['foto']?.toString();

        if (dbName != null && dbName.isNotEmpty && dbName != user.displayName) {
          await user.updateDisplayName(dbName);
        }
        if (dbPhoto != null && dbPhoto.isNotEmpty && dbPhoto != user.photoURL) {
          await user.updatePhotoURL(dbPhoto);
        }
      }

      await registerSession(user);
    }

    return userCredential;
  }

  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
    final credential = oAuthProvider.credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    // Apple only provides the name on the very first sign-in.
    String? appleName;
    if (appleCredential.givenName != null ||
        appleCredential.familyName != null) {
      appleName =
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
              .trim();
    }

    // Save user data to Firestore
    if (userCredential.user != null) {
      final user = userCredential.user!;

      // Update display name in Firebase Auth if we got it from Apple
      if (appleName != null &&
          appleName.isNotEmpty &&
          user.displayName == null) {
        await user.updateDisplayName(appleName);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': appleName ?? user.displayName ?? 'Usuario de Apple',
        'email': user.email,
        'photoURL': user.photoURL,
        'lastSignIn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await registerSession(user);
    }

    return userCredential;
  }

  Future<UserCredential> linkWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) {
      throw Exception('Inicio de sesión con Google cancelado.');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.currentUser!.linkWithCredential(credential);
  }

  Future<UserCredential> linkWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
    final credential = oAuthProvider.credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    return await _auth.currentUser!.linkWithCredential(credential);
  }

  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.currentUser?.linkWithCredential(credential);
      },
      verificationFailed: onVerificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> linkPhone(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final user = _auth.currentUser;
    if (user != null) {
      await user.linkWithCredential(credential);
      // Also update Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'phone': user.phoneNumber, 'phoneVerified': true},
      );
    }
  }

  Future<void> unlinkPhone() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Unlink from Firebase Auth
      await user.unlink('phone');
      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'phone': FieldValue.delete(),
        'phoneVerified': false,
      });
    }
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      await removeSession(user);
    }
    await _auth.signOut();
    await _google.signOut();
  }

  Future<void> registerSession(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? sessionId = prefs.getString('device_session_id');

      if (sessionId == null) {
        sessionId = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .doc()
            .id;
        await prefs.setString('device_session_id', sessionId);
      }

      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Dispositivo Desconocido';
      String deviceType = 'Dispositivo';

      try {
        if (Platform.isAndroid) {
          final info = await deviceInfo.androidInfo;
          deviceName = '${info.brand} ${info.model}';
          deviceType = 'Android';
        } else if (Platform.isIOS) {
          final info = await deviceInfo.iosInfo;
          deviceName = info.name;
          deviceType = 'iPhone';
        } else if (Platform.isMacOS) {
          final info = await deviceInfo.macOsInfo;
          deviceName = info.computerName;
          deviceType = 'Mac';
        }
      } catch (_) {}

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(sessionId)
          .set({
            'deviceId': sessionId,
            'deviceName': deviceName,
            'deviceType': deviceType,
            'location': 'Ubicación aproximada',
            'lastActive': FieldValue.serverTimestamp(),
            'isActive': true,
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error registering session: $e');
    }
  }

  Future<void> removeSession(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('device_session_id');
      if (sessionId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .doc(sessionId)
            .delete();
      }
    } catch (e) {
      print('Error removing session: $e');
    }
  }
}
