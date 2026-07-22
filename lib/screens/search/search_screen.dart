import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/search_service.dart';
import '../../widgets/connect_title.dart';
import 'search_results_screen.dart';
import '../../services/location_service.dart';
import '../../widgets/location_picker/location_bottom_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _searchService = SearchService();
  List<String> _recentSearches = [];
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _initSpeech();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final loc = LocationService();
    if (loc.currentCity == null) {
      await loc.updateCurrentLocation();
    }
    if (mounted) {
      setState(() {
        _selectedLocation = loc.currentCity ?? 'Bogotá';
      });
    }
  }

  void _showLocationPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: LocationBottomSheet(currentLocation: _selectedLocation),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (mounted) {
        LocationService().setCurrentCity(result);
        setState(() {
          _selectedLocation = result;
        });
      }
    }
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) return;

    // Request permission if not granted
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }
    // Also check speech permission explicitly if needed, but microphone is often enough for basic speech_to_text package on Android.
    // However, best practice is to let initialize() handle permissions or use the dedicated permission.
    // Let's add explicit speech permission request just in case.
    var speechStatus = await Permission.speech.status;
    if (!speechStatus.isGranted) {
      speechStatus = await Permission.speech.request();
      if (!speechStatus.isGranted) return;
    }

    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _searchController.text = result.recognizedWords;
            // If final result, trigger search? Or let user press enter.
            // User said "vas hacerlo funcionar", usually voice search triggers auto search or just fills text.
            // Let's just fill text for now, maybe auto search if final.
          });
        },
      );
      setState(() => _isListening = true);
    }
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _searchService.getRecentSearches(limit: 4);
    setState(() => _recentSearches = searches);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    await _searchService.saveSearch(query);

    // Navigate to search results
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsScreen(query: query),
        ),
      );
    }
    _loadRecentSearches();
  }

  Future<void> _removeSearch(String query) async {
    await _searchService.removeSearch(query);
    _loadRecentSearches();
  }

  void _navigateToCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SearchResultsScreen(query: '', category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        toolbarHeight: 45, // Reducir altura para acercar la barra al título
        centerTitle: true,
        title: const ConnectTitle(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 8),
              child: SizedBox(
                height: 38, // Más delgada
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _performSearch,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.0),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: '¿Que estas buscando?',
                    hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset('imgenes/BUSCAR.png', width: 28, height: 28), // Mucho más grande
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic_fill,
                        color: _isListening ? Colors.blue : Colors.grey[700], // Más contraste
                        size: 24, // Más grande
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: _startListening,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFE0E0E0), // Más gris
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Recent searches
            if (_recentSearches.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Búsqueda Reciente',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final allSearches = await _searchService
                          .getRecentSearches(limit: 0);
                      if (mounted) {
                        _showAllSearches(allSearches);
                      }
                    },
                    child: const Text(
                      'Ver todo',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF0094FF),
                      ),
                    ),
                  ),
                ],
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _recentSearches.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1, 
                  color: Color(0xFFEEEEEE), 
                  thickness: 1, 
                  endIndent: 20, // Líneas que no tocan bordes
                  indent: 20,
                ),
                itemBuilder: (context, index) => _buildRecentItem(_recentSearches[index]),
              ),
              const SizedBox(height: 16),
            ],

            // Categories
            const Text(
              'Categorías principales',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: [
                  _buildCategoryItem('assets/iconos/AssetsCPu/productos.png', 'Productos', 'productos'),
                  _buildCategoryItem('assets/iconos/AssetsCPu/servicios.png', 'Servicios', 'servicios'),
                  _buildCategoryItem('assets/iconos/AssetsCPu/empleos.png', 'Empleos', 'empleos'),
                  _buildCategoryItem('assets/iconos/AssetsCPu/vehiculos.png', 'Vehículos', 'vehiculos'),
                  _buildCategoryItem('assets/iconos/AssetsCPu/propiedades.png', 'Propiedades', 'propiedades'),
                  _buildCategoryItem('assets/iconos/AssetsCPu/mascotas.png', 'Mascotas', 'mascotas'),
                  _buildCategoryItem('assets/iconos/AssetsCPu/alquiler.png', 'Alquiler', 'alquiler'),
                  _buildCategoryItem('assets/iconos/AssetsCPu/trueques.png', 'Trueques', 'trueques'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItem(String query) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      leading: const Icon(CupertinoIcons.clock, color: Colors.black87, size: 18),
      visualDensity: VisualDensity.compact,
      title: Text(
        query,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, color: Colors.black, fontWeight: FontWeight.w500),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 16, color: Colors.grey),
        onPressed: () => _removeSearch(query),
      ),
      onTap: () => _performSearch(query),
    );
  }

  Widget _buildCategoryItem(String iconPath, String label, String categoryId) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToCategory(categoryId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8), // Mucho más pegados
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE0E0E0), // Más gris para el círculo también
              ),
              child: Image.asset(iconPath, width: 32, height: 32), // Icono más grande
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16, // Texto más grande
                fontWeight: FontWeight.bold, // En negrita
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationIndicator() {
    return GestureDetector(
      onTap: _showLocationPicker,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Ubicación actual',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0094FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Color(0xFF0094FF),
                ),
                const SizedBox(width: 4),
                Text(
                  _selectedLocation?.toLowerCase() == 'todo' ||
                          _selectedLocation?.toLowerCase().contains('todo') ==
                              true
                      ? 'Todo'
                      : '${_selectedLocation ?? 'Buscando...'} • ${LocationService().currentRadius.toInt()} KM',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0094FF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllSearches(List<String> searches) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Todas las búsquedas',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await _searchService.clearAllSearches();
                    Navigator.pop(context);
                    _loadRecentSearches();
                  },
                  child: const Text(
                    'Borrar todo',
                    style: TextStyle(fontFamily: 'Poppins', color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...searches.map((query) => _buildRecentItem(query)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
