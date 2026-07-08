import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/place_model.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────
// PlaceCard — CatchTable 스타일 세로 이미지 카드
// ─────────────────────────────────────────────

class PlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onTap;

  const PlaceCard({super.key, required this.place, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── 배경 이미지 ──
              CachedNetworkImage(
                imageUrl: place.imageUrl,
                width: 130,
                height: 175,
                fit: BoxFit.cover,
                placeholder: (_, __) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFF0F0F5),
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined,
                        color: Colors.grey, size: 32),
                  ),
                ),
              ),

              // ── 하단 그라디언트 오버레이 ──
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.darkOverlay,
                  ),
                ),
              ),

              // ── 평점 뱃지 (우상단) ──
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFD700), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        place.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 카테고리 칩 (좌상단) ──
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    place.subcategory.isNotEmpty
                        ? place.subcategory
                        : place.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // ── 하단 텍스트 ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        place.address.isNotEmpty ? place.address : place.region,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
