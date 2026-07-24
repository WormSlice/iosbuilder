import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://firestore.googleapis.com/v1/projects/connect-6e069/databases/(default)/documents/posts?pageSize=2'));
  print(res.body);
}
