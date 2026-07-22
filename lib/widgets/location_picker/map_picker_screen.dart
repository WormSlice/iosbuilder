import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/location_service.dart';
import 'dart:async';

/// Pantalla de selección de ubicación mediante mapa interactivo.
/// 
/// Permite al usuario mover el mapa para centrar la ubicación deseada
/// y ajustar un radio de búsqueda mediante un control deslizante.
class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialRadius;

  const MapPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialRadius = 23,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

const String _mapStyle = '''
[
  {
    "featureType": "poi",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.business",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  }
]
''';

class _MapPickerScreenState extends State<MapPickerScreen> {
  late GoogleMapController _mapController;
  late LatLng _currentCenter;
  late double _currentRadius;
  bool _customRadius = true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<String> _suggestions = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  bool _isGeocoding = false;
  bool _hasSearchFocus = false;

  @override
  void initState() {
    super.initState();
    _currentCenter = LatLng(widget.initialLat, widget.initialLng);
    _currentRadius = widget.initialRadius;
    _searchFocus.addListener(() {
      setState(() {
        _hasSearchFocus = _searchFocus.hasFocus;
      });
    });
    _loadRecents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final recents = await LocationService().getRecentLocations();
    if (mounted) {
      setState(() => _recentSearches = recents);
    }
  }

  Future<void> _removeRecent(String location) async {
    await LocationService().removeRecentLocation(location);
    _loadRecents();
  }

  Future<void> _clearRecents() async {
    await LocationService().clearRecentLocations();
    _loadRecents();
  }

  /// Actualiza el centro del mapa al mover la cámara.
  /// 
  /// @param position Nueva posición de la cámara.
  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
  }

  /// Se ejecuta cuando el mapa deja de moverse.
  void _onCameraIdle() {
    setState(() {}); // Actualiza los círculos al dejar de mover
    _reverseGeocode(_currentCenter);
  }

  /// Obtiene el nombre de la ciudad a partir de coordenadas.
  Future<void> _reverseGeocode(LatLng position) async {
    if (_isGeocoding) return;
    _isGeocoding = true;
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final cityName =
            place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea;

        if (cityName != null) {
          setState(() {
            _searchController.text = cityName;
          });
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    } finally {
      _isGeocoding = false;
    }
  }

  /// Realiza la búsqueda de ciudades según el texto ingresado.
  void _onSearchChanged(String query) async {
    if (query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    final results = await LocationService().searchCities(query);
    setState(() {
      _suggestions = results;
      _isSearching = true;
    });
  }

  /// Geocodifica la ciudad seleccionada y mueve la cámara del mapa.
  void _selectSuggestion(String city) async {
    _searchFocus.unfocus();
    setState(() {
      _isSearching = false;
      _suggestions = [];
      _searchController.text = city;
    });

    // Guardar en recientes al elegir sugerencia o reciente explícito
    await LocationService().saveRecentLocation(city);
    _loadRecents();

    final coords = await LocationService().getCoordinatesFromAddress(city);
    if (coords != null) {
      final latLng = LatLng(coords['latitude']!, coords['longitude']!);
      _mapController.animateCamera(CameraUpdate.newLatLng(latLng));
    }
  }

  /// Confirma la ubicación seleccionada y retorna los datos al llamador.
  void _onApply() {
    LocationService().setCurrentRadius(_currentRadius);
    LocationService().setSelectedLocation(
      _currentCenter.latitude,
      _currentCenter.longitude,
    );
    final String finalName = _searchController.text.isNotEmpty
        ? _searchController.text
        : 'Punto en mapa';

    Navigator.pop(context, {
      'latitude': _currentCenter.latitude,
      'longitude': _currentCenter.longitude,
      'radius': _currentRadius,
      'name': finalName == 'Todo' ? 'Todo' : finalName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F6),
        elevation: 0,
        toolbarHeight: 48,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ubicación',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentCenter,
                    zoom: 13,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _mapController.setMapStyle(_mapStyle);
                  },
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  circles: {
                    Circle(
                      circleId: const CircleId('radius_circle'),
                      center: _currentCenter,
                      radius: _currentRadius * 1000,
                      fillColor: const Color(0x330094FF),
                      strokeColor: const Color(0xFF0094FF),
                      strokeWidth: 2,
                    ),
                  },
                ),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 35),
                    child: Icon(
                      Icons.location_on,
                      color: Color(0xFF0094FF),
                      size: 36,
                    ),
                  ),
                ),
                // Buscador flotante dentro del mapa
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Buscar ciudad...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _suggestions = [];
                                        _isSearching = false;
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // New: Quick Filter "Todo"
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentRadius = 25000;
                              _searchController.text = 'Todo';
                            });
                            _onApply();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0094FF),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.public,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Todo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_isSearching && _suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                dense: true,
                                title: Text(
                                  _suggestions[index],
                                  style: const TextStyle(fontSize: 13),
                                ),
                                onTap: () =>
                                    _selectSuggestion(_suggestions[index]),
                              );
                            },
                          ),
                        )
                      else if (_hasSearchFocus &&
                          !_isSearching &&
                          _recentSearches.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Búsquedas recientes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _clearRecents,
                                      child: const Text(
                                        'Limpiar todo',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Flexible(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _recentSearches.length,
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.history,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                      title: Text(
                                        _recentSearches[index],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () => _removeRecent(
                                          _recentSearches[index],
                                        ),
                                      ),
                                      onTap: () => _selectSuggestion(
                                        _recentSearches[index],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () async {
                      final pos = await Geolocator.getCurrentPosition();
                      _mapController.animateCamera(
                        CameraUpdate.newLatLng(
                          LatLng(pos.latitude, pos.longitude),
                        ),
                      );
                    },
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  /// Genera el panel inferior con controles de radio compactos.
  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F6F6),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRadioOption(
            'Radio local sugerido',
            'Publicaciones cercanas recomendadas.',
            !_customRadius,
            () => setState(() => _customRadius = false),
          ),
          const SizedBox(height: 12),
          _buildRadioOption(
            'Radio personalizado',
            'Publicaciones dentro de una distancia específica.',
            _customRadius,
            () => setState(() => _customRadius = true),
          ),
          if (_customRadius) ...[
            Slider(
              value: _currentRadius,
              min: 0.5,
              max: 200,
              divisions: 399, // Pasos de 0.5km hasta 200km
              activeColor: const Color(0xFF0094FF),
              onChanged: (val) {
                setState(() {
                  _currentRadius = val;
                });
                // Ajustar zoom dinámicamente según el radio
                double zoom = 13;
                if (_currentRadius <= 1) {
                  zoom = 15;
                } else if (_currentRadius <= 5)
                  zoom = 14;
                else if (_currentRadius > 50)
                  zoom = 10;
                _mapController.animateCamera(CameraUpdate.zoomTo(zoom));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '0.5 KM',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  Text(
                    '${_currentRadius < 1 ? _currentRadius.toStringAsFixed(1) : _currentRadius.toInt()} KM',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Text(
                    '200 KM',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44, // Altura reducida
            child: ElevatedButton(
              onPressed: _onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0094FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    22,
                  ), // Botón más redondeado
                ),
              ),
              child: const Text(
                'Aplicar selección',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Genera una opción de selección radial compacta.
  Widget _buildRadioOption(
    String title,
    String desc,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? const Color(0xFF0094FF) : Colors.grey,
                width: 1.5,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0094FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
