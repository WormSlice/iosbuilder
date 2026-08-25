import 'package:flutter/material.dart';
import 'liquid_glass_location_picker_dialog.dart';

/// Campo de selección de ubicación universal para formularios de publicación y edición.
/// Abre un modal con diseño Liquid Glass que permite buscar cualquier pueblo, ciudad,
/// corregimiento o vereda en Colombia sin estar restringido a una lista cerrada.
class LocationSelectorField extends StatelessWidget {
  final String location;
  final ValueChanged<String> onLocationChanged;
  final String? label;

  const LocationSelectorField({
    super.key,
    required this.location,
    required this.onLocationChanged,
    this.label,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await LiquidGlassLocationPickerDialog.show(
      context: context,
      currentLocation: location,
    );

    if (selected != null && selected.isNotEmpty) {
      onLocationChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: () => _openPicker(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF0094FF),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    location.isNotEmpty ? location : 'Seleccionar ubicación...',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: location.isNotEmpty ? Colors.black87 : Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Buscar',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0094FF),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.search,
                        size: 13,
                        color: Color(0xFF0094FF),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
