import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad_campaign.dart';
import '../services/firestore_service.dart';

/// Widget unificado y estético para Campañas Publicitarias y Anuncios (Ads) en CONNECT.
/// Diseñado bajo la estética CONNECT: bordes sutiles, micro-interacciones suaves,
/// sin badges genéricos de IA, soporte de múltiples ubicaciones y métricas automáticas.
class ConnectAdBanner extends StatefulWidget {
  final AdCampaign ad;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final bool compact;

  const ConnectAdBanner({
    super.key,
    required this.ad,
    this.height,
    this.margin,
    this.compact = false,
  });

  @override
  State<ConnectAdBanner> createState() => _ConnectAdBannerState();
}

class _ConnectAdBannerState extends State<ConnectAdBanner> {
  bool _recordedImpression = false;

  @override
  void initState() {
    super.initState();
    _recordImpressionOnce();
  }

  void _recordImpressionOnce() {
    if (!_recordedImpression && widget.ad.id.isNotEmpty) {
      _recordedImpression = true;
      FirestoreService().recordAdImpression(widget.ad.id);
    }
  }

  Future<void> _handleAdTap() async {
    final ad = widget.ad;
    if (ad.id.isNotEmpty) {
      FirestoreService().recordAdClick(ad.id);
    }

    final rawUrl = ad.linkUrl.trim();
    if (rawUrl.isEmpty) return;

    try {
      Uri uri;
      if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
        uri = Uri.parse('https://$rawUrl');
      } else {
        uri = Uri.parse(rawUrl);
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('[ConnectAdBanner] No se pudo abrir la URL: $rawUrl');
      }
    } catch (e) {
      debugPrint('[ConnectAdBanner] Error abriendo enlace: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final isInterstitial = ad.placement == 'feed_interstitial';
    final defaultHeight = isInterstitial ? 200.0 : (widget.compact ? 95.0 : 135.0);
    final finalHeight = widget.height ?? defaultHeight;

    return Container(
      margin: widget.margin ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      height: finalHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleAdTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Imagen del banner
                if (ad.imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: ad.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Color(0xFF0094FF)),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFF3F4F6),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.campaign_outlined,
                              color: Color(0xFF9CA3AF), size: 28),
                          const SizedBox(height: 4),
                          Text(
                            ad.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'CanvaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0B192C), Color(0xFF1E3E62)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ad.client.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'CanvaSans',
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0094FF),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ad.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Alexandria',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Gradiente suave inferior para asegurar legibilidad si hay título superpuesto
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // Etiqueta sutil de patrocinio (Sobria y elegante, no badge genérico)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 10,
                          color: Color(0xFF00B4FF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Publicidad • ${ad.client}',
                          style: const TextStyle(
                            fontFamily: 'CanvaSans',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Información inferior con botón de acción directo
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ad.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Alexandria',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0094FF),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0094FF).withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ver más',
                              style: TextStyle(
                                fontFamily: 'CanvaSans',
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carrusel automático y suave para banners superiores (`home_top` o `explore_banner`)
class ConnectAdCarousel extends StatefulWidget {
  final List<AdCampaign> ads;
  final double height;
  final EdgeInsetsGeometry? margin;

  const ConnectAdCarousel({
    super.key,
    required this.ads,
    this.height = 135.0,
    this.margin,
  });

  @override
  State<ConnectAdCarousel> createState() => _ConnectAdCarouselState();
}

class _ConnectAdCarouselState extends State<ConnectAdCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  void _startTimer() {
    if (widget.ads.length <= 1) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_currentIndex + 1) % widget.ads.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(covariant ConnectAdCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ads.length != widget.ads.length) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) return const SizedBox.shrink();

    if (widget.ads.length == 1) {
      return ConnectAdBanner(
        ad: widget.ads.first,
        height: widget.height,
        margin: widget.margin,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.ads.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return ConnectAdBanner(
                ad: widget.ads[index],
                height: widget.height,
                margin: widget.margin ??
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.ads.length, (i) {
            final isCurrent = i == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: isCurrent ? 16 : 5,
              height: 4,
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFF0094FF)
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
