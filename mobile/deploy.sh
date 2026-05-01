#!/usr/bin/env bash
# iOS build + TestFlight upload
#
# Gerekli environment variables:
#   APPLE_ID          — Apple kimlik e-postası
#   APP_SPECIFIC_PASS — App-specific password (appleid.apple.com)
#
# Örnek kullanım:
#   APPLE_ID=you@email.com APP_SPECIFIC_PASS=xxxx-xxxx-xxxx-xxxx ./deploy.sh 15

set -euo pipefail

# ── Ön kontroller ─────────────────────────────────────────────────────────────

BUILD_NO=${1:-}
if [ -z "$BUILD_NO" ]; then
  echo "HATA: Build numarası gerekli."
  echo "Kullanım: ./deploy.sh <build_no>"
  exit 1
fi

if [ -z "${APPLE_ID:-}" ] || [ -z "${APP_SPECIFIC_PASS:-}" ]; then
  echo "HATA: APPLE_ID ve APP_SPECIFIC_PASS set edilmemiş."
  echo "Örnek: APPLE_ID=you@email.com APP_SPECIFIC_PASS=xxxx-xxxx-xxxx-xxxx ./deploy.sh $BUILD_NO"
  exit 1
fi

if [ ! -f dart_defines.json ]; then
  echo "HATA: dart_defines.json bulunamadı."
  echo "  cp dart_defines.example.json dart_defines.json"
  echo "  # dart_defines.json içine API_KEY değerini gir"
  exit 1
fi

DEFINES="--dart-define-from-file=dart_defines.json"
SYMBOLS_DIR="build/app/outputs/symbols"
VERSION="1.0.1+$BUILD_NO"

echo "▸ Versiyon $VERSION ayarlanıyor..."
sed -i '' -E "s/^version: .*/version: $VERSION/" pubspec.yaml

# ── [1/5] Kalite kontrol ──────────────────────────────────────────────────────

echo "▸ [1/5] Otomatik düzeltmeler ve kod analizi..."
dart fix --apply
flutter analyze --no-fatal-infos

# ── [2/5] Cache temizliği ─────────────────────────────────────────────────────

echo "▸ [2/5] Cache temizleniyor..."
flutter clean
flutter pub get

# ── [3/5] Release build ───────────────────────────────────────────────────────

echo "▸ [3/5] Release build (obfuscated)..."
flutter build ipa --release \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  --export-method app-store \
  $DEFINES

# ── [4/5] Sembol arşivi ───────────────────────────────────────────────────────

echo "▸ [4/5] Debug sembolleri arşivleniyor..."
SYMBOLS_ARCHIVE="symbols_${VERSION}_$(date +%Y%m%d_%H%M).zip"
zip -r "$SYMBOLS_ARCHIVE" "$SYMBOLS_DIR"
echo "  → $SYMBOLS_ARCHIVE — sakla, crash stack trace çözümlemesi için gerekli"

# ── [5/5] TestFlight upload ───────────────────────────────────────────────────

echo "▸ [5/5] Apple sunucularına gönderiliyor..."
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/*.ipa \
  -u "$APPLE_ID" \
  -p "$APP_SPECIFIC_PASS"

echo ""
echo "✓ Build $BUILD_NO TestFlight'a gönderildi. ($(date))"
