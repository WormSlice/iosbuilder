import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicAuthService extends ChangeNotifier {
  static final MusicAuthService instance = MusicAuthService._internal();
  MusicAuthService._internal();

  bool _isSpotifyConnected = false;
  String? _spotifyUser;
  String? _spotifyAvatar;
  String? _spotifyProduct;
  String? _spotifyAccessToken;

  bool _isAppleMusicConnected = false;
  String? _appleMusicUser;

  bool _isInitialized = false;

  bool get isSpotifyConnected => _isSpotifyConnected;
  String? get spotifyUser => _spotifyUser;
  String? get spotifyAvatar => _spotifyAvatar;
  String? get spotifyProduct => _spotifyProduct;
  String? get spotifyAccessToken => _spotifyAccessToken;

  bool get isAppleMusicConnected => _isAppleMusicConnected;
  String? get appleMusicUser => _appleMusicUser;

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
      _spotifyAvatar = prefs.getString('music_spotify_avatar');
      _spotifyProduct = prefs.getString('music_spotify_product');
      _spotifyAccessToken = prefs.getString('music_spotify_token');

      _isAppleMusicConnected = prefs.getBool('music_apple_connected') ?? false;
      _appleMusicUser = prefs.getString('music_apple_user');

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error initializing MusicAuthService: $e');
    }
  }

  /// Vincula la cuenta de Spotify del usuario
  Future<bool> connectSpotify({
    String? customDisplayName,
    String? customAvatar,
    String? token,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isSpotifyConnected = true;
      _spotifyUser = customDisplayName ?? 'Usuario Spotify';
      _spotifyAvatar = customAvatar ??
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200';
      _spotifyProduct = 'Premium';
      _spotifyAccessToken = token ?? 'mock_spotify_token_${DateTime.now().millisecondsSinceEpoch}';

      await prefs.setBool('music_spotify_connected', true);
      await prefs.setString('music_spotify_user', _spotifyUser!);
      await prefs.setString('music_spotify_avatar', _spotifyAvatar!);
      await prefs.setString('music_spotify_product', _spotifyProduct!);
      await prefs.setString('music_spotify_token', _spotifyAccessToken!);

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error connecting Spotify: $e');
      return false;
    }
  }

  /// Desvincula la cuenta de Spotify
  Future<void> disconnectSpotify() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSpotifyConnected = false;
      _spotifyUser = null;
      _spotifyAvatar = null;
      _spotifyProduct = null;
      _spotifyAccessToken = null;

      await prefs.remove('music_spotify_connected');
      await prefs.remove('music_spotify_user');
      await prefs.remove('music_spotify_avatar');
      await prefs.remove('music_spotify_product');
      await prefs.remove('music_spotify_token');

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error disconnecting Spotify: $e');
    }
  }

  /// Vincula la cuenta de Apple Music
  Future<bool> connectAppleMusic({String? customDisplayName}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isAppleMusicConnected = true;
      _appleMusicUser = customDisplayName ?? 'Apple Music User';

      await prefs.setBool('music_apple_connected', true);
      await prefs.setString('music_apple_user', _appleMusicUser!);

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error connecting Apple Music: $e');
      return false;
    }
  }

  /// Desvincula la cuenta de Apple Music
  Future<void> disconnectAppleMusic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAppleMusicConnected = false;
      _appleMusicUser = null;

      await prefs.remove('music_apple_connected');
      await prefs.remove('music_apple_user');

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error disconnecting Apple Music: $e');
    }
  }
}
