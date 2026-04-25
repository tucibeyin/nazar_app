# Nazar & Ferahlama — CLAUDE.md

## Proje Özeti

Flutter mobil uygulama + FastAPI backend. Kamera ile fotoğraf çeker, SHA-256 hash üretir, backend'den Kuran ayeti alır, sesli okur.

## Klasör Yapısı

```
nazar_app/
├── main.py                  # FastAPI backend
├── build_db.py              # quran_data.json üretici
├── requirements.txt         # Python bağımlılıkları
├── tests/                   # Backend pytest testleri
├── .github/workflows/       # CI/CD pipeline
└── mobile/
    └── lib/
        ├── config/          # app_constants.dart, theme.dart, api_config.dart
        ├── core/            # logger.dart
        ├── models/          # ayet.dart
        ├── providers/       # service_providers.dart (Riverpod)
        ├── screens/         # home_screen.dart (UI orchestration)
        ├── services/        # api_service.dart, audio_service.dart
        ├── utils/           # hash_util.dart
        └── widgets/
            ├── painters/    # Tüm CustomPainter sınıfları
            ├── camera_frame_widget.dart
            ├── result_panel_widget.dart
            ├── tesbih_widget.dart
            └── analyzing_indicator.dart
```

## Renk Paleti (Topkapı El Yazması)

`lib/config/app_constants.dart` dosyasında tanımlı:
- `kBg` (0xFFF3E8CE) — parşömen sarısı
- `kGreen` (0xFF1B4B3E) — zümrüt yeşili
- `kGold` (0xFFC9A84C) — Osmanlı altını
- `kIndigo` (0xFF1A3A5C) — lapis lazuli

## Mimari Kurallar

- **Servis katmanı** (`services/`): Tüm I/O (HTTP, ses) buraya. Widget bağımlılığı yok.
- **Provider** (`providers/`): Riverpod ile DI. `ref.read(apiServiceProvider)` ile erişim.
- **Painter** (`widgets/painters/`): Sadece çizim mantığı. Hiçbir iş mantığı içermez.
- **Widget** (`widgets/`): Saf görsel bileşen. State taşımaz.
- **Screen** (`screens/`): State yönetimi burada. Servisler `ref.read()` ile çekilir.

## Analiz Akışı

```
camera → (shutter flash) → analyzing → (hash + API fetch) → playing → camera
```

`AppViewState` enum: `camera | analyzing | playing`

## Önemli Notlar

- `Ayet.fromJson`: tam tip güvenceli (is num / is String kontrolleri)
- `ApiService`: 3 deneme, exponential backoff, kullanıcı dostu hata mesajları
- `HashUtil.fromBytes`: SHA-256 → ilk 8 bayt → int64 → abs()
- deploy.sh: credentials **asla** kodda olmaz, env var kullanılır

## Gizli Ayarlar (dart-define)

API key ve base URL `--dart-define-from-file` ile enjekte edilir:

```
mobile/dart_defines.json        ← git-ignored, gerçek değerler
mobile/dart_defines.example.json ← şablon, repo'da
```

İlk kurulum:
```bash
cp mobile/dart_defines.example.json mobile/dart_defines.json
# dart_defines.json içine API_KEY değerini gir
```

## Komutlar

```bash
# Backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
pytest tests/ -v

# Flutter — Makefile kısayolları (proje kökünden)
make run           # debug
make run-profile   # profiling
make build-apk     # Android release
make build-ipa     # iOS release
make clean         # flutter clean + pub get
make test          # flutter test
make analyze       # flutter analyze

# Flutter — doğrudan (mobile/ içinden)
flutter run --dart-define-from-file=dart_defines.json
flutter build ipa --release --dart-define-from-file=dart_defines.json
./deploy.sh <build_no>   # APPLE_ID ve APP_SPECIFIC_PASS env var gerekli
```
