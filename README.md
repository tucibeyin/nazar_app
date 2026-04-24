# Nazar & Ferahlama

Kamera ile yüz analizi yapan, SHA-256 hash üzerinden Kuran ayeti seçen ve sesli okuyan Flutter mobil uygulaması.

## Kurulum

### Backend

```bash
cp .env.example .env       # ortam değişkenlerini düzenle
pip install -r requirements.txt
python build_db.py         # quran_data.json üret (bir kez)
uvicorn main:app --host 0.0.0.0 --port 8000
```

### Mobil

```bash
cd mobile
flutter pub get
flutter run
```

## Testler

```bash
# Backend
pytest tests/ -v

# Flutter
cd mobile && flutter test
```

## Deploy

```bash
cd mobile
APPLE_ID=... APP_SPECIFIC_PASS=... ./deploy.sh <build_no>
```

## Mimari

```
Kamera → SHA-256 Hash → FastAPI → Ayet → Ses Oynatıcı
```

Detaylı mimari dokümantasyon için [CLAUDE.md](CLAUDE.md) dosyasına bakın.
