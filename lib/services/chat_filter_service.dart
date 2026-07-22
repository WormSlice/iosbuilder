import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_tag.dart';

class ChatFilterService extends ChangeNotifier {
  static const String _tagsKey = 'chat_tags_';
  static const String _pinnedKey = 'chat_pinned_';
  static const String _hiddenKey = 'chat_hidden_';

  List<ChatTag> _tags = [];
  List<String> _pinnedChatIds = [];
  List<String> _hiddenChatIds = [];
  ChatTag? _activeFilter;
  String? _userId;

  ChatFilterService() {
    _tags = [
      ChatTag(id: todoId, name: 'Todo', color: 0xFF1E88E5, type: TagType.fixed),
      ChatTag(id: unreadId, name: 'No leídos', color: 0xFF43A047, type: TagType.fixed),
      ChatTag(id: favoritesId, name: 'Favoritos', color: 0xFFFDD835, type: TagType.fixed),
    ];
    _activeFilter = _tags.first;
  }

  List<ChatTag> get tags => _tags;
  List<String> get pinnedChatIds => _pinnedChatIds;
  List<String> get hiddenChatIds => _hiddenChatIds;
  ChatTag? get activeFilter => _activeFilter;

  // Fixed tags IDs
  static const String todoId = 'all';
  static const String unreadId = 'unread';
  static const String favoritesId = 'favorites';

  Future<void> init(String userId) async {
    _userId = userId;
    await _loadTags();
    await _loadPinnedAndHidden();
  }

  Future<void> _loadPinnedAndHidden() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    _pinnedChatIds = prefs.getStringList('$_pinnedKey$_userId') ?? [];
    _hiddenChatIds = prefs.getStringList('$_hiddenKey$_userId') ?? [];
    notifyListeners();
  }

  Future<void> _loadTags() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final String? tagsJson = prefs.getString('$_tagsKey$_userId');

    List<ChatTag> loadedTags = [
      ChatTag(
        id: todoId,
        name: 'Todo',
        color: 0xFF1E88E5,
        type: TagType.fixed,
      ),
      ChatTag(
        id: unreadId,
        name: 'No leídos',
        color: 0xFF43A047,
        type: TagType.fixed,
      ),
      ChatTag(
        id: favoritesId,
        name: 'Favoritos',
        color: 0xFFFDD835,
        type: TagType.fixed,
      ),
    ];

    if (tagsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tagsJson);
        final customTags = decoded
            .map((e) => ChatTag.fromJson(e))
            .where((t) => t.type == TagType.custom)
            .toList();
        loadedTags.addAll(customTags);

        // Merge persisted favorites state if exists
        final persistedFav = decoded
            .map((e) => ChatTag.fromJson(e))
            .firstWhere(
              (t) => t.id == favoritesId,
              orElse: () => loadedTags[2],
            );
        loadedTags[2] = persistedFav;
      } catch (e) {
        debugPrint('Error loading tags: $e');
      }
    }

    _tags = loadedTags;
    // Default filter is "TODO"
    _activeFilter = _tags.first;
    notifyListeners();
  }

  Future<void> _saveTags() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    // We save all tags including fixed ones to persist assignments (favorites)
    final String encoded = jsonEncode(_tags.map((e) => e.toJson()).toList());
    await prefs.setString('$_tagsKey$_userId', encoded);
  }

  void selectFilter(ChatTag tag) {
    _activeFilter = tag;
    notifyListeners();
  }

  Future<void> addCustomTag(String name, int color) async {
    final newTag = ChatTag(
      id: const Uuid().v4(),
      name: name,
      color: color,
      type: TagType.custom,
    );
    _tags.add(newTag);
    await _saveTags();
    notifyListeners();
  }

  Future<void> updateCustomTag(ChatTag updatedTag) async {
    final index = _tags.indexWhere((t) => t.id == updatedTag.id);
    if (index != -1) {
      final finalTag = ChatTag(
        id: updatedTag.id,
        name: updatedTag.name,
        color: updatedTag.color,
        type: updatedTag.type,
        chatIds: _tags[index].chatIds,
      );
      _tags[index] = finalTag;
      await _saveTags();
      if (_activeFilter?.id == updatedTag.id) {
        _activeFilter = finalTag;
      }
      notifyListeners();
    }
  }

  Future<void> deleteCustomTag(String tagId) async {
    _tags.removeWhere((t) => t.id == tagId);
    if (_activeFilter?.id == tagId) {
      _activeFilter = _tags.first;
    }
    await _saveTags();
    notifyListeners();
  }

  // Toggle chat in a tag (mainly for Favorites and Custom tags)
  Future<void> toggleChatInTag(String chatId, ChatTag tag) async {
    if (tag.id == todoId || tag.id == unreadId) {
      return; // Can't manually assign to All or Unread
    }

    final index = _tags.indexWhere((t) => t.id == tag.id);
    if (index != -1) {
      final targetTag = _tags[index];
      if (targetTag.chatIds.contains(chatId)) {
        targetTag.chatIds.remove(chatId);
      } else {
        targetTag.chatIds.add(chatId);
      }
      await _saveTags();
      notifyListeners();
    }
  }

  bool isChatInTag(String chatId, String tagId) {
    final tag = _tags.firstWhere(
      (t) => t.id == tagId,
      orElse: () => _tags.first,
    );
    return tag.chatIds.contains(chatId);
  }

  // Helper for UI to check if chat is favorite
  bool isFavorite(String chatId) {
    return isChatInTag(chatId, favoritesId);
  }

  Future<void> toggleFavorite(String chatId) async {
    final favTag = _tags.firstWhere((t) => t.id == favoritesId);
    await toggleChatInTag(chatId, favTag);
  }

  // PINNING
  Future<void> togglePin(String chatId) async {
    if (_pinnedChatIds.contains(chatId)) {
      _pinnedChatIds.remove(chatId);
    } else {
      _pinnedChatIds.add(chatId);
    }
    await _savePinned();
    notifyListeners();
  }

  bool isPinned(String chatId) => _pinnedChatIds.contains(chatId);

  Future<void> _savePinned() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_pinnedKey$_userId', _pinnedChatIds);
  }

  // HIDING (DELETE)
  Future<void> hideChat(String chatId) async {
    if (!_hiddenChatIds.contains(chatId)) {
      _hiddenChatIds.add(chatId);
      await _saveHidden();
      notifyListeners();
    }
  }

  bool isHidden(String chatId) => _hiddenChatIds.contains(chatId);

  Future<void> _saveHidden() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_hiddenKey$_userId', _hiddenChatIds);
  }
}
