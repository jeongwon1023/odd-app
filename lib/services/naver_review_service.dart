import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/place_model.dart';

/// 네이버 블로그 검색 API — 인라인 리뷰 수집
class NaverReviewService {
  static const _blogUrl =
      'https://openapi.naver.com/v1/search/blog.json';

  static Map<String, String> get _headers => {
        'X-Naver-Client-Id': Env.naverClientId,
        'X-Naver-Client-Secret': Env.naverClientSecret,
      };

  /// [placeName] 으로 블로그 후기 최대 12건 검색
  static Future<List<NaverBlogReview>> fetchReviews(
      String placeName) async {
    try {
      final query = Uri.encodeComponent('$placeName 방문후기');
      final uri =
          Uri.parse('$_blogUrl?query=$query&display=12&sort=sim');

      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return [];

      final data = json.decode(utf8.decode(res.bodyBytes));
      final items = data['items'] as List? ?? [];

      return items.map((item) {
        final m = item as Map<String, dynamic>;

        final cleanTitle = _stripHtml(m['title'] as String? ?? '');
        final cleanDesc =
            _stripHtml(m['description'] as String? ?? '');

        if (cleanDesc.isEmpty) return null;

        final rawDate = m['postdate'] as String? ?? '';
        final postDate = rawDate.length == 8
            ? '${rawDate.substring(0, 4)}.${rawDate.substring(4, 6)}.${rawDate.substring(6, 8)}'
            : rawDate;

        return NaverBlogReview(
          bloggerName: m['bloggername'] as String? ?? '블로거',
          title: cleanTitle,
          description: cleanDesc,
          link: m['link'] as String? ??
              m['bloggerlink'] as String? ??
              '',
          postDate: postDate,
        );
      }).whereType<NaverBlogReview>().toList();
    } catch (_) {
      return [];
    }
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}
