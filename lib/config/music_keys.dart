/// Configuración central de credenciales para servicios de música oficial (Spotify & Apple Music)
///
/// Configuración de Spotify:
/// - Client ID: 82292d9d581a422682d2b36d6d6049f4
/// - Client Secret: 82b77ef92d944fc2b7bf0786a8401805
/// - Redirect URI: connectapp://spotify-callback
/// - Package Name: com.connectapp.co
class MusicKeys {
  // --- SPOTIFY DEVELOPER CREDENTIALS ---
  static const String spotifyClientId = '82292d9d581a422682d2b36d6d6049f4';
  static const String spotifyClientSecret = '82b77ef92d944fc2b7bf0786a8401805';
  static const String spotifyRedirectUri = 'connectapp://spotify-callback';
  static const List<String> spotifyScopes = [
    'user-read-email',
    'user-read-private',
    'user-read-playback-state',
    'user-modify-playback-state',
    'streaming',
    'playlist-read-private',
    'user-library-read',
  ];

  // --- APPLE MUSIC (MUSICKIT) CREDENTIALS ---
  static const String appleMusicTeamId = '';
  static const String appleMusicKeyId = '';
  static const String appleMusicDeveloperToken = '';

  static bool get hasSpotifyConfigured => spotifyClientId.isNotEmpty;
  static bool get hasAppleMusicConfigured => appleMusicDeveloperToken.isNotEmpty;
}
