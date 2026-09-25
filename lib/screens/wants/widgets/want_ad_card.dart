import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/ad_campaign.dart';
import '../../../services/firestore_service.dart';

class WantAdCard extends StatelessWidget {
  final AdCampaign ad;

  const WantAdCard({super.key, required this.ad});

  Future<void> _handleTap(BuildContext context) async {
    FirestoreService().recordAdClick(ad.id);

    final rawUrl = ad.linkUrl.trim();
    if (rawUrl.isEmpty) return;

    final uri = Uri.tryParse(rawUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('[WantAdCard] Error abriendo enlace: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Record impression
    FirestoreService().recordAdImpression(ad.id);

    return InkWell(
      onTap: () => _handleTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Square Image matching WantCard exactly
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: ad.imageUrl,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(width: 90, height: 90, color: Colors.grey[100]),
                errorWidget: (context, url, error) => Container(
                  width: 90,
                  height: 90,
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.campaign_outlined,
                    size: 24,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info section matching WantCard layout
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    style: const TextStyle(
                      fontFamily: 'CanvaSans',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Publicidad • ${ad.client.isNotEmpty ? ad.client : 'Ver más'}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF0496FF),
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ad.client.isNotEmpty
                        ? 'Anuncio patrocinado por ${ad.client}. Toca para conocer más detalles.'
                        : 'Conoce más sobre esta oferta exclusiva en CONNECT.',
                    style: const TextStyle(
                      fontFamily: 'CanvaSans',
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
