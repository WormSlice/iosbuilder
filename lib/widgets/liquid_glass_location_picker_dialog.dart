import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../services/location_service.dart';
import 'location_picker/map_picker_screen.dart';

/// Modal Liquid Glass para búsqueda y selección universal de ubicaciones en Colombia
/// (ciudades, municipios, pueblos, corregimientos y veredas).
class LiquidGlassLocationPickerDialog extends StatefulWidget {
  final String? currentLocation;

  const LiquidGlassLocationPickerDialog({
    super.key,
    this.currentLocation,
  });

  static Future<String?> show({
    required BuildContext context,
    String? currentLocation,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => LiquidGlassLocationPickerDialog(
        currentLocation: currentLocation,
      ),
    );
  }

  @override
  State<LiquidGlassLocationPickerDialog> createState() =>
      _LiquidGlassLocationPickerDialogState();
}

class _LiquidGlassLocationPickerDialogState
    extends State<LiquidGlassLocationPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();

  List<String> _filteredLocations = [];
  bool _isSearchingGeocoding = false;
  List<String> _geocodedResults = [];

  // Lista exhaustiva de ciudades, municipios y pueblos principales de Colombia
  static const List<String> _colombiaPlaces = [
    'Bogotá, D.C.',
    'Medellín, Antioquia',
    'Cali, Valle del Cauca',
    'Barranquilla, Atlántico',
    'Cartagena, Bolívar',
    'Bucaramanga, Santander',
    'Pereira, Risaralda',
    'Manizales, Caldas',
    'Cúcuta, Norte de Santander',
    'Ibagué, Tolima',
    'Santa Marta, Magdalena',
    'Villavicencio, Meta',
    'Pasto, Nariño',
    'Armenia, Quindío',
    'Montería, Córdoba',
    'Valledupar, Cesar',
    'Popayán, Cauca',
    'Sincelejo, Sucre',
    'Neiva, Huila',
    'Tunja, Boyacá',
    'Riohacha, La Guajira',
    'Florencia, Caquetá',
    'Quibdó, Chocó',
    'Yopal, Casanare',
    'Mocoa, Putumayo',
    'San Andrés, San Andrés y Providencia',
    'Envigado, Antioquia',
    'Bello, Antioquia',
    'Itagüí, Antioquia',
    'Sabaneta, Antioquia',
    'Rionegro, Antioquia',
    'Guarne, Antioquia',
    'Marinilla, Antioquia',
    'La Ceja, Antioquia',
    'El Retiro, Antioquia',
    'Guatapé, Antioquia',
    'Jardín, Antioquia',
    'Jerico, Antioquia',
    'Santa Fe de Antioquia, Antioquia',
    'Soledad, Atlántico',
    'Malambo, Atlántico',
    'Puerto Colombia, Atlántico',
    'Floridablanca, Santander',
    'Girón, Santander',
    'Piedecuesta, Santander',
    'Barrancabermeja, Santander',
    'San Gil, Santander',
    'Barichara, Santander',
    'Zapatoca, Santander',
    'Socorro, Santander',
    'Soacha, Cundinamarca',
    'Chía, Cundinamarca',
    'Zipaquirá, Cundinamarca',
    'Facatativá, Cundinamarca',
    'Fusagasugá, Cundinamarca',
    'Mosquera, Cundinamarca',
    'Madrid, Cundinamarca',
    'Funza, Cundinamarca',
    'Cajicá, Cundinamarca',
    'Girardot, Cundinamarca',
    'Sopó, Cundinamarca',
    'Tocancipá, Cundinamarca',
    'Cota, Cundinamarca',
    'La Calera, Cundinamarca',
    'Villeta, Cundinamarca',
    'Anapoima, Cundinamarca',
    'La Mesa, Cundinamarca',
    'Guaduas, Cundinamarca',
    'Subachoque, Cundinamarca',
    'Tabio, Cundinamarca',
    'Tenjo, Cundinamarca',
    'Gachancipá, Cundinamarca',
    'Sesquilé, Cundinamarca',
    'Guatavita, Cundinamarca',
    'Suesca, Cundinamarca',
    'Nemocón, Cundinamarca',
    'Villa de Leyva, Boyacá',
    'Duitama, Boyacá',
    'Sogamoso, Boyacá',
    'Paipa, Boyacá',
    'Chiquinquirá, Boyacá',
    'Monguí, Boyacá',
    'Iza, Boyacá',
    'Ráquira, Boyacá',
    'Nobsa, Boyacá',
    'Tibata, Boyacá',
    'Moniquirá, Boyacá',
    'Palmira, Valle del Cauca',
    'Buenaventura, Valle del Cauca',
    'Tuluá, Valle del Cauca',
    'Cartago, Valle del Cauca',
    'Buga (Guadalajara de Buga), Valle del Cauca',
    'Jamundí, Valle del Cauca',
    'Yumbo, Valle del Cauca',
    'Candelaria, Valle del Cauca',
    'Roldanillo, Valle del Cauca',
    'Sevilla, Valle del Cauca',
    'Dosquebradas, Risaralda',
    'Santa Rosa de Cabal, Risaralda',
    'La Virginia, Risaralda',
    'Marsella, Risaralda',
    'Belén de Umbría, Risaralda',
    'Santuario, Risaralda',
    'Calarcá, Quindío',
    'Salento, Quindío',
    'Filandia, Quindío',
    'Circasia, Quindío',
    'Montenegro, Quindío',
    'Quimbaya, Quindío',
    'La Tebaida, Quindío',
    'Villamaría, Caldas',
    'Chinchiná, Caldas',
    'Neira, Caldas',
    'Anserma, Caldas',
    'Riosucio, Caldas',
    'Salamina, Caldas',
    'Aguadas, Caldas',
    'Pensilvania, Caldas',
    'La Dorada, Caldas',
    'Espinal, Tolima',
    'Melgar, Tolima',
    'Flandes, Tolima',
    'Mariquita, Tolima',
    'Honda, Tolima',
    'Chaparral, Tolima',
    'Líbano, Tolima',
    'Pitalito, Huila',
    'Garzón, Huila',
    'La Plata, Huila',
    'San Agustín, Huila',
    'Rivera, Huila',
    'Gigante, Huila',
    'Aipe, Huila',
    'Turbaco, Bolívar',
    'Arjona, Bolívar',
    'Carmen de Bolívar, Bolívar',
    'Magangué, Bolívar',
    'Mompox (Santa Cruz de Mompox), Bolívar',
    'Cereté, Córdoba',
    'Sahagún, Córdoba',
    'Lorica, Córdoba',
    'Planeta Rica, Córdoba',
    'Montelíbano, Córdoba',
    'Ciénaga, Magdalena',
    'Fundación, Magdalena',
    'El Banco, Magdalena',
    'Plato, Magdalena',
    'Aracataca, Magdalena',
    'Aguachica, Cesar',
    'Codazzi, Cesar',
    'Bosconia, Cesar',
    'Curumaní, Cesar',
    'La Paz, Cesar',
    'Ocaña, Norte de Santander',
    'Pamplona, Norte de Santander',
    'Villa del Rosario, Norte de Santander',
    'Los Patios, Norte de Santander',
    'Tibú, Norte de Santander',
    'Chinácota, Norte de Santander',
    'Ipiales, Nariño',
    'Tumaco, Nariño',
    'Túquerres, Nariño',
    'La Unión, Nariño',
    'Samaniego, Nariño',
    'Santander de Quilichao, Cauca',
    'Puerto Tejada, Cauca',
    'Patía (El Bordo), Cauca',
    'Piendamó, Cauca',
    'Silvia, Cauca',
    'Corinto, Cauca',
    'Acacías, Meta',
    'Granada, Meta',
    'Puerto López, Meta',
    'Cumaral, Meta',
    'San Martín, Meta',
    'Maicao, La Guajira',
    'Uribia, La Guajira',
    'Manaure, La Guajira',
    'Fonseca, La Guajira',
    'San Juan del Cesar, La Guajira',
    'Villanueva, La Guajira',
    'Aguazul, Casanare',
    'Villanueva, Casanare',
    'Tauramena, Casanare',
    'Paz de Ariporo, Casanare',
    'San Vicente del Caguán, Caquetá',
    'Puerto Asís, Putumayo',
    'Orito, Putumayo',
    'Valle del Guamuez (La Hormiga), Putumayo',
    'Istmina, Chocó',
    'Tadó, Chocó',
    'Condoto, Chocó',
    'Bahía Solano, Chocó',
    'Nuquí, Chocó',
    'San José del Guaviare, Guaviare',
    'Inírida, Guainía',
    'Mitú, Vaupés',
    'Puerto Carreño, Vichada',
    'Leticia, Amazonas',
    'Puerto Nariño, Amazonas',
  ];

  @override
  void initState() {
    super.initState();
    _filteredLocations = _colombiaPlaces;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredLocations = _colombiaPlaces;
        _geocodedResults = [];
        _isSearchingGeocoding = false;
      });
      return;
    }

    final qLower = query.toLowerCase();
    final localMatches = _colombiaPlaces
        .where((place) => place.toLowerCase().contains(qLower))
        .toList();

    setState(() {
      _filteredLocations = localMatches;
    });

    if (query.length >= 3) {
      _searchDynamicGeocoding(query);
    }
  }

  Future<void> _searchDynamicGeocoding(String query) async {
    setState(() => _isSearchingGeocoding = true);
    try {
      final placemarks = await locationFromAddress('$query, Colombia');
      if (placemarks.isNotEmpty) {
        final List<String> dynamicList = [];
        for (var loc in placemarks.take(3)) {
          final places = await placemarkFromCoordinates(loc.latitude, loc.longitude);
          if (places.isNotEmpty) {
            final p = places.first;
            final parts = <String>[];
            if (p.name != null && p.name!.isNotEmpty && p.name != p.locality) {
              parts.add(p.name!);
            }
            if (p.subLocality != null && p.subLocality!.isNotEmpty) {
              parts.add(p.subLocality!);
            }
            if (p.locality != null && p.locality!.isNotEmpty) {
              parts.add(p.locality!);
            }
            if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
              parts.add(p.administrativeArea!);
            }
            if (parts.isNotEmpty) {
              final formatted = parts.toSet().join(', ');
              if (!dynamicList.contains(formatted) && !_filteredLocations.contains(formatted)) {
                dynamicList.add(formatted);
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _geocodedResults = dynamicList;
            _isSearchingGeocoding = false;
          });
        }
      } else {
        if (mounted) setState(() => _isSearchingGeocoding = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingGeocoding = false);
    }
  }

  Future<void> _useCurrentGps() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Obteniendo ubicación GPS...'),
        duration: Duration(seconds: 2),
      ),
    );

    await _locationService.updateCurrentLocation();
    if (_locationService.currentPosition != null) {
      try {
        final placemarks = await placemarkFromCoordinates(
          _locationService.currentPosition!.latitude,
          _locationService.currentPosition!.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[];
          if (p.subLocality != null && p.subLocality!.isNotEmpty) {
            parts.add(p.subLocality!);
          }
          if (p.locality != null && p.locality!.isNotEmpty) {
            parts.add(p.locality!);
          }
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
            parts.add(p.administrativeArea!);
          }
          final locationName = parts.isNotEmpty ? parts.join(', ') : (_locationService.currentCity ?? 'Colombia');
          if (mounted) {
            Navigator.pop(context, locationName);
          }
          return;
        }
      } catch (_) {}
    }

    if (_locationService.currentCity != null && mounted) {
      Navigator.pop(context, _locationService.currentCity);
    }
  }

  Future<void> _openMap() async {
    final lat = _locationService.selectedLat ?? 4.5709;
    final lng = _locationService.selectedLng ?? -74.2973;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: lat,
          initialLng: lng,
        ),
      ),
    );

    if (result != null && result['name'] != null && mounted) {
      Navigator.pop(context, result['name'].toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final typedText = _searchController.text.trim();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomInset + 16,
        top: 40,
      ),
      child: LiquidGlassLens(
        style: const LiquidGlassStyle(
          shape: LiquidGlassShape.squircle(cornerRadius: 30),
          appearance: LiquidGlassAppearance(
            color: Color(0xE614161E), // Dark frosted pure liquid glass
          ),
        ),
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull indicator pill
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF0094FF),
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Seleccionar Ubicación',
                        style: TextStyle(
                          fontFamily: 'CanvaSans',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Liquid Glass Search Input Field
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'Buscar pueblo, vereda, municipio o ciudad...',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF0094FF),
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons: GPS & Interactive Map
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _useCurrentGps,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0094FF).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF0094FF).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.my_location_rounded, color: Color(0xFF0094FF), size: 15),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Mi ubicación GPS',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openMap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_rounded, color: Colors.white70, size: 15),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Abrir mapa',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Custom typed location button (when user types a specific vereda/sector)
              if (typedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, typedText),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0094FF),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_location_alt_rounded, color: Color(0xFF0094FF), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                text: 'Usar: ',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                                children: [
                                  TextSpan(
                                    text: '"$typedText"',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 12),
                        ],
                      ),
                    ),
                  ),
                ),

              // Dynamic geocoding loader
              if (_isSearchingGeocoding)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0094FF),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Buscando veredas y municipios...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),

              // Search results list
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (_geocodedResults.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          'Sugerencias geográficas',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0094FF),
                          ),
                        ),
                      ),
                      ..._geocodedResults.map((loc) => _buildLocationItem(loc, isGeocoded: true)),
                      const Divider(color: Colors.white12, height: 16),
                    ],
                    ..._filteredLocations.map((loc) => _buildLocationItem(loc)),
                    if (_filteredLocations.isEmpty && _geocodedResults.isEmpty && !_isSearchingGeocoding)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.location_off_rounded, color: Colors.white.withOpacity(0.4), size: 36),
                              const SizedBox(height: 8),
                              Text(
                                'No se encontraron coincidencias locales',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Puedes presionar "Usar: $typedText" arriba para guardarlo.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationItem(String location, {bool isGeocoded = false}) {
    final isSelected = widget.currentLocation != null &&
        widget.currentLocation!.toLowerCase().trim() == location.toLowerCase().trim();

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: Icon(
        isGeocoded ? Icons.explore_rounded : Icons.location_on_outlined,
        size: 18,
        color: isSelected ? const Color(0xFF0094FF) : Colors.white60,
      ),
      title: Text(
        location,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? const Color(0xFF0094FF) : Colors.white,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0094FF), size: 18)
          : null,
      onTap: () {
        Navigator.pop(context, location);
      },
    );
  }
}
