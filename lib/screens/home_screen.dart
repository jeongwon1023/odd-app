import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place_model.dart';
import '../services/cache_service.dart';
import '../services/cultural_event_service.dart';
import '../services/location_service.dart';
import '../services/google_places_service.dart';
import '../services/supabase_course_service.dart';
import '../services/user_preference_service.dart';
import '../utils/app_theme.dart';
import 'course_result_screen.dart';
import '../widgets/place_card.dart';
import 'place_detail_screen.dart';

// ─────────────────────────────────────────────
// 도시 → 구/동 단위 지역 데이터
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// 위치 데이터 — 시 → 구 → 동 3단계 구조
// ─────────────────────────────────────────────

/// 레벨 2: 시 → 구 목록
const _guMap = {
  '서울': [
    {'label': '강남구', 'key': '강남구', 'query': '서울 강남구', 'emoji': '👔'},
    {'label': '서초구', 'key': '서초구', 'query': '서울 서초구', 'emoji': '🌳'},
    {'label': '마포구', 'key': '마포구', 'query': '서울 마포구', 'emoji': '🎸'},
    {'label': '성동구', 'key': '성동구', 'query': '서울 성동구', 'emoji': '🧃'},
    {'label': '용산구', 'key': '용산구', 'query': '서울 용산구', 'emoji': '🌍'},
    {'label': '종로구', 'key': '종로구', 'query': '서울 종로구', 'emoji': '🏯'},
    {'label': '송파구', 'key': '송파구', 'query': '서울 송파구', 'emoji': '🦋'},
    {'label': '영등포구', 'key': '영등포구', 'query': '서울 영등포구', 'emoji': '🏢'},
    {'label': '서대문구', 'key': '서대문구', 'query': '서울 서대문구', 'emoji': '🎓'},
    {'label': '광진구', 'key': '광진구', 'query': '서울 광진구', 'emoji': '⚡'},
    {'label': '관악구', 'key': '관악구', 'query': '서울 관악구', 'emoji': '🎪'},
    {'label': '강서구', 'key': '강서구서울', 'query': '서울 강서구', 'emoji': '✈️'},
    {'label': '동작구', 'key': '동작구', 'query': '서울 동작구', 'emoji': '🚇'},
    {'label': '중구', 'key': '중구서울', 'query': '서울 중구', 'emoji': '🏙️'},
    {'label': '강동구', 'key': '강동구', 'query': '서울 강동구', 'emoji': '🌅'},
    {'label': '은평구', 'key': '은평구', 'query': '서울 은평구', 'emoji': '🌿'},
    {'label': '강북구', 'key': '강북구', 'query': '서울 강북구', 'emoji': '⛰️'},
    {'label': '노원구', 'key': '노원구', 'query': '서울 노원구', 'emoji': '📚'},
    {'label': '동대문구', 'key': '동대문구', 'query': '서울 동대문구', 'emoji': '🧵'},
  ],
  '경기': [
    {'label': '성남 분당구', 'key': '분당구', 'query': '성남시 분당구', 'emoji': '💻'},
    {'label': '수원시', 'key': '수원시', 'query': '수원시', 'emoji': '🏰'},
    {'label': '고양 일산', 'key': '고양시', 'query': '고양시 일산', 'emoji': '🌸'},
    {'label': '용인시', 'key': '용인시', 'query': '용인시', 'emoji': '🎢'},
    {'label': '화성 동탄', 'key': '동탄', 'query': '화성시 동탄', 'emoji': '🏘️'},
    {'label': '하남시', 'key': '하남시', 'query': '하남시', 'emoji': '🛍️'},
    {'label': '의정부시', 'key': '의정부시', 'query': '의정부시', 'emoji': '🚂'},
    {'label': '남양주시', 'key': '남양주시', 'query': '남양주시', 'emoji': '🌊'},
    {'label': '파주시', 'key': '파주시', 'query': '파주시', 'emoji': '📖'},
    {'label': '안산시', 'key': '안산시', 'query': '안산시', 'emoji': '🌅'},
    {'label': '평택시', 'key': '평택시', 'query': '평택시', 'emoji': '🎸'},
    {'label': '가평군', 'key': '가평군', 'query': '가평군', 'emoji': '🏕️'},
    {'label': '양평군', 'key': '양평군', 'query': '양평군', 'emoji': '🚵'},
    {'label': '광교', 'key': '광교', 'query': '수원시 영통구 광교', 'emoji': '🌲'},
  ],
  '부산': [
    {'label': '해운대구', 'key': '해운대구', 'query': '부산 해운대구', 'emoji': '🏖️'},
    {'label': '수영구', 'key': '수영구', 'query': '부산 수영구', 'emoji': '🌊'},
    {'label': '부산진구', 'key': '부산진구', 'query': '부산 부산진구', 'emoji': '🏙️'},
    {'label': '중구', 'key': '부산중구', 'query': '부산 중구', 'emoji': '🎭'},
    {'label': '동래구', 'key': '동래구', 'query': '부산 동래구', 'emoji': '♨️'},
    {'label': '기장군', 'key': '기장군', 'query': '부산 기장군', 'emoji': '🦐'},
    {'label': '사하구', 'key': '사하구', 'query': '부산 사하구', 'emoji': '🏝️'},
  ],
  '대전': [
    {'label': '유성구', 'key': '유성구', 'query': '대전 유성구', 'emoji': '🔬'},
    {'label': '서구', 'key': '대전서구', 'query': '대전 서구', 'emoji': '🏛️'},
    {'label': '동구', 'key': '대전동구', 'query': '대전 동구', 'emoji': '🌄'},
    {'label': '중구', 'key': '대전중구', 'query': '대전 중구', 'emoji': '🏙️'},
    {'label': '대덕구', 'key': '대덕구', 'query': '대전 대덕구', 'emoji': '⚙️'},
  ],
  '대구': [
    {'label': '중구', 'key': '대구중구', 'query': '대구 중구', 'emoji': '🛍️'},
    {'label': '수성구', 'key': '수성구', 'query': '대구 수성구', 'emoji': '🏊'},
    {'label': '달서구', 'key': '달서구', 'query': '대구 달서구', 'emoji': '🌸'},
    {'label': '동구', 'key': '대구동구', 'query': '대구 동구', 'emoji': '🌄'},
    {'label': '북구', 'key': '대구북구', 'query': '대구 북구', 'emoji': '🏭'},
  ],
  '인천': [
    {'label': '연수구 송도', 'key': '연수구', 'query': '인천 연수구 송도', 'emoji': '🌆'},
    {'label': '부평구', 'key': '부평구', 'query': '인천 부평구', 'emoji': '🚂'},
    {'label': '남동구', 'key': '남동구', 'query': '인천 남동구', 'emoji': '🏪'},
    {'label': '중구', 'key': '인천중구', 'query': '인천 중구', 'emoji': '🗼'},
    {'label': '서구 청라', 'key': '인천서구', 'query': '인천 서구 청라', 'emoji': '🏗️'},
  ],
  '광주': [
    {'label': '동구', 'key': '광주동구', 'query': '광주 동구', 'emoji': '🎭'},
    {'label': '서구', 'key': '광주서구', 'query': '광주 서구', 'emoji': '🏙️'},
    {'label': '남구', 'key': '광주남구', 'query': '광주 남구', 'emoji': '🌳'},
    {'label': '북구', 'key': '광주북구', 'query': '광주 북구', 'emoji': '📚'},
    {'label': '광산구', 'key': '광산구', 'query': '광주 광산구', 'emoji': '🏭'},
  ],
  '울산': [
    {'label': '남구', 'key': '울산남구', 'query': '울산 남구', 'emoji': '🏙️'},
    {'label': '중구', 'key': '울산중구', 'query': '울산 중구', 'emoji': '🎭'},
    {'label': '동구', 'key': '울산동구', 'query': '울산 동구', 'emoji': '⚓'},
    {'label': '북구', 'key': '울산북구', 'query': '울산 북구', 'emoji': '🏭'},
    {'label': '울주군', 'key': '울주군', 'query': '울산 울주군', 'emoji': '🌊'},
  ],
  '기타': [
    {'label': '전주시', 'key': '전주시', 'query': '전주시', 'emoji': '🍃'},
    {'label': '춘천시', 'key': '춘천시', 'query': '춘천시', 'emoji': '🏞️'},
    {'label': '제주시', 'key': '제주시', 'query': '제주시', 'emoji': '🌊'},
    {'label': '서귀포시', 'key': '서귀포시', 'query': '서귀포시', 'emoji': '🌺'},
    {'label': '강릉시', 'key': '강릉시', 'query': '강릉시', 'emoji': '🌊'},
    {'label': '속초시', 'key': '속초시', 'query': '속초시', 'emoji': '🏔️'},
    {'label': '경주시', 'key': '경주시', 'query': '경주시', 'emoji': '🏛️'},
    {'label': '여수시', 'key': '여수시', 'query': '여수시', 'emoji': '🌅'},
  ],
};

/// 레벨 3: 구 key → 동 목록 (주요 지역만. 없으면 구 레벨에서 바로 선택)
const _dongMap = {
  '강남구': [
    {'label': '역삼·강남역', 'query': '서울 강남구 역삼동'},
    {'label': '삼성·코엑스', 'query': '서울 강남구 삼성동'},
    {'label': '신사·가로수길', 'query': '서울 강남구 신사동'},
    {'label': '압구정·청담', 'query': '서울 강남구 압구정동'},
    {'label': '논현·학동', 'query': '서울 강남구 논현동'},
    {'label': '대치·도곡', 'query': '서울 강남구 대치동'},
  ],
  '서초구': [
    {'label': '강남역·서초', 'query': '서울 서초구 서초동'},
    {'label': '방배·방배동', 'query': '서울 서초구 방배동'},
    {'label': '서래마을·반포', 'query': '서울 서초구 반포동'},
    {'label': '교대·법원', 'query': '서울 서초구 서초동 교대'},
  ],
  '마포구': [
    {'label': '홍대·홍대입구', 'query': '서울 마포구 서교동'},
    {'label': '합정·당인리', 'query': '서울 마포구 합정동'},
    {'label': '망원·망리단길', 'query': '서울 마포구 망원동'},
    {'label': '연남동', 'query': '서울 마포구 연남동'},
    {'label': '상수·와우산', 'query': '서울 마포구 상수동'},
  ],
  '성동구': [
    {'label': '성수·뚝섬', 'query': '서울 성동구 성수동'},
    {'label': '서울숲·응봉', 'query': '서울 성동구 응봉동'},
    {'label': '왕십리·행당', 'query': '서울 성동구 왕십리동'},
    {'label': '금호·옥수', 'query': '서울 성동구 금호동'},
  ],
  '용산구': [
    {'label': '이태원', 'query': '서울 용산구 이태원동'},
    {'label': '한남·한강진', 'query': '서울 용산구 한남동'},
    {'label': '경리단길·보광', 'query': '서울 용산구 보광동'},
    {'label': '후암·해방촌', 'query': '서울 용산구 후암동'},
    {'label': '삼각지·숙대입구', 'query': '서울 용산구 삼각지'},
  ],
  '종로구': [
    {'label': '광화문·삼청', 'query': '서울 종로구 삼청동'},
    {'label': '북촌·인사동', 'query': '서울 종로구 인사동'},
    {'label': '익선동·낙원', 'query': '서울 종로구 익선동'},
    {'label': '서촌·경복궁', 'query': '서울 종로구 통인동'},
    {'label': '대학로·혜화', 'query': '서울 종로구 혜화동'},
  ],
  '송파구': [
    {'label': '잠실·석촌호수', 'query': '서울 송파구 잠실동'},
    {'label': '방이·올림픽공원', 'query': '서울 송파구 방이동'},
    {'label': '위례·문정', 'query': '서울 송파구 문정동'},
    {'label': '가락·천호', 'query': '서울 송파구 가락동'},
  ],
  '영등포구': [
    {'label': '여의도', 'query': '서울 영등포구 여의도동'},
    {'label': '당산·선유도', 'query': '서울 영등포구 당산동'},
    {'label': '영등포역·타임스퀘어', 'query': '서울 영등포구 영등포동'},
  ],
  '서대문구': [
    {'label': '신촌·연세대', 'query': '서울 서대문구 신촌동'},
    {'label': '이대·대현', 'query': '서울 서대문구 대현동'},
    {'label': '홍제·북가좌', 'query': '서울 서대문구 홍제동'},
  ],
  '광진구': [
    {'label': '건대·화양', 'query': '서울 광진구 화양동'},
    {'label': '자양·구의', 'query': '서울 광진구 자양동'},
    {'label': '뚝섬유원지', 'query': '서울 광진구 뚝섬'},
  ],
  '해운대구': [
    {'label': '해운대 해수욕장', 'query': '부산 해운대구 우동'},
    {'label': '센텀·벡스코', 'query': '부산 해운대구 우동 센텀'},
    {'label': '달맞이·청사포', 'query': '부산 해운대구 중동 달맞이'},
    {'label': '마린시티', 'query': '부산 해운대구 우동 마린시티'},
  ],
  // ── 부산 추가 ──
  '수영구': [
    {'label': '광안리 해수욕장', 'query': '부산 수영구 광안동'},
    {'label': '민락·회센터', 'query': '부산 수영구 민락동'},
    {'label': '남천·수영역', 'query': '부산 수영구 남천동'},
  ],
  '부산진구': [
    {'label': '서면·쥬디스태화', 'query': '부산 부산진구 서면'},
    {'label': '전포·카페거리', 'query': '부산 부산진구 전포동'},
    {'label': '부전시장·범천', 'query': '부산 부산진구 부전동'},
  ],
  '부산중구': [
    {'label': '남포동·BIFF광장', 'query': '부산 중구 남포동'},
    {'label': '보수동·책방골목', 'query': '부산 중구 보수동'},
    {'label': '영도다리·자갈치', 'query': '부산 중구 영도'},
  ],
  // ── 대전 추가 ──
  '유성구': [
    {'label': '유성온천·궁동', 'query': '대전 유성구 궁동'},
    {'label': '봉명동·카페거리', 'query': '대전 유성구 봉명동'},
    {'label': '도룡·엑스포', 'query': '대전 유성구 도룡동'},
    {'label': 'KAIST·어은동', 'query': '대전 유성구 어은동'},
  ],
  '대전서구': [
    {'label': '둔산·갤러리아', 'query': '대전 서구 둔산동'},
    {'label': '탄방·타임월드', 'query': '대전 서구 탄방동'},
    {'label': '용문·도마동', 'query': '대전 서구 도마동'},
    {'label': '관저·유통단지', 'query': '대전 서구 관저동'},
  ],
  '대전중구': [
    {'label': '으능정이·중앙로', 'query': '대전 중구 은행동'},
    {'label': '대흥동·문화거리', 'query': '대전 중구 대흥동'},
    {'label': '선화·목동', 'query': '대전 중구 선화동'},
  ],
  '대전동구': [
    {'label': '대전역·인동', 'query': '대전 동구 대전역'},
    {'label': '소제동·카페거리', 'query': '대전 동구 소제동'},
    {'label': '판암·신인', 'query': '대전 동구 판암동'},
  ],
  // ── 대구 추가 ──
  '대구중구': [
    {'label': '동성로·중앙로', 'query': '대구 중구 동성로'},
    {'label': '대봉·카페거리', 'query': '대구 중구 대봉동'},
    {'label': '북성로·공구골목', 'query': '대구 중구 북성로'},
    {'label': '서문시장·달성공원', 'query': '대구 중구 서문시장'},
  ],
  '수성구': [
    {'label': '수성못·들안길', 'query': '대구 수성구 수성못'},
    {'label': '범어동·동대구', 'query': '대구 수성구 범어동'},
    {'label': '만촌·황금동', 'query': '대구 수성구 만촌동'},
  ],
  '달서구': [
    {'label': '성당못·월성동', 'query': '대구 달서구 월성동'},
    {'label': '두류공원·두류동', 'query': '대구 달서구 두류동'},
    {'label': '죽전·상인동', 'query': '대구 달서구 상인동'},
  ],
  // ── 인천 추가 ──
  '연수구': [
    {'label': '송도국제도시', 'query': '인천 연수구 송도동'},
    {'label': '송도 센트럴파크', 'query': '인천 연수구 송도 센트럴파크'},
    {'label': '연수·옥련동', 'query': '인천 연수구 연수동'},
  ],
  '인천중구': [
    {'label': '개항로·차이나타운', 'query': '인천 중구 개항로'},
    {'label': '신포시장·동인천', 'query': '인천 중구 신포동'},
    {'label': '월미도·인천항', 'query': '인천 중구 월미도'},
  ],
  // ── 광주 추가 ──
  '광주동구': [
    {'label': '충장로·금남로', 'query': '광주 동구 충장로'},
    {'label': '예술의거리·계림동', 'query': '광주 동구 예술의거리'},
    {'label': '동명동·카페거리', 'query': '광주 동구 동명동'},
  ],
  '광주서구': [
    {'label': '상무지구·NC백화점', 'query': '광주 서구 상무지구'},
    {'label': '치평동·유스퀘어', 'query': '광주 서구 치평동'},
  ],
  // ── 서울 추가 ──
  '관악구': [
    {'label': '신림·신림역', 'query': '서울 관악구 신림동'},
    {'label': '봉천·낙성대', 'query': '서울 관악구 봉천동'},
    {'label': '서울대·관악산', 'query': '서울 관악구 신림동 서울대'},
  ],
  '강서구서울': [
    {'label': '발산·마곡', 'query': '서울 강서구 발산동'},
    {'label': '화곡·우장산', 'query': '서울 강서구 화곡동'},
    {'label': '염창·등촌', 'query': '서울 강서구 등촌동'},
  ],
  '동작구': [
    {'label': '노량진·노들역', 'query': '서울 동작구 노량진동'},
    {'label': '상도·숭실대', 'query': '서울 동작구 상도동'},
    {'label': '흑석·중앙대', 'query': '서울 동작구 흑석동'},
  ],
  '중구서울': [
    {'label': '명동·롯데백화점', 'query': '서울 중구 명동'},
    {'label': '을지로·청계천', 'query': '서울 중구 을지로'},
    {'label': '남산·회현', 'query': '서울 중구 회현동'},
    {'label': '동대문·신당', 'query': '서울 중구 신당동'},
  ],
  '강동구': [
    {'label': '천호·강동역', 'query': '서울 강동구 천호동'},
    {'label': '암사·길동', 'query': '서울 강동구 암사동'},
    {'label': '고덕·명일동', 'query': '서울 강동구 고덕동'},
  ],
  '은평구': [
    {'label': '홍제·연신내', 'query': '서울 은평구 연신내'},
    {'label': '불광·갈현', 'query': '서울 은평구 불광동'},
    {'label': '은평뉴타운·진관', 'query': '서울 은평구 진관동'},
  ],
  '노원구': [
    {'label': '노원역·중계동', 'query': '서울 노원구 중계동'},
    {'label': '공릉·태릉', 'query': '서울 노원구 공릉동'},
    {'label': '상계동·수락산', 'query': '서울 노원구 상계동'},
  ],
  '동대문구': [
    {'label': '회기·경희대', 'query': '서울 동대문구 회기동'},
    {'label': '청량리·전농', 'query': '서울 동대문구 청량리동'},
    {'label': '동대문디자인플라자', 'query': '서울 동대문구 신설동'},
  ],
  '강북구': [
    {'label': '수유·4.19광장', 'query': '서울 강북구 수유동'},
    {'label': '미아·삼양동', 'query': '서울 강북구 미아동'},
  ],
};

/// LocationResult.city에서 도시 키를 추출
String _cityKey(String city) {
  if (city.contains('서울')) return '서울';
  if (city.contains('대전')) return '대전';
  if (city.contains('부산')) return '부산';
  if (city.contains('대구')) return '대구';
  if (city.contains('인천')) return '인천';
  if (city.contains('광주')) return '광주';
  if (city.contains('울산')) return '울산';
  // 경기도 주요 도시
  if (city.contains('수원') || city.contains('성남') || city.contains('고양') ||
      city.contains('용인') || city.contains('화성') || city.contains('하남') ||
      city.contains('의정부') || city.contains('남양주') || city.contains('파주') ||
      city.contains('평택') || city.contains('안산') || city.contains('가평') ||
      city.contains('양평') || city.contains('포천') || city.contains('구리') ||
      city.contains('경기')) return '경기';
  return '기타';
}

// ─────────────────────────────────────────────
// ODD 홈 화면 — CatchTable 스타일 리뉴얼
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final LocationResult location;
  final Map<String, List<Place>> places;
  final List<CulturalEvent> culturalEvents;
  final bool isLoadingPlaces;
  final void Function(String category)? onCategoryTap;
  final VoidCallback? onExploreTap;
  final VoidCallback? onAiCourseTap;
  final VoidCallback? onSavedTap;
  final Future<void> Function(String region)? onRegionChanged;
  final String? gpsDistrict;
  final VoidCallback? onOpenNowTap;
  final Future<void> Function()? onRefreshPlaces;

  const HomeScreen({
    super.key,
    required this.location,
    required this.places,
    this.culturalEvents = const [],
    this.isLoadingPlaces = false,
    this.onCategoryTap,
    this.onExploreTap,
    this.onAiCourseTap,
    this.onSavedTap,
    this.onRegionChanged,
    this.gpsDistrict,
    this.onOpenNowTap,
    this.onRefreshPlaces,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── 배너 캐러셀 ──
  final _pageCtrl = PageController();
  int _bannerPage = 0;
  Timer? _bannerTimer;

  // ── DB 큐레이션 코스 ──
  List<DateCourse> _curatedCourses = [];
  bool _loadingCurated = false;
  final Map<int, String> _curatedPhotos = {};

  // Q1: 인기 코스
  List<DateCourse> _popularCourses = [];

  // Q2: 특별한 날
  List<DateCourse> _specialDayCourses = [];
  String? _specialDayLabel;

  static const _banners = [
    {
      'title': '봄 분위기 가득\n로맨틱 스팟',
      'sub': '커플이 사랑하는 공간',
      'emoji': '🌸',
      'gradient': [Color(0xFF667EEA), Color(0xFF764BA2)],
      'action': 'romantic',
    },
    {
      'title': '이번 주 핫한\n데이트 코스',
      'sub': '가장 많이 저장된 코스',
      'emoji': '🔥',
      'gradient': [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      'action': 'popular',
    },
    {
      'title': 'AI가 설계하는\n오늘의 코스',
      'sub': '취향 맞춤 데이트 추천',
      'emoji': '✨',
      'gradient': [Color(0xFF5C6BC0), Color(0xFF26A69A)],
      'action': 'today',
    },
  ];

  // ── 카테고리 스트립 (5 원형 아이콘) ──
  static const _catStrip = [
    {'emoji': '🔥', 'label': '지금뜨는\n코스', 'type': 'explore'},
    {'emoji': '✦',  'label': 'AI추천',       'type': 'ai'},
    {'emoji': '🎪', 'label': '문화행사',      'key': '문화행사', 'type': 'cat'},
    {'emoji': '💕', 'label': '데이트핫플',    'key': '맛집',    'type': 'cat'},
    {'emoji': '🔖', 'label': '저장한코스',    'type': 'saved'},
  ];
  // Figma 카테고리 배경·전경색
  static const _catBg = [
    Color(0xFFFFE4DC), Color(0xFFD8DCF4), Color(0xFFD1FAE5),
    Color(0xFFFFE0E0), Color(0xFFFEF3C7),
  ];
  static const _catFg = [
    Color(0xFFFF6B6B), Color(0xFF5C6BC0), Color(0xFF10B981),
    Color(0xFFFF6B6B), Color(0xFFF59E0B),
  ];

  // ── 홈 섹션 ──
  static const _sections = [
    {'key': '카페·브런치',   'title': '☕  카페 & 브런치',    'sub': '설레는 시작'},
    {'key': '전시·문화',    'title': '🎨  전시·문화 공간',   'sub': '감성 충전'},
    {'key': '체험·액티비티', 'title': '🎯  체험 & 액티비티',  'sub': '함께하는 경험'},
    {'key': '맛집',         'title': '🍽️  인기 맛집',        'sub': '맛있는 마무리'},
    {'key': '야경·뷰',      'title': '🌙  야경 & 뷰맛집',    'sub': '저녁의 하이라이트'},
  ];

  /// Q2: 오늘이 특별한 날인지 감지 → 라벨 반환 (null이면 평일)
  static String? _detectSpecialDay() {
    final now = DateTime.now();
    final m = now.month; final d = now.day;
    final w = now.weekday; // 6=토, 7=일
    if (m == 2 && d == 14) return '💝 발렌타인데이';
    if (m == 3 && d == 14) return '🍬 화이트데이';
    if (m == 12 && d == 24) return '🎄 크리스마스 이브';
    if (m == 12 && d == 25) return '🎄 크리스마스';
    if (m == 12 && d == 31) return '🎆 연말 카운트다운';
    if (m == 1  && d == 1 ) return '🎊 새해 첫날';
    if (w == 6 || w == 7)   return '🌙 주말 스페셜';
    return null;
  }

  /// Q3: 현재 시간대 자동 감지 → time_slot 문자열 반환
  static String _detectTimeSlot() {
    final hour = DateTime.now().hour;
    if (hour < 17) return '낮';
    if (hour < 21) return '저녁';
    return '야간';
  }

  /// 현재 월 기준 계절 단어 — 배너 카피 시점 불일치 방지
  static String _seasonWord() {
    final m = DateTime.now().month;
    if (m >= 3 && m <= 5) return '봄';
    if (m >= 6 && m <= 8) return '여름';
    if (m >= 9 && m <= 11) return '가을';
    return '겨울';
  }

  Future<void> _loadCuratedCourses() async {
    if (_loadingCurated) return;
    setState(() => _loadingCurated = true);
    final raw  = widget.location.fullRegion;
    final city = raw.split(' ').first.isNotEmpty ? raw.split(' ').first : '서울';

    // Q3: 시간대 + 예산 선호도 읽기 (병렬)
    final timeSlot = _detectTimeSlot();
    final budgetStr = await UserPreferenceService.getPreferredBudget();
    final budgetLevel = budgetStr == '저렴' ? 1 : budgetStr == '고급' ? 3 : null;

    final courses = await SupabaseCourseService.fetchTopCourses(
      city: city,
      preferredTimeSlot: timeSlot,
      preferredBudget: budgetLevel,
      limit: 10,
    );
    if (!mounted) return;
    setState(() { _curatedCourses = courses; _loadingCurated = false; });

    // 코스 장소 사진을 실제 사진으로 채워 카드 배경에 사용 (#3)
    _enrichCourses(courses).then((enriched) {
      if (mounted) setState(() => _curatedCourses = enriched);
    });
  }

  Future<void> _loadPopularCourses() async {
    final raw  = widget.location.fullRegion;
    final city = raw.split(' ').first.isNotEmpty ? raw.split(' ').first : '서울';
    final courses = await SupabaseCourseService.fetchPopularCourses(city: city);
    if (!mounted) return;
    setState(() => _popularCourses = courses);
    _enrichCourses(courses, maxCourses: 4).then((enriched) {
      if (mounted) setState(() => _popularCourses = enriched);
    });
  }

  /// 코스 장소 imageUrl을 Google 사진으로 보강 (카드 배경용)
  Future<List<DateCourse>> _enrichCourses(List<DateCourse> courses,
      {int maxCourses = 6, int placesPer = 3}) async {
    final out = <DateCourse>[];
    for (var ci = 0; ci < courses.length; ci++) {
      final c = courses[ci];
      if (ci >= maxCourses) {
        out.add(c);
        continue;
      }
      final places = await Future.wait(List.generate(c.places.length, (pi) async {
        final p = c.places[pi];
        if (pi >= placesPer || p.imageUrl.isNotEmpty) return p;
        final url = await GooglePlacesService.fetchFirstPhotoUrl(p.name, p.address);
        return url != null ? p.copyWith(imageUrl: url) : p;
      }));
      out.add(DateCourse(
        title: c.title,
        concept: c.concept,
        mood: c.mood,
        description: c.description,
        places: places,
        totalDuration: c.totalDuration,
        savedAt: c.savedAt,
      ));
    }
    return out;
  }

  Future<void> _loadSpecialDayCourses() async {
    final label = _detectSpecialDay();
    if (label == null) return; // 평일이면 로드 생략
    final raw  = widget.location.fullRegion;
    final city = raw.split(' ').first.isNotEmpty ? raw.split(' ').first : '서울';
    final courses = await SupabaseCourseService.fetchSpecialDayCourses(city: city);
    if (!mounted) return;
    setState(() { _specialDayCourses = courses; _specialDayLabel = label; });
  }

  /// #3 당겨서 새로고침 — 코스 섹션 + 장소(부모) 동시 갱신
  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadCuratedCourses(),
      _loadPopularCourses(),
      _loadSpecialDayCourses(),
      if (widget.onRefreshPlaces != null) widget.onRefreshPlaces!(),
    ]);
  }

  Future<void> _loadCuratedPhotos(List<DateCourse> courses) async {
    final targets = courses.take(5).toList();
    await Future.wait(targets.asMap().entries.map((e) async {
      final i = e.key;
      final place = e.value.places.isNotEmpty ? e.value.places.first : null;
      if (place == null) return;
      final url = await GooglePlacesService.fetchFirstPhotoUrl(
          place.name, place.address);
      if (url != null && mounted) {
        setState(() => _curatedPhotos[i] = url);
      }
    }));
  }

  @override
  void initState() {
    super.initState();
    _loadCuratedCourses();
    _loadPopularCourses();
    _loadSpecialDayCourses();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 지역 변경 시 코스 재로드 (대전 GPS 초기값 고정 방지)
    if (oldWidget.location.district != widget.location.district) {
      _loadCuratedCourses();
      _loadPopularCourses();
      _loadSpecialDayCourses();
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  홈 화면 — Warm Natural 리디자인 (Figma Make v2)
  //  기존 빌더(_buildAppBar/_buildBannerCarousel 등)는 미사용(추후 정리)
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    final noContent = _curatedCourses.isEmpty && _popularCourses.isEmpty;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context),
                  _buildGreeting(context),
                  if (widget.isLoadingPlaces && noContent)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary, strokeWidth: 2.5)),
                    ),
                  // D-day 특별 코스 배너 — 특별한 날 + 코스가 있을 때만 노출
                  if (_specialDayLabel != null && _specialDayCourses.isNotEmpty) ...[
                    _buildSpecialDayBanner(context),
                    const SizedBox(height: 20),
                  ],
                  _buildTodaySection(context),
                  _buildPopularSection(context),
                  _buildUniqueSection(context),
                  _buildNearbySection(context),
                  _buildEventsSection(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 지역 짧은 이름 ──
  String _regionShort() {
    final src = widget.location.district.isNotEmpty
        ? widget.location.district
        : widget.location.city;
    final toks = src.split(' ').where((t) => t.isNotEmpty).toList();
    for (final t in toks) {
      if (t.endsWith('구') || t.endsWith('동')) return t;
    }
    final first = toks.isNotEmpty ? toks.first : '내 주변';
    return first
        .replaceAll('광역시', '')
        .replaceAll('특별시', '')
        .replaceAll('특별자치시', '')
        .replaceAll('특별자치도', '');
  }

  // ── 상단 바 (ODD + 지역칩 + 알림) ──
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Row(
        children: [
          const Text('ODD',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -0.5)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showLocationSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text(_regionShort(),
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w600)),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppTheme.textMid),
                ],
              ),
            ),
          ),
          const Spacer(),
          Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.divider),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    size: 18, color: AppTheme.textDark),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05555),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.bg, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 에디토리얼 인사 ──
  Widget _buildGreeting(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                  height: 1.48,
                  letterSpacing: -0.3),
              children: [
                TextSpan(text: '오늘 ${_regionShort()}에서\n'),
                const TextSpan(
                    text: '느긋한 데이트',
                    style: TextStyle(color: AppTheme.primary)),
                const TextSpan(text: ' 어때요?'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text('검증된 코스 · 실제 사진 · 손으로 고른',
              style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
        ],
      ),
    );
  }

  // ── 섹션 타이틀 ──
  Widget _sectionTitle(String title, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                  letterSpacing: -0.2)),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text('$action →',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
            ),
        ],
      ),
    );
  }

  Widget _grid2(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(builder: (ctx, cons) {
        final w = (cons.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children.map((c) => SizedBox(width: w, child: c)).toList(),
        );
      }),
    );
  }

  // ── 오늘의 추천 코스 (한눈에 코스 카드 A, 스와이프) ──
  Widget _buildTodaySection(BuildContext context) {
    final today = _curatedCourses.isNotEmpty ? _curatedCourses : _popularCourses;
    if (today.isEmpty) return const SizedBox.shrink();
    final list = today.take(6).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('오늘의 추천 코스'),
          SizedBox(
            height: 252,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: list.length,
              onPageChanged: (p) => setState(() => _bannerPage = p),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _courseCardA(list[i]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(list.length, (i) {
                final active = i == _bannerPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primary : AppTheme.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── 이번 주 인기 코스 (카드 B 2열) ──
  Widget _buildPopularSection(BuildContext context) {
    if (_popularCourses.isEmpty) return const SizedBox.shrink();
    final list = _popularCourses.take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('이번 주 인기 코스',
              action: '더보기', onAction: widget.onAiCourseTap),
          _grid2(List.generate(
              list.length, (i) => _courseCardB(list[i], rank: i + 1))),
        ],
      ),
    );
  }

  // ── 이색 데이트 (칩 + 카드 B) ──
  Widget _buildUniqueSection(BuildContext context) {
    const chips = ['만화카페', '카트장', '방탈출', '동물카페', '원데이클래스'];
    const tints = [
      AppTheme.tintCafe,
      AppTheme.tintPlay,
      AppTheme.tintCulture,
      AppTheme.tintCafe,
      AppTheme.tintPlay
    ];
    final grid = _curatedCourses.length > 2
        ? _curatedCourses.skip(2).take(2).toList()
        : _popularCourses.take(2).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('이색 데이트'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (var i = 0; i < chips.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      // 각 칩을 자기 키워드로 검색 (모두 같은 결과 방지)
                      onTap: () => widget.onCategoryTap?.call(chips[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: tints[i % tints.length],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Text(chips[i],
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textDark)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (grid.isNotEmpty)
            _grid2(grid.map((c) => _courseCardB(c)).toList()),
        ],
      ),
    );
  }

  // ── 가까운 카페 · 맛집 (장소 카드 2열) ──
  Widget _buildNearbySection(BuildContext context) {
    final places = <Place>[
      ...(widget.places['카페·브런치'] ?? []),
      ...(widget.places['맛집'] ?? []),
    ];
    if (places.isEmpty) return const SizedBox.shrink();
    final list = places.take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('가까운 카페 · 맛집',
              action: '더보기', onAction: widget.onExploreTap),
          _grid2(list.map((p) => _placeCardNew(p)).toList()),
        ],
      ),
    );
  }

  // ── 문화행사 (리스트) ──
  Widget _buildEventsSection(BuildContext context) {
    if (widget.culturalEvents.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('지금 우리 동네 문화행사'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children:
                  widget.culturalEvents.take(4).map((e) => _eventRow(e)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════ 카드 컴포넌트 ═══════════

  Widget _netImage(String url, {double? w, double? h, String emoji = '📷'}) {
    Widget ph() => Container(
          width: w,
          height: h,
          color: AppTheme.tintCafe,
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
        );
    if (url.isEmpty) return ph();
    return Image.network(url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ph());
  }

  String _shortName(String n) => n.length > 8 ? '${n.substring(0, 7)}…' : n;

  String _hoursLabel(DateCourse c) {
    final h = (c.totalDuration / 60).round();
    return h > 0 ? '$h시간' : '반나절';
  }

  String _budgetLabel(DateCourse c) {
    final pr = c.places.map((p) => p.priceRange).toList();
    if (pr.any((p) => p == '고급')) return '특별하게';
    if (pr.isNotEmpty && pr.every((p) => p == '저렴')) return '가성비';
    return '적당';
  }

  void _openCourse(DateCourse c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CourseResultScreen(
        courses: [c],
        mood: c.mood.isNotEmpty ? c.mood : c.concept,
        timeSlot: _detectTimeSlot(),
      ),
    ));
  }

  Widget _metaPill(String icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Text('$icon $text',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
      );

  // 3스톱 route strip
  Widget _routeStrip(List<Place> stops) {
    final s = stops.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Stack(
        children: [
          Positioned(
            left: 43,
            right: 43,
            top: 34,
            child: Container(height: 2, color: AppTheme.primary.withOpacity(0.30)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(s.length, (i) {
              final p = s[i];
              return SizedBox(
                width: 86,
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _netImage(p.imageUrl, w: 86, h: 70, emoji: '📍'),
                        ),
                        Positioned(
                          left: -6,
                          top: -6,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                                color: AppTheme.primary, shape: BoxShape.circle),
                            child: Center(
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_shortName(p.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMid)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _courseCardA(DateCourse c) {
    return GestureDetector(
      onTap: () => _openCourse(c),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0F3C2D1E), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _routeStrip(c.places),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                              height: 1.35,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _metaPill('⏱', _hoursLabel(c)),
                          _metaPill('₩', _budgetLabel(c)),
                          _metaPill('📍', _regionShort()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    shape: BoxShape.circle),
                child: const Icon(Icons.favorite_border_rounded,
                    size: 16, color: AppTheme.textLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _routeOverlay(List<Place> stops) {
    final s = stops.take(3).toList();
    final out = <Widget>[];
    for (var i = 0; i < s.length; i++) {
      out.add(Container(
        width: 16,
        height: 16,
        decoration:
            const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
        child: Center(
          child: Text('${i + 1}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
        ),
      ));
      out.add(const SizedBox(width: 3));
      out.add(Flexible(
        child: Text(_shortName(s[i].name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: AppTheme.textMid)),
      ));
      if (i < s.length - 1) {
        out.add(const Text(' › ',
            style: TextStyle(fontSize: 9, color: AppTheme.textLight)));
      }
    }
    return out;
  }

  Widget _courseCardB(DateCourse c, {int? rank}) {
    final cover = c.places.isNotEmpty ? c.places.first.imageUrl : '';
    return GestureDetector(
      onTap: () => _openCourse(c),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A3C2D1E), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _netImage(cover, w: double.infinity, h: 118, emoji: '💕'),
                if (rank != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppTheme.secondary,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('인기 $rank',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.favorite_border_rounded,
                        size: 13, color: AppTheme.textLight),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.white.withOpacity(0.93),
                    child: Row(children: _routeOverlay(c.places)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                          height: 1.4)),
                  const SizedBox(height: 5),
                  Text('⏱ ${_hoursLabel(c)} · ₩ ${_budgetLabel(c)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textLight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _catTint(String cat) {
    if (cat.contains('카페')) return AppTheme.tintCafe;
    if (cat.contains('맛집') || cat.contains('식당')) return AppTheme.tintFood;
    if (cat.contains('체험') || cat.contains('액티') || cat.contains('이색')) {
      return AppTheme.tintPlay;
    }
    if (cat.contains('전시') || cat.contains('문화')) return AppTheme.tintCulture;
    if (cat.contains('야경') || cat.contains('뷰')) return AppTheme.tintView;
    return AppTheme.chipBg;
  }

  String _catShort(Place p) => p.subcategory.isNotEmpty
      ? p.subcategory
      : (p.category.isNotEmpty ? p.category : '장소');

  String _areaOf(Place p) {
    final parts =
        p.address.split(' ').where((t) => t.isNotEmpty && t != '대한민국').toList();
    for (final t in parts) {
      if (t.endsWith('동')) return t;
    }
    for (final t in parts) {
      if (t.endsWith('구')) return t;
    }
    return parts.isNotEmpty ? parts.last : '';
  }

  Widget _placeCardNew(Place p) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: p))),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A3C2D1E), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _netImage(p.imageUrl, w: double.infinity, h: 110, emoji: '☕'),
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.bookmark_border_rounded,
                        size: 13, color: AppTheme.textLight),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                            color: _catTint(p.category),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(_catShort(p),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMid)),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('· ${_areaOf(p)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMid)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 12, color: Color(0xFFE8A844)),
                      const SizedBox(width: 3),
                      Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : '–',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark)),
                      if (p.reviewCount > 0) ...[
                        const SizedBox(width: 3),
                        Text('(${p.reviewCount})',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textLight)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventRow(CulturalEvent ev) {
    return GestureDetector(
      onTap: () async {
        final u = Uri.tryParse(ev.url);
        if (ev.url.isNotEmpty && u != null) {
          await launchUrl(u, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A3C2D1E), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _netImage(ev.thumbnail, w: 52, h: 52, emoji: '🎭'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ev.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                          height: 1.4)),
                  const SizedBox(height: 3),
                  Text(ev.startDate,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMid)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppTheme.textLight),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────
  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withOpacity(0.06),
      titleSpacing: 16,
      title: Row(
        children: [
          // ODD. 로고 — "ODD" 인디고 + "." 빨간 점 (Figma 기준)
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'ODD',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                TextSpan(
                  text: '.',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // 히스토리 아이콘
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.history_rounded,
                size: 24, color: AppTheme.textDark),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          // 알림 아이콘
          Stack(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.notifications_none_rounded,
                    size: 24, color: AppTheme.textDark),
                onPressed: () {},
              ),
              Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4B4B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 검색바 + 위치 행 ──────────────────────────
  Widget _buildSearchAndLocation(BuildContext context) {
    final label = widget.location.district.isNotEmpty
        ? widget.location.district
        : widget.location.city.isNotEmpty
            ? widget.location.city
            : '내 주변';
    final short = label
        .replaceAll('광역시', '').replaceAll('특별시', '')
        .replaceAll('특별자치시', '').replaceAll('특별자치도', '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 검색바
          GestureDetector(
            onTap: widget.onExploreTap,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.bg2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E8F0)),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 14),
                  Icon(Icons.search_rounded, color: AppTheme.textLight, size: 20),
                  SizedBox(width: 10),
                  Text('장소, 코스, 분위기를 검색해보세요',
                      style: TextStyle(color: AppTheme.textLight, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 위치 행
          Row(
            children: [
              GestureDetector(
                onTap: () => _showLocationSheet(context),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 3),
                    Text(short,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark)),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: AppTheme.textMid),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (widget.gpsDistrict != null) {
                    widget.onRegionChanged?.call(widget.gpsDistrict!);
                  }
                },
                child: const Row(
                  children: [
                    Icon(Icons.my_location_rounded,
                        size: 13, color: AppTheme.primary),
                    SizedBox(width: 3),
                    Text('현재 위치로',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 배너 탭 → 실제 코스 결과로 직접 이동 ──────
  // #4 수정: 탭만 바꾸지 않고 보유 코스를 CourseResultScreen으로 즉시 노출.
  // 보유 코스가 없을 때만 AI 플래너로 안전 폴백(dead tap 방지).
  void _onBannerTap(String action) {
    List<DateCourse> courses;
    String mood;
    switch (action) {
      case 'romantic':
        final romantic = _curatedCourses
            .where((c) => '${c.concept}${c.mood}'.contains('감성') ||
                '${c.concept}${c.mood}'.contains('로맨'))
            .toList();
        courses = romantic.isNotEmpty
            ? romantic
            : (_curatedCourses.isNotEmpty ? _curatedCourses : _popularCourses);
        mood = '감성 로맨스';
        break;
      case 'popular':
        courses = _popularCourses.isNotEmpty ? _popularCourses : _curatedCourses;
        mood = '인기';
        break;
      case 'today':
      default:
        courses = _curatedCourses.isNotEmpty ? _curatedCourses : _popularCourses;
        mood = '혼합';
        break;
    }

    if (courses.isEmpty) {
      widget.onAiCourseTap?.call();
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CourseResultScreen(
        courses: courses,
        mood: mood,
        timeSlot: _detectTimeSlot(),
      ),
    ));
  }

  // ── 배너 캐러셀 ─────────────────────────────
  Widget _buildBannerCarousel(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 176,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _banners.length,
            onPageChanged: (p) => setState(() => _bannerPage = p),
            itemBuilder: (_, i) {
              final b = _banners[i];
              final colors = b['gradient'] as List<Color>;
              return GestureDetector(
                onTap: () => _onBannerTap(b['action'] as String),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colors[0].withOpacity(0.35),
                        blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // 배경 원형 장식
                      Positioned(right: -16, top: -16,
                        child: Container(width: 110, height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08)))),
                      Positioned(right: 28, bottom: -20,
                        child: Container(width: 70, height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06)))),
                      // 콘텐츠
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(b['emoji'] as String,
                                style: const TextStyle(fontSize: 32)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    b['action'] == 'romantic'
                                        ? '${_seasonWord()} 분위기 가득\n로맨틱 스팟'
                                        : b['title'] as String,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        height: 1.25, letterSpacing: -0.5)),
                                const SizedBox(height: 4),
                                Text(b['sub'] as String,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 페이지 넘버 (우측 하단)
                      Positioned(
                        right: 14, bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${i + 1} / ${_banners.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // 페이지 인디케이터 도트
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final active = i == _bannerPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppTheme.primary : const Color(0xFFD0D0DC),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── 카테고리 스트립 (5 원형 아이콘) ──────────
  Widget _buildCategoryStrip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_catStrip.length, (i) {
          final cat = _catStrip[i];
          return GestureDetector(
            onTap: () {
              switch (cat['type']) {
                case 'explore': widget.onExploreTap?.call(); break;
                case 'ai':      widget.onAiCourseTap?.call(); break;
                case 'saved':   widget.onSavedTap?.call(); break;
                case 'cat':     widget.onCategoryTap?.call(cat['key']!); break;
              }
            },
            child: SizedBox(
              width: 60,
              child: Column(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: _catBg[i],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _catFg[i].withOpacity(0.12),
                          blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Center(
                      child: Text(cat['emoji']!,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat['label']!,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                        height: 1.3),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── DB 큐레이션 코스 수평 스크롤 ─────────
  static const _archEmoji = {
    '감성 로맨스':  '💕',
    '액티비티 챌린지': '⚡',
    '로컬 힐링':   '🌿',
    '힙스터 컬처': '🎨',
    '럭셔리 스페셜': '👑',
    '인스타 포토': '📸',
    '야경 데이트': '🌙',
    '미식 투어':   '🍽️',
    '자연 힐링':   '🌲',
  };
  static const _archGrad = {
    '감성 로맨스':     [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    '액티비티 챌린지': [Color(0xFF667EEA), Color(0xFF764BA2)],
    '로컬 힐링':      [Color(0xFF56AB2F), Color(0xFFA8E063)],
    '힙스터 컬처':    [Color(0xFF373B44), Color(0xFF4286F4)],
    '럭셔리 스페셜':  [Color(0xFFB8860B), Color(0xFFFFD700)],
    '인스타 포토':    [Color(0xFFE040FB), Color(0xFF7C4DFF)],
    '야경 데이트':    [Color(0xFF0F2027), Color(0xFF203A43)],
    '미식 투어':      [Color(0xFFEB5757), Color(0xFF000000)],
    '자연 힐링':      [Color(0xFF11998E), Color(0xFF38EF7D)],
  };

  Widget _buildCuratedCoursesList(BuildContext context) {
    if (_loadingCurated) {
      return const SizedBox(
        height: 170,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _curatedCourses.length,
        itemBuilder: (ctx, i) => _buildCuratedCard(ctx, _curatedCourses[i]),
      ),
    );
  }

  Widget _buildCuratedCard(BuildContext context, DateCourse course) {
    final idx    = _curatedCourses.indexOf(course);
    final photo  = _curatedPhotos[idx];
    final arch   = course.concept.isEmpty ? course.mood : course.concept;
    final emoji  = _archEmoji[arch] ?? '✦';
    final grads  = _archGrad[arch] ?? [const Color(0xFF5C6BC0), const Color(0xFF26A69A)];
    final places = course.places;

    // Q2: 사진 있으면 이미지 배경 + 다크 그라디언트 오버레이, 없으면 기존 그라디언트
    final Widget cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              arch,
              style: const TextStyle(
                color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          course.title,
          style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const Spacer(),
        ...places.take(3).map((p) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(children: [
            const Icon(Icons.circle, size: 5, color: Colors.white54),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                p.name,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        )),
      ],
    );

    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CourseResultScreen(
            courses: [course],
            mood: course.mood.isNotEmpty ? course.mood : course.concept,
            timeSlot: _detectTimeSlot(),
          ),
        )),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // ① 배경 — 사진 or 그라디언트
              Positioned.fill(
                child: photo != null
                    ? Image.network(photo, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _gradientBox(grads))
                    : _gradientBox(grads),
              ),
              // ② 다크 오버레이
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: photo != null
                          ? [Colors.black.withAlpha(80), Colors.black.withAlpha(200)]
                          : [Colors.transparent, Colors.black.withAlpha(60)],
                    ),
                  ),
                ),
              ),
              // ③ 텍스트 콘텐츠
              Padding(padding: const EdgeInsets.all(14), child: cardContent),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _gradientBox(List<Color> grads) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [grads[0].withAlpha(230), grads[1].withAlpha(230)],
      ),
    ),
  );

  // ── Q2: 특별한 날 배너 ────────────────────────
  Widget _buildSpecialDayBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_specialDayLabel!, style: const TextStyle(
                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: 4),
                const Text('오늘을 위한 특별 코스', style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800,
                )),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _specialDayCourses.length,
              itemBuilder: (ctx, i) {
                final course = _specialDayCourses[i];
                return _buildPopularCard(ctx, course, rank: null);
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── Q1: 인기 코스 리스트 ─────────────────────
  Widget _buildPopularCoursesList(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _popularCourses.length,
        itemBuilder: (ctx, i) => _buildPopularCard(ctx, _popularCourses[i], rank: i + 1),
      ),
    );
  }

  Widget _buildPopularCard(BuildContext context, DateCourse course, {int? rank}) {
    final arch  = course.concept.isEmpty ? course.mood : course.concept;
    final emoji = _archEmoji[arch] ?? '✦';
    final grads = _archGrad[arch] ?? [const Color(0xFF5C6BC0), const Color(0xFF26A69A)];

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CourseResultScreen(
          courses: [course],
          mood: course.mood.isNotEmpty ? course.mood : course.concept,
          timeSlot: _detectTimeSlot(),
        ),
      )),
      child: Container(
        width: 190,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [grads[0].withAlpha(220), grads[1].withAlpha(220)],
          ),
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (rank != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$rank위', style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800,
                  )),
                ),
                const SizedBox(width: 6),
              ],
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Flexible(child: Text(arch, style: const TextStyle(
                color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600,
              ), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text(course.title, style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, height: 1.3,
            ), maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            ...course.places.take(3).map((p) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(children: [
                const Icon(Icons.circle, size: 4, color: Colors.white54),
                const SizedBox(width: 4),
                Flexible(child: Text(p.name, style: const TextStyle(
                  color: Colors.white70, fontSize: 9,
                ), overflow: TextOverflow.ellipsis)),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  // ── 섹션 헤더 ──────────────────────────────
  Widget _buildSectionHeader(BuildContext context, String title, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: AppTheme.textDark, letterSpacing: -0.5)),
          const Spacer(),
          if (action.isNotEmpty)
            GestureDetector(
              onTap: widget.onExploreTap,
              child: Row(
                children: [
                  Text(action,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMid,
                          fontWeight: FontWeight.w500)),
                  const Icon(Icons.chevron_right_rounded,
                      size: 15, color: AppTheme.textLight),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── AI 배너 ────────────────────────────────
  Widget _buildAiBanner(BuildContext context) {
    return GestureDetector(
      onTap: widget.onAiCourseTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, const Color(0xFF3949AB)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.35),
              blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('✦ AI 데이트 플래너',
                        style: TextStyle(color: Colors.white,
                            fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  const Text('오늘 어디 갈지\nAI에게 물어봐요',
                      style: TextStyle(
                          color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.25, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('취향과 분위기를 알려주면 코스를 짜드려요',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('시작하기',
                  style: TextStyle(
                      color: AppTheme.primary, fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 전체 섹션 ──────────────────────────────
  List<Widget> _buildAllSections(
      BuildContext context, List<Map<String, String>> sections) {
    final widgets = <Widget>[];
    for (final s in sections) {
      widgets.add(_buildSectionHeader(context, s['title']!, '더보기'));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildHorizontalList(context, widget.places[s['key']]!));
      widgets.add(const SizedBox(height: 28));
    }
    return widgets;
  }

  Widget _buildHorizontalList(BuildContext context, List<Place> list) {
    return SizedBox(
      height: 195,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16, right: 4),
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        itemBuilder: (ctx, i) => PlaceCard(
          place: list[i],
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => PlaceDetailScreen(place: list[i]))),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(children: [
          CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('새 지역 핫플을 불러오는 중이에요 💕',
              style: TextStyle(color: AppTheme.textMid, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(children: [
          Container(width: 60, height: 60,
            decoration: BoxDecoration(
                color: AppTheme.chipBg,
                borderRadius: BorderRadius.circular(30)),
            child: const Center(
                child: Text('💕', style: TextStyle(fontSize: 26)))),
          const SizedBox(height: 12),
          const Text('주변 데이트 코스를\n불러오는 중이에요',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textMid, fontSize: 14, height: 1.6)),
        ]),
      ),
    );
  }

  Widget _buildEventList(BuildContext context, List<CulturalEvent> events) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 4),
        itemCount: events.length,
        itemBuilder: (_, i) => _EventCard(
          event: events[i],
          onTap: () async {
            final url = events[i].url;
            if (url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
        ),
      ),
    );
  }

  void _showLocationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (_) => _LocationSheet(
        location: widget.location,
        gpsDistrict: widget.gpsDistrict,
        onSelect: (label, query) {
          CacheService.addRecentRegion(label, query);
          widget.onRegionChanged?.call(query);
        },
      ),
    );
  }
}


// ─────────────────────────────────────────────
// 지역 선택 바텀시트 (최근 지역 async 로드)
// ─────────────────────────────────────────────
class _LocationSheet extends StatefulWidget {
  final LocationResult location;
  final String? gpsDistrict;
  final void Function(String label, String query) onSelect;

  const _LocationSheet({
    required this.location,
    this.gpsDistrict,
    required this.onSelect,
  });

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}


class _LocationSheetState extends State<_LocationSheet> {
  List<Map<String, String>> _recent = [];
  String? _selectedCity;
  Map<String, String>? _selectedGu;

  static const _cityOrder = ['서울', '경기', '대전', '부산', '대구', '인천', '광주', '울산', '기타'];

  static const _cityEmoji = {
    '서울': '🏙️', '경기': '🌿', '대전': '🔬', '부산': '🌊',
    '대구': '🍎', '인천': '✈️', '광주': '🎨', '울산': '🏭', '기타': '🗺️',
  };

  @override
  void initState() {
    super.initState();
    CacheService.getRecentRegions().then((r) {
      if (mounted) setState(() => _recent = r);
    });
  }

  void _pick(BuildContext ctx, String label, String query) {
    Navigator.pop(ctx);
    widget.onSelect(label, query);
  }

  void _selectGu(BuildContext ctx, Map<String, String> gu) {
    final dongs = _dongMap[gu['key']] ?? [];
    if (dongs.isNotEmpty) {
      setState(() => _selectedGu = gu);
    } else {
      _pick(ctx, gu['label']!, gu['query']!);
    }
  }

  Widget _handle() => Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
    child: Center(
      child: Container(width: 36, height: 4,
        decoration: BoxDecoration(color: AppTheme.divider,
            borderRadius: BorderRadius.circular(2))),
    ),
  );

  Widget _header() {
    final String title;
    final VoidCallback? onBack;

    if (_selectedGu != null) {
      title = '${_selectedGu!['emoji'] ?? ''} ${_selectedGu!['label']}';
      onBack = () => setState(() => _selectedGu = null);
    } else if (_selectedCity != null) {
      title = '${_cityEmoji[_selectedCity] ?? ''} $_selectedCity';
      onBack = () => setState(() => _selectedCity = null);
    } else {
      title = '지역 선택';
      onBack = null;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 20, 10),
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.arrow_back_ios_rounded, size: 18,
                    color: AppTheme.textDark),
              ),
            ),
          Text(title,
            style: const TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
          if (onBack == null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _cityKey(widget.location.city) == '기타'
                    ? '' : _cityKey(widget.location.city),
                style: const TextStyle(fontSize: 12,
                    color: AppTheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gpsButton(BuildContext ctx) {
    final gps = widget.gpsDistrict;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: GestureDetector(
        onTap: gps != null ? () => _pick(ctx, gps, gps) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5C6BC0).withOpacity(0.25),
                blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.my_location_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                gps != null ? '현재 GPS 위치로  ($gps)' : '현재 GPS 위치로',
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1단계: 시(City) 목록 ──────────────────────────────────────
  Widget _buildCityList(BuildContext ctx, ScrollController sc) {
    final currentCityKey = _cityKey(widget.location.city);
    return ListView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        _gpsButton(ctx),
        if (_recent.isNotEmpty) ...[
          const Text('최근 지역',
            style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: AppTheme.textMid,
                letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _recent.map((r) => _DistrictChip(
              label: '🕐  ${r['label']!}',
              isSelected: false,
              onTap: () => _pick(ctx, r['label']!, r['query']!),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.black.withOpacity(0.05)),
          const SizedBox(height: 12),
        ],
        const Text('도시 선택',
          style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700, color: AppTheme.textMid,
              letterSpacing: 0.2)),
        const SizedBox(height: 10),
        ..._cityOrder.map((city) {
          final emoji = _cityEmoji[city] ?? '🗺️';
          final isCurrent = city == currentCityKey;
          return GestureDetector(
            onTap: () => setState(() { _selectedCity = city; _selectedGu = null; }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isCurrent ? AppTheme.primary.withOpacity(0.06) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? AppTheme.primary.withOpacity(0.4)
                      : Colors.black.withOpacity(0.06)),
                boxShadow: isCurrent ? [] : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Text(city,
                    style: TextStyle(fontSize: 15,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? AppTheme.primary : AppTheme.textDark)),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 18,
                      color: isCurrent ? AppTheme.primary : AppTheme.textLight),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── 2단계: 구(District) 목록 ──────────────────────────────────
  Widget _buildGuList(BuildContext ctx, ScrollController sc) {
    final gus = _guMap[_selectedCity!] ?? [];
    return ListView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        Wrap(
          spacing: 8, runSpacing: 8,
          children: gus.map((gu) {
            final hasDong = (_dongMap[gu['key']] ?? []).isNotEmpty;
            return GestureDetector(
              onTap: () => _selectGu(ctx, Map<String, String>.from(gu)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${gu['emoji'] ?? ''} ${gu['label']}',
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    if (hasDong) ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.chevron_right_rounded, size: 13,
                          color: AppTheme.textLight),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── 3단계: 동(Dong) 목록 ──────────────────────────────────────
  Widget _buildDongList(BuildContext ctx, ScrollController sc) {
    final dongs = _dongMap[_selectedGu!['key']] ?? [];
    return ListView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        // "{구} 전체" 버튼 — 인디고 그라디언트
        GestureDetector(
          onTap: () => _pick(ctx, _selectedGu!['label']!, _selectedGu!['query']!),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                begin: Alignment.centerLeft, end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5C6BC0).withOpacity(0.25),
                  blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 7),
                Text('${_selectedGu!['label']} 전체',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ),
        const Text('세부 동네',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppTheme.textMid)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: dongs.map((dong) => _DistrictChip(
            label: dong['label']!,
            isSelected: false,
            onTap: () => _pick(ctx, dong['label']!, dong['query']!),
          )).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, sc) => Column(
        children: [
          _handle(),
          _header(),
          const Divider(height: 1, color: Color(0xFFF0F0F2)),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.12, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: _selectedGu != null
                  ? KeyedSubtree(
                      key: ValueKey('dong_${_selectedGu!['key']}'),
                      child: _buildDongList(ctx, sc))
                  : _selectedCity != null
                      ? KeyedSubtree(
                          key: ValueKey('gu_$_selectedCity'),
                          child: _buildGuList(ctx, sc))
                      : KeyedSubtree(
                          key: const ValueKey('city'),
                          child: _buildCityList(ctx, sc)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 시간대 정보 데이터 클래스
// ─────────────────────────────────────────────
class _TimeSlotInfo {
  final String emoji;
  final String label;
  final String desc;
  final String keyword;
  final List<Color> gradient;
  final Color textColor;

  const _TimeSlotInfo({
    required this.emoji,
    required this.label,
    required this.desc,
    required this.keyword,
    required this.gradient,
    required this.textColor,
  });
}

// ─────────────────────────────────────────────
// 문화 이벤트 카드
// ─────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final CulturalEvent event;
  final VoidCallback? onTap;

  const _EventCard({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: event.thumbnail.isNotEmpty
                  ? Image.network(event.thumbnail,
                      height: 88, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                  const SizedBox(height: 3),
                  Text(event.startDate,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMid)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 88, width: double.infinity,
    color: const Color(0xFFF5F5FA),
    child: const Center(child: Text('🎭', style: TextStyle(fontSize: 28))),
  );
}

// ─────────────────────────────────────────────
// 지역 선택 칩
// ─────────────────────────────────────────────
class _DistrictChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DistrictChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Colors.black.withOpacity(0.1)),
          boxShadow: isSelected ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textDark,
          )),
      ),
    );
  }
}

