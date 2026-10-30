# OmniPulse AI

> **Bulut Tabanlı Çoklu Sosyal Medya Analitik ve Otonom Strateji Platformu** (TikTok, Instagram, YouTube)

OmniPulse AI, sosyal medya hesaplarını (TikTok, Instagram, YouTube) derinlemesine analiz eden, rakipleri otonom olarak keşfeden, virallik ve hashtag skorlaması yapan ve Google Gemini tabanlı otonom içerik stratejileri üreten tam kapsamlı bir monorepo platformudur.

---

## 🏗️ Proje Mimarisi

```
omnipulse-ai/
├── .github/workflows/          # GitHub Actions Bulut Otomasyonu
│   ├── cloud_sync_engine.yml   # Periyodik (Cron) ve Mobil Tetiklemeli Scraping/AI Motoru
│   └── build_releases.yml      # Android APK & Windows Masaüstü Derleme Pipeline'ı
├── app/                        # Flutter (Dart) Mobil & Masaüstü Uygulaması
│   ├── lib/
│   │   ├── core/               # Tema, sabitler, GitHub Actions tetikleyici
│   │   ├── models/             # Veri modelleri (Account, Video, Competitor, AI Report)
│   │   ├── providers/          # Riverpod state yönetimi & Supabase stream sağlayıcıları
│   │   ├── screens/            # Dashboard, Video Röntgeni, AI Strateji Merkezi, Hesap Yönetimi
│   │   └── widgets/            # Sparkline grafikleri, metrik rozetleri, senkronizasyon barı
│   └── pubspec.yaml            # Flutter paket ve bağımlılık tanımları
├── engine/                     # Python 3.11 Veri Çekme, Analitik & Yapay Zeka Motoru
│   ├── ai_strategist/          # Gemini API istemcisi ve otonom sistem promptları
│   ├── analytics/              # Matematiksel virallik skoru, medyan izlenme, hashtag matrisi
│   ├── scrapers/               # YouTube, TikTok, Instagram & Otonom Rakip Radarı
│   ├── config.py               # Anti-ban gecikmeleri, jitter ve ortam değişkenleri
│   ├── db_client.py            # Supabase PostgreSQL istemcisi
│   ├── main.py                 # Bulut motoru orkestrasyonu
│   └── requirements.txt        # Python bağımlılıkları
└── supabase/
    └── schema.sql              # PostgreSQL şeması, RLS politikaları, görünümler & Realtime
```

---

## 🚀 Başlangıç ve Kurulum

### 1. Supabase Veritabanı Kurulumu
1. [Supabase](https://supabase.com) üzerinde yeni bir proje oluşturun.
2. `supabase/schema.sql` dosyasındaki SQL komutlarını Supabase SQL Editor içerisinde çalıştırın.
3. Project Settings > API bölümünden `Project URL` ve `service_role` (veya `anon`) anahtarınızı alın.

### 2. Bulut Motoru (Python Engine)
```bash
cd engine
python -m venv .venv
# Windows:
.venv\Scripts\activate
# Linux/macOS:
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
# .env dosyasını kendi API anahtarlarınızla düzenleyin
python main.py
```

### 3. Mobil & Masaüstü Uygulaması (Flutter)
```bash
cd app
flutter pub get
flutter run
```

---

## 🔒 GitHub Actions Secrets Yapılandırması
GitHub Actions bulut senkronizasyon motorunun sorunsuz çalışması için Repository Settings > Secrets and variables > Actions kısmına şu gizli anahtarları ekleyin:
- `SUPABASE_URL`: Supabase proje bağlantı adresi
- `SUPABASE_SERVICE_ROLE_KEY`: Supabase Service Role API anahtarı
- `GEMINI_API_KEY`: Google Gemini API anahtarı
- `YOUTUBE_API_KEY`: (Opsiyonel) YouTube Data API v3 anahtarı
