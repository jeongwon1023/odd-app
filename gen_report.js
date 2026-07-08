const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  HeadingLevel, AlignmentType, LevelFormat, BorderStyle, WidthType,
  ShadingType, VerticalAlign, PageNumber, Header, Footer, PageBreak,
  TableOfContents
} = require('/usr/local/lib/node_modules_global/lib/node_modules/docx');
const fs = require('fs');

const C = {
  indigo:'3A4F9E', indigoL:'EEF1FA', indigoM:'7B8EC8',
  coral:'E8563A', coralL:'FDF0ED',
  gray:'6B7280', grayL:'F3F4F6', dark:'1F2937', black:'111827', white:'FFFFFF',
  green:'059669', greenL:'ECFDF5', amber:'D97706', amberL:'FFFBEB',
  red:'DC2626', redL:'FEF2F2', border:'E5E7EB',
};

const border1 = { style:BorderStyle.SINGLE, size:1, color:C.border };
const noBorder = { style:BorderStyle.NONE, size:0, color:'FFFFFF' };
const allBorders = { top:border1, bottom:border1, left:border1, right:border1 };
const noBorders  = { top:noBorder, bottom:noBorder, left:noBorder, right:noBorder };

function h(level, text, color) {
  const col = color || (level<=2 ? C.indigo : C.black);
  const sizes  = {1:36,2:28,3:24,4:22};
  const spaces = {1:[360,200],2:[280,160],3:[220,120],4:[180,80]};
  const lvl = level===1?HeadingLevel.HEADING_1:level===2?HeadingLevel.HEADING_2:level===3?HeadingLevel.HEADING_3:HeadingLevel.HEADING_4;
  return new Paragraph({
    heading:lvl, spacing:{before:spaces[level][0],after:spaces[level][1]},
    children:[new TextRun({text,bold:true,size:sizes[level],color:col,font:'Arial'})],
  });
}

function p(text, opts={}) {
  const {size=22,color=C.dark,bold=false,indent=0,after=120,before=0,align}=opts;
  return new Paragraph({
    alignment:align, spacing:{before,after},
    indent:indent?{left:indent}:undefined,
    children:[new TextRun({text,size,color,bold,font:'Arial'})],
  });
}

function pb() { return new Paragraph({children:[new PageBreak()]}); }

function divider(color) {
  return new Paragraph({
    spacing:{before:120,after:120},
    border:{bottom:{style:BorderStyle.SINGLE,size:4,color:color||C.indigo,space:1}},
    children:[],
  });
}

function callout(text,bg,textColor,borderColor) {
  bg=bg||C.indigoL; textColor=textColor||C.indigo; borderColor=borderColor||C.indigo;
  return new Table({
    width:{size:9026,type:WidthType.DXA},columnWidths:[9026],
    rows:[new TableRow({children:[new TableCell({
      borders:{top:{style:BorderStyle.SINGLE,size:8,color:borderColor},
               bottom:noBorder,left:noBorder,right:noBorder},
      shading:{fill:bg,type:ShadingType.CLEAR},
      margins:{top:120,bottom:120,left:180,right:120},
      width:{size:9026,type:WidthType.DXA},
      children:[new Paragraph({children:[new TextRun({text,size:20,color:textColor,font:'Arial'})]})],
    })]})],
  });
}

function bullet(items,color) {
  color=color||C.dark;
  return items.map(text=>new Paragraph({
    numbering:{reference:'bullets',level:0},
    spacing:{before:40,after:40},
    children:[new TextRun({text,size:20,color,font:'Arial'})],
  }));
}

function numbered(items,color) {
  color=color||C.dark;
  return items.map(text=>new Paragraph({
    numbering:{reference:'numbers',level:0},
    spacing:{before:40,after:40},
    children:[new TextRun({text,size:20,color,font:'Arial'})],
  }));
}

function cell(text,bg,bold,width,textColor,align) {
  bg=bg||C.white; bold=bold||false; width=width||1000; textColor=textColor||C.dark; align=align||AlignmentType.LEFT;
  return new TableCell({
    borders:allBorders,
    shading:{fill:bg,type:ShadingType.CLEAR},
    margins:{top:80,bottom:80,left:120,right:120},
    width:{size:width,type:WidthType.DXA},
    verticalAlign:VerticalAlign.CENTER,
    children:[new Paragraph({alignment:align,children:[new TextRun({text,bold,size:19,color:textColor,font:'Arial'})]})],
  });
}

const doc = new Document({
  numbering:{config:[
    {reference:'bullets',levels:[{level:0,format:LevelFormat.BULLET,text:'•',alignment:AlignmentType.LEFT,
      style:{paragraph:{indent:{left:600,hanging:300}}}}]},
    {reference:'numbers',levels:[{level:0,format:LevelFormat.DECIMAL,text:'%1.',alignment:AlignmentType.LEFT,
      style:{paragraph:{indent:{left:600,hanging:300}}}}]},
  ]},
  styles:{
    default:{document:{run:{font:'Arial',size:22,color:C.dark}}},
    paragraphStyles:[
      {id:'Heading1',name:'Heading 1',basedOn:'Normal',next:'Normal',quickFormat:true,
       run:{size:36,bold:true,font:'Arial',color:C.black},
       paragraph:{spacing:{before:360,after:200},outlineLevel:0}},
      {id:'Heading2',name:'Heading 2',basedOn:'Normal',next:'Normal',quickFormat:true,
       run:{size:28,bold:true,font:'Arial',color:C.indigo},
       paragraph:{spacing:{before:280,after:160},outlineLevel:1}},
      {id:'Heading3',name:'Heading 3',basedOn:'Normal',next:'Normal',quickFormat:true,
       run:{size:24,bold:true,font:'Arial',color:C.black},
       paragraph:{spacing:{before:220,after:120},outlineLevel:2}},
      {id:'Heading4',name:'Heading 4',basedOn:'Normal',next:'Normal',quickFormat:true,
       run:{size:22,bold:true,font:'Arial',color:C.gray},
       paragraph:{spacing:{before:180,after:80},outlineLevel:3}},
    ],
  },
  sections:[{
    properties:{page:{size:{width:11906,height:16838},margin:{top:1440,right:1440,bottom:1440,left:1440}}},
    headers:{default:new Header({children:[new Paragraph({
      border:{bottom:{style:BorderStyle.SINGLE,size:4,color:C.indigo,space:1}},
      children:[
        new TextRun({text:'ODD 앱 v4.0 전략 기획 보고서',size:18,color:C.indigo,font:'Arial'}),
        new TextRun({text:'\t2026.06',size:18,color:C.gray,font:'Arial'}),
      ],
      tabStops:[{type:'right',position:9026}],
    })]})},
    footers:{default:new Footer({children:[new Paragraph({
      alignment:AlignmentType.CENTER,
      children:[
        new TextRun({text:'ODD  |  p.',size:18,color:C.gray,font:'Arial'}),
        new TextRun({children:[PageNumber.CURRENT],size:18,color:C.gray,font:'Arial'}),
      ],
    })]})},
    children:[
      // ── 표지
      new Paragraph({spacing:{before:2400,after:0},
        children:[new TextRun({text:'ODD',size:96,bold:true,color:C.indigo,font:'Arial'})]}),
      new Paragraph({spacing:{before:0,after:200},
        children:[new TextRun({text:'앱 v4.0  전략 기획 보고서',size:52,bold:true,color:C.black,font:'Arial'})]}),
      divider(C.indigo),
      new Paragraph({spacing:{before:160,after:80},
        children:[new TextRun({text:'10년차 프로그래머 · 기획자 · 마케터 관점의 종합 분석 및 개선안',size:24,color:C.gray,font:'Arial'})]}),
      new Paragraph({spacing:{before:80,after:400},
        children:[new TextRun({text:'작성일: 2026.06  |  현재: v3.1.0  →  목표: v4.0',size:20,color:C.gray,font:'Arial'})]}),
      new Table({
        width:{size:9026,type:WidthType.DXA},columnWidths:[2256,2256,2257,2257],
        rows:[
          new TableRow({children:[cell('현재 버전',C.indigoL,true,2256,C.indigo,AlignmentType.CENTER),cell('목표 버전',C.indigoL,true,2256,C.indigo,AlignmentType.CENTER),cell('개선 항목',C.indigoL,true,2257,C.indigo,AlignmentType.CENTER),cell('예상 기간',C.indigoL,true,2257,C.indigo,AlignmentType.CENTER)]}),
          new TableRow({children:[cell('v3.1.0',C.white,false,2256,C.dark,AlignmentType.CENTER),cell('v4.0',C.white,false,2256,C.dark,AlignmentType.CENTER),cell('11개 요청 + 8개 전문가 추가',C.white,false,2257,C.dark,AlignmentType.CENTER),cell('4단계 / 약 8개월',C.white,false,2257,C.dark,AlignmentType.CENTER)]}),
        ],
      }),
      pb(),

      // ── 목차
      h(1,'목   차'),
      new TableOfContents('목차',{hyperlink:true,headingStyleRange:'1-3'}),
      pb(),

      // ── 1. 현황 진단
      h(1,'1. 현황 진단 및 스크린샷 분석'),
      p('제공된 스크린샷(v3.1.0)과 코드베이스를 기반으로 현재 앱의 강점 및 개선 필요 영역을 분석한다.'),
      p(''),
      h(2,'1.1 강점'),
      ...bullet([
        'AI 코스 추천 엔진 — Gemini + Thompson Sampling + PlaceRanker 6요소 스코어링 완성',
        '장소 데이터 3-소스 통합 — 네이버/카카오/Google Places 병렬 fetch',
        '인앱 WebView 블로그 리뷰 + PC URL 자동 우회 (Naver 로그인 벽 대응)',
        '홈 화면 퀵 필터 배너 — 원탭 카테고리·영업중 탐색 진입 (v3.1.0 신규)',
        '지역 2단계 드릴다운 (시→구) 바텀시트, 최근 지역 캐시',
        '문화행사 실시간 연동 + 탐색 화면 전용 탭',
        'Thompson Sampling 취향 학습 + 온보딩 퀴즈 콜드스타트',
      ]),
      p(''),
      h(2,'1.2 개선 필요 영역'),
      ...bullet([
        '컬러 시스템: 핑크 계열이 20-30대 커플 앱 포지셔닝에 맞지 않음. 섹션마다 색상이 달라 시각적 산만함',
        '하단 탭: "AI코스" 라벨/아이콘이 서비스 가치를 직관적으로 표현하지 못함',
        '홈 화면: 컬러가 너무 많고 섹션 간 시각적 위계 약함 — CatchTable 대비 산만',
        '백엔드 부재: 현재 100% 로컬 — 커뮤니티/프로필/커플 기능 불가',
        '인증 없음: 사용자 식별 불가 → 소셜 기능, 클라우드 저장 불가',
        '위치 계층: 시→구 2단계만, 동(洞) 단위 선택 미지원',
        '문화행사: 지역 표시 없음, 상세보기 없음, 외부 링크만',
        '수익화 모델: 현재 매출 구조 전무',
        '애널리틱스: 사용자 행동 데이터 수집 0 — 개선 방향 판단 불가',
      ]),
      pb(),

      // ── 2. 색상
      h(1,'2. 색상 시스템 리뉴얼 권고안'),
      p('핑크(#FF5A5F)에서 벗어나 더 세련되고 젠더 뉴트럴한 팔레트로 전환한다.'),
      p(''),
      h(2,'2.1 후보 팔레트 비교'),
      new Table({
        width:{size:9026,type:WidthType.DXA},columnWidths:[1800,1600,2000,3626],
        rows:[
          new TableRow({children:[cell('팔레트',C.grayL,true,1800,C.dark),cell('Primary',C.grayL,true,1600,C.dark),cell('분위기',C.grayL,true,2000,C.dark),cell('평가',C.grayL,true,3626,C.dark)]}),
          new TableRow({children:[cell('A. 딥 인디고 ★ 추천',C.indigoL,true,1800,C.indigo),cell('#3A4F9E',C.indigoL,false,1600,C.indigo),cell('지적·모던·프리미엄',C.indigoL,false,2000,C.indigo),cell('20-35세 커플, 젠더 뉴트럴, CatchTable급 품격',C.indigoL,false,3626,C.indigo)]}),
          new TableRow({children:[cell('B. 딥 티얼',C.white,false,1800),cell('#0F6B8A',C.white,false,1600),cell('청량·신뢰·세련',C.white,false,2000),cell('좋으나 데이트 앱 연상 약함',C.white,false,3626)]}),
          new TableRow({children:[cell('C. 앤트러사이트',C.white,false,1800),cell('#2D3748',C.white,false,1600),cell('고급·차분·중성',C.white,false,2000),cell('너무 어두움, 밝은 감성 부족',C.white,false,3626)]}),
          new TableRow({children:[cell('D. 버건디',C.white,false,1800),cell('#8B2252',C.white,false,1600),cell('로맨틱·성숙·품격',C.white,false,2000),cell('핑크와 유사계열, 차별화 약함',C.white,false,3626)]}),
        ],
      }),
      p(''),
      h(2,'2.2 추천 팔레트: 딥 인디고 시스템'),
      callout(
        '추천 이유: 인디고 블루는 신뢰·지성·프리미엄을 동시에 상징하며 20-35세 커플 앱에 최적화된 색상이다. ' +
        'CatchTable이 오렌지·화이트로 "예약 앱"임을 강조하듯, ODD는 인디고로 "AI 큐레이션 데이트 앱"임을 각인시킨다.',
        C.indigoL, C.indigo, C.indigo
      ),
      p(''),
      new Table({
        width:{size:9026,type:WidthType.DXA},columnWidths:[2000,1600,5426],
        rows:[
          new TableRow({children:[cell('역할',C.grayL,true,2000,C.dark),cell('HEX',C.grayL,true,1600,C.dark),cell('사용처',C.grayL,true,5426,C.dark)]}),
          new TableRow({children:[cell('Primary',C.indigoL,true,2000,C.indigo),cell('#3A4F9E',C.indigoL,false,1600,C.indigo),cell('주요 버튼, 선택 탭, 핵심 CTA, AppBar 아이콘',C.indigoL,false,5426,C.indigo)]}),
          new TableRow({children:[cell('Primary Light',C.white,false,2000),cell('#EEF1FA',C.white,false,1600),cell('선택 카드 배경, 칩 배경, 섹션 하이라이트',C.white,false,5426)]}),
          new TableRow({children:[cell('Primary Mid',C.white,false,2000),cell('#7B8EC8',C.white,false,1600),cell('서브 텍스트, 아이콘 비활성',C.white,false,5426)]}),
          new TableRow({children:[cell('Accent 코랄',C.coralL,true,2000,C.coral),cell('#E8563A',C.coralL,false,1600,C.coral),cell('"AI 코스 생성" CTA 버튼 1개에만 집중 사용',C.coralL,false,5426,C.coral)]}),
          new TableRow({children:[cell('Background',C.white,false,2000),cell('#F7F7FA',C.white,false,1600),cell('앱 전체 배경 (차가운 흰색)',C.white,false,5426)]}),
          new TableRow({children:[cell('Surface',C.white,false,2000),cell('#FFFFFF',C.white,false,1600),cell('카드, 바텀시트, 모달 배경',C.white,false,5426)]}),
          new TableRow({children:[cell('Text Dark',C.white,false,2000),cell('#1F2937',C.white,false,1600),cell('제목, 주요 본문',C.white,false,5426)]}),
          new TableRow({children:[cell('Text Mid',C.white,false,2000),cell('#6B7280',C.white,false,1600),cell('서브 설명, 날짜, 부가정보',C.white,false,5426)]}),
        ],
      }),
      p('적용: app_theme.dart 단일 파일 수정 → 전체 화면 자동 반영 (공수 약 2시간)', {color:C.gray,size:20,before:120}),
      pb(),

      // ── 3. 요청사항 11개
      h(1,'3. 요청사항 11개 — 상세 분석 및 구현 방안'),

      h(2,'① 하단 탭 재구성'),
      p('홈 / 내 주변 / 추천 / 마이 코스 / MY  — 5탭 체계 유지, 역할 명확화'),
      new Table({
        width:{size:9026,type:WidthType.DXA},columnWidths:[1500,1600,1500,4426],
        rows:[
          new TableRow({children:[cell('탭',C.indigoL,true,1500,C.indigo),cell('아이콘',C.indigoL,true,1600,C.indigo),cell('현재',C.indigoL,true,1500,C.indigo),cell('변경안 및 근거',C.indigoL,true,4426,C.indigo)]}),
          new TableRow({children:[cell('홈',C.white,true,1500),cell('home_rounded',C.white,false,1600),cell('HomeScreen',C.white,false,1500),cell('유지 — 진입 허브 역할',C.white,false,4426)]}),
          new TableRow({children:[cell('내 주변',C.white,true,1500),cell('near_me_rounded',C.white,false,1600),cell('탐색(explore)',C.white,false,1500),cell('"탐색" → "내 주변" 개명. 현재 위치 기반 장소 + 지도 뷰 강조',C.white,false,4426)]}),
          new TableRow({children:[cell('추천',C.white,true,1500),cell('auto_awesome_rounded',C.white,false,1600),cell('AI코스',C.white,false,1500),cell('"AI코스" → "추천". 아이콘: 스파클→별. 취향 큐레이션 인식 제고',C.white,false,4426)]}),
          new TableRow({children:[cell('마이 코스',C.white,true,1500),cell('route_rounded',C.white,false,1600),cell('저장(saved)',C.white,false,1500),cell('"저장" → "마이 코스". 내 코스 + 커뮤니티 2개 서브탭 포함 (Phase 2)',C.white,false,4426)]}),
          new TableRow({children:[cell('MY',C.white,true,1500),cell('person_rounded',C.white,false,1600),cell('MyScreen',C.white,false,1500),cell('유지. 사용자 검색 기능 추가 (Phase 2)',C.white,false,4426)]}),
        ],
      }),
      callout('난이도: ★☆☆☆☆  |  예상 공수: 1일  |  우선순위: Phase 1 즉시', C.greenL, C.green, C.green),

      p(''),
      h(2,'② 홈 화면 리디자인 — CatchTable 스타일'),
      ...bullet([
        'CatchTable 홈의 핵심: 화이트 배경 + 강한 타이포그래피 + 단일 포인트컬러 + 카드 그리드',
        '현재 문제: 그라디언트 카드 6가지 색상, 히어로배너·테마캐러셀·시간배너 각각 다른 색 → 시선 분산',
        '개선 1: 카테고리 그리드 — 배경 흰색, 인디고 보더, 이모지+레이블만 — 색상 6개 → 1개',
        '개선 2: 히어로배너 — 인디고 단색 그라디언트로 통일, 텍스트 크기 업',
        '개선 3: 섹션 헤더 — 폰트 크기 키우고 서브 텍스트 줄여 위계 명확화',
        '개선 4: 카드 — 그림자만 주고 배경 흰색. 사진이 주인공이 되게 (CatchTable 방식)',
        '개선 5: 홈 최상단 컨텍스트 바 — 날씨 + 시간 + 지역을 한 줄 요약',
        '개선 6: 퀵 필터 배너(현재 구현) — 인디고 테마로 색상 통일',
      ]),
      callout('난이도: ★★☆☆☆  |  예상 공수: 3-5일  |  우선순위: Phase 1', C.greenL, C.green, C.green),

      p(''),
      h(2,'③ 색상 전환 구현'),
      ...numbered([
        'app_theme.dart: primary = Color(0xFF3A4F9E), bg2 = Color(0xFFEEF1FA)',
        '그라디언트: primaryGradient = [#3A4F9E, #5B73C4], heroBannerGradient = [#1E2D6B, #3A4F9E]',
        'Accent 코랄(#E8563A)은 AI 코스 생성 버튼 1개에만 집중 사용',
        'pubspec.yaml 변경 없음 — 코드 변경만으로 전체 반영',
      ]),
      callout('난이도: ★☆☆☆☆  |  예상 공수: 2일  |  우선순위: Phase 1', C.greenL, C.green, C.green),
      pb(),

      h(2,'④ 마이 코스 탭 — 커뮤니티 기능'),
      callout(
        '중요: 커뮤니티 기능은 백엔드(서버+DB+인증) 없이 구현 불가. ' +
        '현재 앱은 100% 로컬 SharedPreferences 기반이므로 서버 도입이 전제조건이다.',
        C.redL, C.red, C.red
      ),
      p(''),
      p('서브탭 구성:'),
      ...bullet([
        '내 코스 탭: 생성한 코스 + 저장한 코스 + 히스토리 통합 (현재 SavedScreen + MyScreen 히스토리)',
        '커뮤니티 탭: 다른 사용자가 공유한 코스 피드 (카드형 스크롤)',
      ]),
      p('커뮤니티 탭 핵심 기능:'),
      ...bullet([
        '코스 공유: "공개로 저장" → Supabase courses 테이블 업로드',
        '좋아요/북마크: likes 테이블, user_bookmarks 테이블',
        '댓글: comments 테이블 (1단계)',
        '필터: 지역별 / 분위기별 / 최신순·인기순',
        '커스터마이징: 공유 코스에서 장소 추가/삭제 후 내 코스로 복제',
      ]),
      callout('난이도: ★★★★☆  |  예상 공수: 3-4주  |  우선순위: Phase 2 (백엔드 구축 후)', C.amberL, C.amber, C.amber),

      p(''),
      h(2,'⑤ 내 주변 탭 — 커뮤니티 핫픽 (나중에)'),
      ...bullet([
        '상단 섹션: "이 지역 핫 코스" — 좋아요 TOP 3-5 커뮤니티 코스 수평 카드',
        '하단 섹션: 기존 ExploreScreen (장소 검색 + 카테고리 필터)',
        '지도 뷰 토글: 리스트 ↔ 지도 뷰 (카카오 지도 SDK 연동)',
      ]),
      callout('난이도: ★★★☆☆  |  예상 공수: 2주  |  우선순위: Phase 3 (커뮤니티 구축 후)', C.amberL, C.amber, C.amber),

      p(''),
      h(2,'⑥⑦ MY 탭 — 프로필 검색 + 공개 프로필'),
      ...bullet([
        '내 프로필: 닉네임, 프로필 사진(Supabase Storage), 공개 코스 수, 팔로워/팔로잉',
        '사용자 검색: 상단 검색창 → 닉네임 검색 → 프로필 카드 결과',
        '공개 프로필: 타 사용자 클릭 → 공개 코스 그리드 노출',
        '프라이버시 설정: 코스별 공개/비공개 (기본값: 비공개)',
        '팔로우: follower_following 테이블, 팔로우한 사람 코스 피드 우선 노출',
      ]),
      callout('난이도: ★★★☆☆  |  예상 공수: 2-3주  |  우선순위: Phase 2', C.amberL, C.amber, C.amber),
      pb(),

      h(2,'⑧ 문화행사 — 지역 표시 + 상세보기'),
      ...bullet([
        '문제: 선택 지역과 이벤트 지역 불일치 시 혼란, 상세보기 없음',
        '개선 1: 섹션 헤더에 "📍 대전 유성구 문화행사" 식으로 지역명 명시',
        '개선 2: 이벤트 카드 탭 → 상세 바텀시트 (제목/날짜/장소/요금/설명)',
        '개선 3: 바텀시트 내 "공식 홈페이지" 버튼 → 인앱 WebView로 열기',
        '개선 4: 현재 지역 기반 이벤트만 노출, 지역 라벨 명시',
      ]),
      callout('난이도: ★★☆☆☆  |  예상 공수: 2-3일  |  우선순위: Phase 1', C.greenL, C.green, C.green),

      p(''),
      h(2,'⑨ 위치 선택 — 시→구→동 3단계 계층'),
      ...bullet([
        '현재: 시(City) → 구(District) 2단계',
        '목표: 시(市) → 구(區) → 동(洞) 3단계 드릴다운',
        '데이터: 행정안전부 법정동코드 공공데이터 활용 (무료 개방)',
        '서울 424동, 전국 약 3,500개 동 → JSON 에셋 번들링',
        '_districtMap 구조를 Map<String, Map<String, List<String>>> 으로 확장',
        '상위 단계(구 자체)도 선택 가능: "강남구 전체" 검색 허용',
        '인기 동(洞) 검색: 최근 지역 캐시에 동 단위도 저장',
      ]),
      callout('난이도: ★★★☆☆  |  예상 공수: 1주  |  우선순위: Phase 1', C.greenL, C.green, C.green),

      p(''),
      h(2,'⑩ 원데이 클래스 탭'),
      p('원데이클래스는 ODD의 데이트 코스와 완벽히 결합되는 컨텐츠 — 데이트의 "체험" 슬롯을 직접 채운다.'),
      new Table({
        width:{size:9026,type:WidthType.DXA},columnWidths:[2200,1400,5426],
        rows:[
          new TableRow({children:[cell('방법',C.indigoL,true,2200,C.indigo),cell('난이도',C.indigoL,true,1400,C.indigo),cell('상세',C.indigoL,true,5426,C.indigo)]}),
          new TableRow({children:[cell('① 네이버 키워드 검색',C.white,true,2200),cell('★☆☆☆☆',C.white,false,1400),cell('NaverPlaceService "원데이클래스" 쿼리 추가 — 즉시 구현 가능',C.white,false,5426)]}),
          new TableRow({children:[cell('② 카카오 카테고리',C.white,true,2200),cell('★★☆☆☆',C.white,false,1400),cell('CE7(강습/클래스) 카카오 로컬 API 카테고리 검색',C.white,false,5426)]}),
          new TableRow({children:[cell('③ 클래스101 제휴',C.white,true,2200),cell('★★★☆☆',C.white,false,1400),cell('파트너 API 제휴 신청 → 수수료 5-8% 수익 가능 (추천)',C.white,false,5426)]}),
          new TableRow({children:[cell('④ 크롤링',C.white,true,2200),cell('★★★★☆',C.white,false,1400),cell('법적 위험 + 유지보수 부담 — 권장하지 않음',C.white,false,5426)]}),
        ],
      }),
      p('추천: ① 방법으로 즉시 런칭 → 사용자 반응 확인 후 ③ 제휴로 업그레이드'),
      callout('난이도: ★★☆☆☆ (①기준)  |  예상 공수: 3-5일  |  우선순위: Phase 1 말기', C.greenL, C.green, C.green),
      pb(),

      h(2,'⑪ 친구 추가·커플 연동 + 캘린더'),
      callout(
        '이 기능은 앱의 핵심 차별점이 될 "킬러 피처"다. ' +
        '커플 앱(비트윈)과 데이트 코스 앱의 교차점 — 성공 시 강력한 Lock-in 효과.',
        C.indigoL, C.indigo, C.indigo
      ),
      p(''),
      p('구현 구조:'),
      ...numbered([
        '파트너 코드: 6자리 랜덤 코드 생성 → 파트너 입력 → couple_links 테이블',
        '커플 캘린더: shared_calendar 테이블 (event_date, course_id, note)',
        '코스 등록: 코스 결과 화면 → "캘린더에 저장" → 날짜 선택 → 커플 캘린더',
        '알림: 저장한 데이트 D-3, D-1, 당일 아침 푸시 (Firebase Messaging)',
        '기념일: anniversary 테이블 → 매년 자동 알림 + 맞춤 코스 추천',
      ]),
      p(''),
      p('친구(비커플) 기능:'),
      ...bullet([
        '친구 추가: 닉네임 또는 코드 검색 → 팔로우',
        '"친구에게 코스 공유" 버튼 → 카카오톡/문자 딥링크',
        '그룹 코스: Phase 4에서 3인 이상 그룹 데이트 코스 지원 고려',
      ]),
      callout('난이도: ★★★★★  |  예상 공수: 4-6주  |  우선순위: Phase 3', C.redL, C.red, C.red),
      pb(),

      // ── 4. 전문가 추가 개선안
      h(1,'4. 전문가 추가 개선안 (요청 외 — 10년차 관점)'),
      p('아래 항목들은 요청사항에 없지만 앱의 성장과 생존을 위해 반드시 함께 다루어야 한다.'),

      h(2,'A. 백엔드 아키텍처 도입 [최우선]'),
      callout('현재 앱은 서버가 없다. 커뮤니티·프로필·커플 기능 등 v4.0의 절반 이상이 백엔드 없이 불가능하다.', C.redL, C.red, C.red),
      p('추천: Supabase (PostgreSQL + Auth + Realtime + Storage 올인원)'),
      ...bullet([
        'Auth: 카카오·네이버 소셜 로그인, 이메일/비밀번호',
        'Database: users, courses(공개), likes, couples, calendar, events 테이블',
        'Storage: 프로필 사진, 코스 커버 이미지',
        'Realtime: 커플 캘린더 실시간 동기화, 좋아요 카운트 실시간',
        '비용: Free tier — 유저 1만명까지 무료',
      ]),

      p(''),
      h(2,'B. 소셜 로그인'),
      ...bullet([
        '카카오 로그인: flutter_kakao_login (국내 MAU 4천만)',
        '네이버 로그인: flutter_naver_login',
        '애플 로그인: sign_in_with_apple (iOS App Store 제출 필수)',
        '로그인 없이 탐색 허용: 코스 생성까지 비회원 가능, 저장/공유 시 로그인 유도',
      ]),

      p(''),
      h(2,'C. 홈 화면 컨텍스트 인텔리전스'),
      ...bullet([
        '날씨 연동 강화: 현재 코스 프롬프트 주입만 → 홈 상단 날씨 카드 노출',
        '"지금 이 시간 추천": 오전/낮/저녁/밤 + 날씨 + 지역 조합 → 맞춤 배너 1개',
        '커플 기념일 카운트다운: 로그인 시 홈 최상단 "D-12 사귄 날 기념일" 표시',
        '최근 본 장소: 홈 하단 "최근 탐색한 장소" 가로 스크롤 (CacheService 활용)',
      ]),

      p(''),
      h(2,'D. 성능 최적화'),
      ...bullet([
        '홈 화면 지연 로딩: initState 6카테고리 병렬 fetch → 화면 표시 후 순차 로딩으로 체감 속도 개선',
        'Skeleton Screen: shimmer를 홈 카드에도 적용 (현재 상세 화면만)',
        '이미지 캐시: cached_network_image CacheManager maxAge 7일 설정',
        'API 병렬화: 일부 직렬 fetch → Future.wait() 전환으로 30% 속도 개선 가능',
      ]),

      p(''),
      h(2,'E. 수익화 모델 설계 [현재 매출 0원]'),
      new Table({
        width:{size:9026,type:WidthType.DXA},columnWidths:[1800,1400,1600,4226],
        rows:[
          new TableRow({children:[cell('모델',C.indigoL,true,1800,C.indigo),cell('시점',C.indigoL,true,1400,C.indigo),cell('예상 수익',C.indigoL,true,1600,C.indigo),cell('방법',C.indigoL,true,4226,C.indigo)]}),
          new TableRow({children:[cell('제휴 수수료',C.white,true,1800),cell('Phase 1',C.white,false,1400),cell('월 30-100만원',C.white,false,1600),cell('네이버 예약/CatchTable 레퍼럴 딥링크 수수료 2-5%',C.white,false,4226)]}),
          new TableRow({children:[cell('클래스 수수료',C.white,true,1800),cell('Phase 2',C.white,false,1400),cell('월 50-200만원',C.white,false,1600),cell('클래스101/탈잉 제휴 5-8% 수수료',C.white,false,4226)]}),
          new TableRow({children:[cell('ODD Premium',C.white,true,1800),cell('Phase 3',C.white,false,1400),cell('월 3,900원/인',C.white,false,1600),cell('무제한 코스, 커플 캘린더 고급 기능, 광고 제거',C.white,false,4226)]}),
          new TableRow({children:[cell('B2B 광고',C.white,true,1800),cell('Phase 4',C.white,false,1400),cell('월 200만원~',C.white,false,1600),cell('지역 카페/식당 "ODD 추천 장소" 배지 유료 노출',C.white,false,4226)]}),
        ],
      }),

      p(''),
      h(2,'F. 애널리틱스 도입'),
      ...bullet([
        '현재: 사용자 행동 데이터 0 — 어떤 카테고리를 보는지, 코스 완료율이 얼마인지 모름',
        'Firebase Analytics: 무료, Flutter 패키지 완비 (설치 반나절)',
        '핵심 이벤트: course_generated, place_viewed, category_tapped, course_shared',
        'Crashlytics: 앱 크래시 자동 리포팅',
        'A/B 테스트: Firebase Remote Config → 색상/카피/카드 레이아웃 실험',
      ]),

      p(''),
      h(2,'G. 콘텐츠 모더레이션 (커뮤니티 전제)'),
      ...bullet([
        '이미지: Gemini Vision API SafetySettings → 부적절 이미지 자동 차단',
        '텍스트: 욕설/혐오 키워드 필터링 + 신고 기능',
        '신고 시스템: 3회 신고 → 자동 비공개, 관리자 검토 큐',
      ]),

      p(''),
      h(2,'H. ASO (앱 스토어 최적화)'),
      ...bullet([
        '앱 이름: "ODD - AI 데이트 코스 추천" (검색 키워드 포함)',
        '키워드: 데이트 앱, 커플 앱, 데이트 코스, 데이트 장소 추천, 주말 데이트',
        '스크린샷: 코스 생성 결과 → 실제 장소 사진 포함 결과 화면이 가장 효과적',
        '리뷰 유도: 코스 완료 후 "즐거우셨나요?" 팝업 (in_app_review 패키지)',
        '현재 미등록 → 조기 등록 시 신규 앱 우대 노출 기간 활용 가능',
      ]),
      pb(),

      // ── 5. 기술 아키텍처
      h(1,'5. 기술 아키텍처 설계'),
      h(2,'5.1 현재 vs 목표 아키텍처'),
      new Table({
        width:{size:9026,type:WidthType.DXA},columnWidths:[2000,3513,3513],
        rows:[
          new TableRow({children:[cell('레이어',C.indigoL,true,2000,C.indigo),cell('현재 (v3.1)',C.indigoL,true,3513,C.indigo),cell('목표 (v4.0)',C.indigoL,true,3513,C.indigo)]}),
          new TableRow({children:[cell('Frontend',C.white,true,2000),cell('Flutter 3.44 / Dart 3.12',C.white,false,3513),cell('동일 + Riverpod 상태관리',C.white,false,3513)]}),
          new TableRow({children:[cell('Storage',C.white,true,2000),cell('SharedPreferences (로컬)',C.white,false,3513),cell('+ Supabase PostgreSQL (서버)',C.white,false,3513)]}),
          new TableRow({children:[cell('Auth',C.white,true,2000),cell('없음',C.white,false,3513),cell('Supabase Auth + 카카오/네이버',C.white,false,3513)]}),
          new TableRow({children:[cell('AI 엔진',C.white,true,2000),cell('Gemini 1.5 Flash (직접 호출)',C.white,false,3513),cell('동일 (키 서버사이드 이전 권장)',C.white,false,3513)]}),
          new TableRow({children:[cell('Place API',C.white,true,2000),cell('Naver + Kakao + Google',C.white,false,3513),cell('동일 + 원데이클래스 전용 쿼리',C.white,false,3513)]}),
          new TableRow({children:[cell('Push',C.white,true,2000),cell('없음',C.white,false,3513),cell('Firebase Cloud Messaging',C.white,false,3513)]}),
          new TableRow({children:[cell('Analytics',C.white,true,2000),cell('없음',C.white,false,3513),cell('Firebase Analytics + Crashlytics',C.white,false,3513)]}),
          new TableRow({children:[cell('지도',C.white,true,2000),cell('없음',C.white,false,3513),cell('카카오맵 Flutter SDK',C.white,false,3513)]}),
        ],
      }),

      p(''),
      h(2,'5.2 신규 추가 패키지'),
      new Table({
        width:{size:9026,type:WidthType.DXA},columnWidths:[2600,1600,4826],
        rows:[
          new TableRow({children:[cell('패키지',C.indigoL,true,2600,C.indigo),cell('버전',C.indigoL,true,1600,C.indigo),cell('용도',C.indigoL,true,4826,C.indigo)]}),
          new TableRow({children:[cell('supabase_flutter',C.white,false,2600),cell('^2.5.0',C.white,false,1600),cell('백엔드 DB + Auth + Storage + Realtime',C.white,false,4826)]}),
          new TableRow({children:[cell('flutter_kakao_login',C.white,false,2600),cell('^5.0.0',C.white,false,1600),cell('카카오 소셜 로그인',C.white,false,4826)]}),
          new TableRow({children:[cell('firebase_analytics',C.white,false,2600),cell('^11.0.0',C.white,false,1600),cell('사용자 행동 분석',C.white,false,4826)]}),
          new TableRow({children:[cell('firebase_messaging',C.white,false,2600),cell('^15.0.0',C.white,false,1600),cell('푸시 알림',C.white,false,4826)]}),
          new TableRow({children:[cell('flutter_riverpod',C.white,false,2600),cell('^2.5.0',C.white,false,1600),cell('상태관리 (Provider 패턴 → Riverpod 이전)',C.white,false,4826)]}),
          new TableRow({children:[cell('in_app_review',C.white,false,2600),cell('^2.0.0',C.white,false,1600),cell('앱스토어 리뷰 유도 팝업',C.white,false,4826)]}),
          new TableRow({children:[cell('table_calendar',C.white,false,2600),cell('^3.1.0',C.white,false,1600),cell('커플 캘린더 UI',C.white,false,4826)]}),
        ],
      }),
      pb(),

      // ── 6. 로드맵
      h(1,'6. 단계별 개발 로드맵'),
      new Table({
        width:{size:9026,type:WidthType.DXA},columnWidths:[1400,1000,3413,3213],
        rows:[
          new TableRow({children:[cell('단계',C.indigoL,true,1400,C.indigo),cell('기간',C.indigoL,true,1000,C.indigo),cell('주요 작업',C.indigoL,true,3413,C.indigo),cell('완료 기준',C.indigoL,true,3213,C.indigo)]}),
          new TableRow({children:[
            cell('Phase 1\nUI 리프레시',C.indigoL,true,1400,C.indigo),
            cell('4-6주',C.white,false,1000),
            cell('① 하단탭 개명+아이콘\n② 인디고 색상 전환\n③ 홈화면 리디자인\n⑧ 문화행사 상세보기\n⑨ 시→구→동 3단계\n⑩ 원데이클래스(①방법)',C.white,false,3413),
            cell('앱 색상 통일\n탭 명칭 변경\n지역 3단계 동작\n문화행사 바텀시트',C.white,false,3213),
          ]}),
          new TableRow({children:[
            cell('Phase 2\n백엔드+인증',C.indigoL,true,1400,C.indigo),
            cell('6-8주',C.white,false,1000),
            cell('Supabase 세팅\n카카오/네이버 로그인\n④ 내 코스 탭(클라우드 저장)\n⑥⑦ 프로필+사용자 검색\nFirebase Analytics',C.white,false,3413),
            cell('로그인 동작\n프로필 생성/편집\n코스 클라우드 저장',C.white,false,3213),
          ]}),
          new TableRow({children:[
            cell('Phase 3\n커뮤니티',C.indigoL,true,1400,C.indigo),
            cell('6-8주',C.white,false,1000),
            cell('④ 커뮤니티 탭\n⑤ 핫픽 섹션\n⑪ 커플 연동+캘린더\n모더레이션\nODD Premium 구독',C.white,false,3413),
            cell('코스 공유+좋아요\n커플 연결 동작\n캘린더 코스 등록',C.white,false,3213),
          ]}),
          new TableRow({children:[
            cell('Phase 4\n성장+수익화',C.indigoL,true,1400,C.indigo),
            cell('지속',C.white,false,1000),
            cell('클래스101 제휴(③)\nASO + 앱 출시\nB2B 광고 상품\n그룹 데이트 코스',C.white,false,3413),
            cell('앱스토어 등록\n제휴 수수료 수익\nMAU 1만 달성',C.white,false,3213),
          ]}),
        ],
      }),
      pb(),

      // ── 7. 마케팅
      h(1,'7. 마케팅 & 성장 전략'),
      h(2,'7.1 타겟 세그먼트'),
      new Table({
        width:{size:9026,type:WidthType.DXA},columnWidths:[2200,2000,4826],
        rows:[
          new TableRow({children:[cell('세그먼트',C.indigoL,true,2200,C.indigo),cell('연령대',C.indigoL,true,2000,C.indigo),cell('핵심 가치 제안',C.indigoL,true,4826,C.indigo)]}),
          new TableRow({children:[cell('신혼/장기 커플',C.white,true,2200),cell('20대 후반~30대',C.white,false,2000),cell('"매주 똑같은 데이트" 탈출 → AI가 새로운 코스 발굴',C.white,false,4826)]}),
          new TableRow({children:[cell('새내기 커플',C.white,true,2200),cell('20대 초반',C.white,false,2000),cell('"뭐할지 모르겠어" → 1분 안에 완성된 데이트 코스',C.white,false,4826)]}),
          new TableRow({children:[cell('솔로/친구 그룹',C.white,true,2200),cell('20-30대',C.white,false,2000),cell('주말 계획 없을 때 → 지역 기반 즉흥 코스',C.white,false,4826)]}),
        ],
      }),

      p(''),
      h(2,'7.2 채널 전략'),
      ...bullet([
        '인스타그램/틱톡: 실제 코스 결과 스크린샷 + 장소 사진 → UGC 바이럴 유도',
        '카카오 채널: 오픈 시 무료 메시지 "이번 주말 데이트 코스 AI가 골라드려요"',
        '블로그 SEO: 지역별 "xx동 데이트 코스 추천" 롱테일 키워드 공략',
        '커뮤니티: 나는솔로/결혼, 에브리타임 등 커플 커뮤니티 바이럴',
        'PR: "AI가 짜주는 데이트 코스" 테크 미디어 투고 (뉴닉, 캐릿 등)',
      ]),

      p(''),
      h(2,'7.3 North Star Metric'),
      callout('"주간 코스 생성 수(Weekly Courses Generated)" — 유저가 실제로 데이트 계획을 세운 횟수가 앱의 핵심 가치를 측정한다.', C.indigoL, C.indigo, C.indigo),
      p(''),
      ...bullet([
        'L1 — DAU/WAU: 일간·주간 활성 사용자 (목표: 3개월 내 DAU 1,000)',
        'L2 — 코스 생성 완료율: 시작 → 결과 화면 도달률 (목표: 70% 이상)',
        'L3 — 코스 저장률: 생성 후 저장 비율 (목표: 40% 이상)',
        'L4 — D7 리텐션 (목표: 30% 이상 — 앱 평균 15-20%)',
        'L5 — 커플 연동률: 로그인 유저 중 커플 연결 완료 비율 (목표: 50%)',
      ]),
      pb(),

      // ── 8. 결론
      h(1,'8. 결론 및 우선순위 액션 아이템'),
      callout(
        'ODD는 현재 기술 기반(AI 엔진, 3-소스 장소 DB, UX 구조)이 탄탄하다. ' +
        '다음 도약을 위한 병목은 ① 색상·디자인 통일성, ② 백엔드 도입, ③ 커뮤니티 기반 바이럴 루프 세 가지다.',
        C.indigoL, C.indigo, C.indigo
      ),

      p(''),
      h(2,'즉시 실행 (이번 주)'),
      ...numbered([
        'app_theme.dart: 핑크 → 딥 인디고 (#3A4F9E) 전환 (약 2시간)',
        'main_nav.dart: 탭 라벨·아이콘 변경 — 홈/내 주변/추천/마이 코스/MY (약 1시간)',
        'home_screen.dart: 카테고리 그리드 색상 정리, 히어로배너 인디고 통일 (약 4시간)',
        '문화행사 상세 바텀시트 추가 + 지역명 섹션 헤더 (약 3시간)',
      ]),

      p(''),
      h(2,'1개월 내'),
      ...numbered([
        '위치 시→구→동 3단계 구현 (법정동 JSON 에셋 번들링)',
        '원데이클래스 탭 (네이버 키워드 검색 방식)',
        '홈 화면 컨텍스트 바 (날씨+시간 요약)',
        'Firebase Analytics + Crashlytics 설치',
      ]),

      p(''),
      h(2,'3개월 내'),
      ...numbered([
        'Supabase 백엔드 세팅 + 카카오 소셜 로그인',
        '사용자 프로필 + 공개 코스 기능',
        '커뮤니티 탭 MVP (공유 + 좋아요)',
        'in_app_review 리뷰 유도 팝업',
      ]),

      p(''),
      h(2,'6개월 내'),
      ...numbered([
        '커플 연동 + 공유 캘린더',
        '푸시 알림 (기념일 + 날씨 기반 코스 추천)',
        'ODD Premium 구독 런칭',
        'Google Play / App Store 공식 출시 + ASO',
      ]),

      divider(C.indigo),
      p(''),
      new Paragraph({alignment:AlignmentType.CENTER, children:[
        new TextRun({text:'ODD — 당신의 데이트를 특별하게',size:24,bold:true,color:C.indigo,font:'Arial'})
      ]}),
      new Paragraph({alignment:AlignmentType.CENTER, children:[
        new TextRun({text:'본 보고서는 현재 v3.1.0 스크린샷 및 코드베이스 분석을 기반으로 작성되었습니다.',size:18,color:C.gray,font:'Arial'})
      ]}),
    ],
  }],
});

Packer.toBuffer(doc).then(buf=>{
  fs.writeFileSync('/sessions/epic-relaxed-franklin/mnt/odd-app/ODD_v4_전략기획보고서.docx',buf);
  console.log('DONE');
}).catch(e=>{console.error(e);process.exit(1);});
