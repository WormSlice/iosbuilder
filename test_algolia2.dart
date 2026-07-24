import 'package:algolia_client_search/algolia_client_search.dart';

void main() async {
  try {
    final a = Action.fromJson('addObject');
    print(a);
  } catch(e) {
    print('ERROR: ');
  }
}
