

enum TagType { fixed, custom }

class ChatTag {
  final String id;
  final String name;
  final int color; // Store color as int for easy storage
  final TagType type;
  final List<String> chatIds;

  ChatTag({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    List<String>? chatIds,
  }) : chatIds = chatIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'type': type.index,
        'chatIds': chatIds,
      };

  factory ChatTag.fromJson(Map<String, dynamic> json) {
    return ChatTag(
      id: json['id'],
      name: json['name'],
      color: json['color'],
      type: TagType.values[json['type']],
      chatIds: List<String>.from(json['chatIds'] ?? []),
    );
  }
}
