import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';
import 'map_picker_screen.dart';

/// Panel inferior para la selección de ubicación inicial.
/// 
/// Presenta una interfaz integrada con vista previa de mapa, botón de geolocalización,
/// historial de ubicaciones y sugerencias rápidas.
class LocationBottomSheet extends StatefulWidget {
  final String? currentLocation;

  const LocationBottomSheet({super.key, this.currentLocation});

  @override
  State<LocationBottomSheet> createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends State<LocationBottomSheet> {
  final LocationService _locationService = LocationService();
  List<String> _recentLocations = ['Medellín']; // Mock para UI inicial
  final List<String> _suggestions = ['Bogotá', 'Bucaramanga'];

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  /// Carga las ubicaciones recientes guardadas.
  Future<void> _loadRecents() async {
    final recents = await _locationService.getRecentLocations();
    if (recents.isNotEmpty) {
      setState(() => _recentLocations = recents);
    }
  }

  /// Abre la pantalla de búsqueda y/o mapa completo.
  Future<void> _openSearch() async {
    await _openMapPicker();
  }

  /// Abre el selector de mapa a pantalla completa.
  Future<void> _openMapPicker() async {
    final lat = _locationService.currentPosition?.latitude ?? 7.8939;
    final lng = _locationService.currentPosition?.longitude ?? -72.5078;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLat: lat, initialLng: lng),
      ),
    );
    if (result != null && mounted) {
      _locationService.setSelectedLocation(
        result['latitude'],
        result['longitude'],
      );
      Navigator.pop(context, result['name']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F6F6),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMapPreview(),
                const SizedBox(height: 8),
                _buildSelectionInfo(),
                const SizedBox(height: 10),
                _buildShowAllOption(),
                const SizedBox(height: 10),
                _buildSectionHeader('Recientes'),
                ..._recentLocations
                    .take(2)
                    .map((loc) => _buildRecentItem(loc, Icons.history)),
                const SizedBox(height: 10),
                _buildSectionHeader('Sugerencias'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _suggestions
                        .take(5)
                        .map((city) => _buildSuggestionChip(city))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el indicador visual para arrastrar el panel.
  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: 35,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Construye el encabezado con título y botón de búsqueda.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Elige una ubicación',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch),
        ],
      ),
    );
  }

  /// Genera una vista previa del mapa con dimensiones compactas.
  Widget _buildMapPreview() {
    final lat = _locationService.currentPosition?.latitude ?? 7.8939;
    final lng = _locationService.currentPosition?.longitude ?? -72.5078;

    return GestureDetector(
      onTap: _openMapPicker,
      child: Container(
        height: 80, // Altura ultra-reducida
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade200,
        ),
        clipBehavior: Clip.antiAlias,
        child: IgnorePointer(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(lat, lng),
              zoom: 13,
            ),
            circles: {
              Circle(
                circleId: const CircleId('preview'),
                center: LatLng(lat, lng),
                radius: 3000,
                fillColor: const Color(0x330094FF),
                strokeColor: const Color(0xFF0094FF),
                strokeWidth: 1,
              ),
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
          ),
        ),
      ),
    );
  }

  /// Muestra la información de la ubicación actual y botón de acción.
  Widget _buildSelectionInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.currentLocation ?? 'Seleccionar ubicación',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 32,
          child: ElevatedButton.icon(
            onPressed: () async {
              await _locationService.updateCurrentLocation();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.my_location, size: 14, color: Colors.white),
            label: const Text(
              'Ubicar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0094FF),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Genera el encabezado de cada sección de forma compacta.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          fontFamily: 'Poppins',
          color: Colors.black87,
        ),
      ),
    );
  }

  /// Genera un ítem de historial con diseño compacto.
  Widget _buildRecentItem(String name, IconData icon) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 18, color: Colors.grey),
      title: Text(
        name,
        style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'),
      ),
      dense: true,
      onTap: () async {
        await _locationService.saveRecentLocation(name);
        await _locationService.setLocationByName(name);
        if (mounted) Navigator.pop(context, name);
      },
    );
  }

  /// Construye un chip de sugerencia de ciudad.
  /// 
  /// @param city Nombre de la ciudad sugerida.
  Widget _buildSuggestionChip(String city) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: const Icon(Icons.location_on_outlined, size: 14),
        label: Text(city),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        onPressed: () async {
          await _locationService.saveRecentLocation(city);
          await _locationService.setLocationByName(city);
          if (mounted) Navigator.pop(context, city);
        },
      ),
    );
  }

  Widget _buildShowAllOption() {
    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.public, color: Color(0xFF0094FF), size: 20),
      title: const Text(
        'Mostrar todo',
        style: TextStyle(
          color: Color(0xFF0094FF),
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.pop(context, 'Todo');
      },
    );
  }
}
