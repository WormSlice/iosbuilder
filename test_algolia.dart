import 'package:algolia_client_search/algolia_client_search.dart';

void main() async {
  final hit = Hit(objectID: '123', additionalProperties: {'name': 'test'});
  print(hit.toJson());
}
