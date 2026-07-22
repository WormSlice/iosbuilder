import 'package:shared_preferences/shared_preferences.dart';

class SearchService {
  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  Future<void> saveSearch(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList(_recentSearchesKey) ?? [];

    // Remove if already exists to avoid duplicates
    searches.remove(query);

    // Add to the beginning
    searches.insert(0, query);

    // Keep only the most recent
    if (searches.length > _maxRecentSearches) {
      searches = searches.sublist(0, _maxRecentSearches);
    }

    await prefs.setStringList(_recentSearchesKey, searches);
  }

  Future<List<String>> getRecentSearches({int limit = 4}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList(_recentSearchesKey) ?? [];

    if (limit > 0 && searches.length > limit) {
      return searches.sublist(0, limit);
    }

    return searches;
  }

  Future<void> removeSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList(_recentSearchesKey) ?? [];
    searches.remove(query);
    await prefs.setStringList(_recentSearchesKey, searches);
  }

  Future<void> clearAllSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }
}
