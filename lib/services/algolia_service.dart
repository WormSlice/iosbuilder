import 'package:algolia_client_search/algolia_client_search.dart';

class AlgoliaService {
  static final AlgoliaService _instance = AlgoliaService._internal();
  factory AlgoliaService() => _instance;
  AlgoliaService._internal();

  final String _appId = 'P2CJMQDDSH';
  final String _apiKey = '99ec76cf710a0324bccd1f008514eb36';

  late SearchClient _client;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    print('DEBUG: Inicializando Algolia...');
    _client = SearchClient(appId: _appId, apiKey: _apiKey);
    _initialized = true;
  }

  SearchClient get client {
    if (!_initialized) init();
    return _client;
  }

  static const String postsIndex = 'posts';
  static const String wantsIndex = 'wants';

  Future<SearchResponse> searchPosts(
    String query, {
    String? city,
    Map<String, dynamic>? filter,
    int limit = 20,
  }) async {
    List<String> filters = [];

    if (city != null && city.isNotEmpty && city.toLowerCase() != 'todo') {
      filters.add('city:"$city"');
    }

    if (filter != null) {
      filter.forEach((key, value) {
        filters.add('$key:"$value"');
      });
    }

    final result = await client.searchIndex(
      request: SearchForHits(
        indexName: postsIndex,
        query: query,
        hitsPerPage: limit,
        filters: filters.isNotEmpty ? filters.join(' AND ') : null,
      ),
    );

    return result;
  }

  Future<SearchResponse> searchWants(
    String query, {
    String? city,
    int limit = 20,
  }) async {
    List<String> filters = [];
    if (city != null && city.toLowerCase() != 'todo') {
      filters.add('city:"$city"');
    }

    final result = await client.searchIndex(
      request: SearchForHits(
        indexName: wantsIndex,
        query: query,
        hitsPerPage: limit,
        filters: filters.isNotEmpty ? filters.join(' AND ') : null,
      ),
    );

    return result;
  }
}
