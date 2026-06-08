-- =============================================
-- ODD 앱 Supabase 테이블 스키마
-- Supabase 콘솔 > SQL Editor 에서 실행하세요
-- =============================================

-- 장소 캐시 테이블
CREATE TABLE IF NOT EXISTS places_cache (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  category      TEXT NOT NULL,          -- '감성' | '액티비티'
  subcategory   TEXT DEFAULT '',
  tags          TEXT[] DEFAULT '{}',
  address       TEXT DEFAULT '',
  lat           DOUBLE PRECISION NOT NULL,
  lng           DOUBLE PRECISION NOT NULL,
  rating        DOUBLE PRECISION DEFAULT 4.0,
  price_range   TEXT DEFAULT '보통',
  duration      INTEGER DEFAULT 60,
  image_url     TEXT DEFAULT '',
  description   TEXT DEFAULT '',
  open_hours    TEXT DEFAULT '',
  phone         TEXT DEFAULT '',
  region        TEXT DEFAULT '',
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 지역 + 카테고리 복합 인덱스 (캐시 조회 성능)
CREATE INDEX IF NOT EXISTS idx_places_region_category
  ON places_cache (region, category);

-- 채팅 세션 로그 테이블 (분석용)
CREATE TABLE IF NOT EXISTS chat_sessions (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  region     TEXT DEFAULT '',
  mood       TEXT DEFAULT '',
  time_slot  TEXT DEFAULT '',
  budget     TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Row Level Security (익명 읽기/쓰기 허용)
ALTER TABLE places_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon read places" ON places_cache
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon insert places" ON places_cache
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon upsert places" ON places_cache
  FOR UPDATE TO anon USING (true);

CREATE POLICY "anon insert sessions" ON chat_sessions
  FOR INSERT TO anon WITH CHECK (true);

-- 24시간 지난 캐시 자동 삭제 (선택: pg_cron 필요)
-- SELECT cron.schedule('0 4 * * *', $$
--   DELETE FROM places_cache WHERE created_at < NOW() - INTERVAL '24 hours';
-- $$);
