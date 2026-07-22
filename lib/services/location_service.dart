import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio encargado de la gestión de ubicación, geocodificación y persistencia.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  String? _currentCity;
  double? _selectedLat;
  double? _selectedLng;
  double _currentRadius = 8.0;
  bool _isManualCity = false;
  static const String _recentKey = 'recent_locations';

  Position? get currentPosition => _currentPosition;
  String? get currentCity => _currentCity;
  double? get selectedLat => _selectedLat ?? _currentPosition?.latitude;
  double? get selectedLng => _selectedLng ?? _currentPosition?.longitude;
  double get currentRadius => _currentRadius;

  void setCurrentRadius(double radius) {
    _currentRadius = radius;
  }

  void setCurrentCity(String city) {
    _currentCity = city;
    _isManualCity = true;
  }

  /// Establece las coordenadas seleccionadas manualmente.
  void setSelectedLocation(double lat, double lng) {
    _selectedLat = lat;
    _selectedLng = lng;
  }

  /// Busca las coordenadas de una ubicación por nombre y las establece.
  Future<void> setLocationByName(String name) async {
    final coords = await getCoordinatesFromAddress(name);
    if (coords != null) {
      _selectedLat = coords['latitude'];
      _selectedLng = coords['longitude'];
    }
  }

  /// Gestiona los permisos de ubicación.
  /// 
  /// @return true si los permisos están concedidos, false de lo contrario.
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Obtiene la posición actual y la ciudad del usuario.
  Future<void> updateCurrentLocation() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return;

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_currentPosition != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        if (placemarks.isNotEmpty && !_isManualCity) {
          _currentCity =
              placemarks.first.locality ??
              placemarks.first.subAdministrativeArea;
        }
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  /// Obtiene coordenadas (latitud y longitud) a partir de un nombre de dirección o ciudad.
  Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return {
          'latitude': locations.first.latitude,
          'longitude': locations.first.longitude,
        };
      }
    } catch (e) {
      print('Error geocoding address "$address": $e');
    }
    return null;
  }

  /// Calcula la distancia entre dos puntos geográficos en KM.
  double? calculateDistanceRect(
    double? lat1,
    double? lng1,
    double? lat2,
    double? lng2,
  ) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return null;
    }
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// Calcula la distancia desde la posición actual hasta un punto dado.
  double? calculateDistance(double lat, double lng) {
    if (_currentPosition == null) return null;

    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        ) /
        1000; // Convert to km
  }

  /// Formatea la distancia para ser mostrada en la UI.
  String? formatDistance(double? km) {
    if (km == null) return null;
    if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(1)} KM';
  }

  /// Obtiene el historial de ubicaciones recientes desde SharedPreferences.
  Future<List<String>> getRecentLocations() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? [];
  }

  /// Guarda una ubicación en el historial reciente, con un límite de 10 entradas.
  Future<void> saveRecentLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_recentKey) ?? [];

    current.remove(location);
    current.insert(0, location);

    if (current.length > 10) {
      current.removeLast();
    }

    await prefs.setStringList(_recentKey, current);
  }

  /// Elimina una ubicación específica del historial reciente.
  Future<void> removeRecentLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_recentKey) ?? [];
    current.remove(location);
    await prefs.setStringList(_recentKey, current);
  }

  /// Limpia todo el historial de ubicaciones recientes.
  Future<void> clearRecentLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }

  // --- CITY DATA ---
  final List<String> _colombiaCities = [
    "Bogotá",
    "Medellín",
    "Cali",
    "Barranquilla",
    "Cartagena",
    "Cúcuta",
    "Bucaramanga",
    "Pereira",
    "Santa Marta",
    "Ibagué",
    "Bello",
    "Pasto",
    "Manizales",
    "Neiva",
    "Soledad",
    "Villavicencio",
    "Armenia",
    "Soacha",
    "Valledupar",
    "Itagüí",
    "Montería",
    "Sincelejo",
    "Popayán",
    "Floridablanca",
    "Palmira",
    "Buenaventura",
    "Barrancabermeja",
    "Dosquebradas",
    "Tuluá",
    "Envigado",
    "Cartago",
    "Maicao",
    "Florencia",
    "Girardot",
    "Facatativá",
    "Zipaquirá",
    "Chía",
    "Tumaco",
    "Jamundí",
    "Fusagasugá",
    "Mosquera",
    "Duitama",
    "Yopal",
    "Ciénaga",
    "Malambo",
    "Rionegro",
    "Ocaña",
    "Quibdó",
    "Apartadó",
    "Sogamoso",
    "Pitalito",
    "Turbo",
    "Ipiales",
    "Lorica",
    "Funza",
    "Villa del Rosario",
    "Sahagún",
    "Yumbo",
    "Cereté",
    "Caicedonia",
    "Aguachica",
    "Girón",
    "Espinal",
    "Magangué",
    "Piedecuesta",
    "Caucasia",
    "Sabaneta",
    "La Estrella",
    "Caldas",
    "Girardota",
    "Copacabana",
    "Marinilla",
    "Guarne",
    "El Carmen de Viboral",
    "La Ceja",
    "La Unión",
  ];

  /// Realiza una búsqueda de ciudades con normalización y priorización.
  Future<List<String>> searchCities(String query) async {
    if (query.isEmpty) return [];

    final normQuery = normalize(query);

    final startsWith = _colombiaCities
        .where((city) => normalize(city).startsWith(normQuery))
        .toList();

    final contains = _colombiaCities
        .where(
          (city) =>
              normalize(city).contains(normQuery) && !startsWith.contains(city),
        )
        .toList();

    return [...startsWith, ...contains];
  }

  /// Normaliza texto eliminando acentos y carácteres especiales.
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áäâà]'), 'a')
        .replaceAll(RegExp(r'[éëêè]'), 'e')
        .replaceAll(RegExp(r'[íïîì]'), 'i')
        .replaceAll(RegExp(r'[óöôò]'), 'o')
        .replaceAll(RegExp(r'[úüûù]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n');
  }
}
