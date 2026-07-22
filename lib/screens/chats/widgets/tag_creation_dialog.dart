
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connect/services/chat_filter_service.dart';
import 'package:connect/models/chat_tag.dart';

class TagCreationDialog extends StatefulWidget {
  final ChatTag? tagToEdit;
  const TagCreationDialog({super.key, this.tagToEdit});

  @override
  State<TagCreationDialog> createState() => _TagCreationDialogState();
}

class _TagCreationDialogState extends State<TagCreationDialog> {
  final _controller = TextEditingController();
  int _selectedColor = 0xFF2196F3; // Default Blue

  final List<int> _colors = [
    0xFF2196F3, // Blue
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFFFF9800, // Orange
    0xFF009688, // Teal
    0xFF795548, // Brown
    0xFF607D8B, // Blue Grey
    0xFFF44336, // Red
  ];

  @override
  void initState() {
    super.initState();
    if (widget.tagToEdit != null) {
      _controller.text = widget.tagToEdit!.name;
      _selectedColor = widget.tagToEdit!.color;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Etiqueta',
          style: TextStyle(fontFamily: 'CanvaSans')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: Trabajo, Familia...',
            ),
          ),
          const SizedBox(height: 20),
          const Text('Color', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _colors.map((c) => _buildColorOption(c)).toList(),
          ),
        ],
      ),
      actions: [
        if (widget.tagToEdit != null)
          TextButton(
            onPressed: () {
              Provider.of<ChatFilterService>(context, listen: false)
                  .deleteCustomTag(widget.tagToEdit!.id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              final service = Provider.of<ChatFilterService>(context, listen: false);
              if (widget.tagToEdit != null) {
                final updated = ChatTag(
                  id: widget.tagToEdit!.id,
                  name: _controller.text.trim(),
                  color: _selectedColor,
                  type: TagType.custom,
                );
                service.updateCustomTag(updated);
              } else {
                service.addCustomTag(_controller.text.trim(), _selectedColor);
              }
              Navigator.pop(context);
            }
          },
          child: Text(widget.tagToEdit != null ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  Widget _buildColorOption(int color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(color),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.black, width: 2.5)
              : null,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                spreadRadius: 1,
              )
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
