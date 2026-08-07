import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/location_service.dart';
import 'location_picker/map_picker_screen.dart';

/// Modal de Filtro con diseño Liquid Glass super transparente.
class LiquidGlassFilterModal extends StatefulWidget {
  final String currentSort;
  final String currentCity;
  final Function(String selectedSort, String selectedCity) onApply;

  const LiquidGlassFilterModal({
    super.key,
    required this.currentSort,
    required this.currentCity,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    required String currentSort,
    required String currentCity,
    required Function(String selectedSort, String selectedCity) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) => LiquidGlassFilterModal(
        currentSort: currentSort,
        currentCity: currentCity,
        onApply: onApply,
      ),
    );
  }

  @override
  State<LiquidGlassFilterModal> createState() => _LiquidGlassFilterModalState();
}

class _LiquidGlassFilterModalState extends State<LiquidGlassFilterModal> {
  late String _selectedSort;
  late String _selectedCity;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.currentSort;
    _selectedCity = widget.currentCity;
  }

  Future<void> _openMapPicker() async {
    final locService = LocationService();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLat: locService.currentLat ?? 8.7479,
          initialLng: locService.currentLng ?? -75.8814,
          initialRadius: locService.currentRadius ?? 10,
        ),
      ),
    );

    if (result != null && result['name'] != null) {
      setState(() {
        _selectedCity = result['name'].toString();
      });
      locService.setCurrentCity(_selectedCity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + 20,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Flotante / Píldora Superior
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtros de Búsqueda',
                      style: TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black.withOpacity(0.85),
                        shadows: [
                          Shadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.black.withOpacity(0.7)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sección 1: Ubicación
                Text(
                  'Ubicación',
                  style: TextStyle(
                    fontFamily: 'CanvaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _openMapPicker,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.7),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF0094FF), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedCity.isEmpty ? 'Todo Colombia' : _selectedCity,
                            style: const TextStyle(
                              fontFamily: 'CanvaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0094FF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Cambiar',
                            style: TextStyle(
                              fontFamily: 'CanvaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0094FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sección 2: Ordenamiento
                Text(
                  'Ordenar resultados',
                  style: TextStyle(
                    fontFamily: 'CanvaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                _buildSortTile('relevancia', 'Por relevancia', Icons.auto_awesome),
                _buildSortTile('reciente', 'Más reciente', Icons.access_time),
                _buildSortTile('precio_asc', 'Precio: menor a mayor', Icons.arrow_upward),
                _buildSortTile('precio_desc', 'Precio: mayor a menor', Icons.arrow_downward),
                const SizedBox(height: 24),

                // Botón Aplicar
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onApply(_selectedSort, _selectedCity);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0094FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Aplicar Filtros',
                      style: TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortTile(String value, String title, IconData icon) {
    final bool isSelected = _selectedSort == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedSort = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0094FF).withOpacity(0.18)
                : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0094FF).withOpacity(0.6)
                  : Colors.white.withOpacity(0.5),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF0094FF) : Colors.black54,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'CanvaSans',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0094FF) : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Color(0xFF0094FF), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
