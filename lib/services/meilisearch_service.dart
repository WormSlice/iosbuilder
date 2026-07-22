import 'package:meilisearch/meilisearch.dart';

class MeiliSearchService {
  static final MeiliSearchService _instance = MeiliSearchService._internal();
  factory MeiliSearchService() => _instance;
  MeiliSearchService._internal();

  // Configuración de Meilisearch
  final String _url = 'http://10.42.0.85:7701';
  final String _masterKey = 'master_key';

  late MeiliSearchClient _client;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    print('DEBUG: Inicializando Meilisearch con URL: $_url');
    _client = MeiliSearchClient(_url, _masterKey);
    _initialized = true;
  }

  MeiliSearchClient get client {
    if (!_initialized) init();
    return _client;
  }

  // Índices
  static const String postsIndex = 'posts';
  static const String wantsIndex = 'wants';

  Future<SearchResult> searchPosts(
    String query, {
    String? city,
    Map<String, dynamic>? filter,
    int limit = 20,
  }) async {
    final index = client.index(postsIndex);

    List<String> filters = [];

    if (city != null && city.isNotEmpty && city.toLowerCase() != 'todo') {
      filters.add('city = "$city"');
    }

    if (filter != null) {
      filter.forEach((key, value) {
        filters.add('$key = "$value"');
      });
    }

    // Asegurar que solo mostramos publicaciones activas si el campo existe
    // filters.add('status = "active"'); // Opcional, dependiendo de la lógica de negocio

    final result = await index.search(
      query,
      SearchQuery(
        filter: filters.isNotEmpty ? filters.join(' AND ') : null,
        sort: ['createdAt:desc'],
        limit: limit,
      ),
    );

    return result as SearchResult;
  }

  Future<SearchResult> searchWants(
    String query, {
    String? city,
    int limit = 20,
  }) async {
    final index = client.index(wantsIndex);

    List<String> filters = [];
    if (city != null && city.toLowerCase() != 'todo') {
      filters.add('city = "$city"');
    }

    final result = await index.search(
      query,
      SearchQuery(
        filter: filters.isNotEmpty ? filters.join(' AND ') : null,
        sort: ['createdAt:desc'],
        limit: limit,
      ),
    );

    return result as SearchResult;
  }
}
