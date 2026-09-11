import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
import '../config/music_keys.dart';

class MusicAuthService extends ChangeNotifier {
  static final MusicAuthService instance = MusicAuthService._internal();
  MusicAuthService._internal();

  bool _isSpotifyConnected = false;
  String? _spotifyUser;
  String? _spotifyEmail;
  String? _spotifyAvatar;
  String? _spotifyProduct;
  String? _spotifyAccessToken;
  String? _spotifyRefreshToken;

  bool _isAppleMusicConnected = false;
  String? _appleMusicUser;

  bool _isInitialized = false;
  bool _isAuthenticatingSpotify = false;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool get isSpotifyConnected => _isSpotifyConnected;
  String? get spotifyUser => _spotifyUser;
  String? get spotifyEmail => _spotifyEmail;
  String? get spotifyAvatar => _spotifyAvatar;
  String? get spotifyProduct => _spotifyProduct;
  String? get spotifyAccessToken => _spotifyAccessToken;
  String? get spotifyRefreshToken => _spotifyRefreshToken;
  bool get isAuthenticatingSpotify => _isAuthenticatingSpotify;

  bool get isAppleMusicConnected => _isAppleMusicConnected;
  String? get appleMusicUser => _appleMusicUser;
  bool get isAppleMusicConfigured => MusicKeys.hasAppleMusicConfigured;

  bool get hasAnyLinkedAccount => _isSpotifyConnected || _isAppleMusicConnected;
  bool get isAnyConnected => hasAnyLinkedAccount;

  String get linkedAccountStatusText {
    if (_isSpotifyConnected && _isAppleMusicConnected) {
      return 'Spotify y Apple Music vinculados';
    } else if (_isSpotifyConnected) {
      return 'Spotify (${_spotifyUser ?? "Vinculado"})';
    } else if (_isAppleMusicConnected) {
      return 'Apple Music (${_appleMusicUser ?? "Vinculado"})';
    }
    return 'Sin vincular';
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSpotifyConnected = prefs.getBool('music_spotify_connected') ?? false;
      _spotifyUser = prefs.getString('music_spotify_user');
      _spotifyEmail = prefs.getString('music_spotify_email');
      _spotifyAvatar = prefs.getString('music_spotify_avatar');
      _spotifyProduct = prefs.getString('music_spotify_product');
      _spotifyAccessToken = prefs.getString('music_spotify_token');
      _spotifyRefreshToken = prefs.getString('music_spotify_refresh_token');

      _isAppleMusicConnected = prefs.getBool('music_apple_connected') ?? false;
      _appleMusicUser = prefs.getString('music_apple_user');

      _isInitialized = true;

      // Escuchar deep links de redirección de autenticación (Spotify OAuth)
      _initDeepLinks();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error initializing MusicAuthService: $e');
    }
  }

  void _initDeepLinks() {
    _linkSubscription?.cancel();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => handleIncomingUri(uri),
      onError: (err) {
        if (kDebugMode) print('Error en uriLinkStream: $err');
      },
    );

    // Revisar si la app fue abierta inicialmente desde un deep link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) handleIncomingUri(uri);
    });
  }

  /// Inicia el flujo REAL de autenticación de Spotify con Authorization Code Flow (response_type=code)
  Future<bool> startSpotifyAuth() async {
    _isAuthenticatingSpotify = true;
    notifyListeners();

    try {
      final scopeStr = MusicKeys.spotifyScopes.join(' ');
      final authUri = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': MusicKeys.spotifyClientId,
        'response_type': 'code', // Spotify requiere obligatoriamente 'code'
        'redirect_uri': MusicKeys.spotifyRedirectUri,
        'scope': scopeStr,
        'show_dialog': 'true',
      });

      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _isAuthenticatingSpotify = false;
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error iniciando Spotify OAuth: $e');
      _isAuthenticatingSpotify = false;
      notifyListeners();
      return false;
    }
  }

  /// Procesa la URL de redirección cuando Spotify devuelve el código de autorización (code)
  Future<bool> handleIncomingUri(Uri uri) async {
    final uriStr = uri.toString();
    if (!uriStr.contains('spotify-callback')) {
      return false;
    }

    try {
      // 1. Extraer el código de autorización (query parameter 'code')
      String? code = uri.queryParameters['code'];

      // Fallback a fragment si viene allí
      if (code == null && uri.fragment.isNotEmpty) {
        final fragmentParams = Uri.splitQueryString(uri.fragment);
        code = fragmentParams['code'];
      }

      if (code != null && code.isNotEmpty) {
        // 2. Intercambiar el código por access_token y refresh_token
        final tokens = await _exchangeCodeForTokens(code);
        if (tokens != null) {
          final accessToken = tokens['access_token']?.toString();
          final refreshToken = tokens['refresh_token']?.toString();

          if (accessToken != null && accessToken.isNotEmpty) {
            // 3. Consultar perfil del usuario en Spotify
            final userProfile = await _fetchSpotifyProfile(accessToken);
            if (userProfile != null) {
              final prefs = await SharedPreferences.getInstance();

              _isSpotifyConnected = true;
              _spotifyAccessToken = accessToken;
              _spotifyRefreshToken = refreshToken;
              _spotifyUser = userProfile['name'] ?? 'Usuario Spotify';
              _spotifyEmail = userProfile['email'];
              _spotifyAvatar = userProfile['avatar'];
              _spotifyProduct = userProfile['product'] ?? 'Free';
              _isAuthenticatingSpotify = false;

              await prefs.setBool('music_spotify_connected', true);
              await prefs.setString('music_spotify_token', _spotifyAccessToken!);
              if (_spotifyRefreshToken != null) {
                await prefs.setString(
                    'music_spotify_refresh_token', _spotifyRefreshToken!);
              }
              await prefs.setString('music_spotify_user', _spotifyUser!);
              if (_spotifyEmail != null) {
                await prefs.setString('music_spotify_email', _spotifyEmail!);
              }
              if (_spotifyAvatar != null) {
                await prefs.setString('music_spotify_avatar', _spotifyAvatar!);
              }
              if (_spotifyProduct != null) {
                await prefs.setString('music_spotify_product', _spotifyProduct!);
              }

              notifyListeners();
              return true;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error procesando callback de Spotify: $e');
    }

    _isAuthenticatingSpotify = false;
    notifyListeners();
    return false;
  }

  /// Intercambia el código de autorización por tokens de acceso
  Future<Map<String, dynamic>?> _exchangeCodeForTokens(String code) async {
    try {
      final credentials = '${MusicKeys.spotifyClientId}:${MusicKeys.spotifyClientSecret}';
      final basicAuth = base64Encode(utf8.encode(credentials));

      final res = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $basicAuth',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': MusicKeys.spotifyRedirectUri,
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      } else {
        if (kDebugMode) {
          print('Error en token exchange: ${res.statusCode} -> ${res.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error exchanging Spotify code for tokens: $e');
    }
    return null;
  }

  /// Refresca el access token cuando expira usando el refresh token
  Future<String?> refreshSpotifyToken() async {
    if (_spotifyRefreshToken == null || _spotifyRefreshToken!.isEmpty) {
      return null;
    }

    try {
      final credentials = '${MusicKeys.spotifyClientId}:${MusicKeys.spotifyClientSecret}';
      final basicAuth = base64Encode(utf8.encode(credentials));

      final res = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $basicAuth',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': _spotifyRefreshToken!,
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _spotifyAccessToken = data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('music_spotify_token', _spotifyAccessToken!);
        return _spotifyAccessToken;
      }
    } catch (e) {
      if (kDebugMode) print('Error refreshing Spotify token: $e');
    }
    return null;
  }

  /// Consulta los datos del usuario real autenticado en Spotify
  Future<Map<String, dynamic>?> _fetchSpotifyProfile(String accessToken) async {
    try {
      final res = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final displayName = data['display_name']?.toString() ??
            data['id']?.toString() ??
            'Usuario Spotify';
        final email = data['email']?.toString();
        final product = data['product']?.toString(); // 'premium', 'free', 'open'

        String? avatarUrl;
        final images = data['images'] as List? ?? [];
        if (images.isNotEmpty) {
          avatarUrl = images.first['url']?.toString();
        }

        return {
          'name': displayName,
          'email': email,
          'product': product,
          'avatar': avatarUrl,
        };
      }
    } catch (e) {
      if (kDebugMode) print('Error obteniendo perfil de Spotify: $e');
    }
    return null;
  }

  /// Desvincula la cuenta de Spotify
  Future<void> disconnectSpotify() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSpotifyConnected = false;
      _spotifyUser = null;
      _spotifyEmail = null;
      _spotifyAvatar = null;
      _spotifyProduct = null;
      _spotifyAccessToken = null;
      _spotifyRefreshToken = null;
      _isAuthenticatingSpotify = false;

      await prefs.remove('music_spotify_connected');
      await prefs.remove('music_spotify_token');
      await prefs.remove('music_spotify_refresh_token');
      await prefs.remove('music_spotify_user');
      await prefs.remove('music_spotify_email');
      await prefs.remove('music_spotify_avatar');
      await prefs.remove('music_spotify_product');

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error desvinculando Spotify: $e');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
}
