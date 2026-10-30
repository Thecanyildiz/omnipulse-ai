-- ============================================================================
-- OmniPulse AI — Bulut Tabanlı Çoklu Sosyal Medya Analitik ve Otonom Strateji Platformu
-- Supabase PostgreSQL Veritabanı Şeması (Tam Üretim Sürümü - Zero Placeholders)
-- ============================================================================

-- 0. Gerekli Eklentiler
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. BULUT SENKRONİZASYON İŞ TAKİP TABLOSU (Telefondan canlı ilerleme görmek için)
-- ============================================================================
CREATE TABLE IF NOT EXISTS sync_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    status VARCHAR(20) NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'completed', 'failed')),
    triggered_by VARCHAR(20) DEFAULT 'mobile_app' CHECK (triggered_by IN ('mobile_app', 'desktop_app', 'cron_schedule', 'manual_cli')),
    target_account_id UUID NULL,
    total_accounts INT DEFAULT 0,
    processed_accounts INT DEFAULT 0,
    failed_accounts INT DEFAULT 0,
    current_account_name VARCHAR(100),
    status_message TEXT,
    error_log JSONB DEFAULT '[]'::jsonb,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sync_jobs_started_at ON sync_jobs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_jobs_status ON sync_jobs(status);

-- ============================================================================
-- 2. HESAPLAR TABLOSU (Kullanıcı silene kadar kalıcı, 15+ hesap destekli)
-- ============================================================================
CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('tiktok', 'instagram', 'youtube')),
    username VARCHAR(100) NOT NULL,
    display_name VARCHAR(150),
    avatar_url TEXT,
    bio_text TEXT,
    category_tag VARCHAR(50) DEFAULT 'Genel',
    -- İki Seçenekli Veri Çekme Modu: 'public_only' (Mod A: Sadece @kullaniciadi) veya 'authorized_api' (Mod B: Token/Cookie bağlı)
    fetch_mode VARCHAR(20) NOT NULL DEFAULT 'public_only' CHECK (fetch_mode IN ('public_only', 'authorized_api')),
    auth_credentials JSONB DEFAULT '{}'::jsonb, -- Mod B için API Key, OAuth Refresh Token veya Session ID
    -- Otonom AI Niş Tespiti
    detected_niche VARCHAR(150),
    niche_search_keywords JSONB DEFAULT '[]'::jsonb,
    -- Güncel Özet Metrikler (Hızlı listeleme için)
    current_followers BIGINT DEFAULT 0,
    current_following BIGINT DEFAULT 0,
    current_total_views BIGINT DEFAULT 0,
    current_video_count INT DEFAULT 0,
    current_median_views BIGINT DEFAULT 0,
    current_engagement_rate FLOAT DEFAULT 0.0,
    current_virality_score FLOAT DEFAULT 0.0,
    latest_video_multiplier FLOAT DEFAULT 1.0,
    follower_growth_24h FLOAT DEFAULT 0.0,
    follower_growth_7d FLOAT DEFAULT 0.0,
    follower_growth_30d FLOAT DEFAULT 0.0,
    views_growth_24h FLOAT DEFAULT 0.0,
    views_growth_7d FLOAT DEFAULT 0.0,
    views_growth_30d FLOAT DEFAULT 0.0,
    optimal_best_hour VARCHAR(30) DEFAULT '19:00 - 21:00',
    health_status VARCHAR(20) DEFAULT 'stable' CHECK (health_status IN ('surging', 'growing', 'stable', 'declining', 'anomaly_drop')),
    is_active BOOLEAN DEFAULT TRUE,
    last_sync_error TEXT,
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(platform, username)
);

CREATE INDEX IF NOT EXISTS idx_accounts_platform_active ON accounts(platform, is_active);
CREATE INDEX IF NOT EXISTS idx_accounts_health ON accounts(health_status);

-- ============================================================================
-- 3. HESAP TARİHSEL GELİŞİM TABLOSU (Time-Series Snapshots)
-- ============================================================================
CREATE TABLE IF NOT EXISTS account_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    followers_count BIGINT NOT NULL DEFAULT 0,
    total_views BIGINT NOT NULL DEFAULT 0,
    video_count INT DEFAULT 0,
    median_views BIGINT DEFAULT 0,
    avg_engagement_rate FLOAT DEFAULT 0.0,
    avg_virality_score FLOAT DEFAULT 0.0,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_account_snapshots_time ON account_snapshots(account_id, recorded_at DESC);

-- ============================================================================
-- 4. VİDEOLAR VE DERİN ANALİTİK TABLOSU
-- ============================================================================
CREATE TABLE IF NOT EXISTS videos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    platform_video_id VARCHAR(100) NOT NULL,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    title_or_caption TEXT,
    hashtags JSONB DEFAULT '[]'::jsonb,
    duration_seconds INT DEFAULT 0,
    published_at TIMESTAMPTZ,
    -- 5 Temel Metrik
    views BIGINT DEFAULT 0,
    likes BIGINT DEFAULT 0,
    comments BIGINT DEFAULT 0,
    shares BIGINT DEFAULT 0,
    saves BIGINT DEFAULT 0,
    -- Mod B Ek Metrikler (Mevcutsa)
    avg_watch_percentage FLOAT DEFAULT 0.0,
    traffic_source_summary JSONB DEFAULT '{}'::jsonb,
    -- Hesaplanan Matematiksel Metrikler
    engagement_rate FLOAT DEFAULT 0.0,
    virality_score FLOAT DEFAULT 0.0, -- 0-100 arası kaydetme/paylaşım ağırlıklı puan
    performance_multiplier FLOAT DEFAULT 1.0, -- Kanal medyanının kaç katı (Örn: 4.2x veya 0.3x)
    views_velocity_per_hour FLOAT DEFAULT 0.0, -- Saatlik izlenme artış hızı
    performance_tier VARCHAR(20) DEFAULT 'normal' CHECK (performance_tier IN ('viral_hit', 'above_average', 'normal', 'underperforming', 'flop')),
    -- Yapay Zeka "Neden İzlendi / Neden İzlenmedi" Analizi
    ai_root_cause_analysis JSONB DEFAULT '{}'::jsonb,
    last_updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(account_id, platform_video_id)
);

CREATE INDEX IF NOT EXISTS idx_videos_account_pub ON videos(account_id, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_videos_tier ON videos(account_id, performance_tier);
CREATE INDEX IF NOT EXISTS idx_videos_multiplier ON videos(account_id, performance_multiplier DESC);

-- ============================================================================
-- 5. VİDEO İVME TAKİP TABLOSU (Videonun saatlik/günlük büyüme eğrisi için)
-- ============================================================================
CREATE TABLE IF NOT EXISTS video_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    video_id UUID NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    views BIGINT DEFAULT 0,
    likes BIGINT DEFAULT 0,
    comments BIGINT DEFAULT 0,
    shares BIGINT DEFAULT 0,
    saves BIGINT DEFAULT 0,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_video_snapshots_time ON video_snapshots(video_id, recorded_at DESC);

-- ============================================================================
-- 6. OTONOM KEŞFEDİLEN RAKİP VİDEOLAR TABLOSU (AI kendisi bulup doldurur)
-- ============================================================================
CREATE TABLE IF NOT EXISTS autonomous_competitors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    target_account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('tiktok', 'instagram', 'youtube')),
    competitor_username VARCHAR(100) NOT NULL,
    platform_video_id VARCHAR(100),
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    caption TEXT,
    hashtags JSONB DEFAULT '[]'::jsonb,
    search_keyword_used VARCHAR(150),
    duration_seconds INT DEFAULT 0,
    views BIGINT DEFAULT 0,
    likes BIGINT DEFAULT 0,
    comments BIGINT DEFAULT 0,
    shares BIGINT DEFAULT 0,
    saves BIGINT DEFAULT 0,
    engagement_rate FLOAT DEFAULT 0.0,
    virality_score FLOAT DEFAULT 0.0,
    published_at TIMESTAMPTZ,
    ai_why_it_went_viral TEXT,
    ai_how_to_beat_it TEXT,
    discovered_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(target_account_id, video_url)
);

CREATE INDEX IF NOT EXISTS idx_autonomous_competitors_target ON autonomous_competitors(target_account_id, virality_score DESC);

-- ============================================================================
-- 7. HASHTAG PERFORMANS MATRİSİ TABLOSU
-- ============================================================================
CREATE TABLE IF NOT EXISTS hashtag_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    hashtag VARCHAR(100) NOT NULL,
    usage_count INT DEFAULT 1,
    avg_views_when_used BIGINT DEFAULT 0,
    avg_engagement_rate FLOAT DEFAULT 0.0,
    avg_saves_rate FLOAT DEFAULT 0.0,
    lift_multiplier FLOAT DEFAULT 1.0, -- Bu etiket kullanıldığında izlenme kanal ortalamasının kaç katı oluyor
    status_category VARCHAR(20) DEFAULT 'neutral' CHECK (status_category IN ('booster', 'neutral', 'drag')),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(account_id, hashtag)
);

CREATE INDEX IF NOT EXISTS idx_hashtag_analytics_account_lift ON hashtag_analytics(account_id, lift_multiplier DESC);

-- ============================================================================
-- 8. YAPAY ZEKA STRATEJİ VE FİKİR RAPORLARI TABLOSU
-- ============================================================================
CREATE TABLE IF NOT EXISTS ai_strategy_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID REFERENCES accounts(id) ON DELETE CASCADE, -- NULL ise 15 hesabın Toplu Master Özeti
    report_type VARCHAR(30) NOT NULL CHECK (report_type IN ('master_briefing', 'account_deep_strategy')),
    executive_summary TEXT NOT NULL,
    competitor_gap_summary TEXT,
    optimal_posting_windows JSONB DEFAULT '[]'::jsonb,
    recommended_hashtags JSONB DEFAULT '{}'::jsonb,
    next_5_video_blueprints JSONB DEFAULT '[]'::jsonb,
    raw_ai_payload JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_strategy_reports_account ON ai_strategy_reports(account_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_strategy_reports_type ON ai_strategy_reports(report_type, created_at DESC);

-- ============================================================================
-- 9. OTOMATİK ZAMAN DAMGASI TETİKLEYİCİLERİ (TRIGGERS)
-- ============================================================================
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_accounts_updated_at ON accounts;
CREATE TRIGGER trg_accounts_updated_at
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

-- ============================================================================
-- 10. ANALİTİK GÖRÜNÜMLER (VIEWS - Hızlı Portföy Özeti ve Kanal Ortalamaları)
-- ============================================================================

-- 10.1. Tüm Aktif Hesapların Toplu Portföy Özeti Görünümü
CREATE OR REPLACE VIEW vw_portfolio_master_summary AS
SELECT
    COUNT(id) AS active_account_count,
    COALESCE(SUM(current_followers), 0) AS portfolio_total_followers,
    COALESCE(SUM(current_total_views), 0) AS portfolio_total_views,
    ROUND(COALESCE(AVG(current_engagement_rate), 0.0)::numeric, 2) AS portfolio_avg_engagement_rate,
    ROUND(COALESCE(AVG(current_virality_score), 0.0)::numeric, 1) AS portfolio_avg_virality_score,
    ROUND(COALESCE(AVG(follower_growth_7d), 0.0)::numeric, 2) AS portfolio_avg_follower_growth_7d,
    ROUND(COALESCE(AVG(views_growth_7d), 0.0)::numeric, 2) AS portfolio_avg_views_growth_7d,
    COUNT(CASE WHEN health_status IN ('surging', 'growing') THEN 1 END) AS growing_accounts_count,
    COUNT(CASE WHEN health_status IN ('declining', 'anomaly_drop') THEN 1 END) AS declining_accounts_count,
    MAX(last_synced_at) AS last_portfolio_sync
FROM accounts
WHERE is_active = TRUE;

-- 10.2. Video Röntgen Ekranı İçin Kanal Bazlı Ortalama Metrikler Görünümü
CREATE OR REPLACE VIEW vw_account_video_benchmarks AS
SELECT
    account_id,
    COUNT(id) AS analyzed_video_count,
    COALESCE(AVG(views), 0)::BIGINT AS avg_views,
    COALESCE(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY views), 0)::BIGINT AS median_views,
    COALESCE(AVG(likes), 0)::BIGINT AS avg_likes,
    COALESCE(AVG(comments), 0)::BIGINT AS avg_comments,
    COALESCE(AVG(shares), 0)::BIGINT AS avg_shares,
    COALESCE(AVG(saves), 0)::BIGINT AS avg_saves,
    ROUND(COALESCE(AVG(duration_seconds), 0)::numeric, 1) AS avg_duration_seconds,
    ROUND(COALESCE(AVG(CASE WHEN performance_tier IN ('viral_hit', 'above_average') THEN duration_seconds END), AVG(duration_seconds), 0)::numeric, 1) AS winning_duration_seconds,
    ROUND(COALESCE(AVG(engagement_rate), 0.0)::numeric, 2) AS avg_engagement_rate,
    ROUND(COALESCE(AVG(virality_score), 0.0)::numeric, 1) AS avg_virality_score
FROM videos
GROUP BY account_id;

-- ============================================================================
-- 11. ROW LEVEL SECURITY (RLS) VE ERİŞİM POLİTİKALARI
-- (Anon Key / Service Role ile Mobil & Masaüstü Uygulamadan Doğrudan Çalışma)
-- ============================================================================
ALTER TABLE sync_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE autonomous_competitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE hashtag_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_strategy_reports ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'sync_jobs',
        'accounts',
        'account_snapshots',
        'videos',
        'video_snapshots',
        'autonomous_competitors',
        'hashtag_analytics',
        'ai_strategy_reports'
    ]
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "allow_full_access_%I" ON %I;', tbl, tbl);
        EXECUTE format(
            'CREATE POLICY "allow_full_access_%I" ON %I FOR ALL USING (true) WITH CHECK (true);',
            tbl, tbl
        );
    END LOOP;
END
$$;

-- ============================================================================
-- 12. CANLI SENKRONİZASYON (SUPABASE REALTIME) YAYININI AÇMA
-- ============================================================================
ALTER TABLE sync_jobs REPLICA IDENTITY FULL;
ALTER TABLE accounts REPLICA IDENTITY FULL;
ALTER TABLE videos REPLICA IDENTITY FULL;
ALTER TABLE ai_strategy_reports REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'sync_jobs'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE sync_jobs;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'accounts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE accounts;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'videos'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE videos;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'ai_strategy_reports'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE ai_strategy_reports;
    END IF;
END
$$;