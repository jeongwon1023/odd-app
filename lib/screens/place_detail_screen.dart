import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/place_model.dart';
import '../utils/app_theme.dart';
import 'map_screen.dart';

class PlaceDetailScreen extends StatelessWidget {
  final Place place;
  const PlaceDetailScreen({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppTheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: place.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: place.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.place,
                            size: 60, color: AppTheme.textLight),
                      ),
                    )
                  : Container(color: Colors.grey[200]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _chip(place.category),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded,
                          size: 16, color: Color(0xFFFFB800)),
                      Text(' ${place.rating.toStringAsFixed(1)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(place.name,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 8),
                  if (place.description.isNotEmpty)
                    Text(place.description,
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMid,
                            height: 1.6)),
                  const SizedBox(height: 24),
                  _row(Icons.location_on_outlined, place.address),
                  if (place.openHours.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _row(Icons.access_time_outlined, place.openHours),
                  ],
                  const SizedBox(height: 10),
                  _row(Icons.timer_outlined, '약 ${place.duration}분 소요'),
                  const SizedBox(height: 10),
                  _row(Icons.attach_money_rounded, place.priceRange),
                  if (place.phone.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _row(Icons.phone_outlined, place.phone),
                  ],
                  if (place.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: place.tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('#$t',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMid)),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MapScreen(places: [place])),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('지도에서 보기',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary)),
      );

  Widget _row(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textLight),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textMid))),
        ],
      );
}
