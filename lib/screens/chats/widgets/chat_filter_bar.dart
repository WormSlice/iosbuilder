
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connect/services/chat_filter_service.dart';
import 'package:connect/models/chat_tag.dart';
import 'tag_creation_dialog.dart';

class ChatFilterBar extends StatelessWidget {
  const ChatFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatFilterService>(
      builder: (context, service, _) {
        final tags = service.tags;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ...tags.map((tag) => _buildTagChip(context, tag, service)),
              const SizedBox(width: 8),
              _buildAddTagButton(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagChip(BuildContext context, ChatTag tag, ChatFilterService service) {
    final isSelected = service.activeFilter?.id == tag.id;
    final color = Color(tag.color);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => service.selectFilter(tag),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? (tag.type == TagType.custom ? color : const Color(0xFF0094FF)) : const Color(0xFFE5E5E5),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag.name,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack, // Efecto rebote suave
                    child: (isSelected && tag.type == TagType.custom && tag.id != ChatFilterService.todoId)
                        ? GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => TagCreationDialog(tagToEdit: tag),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.edit,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTagButton(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => const TagCreationDialog(),
      ),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, size: 20, color: Colors.black54),
      ),
    );
  }
}
