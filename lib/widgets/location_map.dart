import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/location_service.dart';

class LocationMap extends StatefulWidget {
  final Map<String, dynamic> data;
  final String? locationText;

  const LocationMap({super.key, required this.data, this.locationText});

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  double? _lat;
  double? _lng;
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    _initCoordinates();
  }

  Future<void> _initCoordinates() async {
    // Si tenemos locationText, intentamos geocodificarlo para mostrar un área general (Privacidad)
    if (widget.locationText != null &&
        widget.locationText!.isNotEmpty &&
        widget.locationText != 'Ubicación desconocida') {
      setState(() => _isGeocoding = true);
      final coords = await LocationService().getCoordinatesFromAddress(
        widget.locationText!,
      );
      if (coords != null) {
        if (mounted) {
          setState(() {
            _lat = coords['latitude'];
            _lng = coords['longitude'];
            _isGeocoding = false;
          });
          return;
        }
      }
    }

    // Si falla la geocodificación o no hay texto, usamos las del documento o Bogotá por defecto
    if (mounted) {
      setState(() {
        _lat = (widget.data['latitude'] ?? widget.data['lat'] ?? 4.6097)
            .toDouble();
        _lng = (widget.data['longitude'] ?? widget.data['lng'] ?? -74.0817)
            .toDouble();
        _isGeocoding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lat == null || _lng == null || _isGeocoding) {
      return Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    const String apiKey = 'AIzaSyCKB9H2-C7C2lbyyl1tp3R5rKoHyGosfII';
    final String staticMapUrl =
        'https://maps.googleapis.com/maps/api/staticmap?center=$_lat,$_lng&zoom=13&size=600x300&maptype=roadmap&markers=color:red%7C$_lat,$_lng&key=$apiKey';

    final String displayLocation =
        (widget.locationText != null &&
            widget.locationText!.isNotEmpty &&
            widget.locationText != 'Ubicación desconocida')
        ? widget.locationText!
        : 'Ubicación';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación Aproximada',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF121212),
            fontFamily: 'CanvaSans',
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final url =
                'https://www.google.com/maps/search/?api=1&query=$_lat,$_lng';
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.zero,
            ),
            child: CachedNetworkImage(
              imageUrl: staticMapUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 40, color: Colors.grey),
                  SizedBox(height: 4),
                  Text(
                    'Toca para ver el mapa',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$displayLocation • Colombia',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0094FF),
            fontFamily: 'CanvaSans',
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
