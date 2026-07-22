import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/want.dart';

class WantCard extends StatelessWidget {
  final Want want;
  const WantCard({super.key, required this.want});

  String _formatCurrency(double value) {
    final format = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return format.format(value).replaceAll(',', '.');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Square Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: want.imageUrl,
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
                  Icons.image_not_supported,
                  size: 24,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  want.title,
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
                  'Dispuesto a pagar: ${_formatCurrency(want.willingToPay)}',
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
                  want.description,
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
    );
  }
}
