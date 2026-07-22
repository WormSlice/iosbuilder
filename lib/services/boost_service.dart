import 'package:flutter/material.dart';

class BoostService extends ChangeNotifier {
  bool _showPrompt = false;
  String? _imageUrl;
  String? _postId;

  bool get showPrompt => _showPrompt;
  String? get imageUrl => _imageUrl;
  String? get postId => _postId;

  void show({required String imageUrl, required String postId}) {
    _showPrompt = true;
    _imageUrl = imageUrl;
    _postId = postId;
    notifyListeners();
  }

  void hide() {
    _showPrompt = false;
    _imageUrl = null;
    _postId = null;
    notifyListeners();
  }
}
