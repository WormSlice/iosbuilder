import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connect/services/chat_filter_service.dart';
import 'package:connect/models/chat_tag.dart';
import 'tag_creation_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatOptionsSheet extends StatelessWidget {
  final String chatId;

  const ChatOptionsSheet({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Consumer<ChatFilterService>(
        builder: (context, service, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Etiquetas del chat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'CanvaSans',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.blue,
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const TagCreationDialog(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...service.tags
                  .where(
                    (t) =>
                        t.id != ChatFilterService.todoId &&
                        t.id != ChatFilterService.unreadId,
                  )
                  .map((tag) => _buildTagOption(context, tag, service)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildActionOption(
                context,
                icon: service.isPinned(chatId)
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                label: service.isPinned(chatId) ? 'Desfijar' : 'Fijar',
                color: Colors.black87,
                onTap: () {
                  service.togglePin(chatId);
                  Navigator.pop(context);
                },
              ),
              _buildActionOption(
                context,
                icon: Icons.delete_outline,
                label: 'Eliminar',
                color: Colors.red,
                onTap: () async {
                  await FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .delete();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildTagOption(
    BuildContext context,
    ChatTag tag,
    ChatFilterService service,
  ) {
    final isAssigned = service.isChatInTag(chatId, tag.id);
    return ListTile(
      leading: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Color(tag.color),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(tag.name),
      trailing: isAssigned
          ? const Icon(Icons.check_circle, color: Colors.blue)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: () => service.toggleChatInTag(chatId, tag),
      contentPadding: EdgeInsets.zero,
    );
  }
}
