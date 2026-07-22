import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AISearchService {
  // TODO: Replace with your actual API Key or use --dart-define
  // For safety, this should ideally be fetched from a remote config or env variable.
  static const String _apiKey = 'AIzaSyBfq958S6r0l7-XRB-flUd8MJH2QXaYDnQ';

  late final GenerativeModel _model;
  bool _initialized = false;

  AISearchService() {
    _init();
  }

  void _init() {
    if (_apiKey.isEmpty || _apiKey.contains('YOUR_GEMINI_API_KEY')) {
      print('Warning: Gemini API Key not configured. Key: \$_apiKey');
      return;
    }
    print(
      'AISearchService initializing with key starting with: \${_apiKey.substring(0, 5)}...',
    );
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
    _initialized = true;
  }

  Future<List<String>> expandSearchQuery(String query) async {
    if (!_initialized) return [];

    try {
      final prompt =
          '''
      Act as a search assistant for a marketplace app. 
      The user is searching for: "$query".
      
      Provide a JSON list of 3 to 5 single-word keywords or short phrases that are synonyms, related categories, or broader terms for this item. 
      Do not include explanations. Output ONLY valid JSON.
      
      Example Input: "Asus TUF 16"
      Example Output: ["Asus", "Portátil", "Laptop", "Gamer", "Computador"]
      
      Example Input: "Iphone 15"
      Example Output: ["iPhone", "Apple", "Celular", "Smartphone", "Móvil"]
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final text = response.text;

      if (text == null) return [];
      return _parseJsonList(text);
    } catch (e) {
      print('AI Search Error: $e');
      return [];
    }
  }

  Future<List<String>> analyzeImageUrl(String imageUrl) async {
    if (!_initialized) return [];

    try {
      print('Downloading image for analysis: $imageUrl');
      final imageResp = await http.get(Uri.parse(imageUrl));
      if (imageResp.statusCode != 200) {
        print('Failed to download image: \${imageResp.statusCode}');
        return [];
      }

      final imageBytes = imageResp.bodyBytes;

      final prompt = '''
      Analyze this image for a marketplace listing.
      Return a JSON list of 5-8 keywords that describe the product.
      Include: Product Type, Brand (if visible), Color, Key Features.
      Example: ["Laptop", "Asus", "Gaming", "Black", "RGB Keyboard"]
      Do NOT include explanations. Output ONLY valid JSON.
      ''';

      // Guess mime type roughly or just use image/jpeg (Gemini is robust)
      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ];

      final response = await _model.generateContent(content);
      final text = response.text;

      if (text == null) return [];
      print('Image analysis result: $text');
      return _parseJsonList(text);
    } catch (e) {
      print('AI Image Analysis Error: $e');
      return [];
    }
  }

  List<String> _parseJsonList(String text) {
    try {
      final cleanText = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final List<dynamic> jsonList = jsonDecode(cleanText);
      return jsonList.map((e) => e.toString()).toList();
    } catch (e) {
      print('JSON Parse Error: $e');
      return [];
    }
  }
}
