import 'package:flutter/material.dart';
import '../models/place_model.dart';
import '../services/location_service.dart';
import '../utils/app_theme.dart';
import '../widgets/place_card.dart';
import 'place_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  final LocationResult location;
  final Map<String, List<Place>> places;

  const HomeScreen({
    super.key,
    required this.location,
    required this.places,
  });

  @override
  Widget build(BuildContext context) {
    final romantic = places['감성'] ?? [];
    final active = places['액티비티'] ?? [];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildBanner(),
                const SizedBox(height: 28),
                if (romantic.isNotEmpty)
                  _buildSection(context, '✨ 감성 코스', '분위기 있는 데이트', romantic),
                if (romantic.isNotEmpty) const SizedBox(height: 28),
                if (active.isNotEmpty)
                  _buildSection(context, '🏃 액티비티 코스', '활기찬 즐거움', active),
                if (romantic.isEmpty && active.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        '주변 데이트 코스를 불러오는 중이에요\n잠시 후 다시 시도해주세요 💕',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppTheme.textMid, height: 1.6),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.surface,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('O',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(width: 8),
          const Text('ODD',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppTheme.textDark)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: AppTheme.primary),
              const SizedBox(width: 3),
              Text(
                location.fullRegion.isNotEmpty
                    ? location.fullRegion
                    : '내 주변',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMid,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${location.fullRegion.isNotEmpty ? "${location.fullRegion}의" : "오늘"} 데이트,',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ODD가 골라드릴게요 💕',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'AI가 엄선한 데이트 코스',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Text('📍', style: TextStyle(fontSize: 40)),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, String subtitle, List<Place> places) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMid)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 230,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 20, right: 8),
            scrollDirection: Axis.horizontal,
            itemCount: places.length,
            itemBuilder: (ctx, i) => PlaceCard(
              place: places[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaceDetailScreen(place: places[i]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
