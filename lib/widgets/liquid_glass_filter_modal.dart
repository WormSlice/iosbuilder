import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../services/location_service.dart';
import 'location_picker/map_picker_screen.dart';

/// Modal de Filtro con diseño PURE LIQUID GLASS idéntico a Brexcel ERP.
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
      barrierColor: Colors.black.withValues(alpha: 0.65), // Oscurece el fondo para que el cristal resalte y sea legible
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
          initialLat: locService.selectedLat ?? 8.7479,
          initialLng: locService.selectedLng ?? -75.8814,
          initialRadius: locService.currentRadius,
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
      child: LiquidGlassLens(
        style: const LiquidGlassStyle(
          shape: LiquidGlassShape.squircle(cornerRadius: 32),
          appearance: LiquidGlassAppearance(
            color: Color(0xD91C1E26), // Cristalline dark frosted glass (un poquitico menos transparente)
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Píldora superior Liquid Glass
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header con Título y Botón Cerrar (Círculo Liquid Glass)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtros de Búsqueda',
                    style: TextStyle(
                      fontFamily: 'CanvaSans',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: LiquidGlassLens(
                      style: const LiquidGlassStyle(
                        shape: LiquidGlassShape.squircle(cornerRadius: 18),
                        appearance: LiquidGlassAppearance(
                          color: Colors.white10,
                        ),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Sección Ubicación
              const Text(
                'Ubicación',
                style: TextStyle(
                  fontFamily: 'CanvaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _openMapPicker,
                borderRadius: BorderRadius.circular(20),
                child: LiquidGlassLens(
                  style: const LiquidGlassStyle(
                    shape: LiquidGlassShape.squircle(cornerRadius: 20),
                    appearance: LiquidGlassAppearance(
                      color: Colors.white10,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF0094FF), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedCity.isEmpty ? 'Todo Colombia' : _selectedCity,
                            style: const TextStyle(
                              fontFamily: 'CanvaSans',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 6),
                              ],
                            ),
                          ),
                        ),
                        LiquidGlassLens(
                          style: const LiquidGlassStyle(
                            shape: LiquidGlassShape.squircle(cornerRadius: 14),
                            appearance: LiquidGlassAppearance(
                              color: Color(0x660094FF),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: const Text(
                              'Cambiar',
                              style: TextStyle(
                                fontFamily: 'CanvaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black87, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sección Ordenamiento
              const Text(
                'Ordenar resultados',
                style: TextStyle(
                  fontFamily: 'CanvaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildSortTile('relevancia', 'Por relevancia', Icons.auto_awesome),
              _buildSortTile('reciente', 'Más reciente', Icons.access_time),
              _buildSortTile('precio_asc', 'Precio: menor a mayor', Icons.arrow_upward),
              _buildSortTile('precio_desc', 'Precio: mayor a menor', Icons.arrow_downward),
              const SizedBox(height: 24),

              // Botón Aplicar Filtros (Liquid Glass resaltado)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: LiquidGlassLens(
                  style: const LiquidGlassStyle(
                    shape: LiquidGlassShape.squircle(cornerRadius: 18),
                    appearance: LiquidGlassAppearance(
                      color: Color(0xCC0094FF),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onApply(_selectedSort, _selectedCity);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: const Center(
                      child: Text(
                        'Aplicar Filtros',
                        style: TextStyle(
                          fontFamily: 'CanvaSans',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
        borderRadius: BorderRadius.circular(16),
        child: LiquidGlassLens(
          style: LiquidGlassStyle(
            shape: const LiquidGlassShape.squircle(cornerRadius: 16),
            appearance: LiquidGlassAppearance(
              color: isSelected
                  ? const Color(0x880094FF)
                  : const Color(0x22FFFFFF),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF0094FF) : Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'CanvaSans',
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.white70,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFF0094FF), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
