#!/bin/bash
# iOS build + TestFlight upload
# Gerekli environment variables:
#   APPLE_ID            — Apple kimlik e-postası
#   APP_SPECIFIC_PASS   — App-specific password (appleid.apple.com'dan üret)
#
# Örnek kullanım:
#   APPLE_ID=you@email.com APP_SPECIFIC_PASS=xxxx-xxxx-xxxx-xxxx ./deploy.sh 5

BUILD_NO=$1
if [ -z "$BUILD_NO" ]; then
  echo "HATA: Build numarası gerekli"
  echo "Kullanım: ./deploy.sh <build_no>"
  exit 1
fi

if [ -z "$APPLE_ID" ] || [ -z "$APP_SPECIFIC_PASS" ]; then
  echo "HATA: APPLE_ID ve APP_SPECIFIC_PASS environment variable'ları set edilmemiş."
  echo "Örnek: APPLE_ID=you@email.com APP_SPECIFIC_PASS=xxxx-xxxx-xxxx-xxxx ./deploy.sh $BUILD_NO"
  exit 1
fi

echo "Versiyon 1.0.1+$BUILD_NO ayarlanıyor..."
sed -i '' -E "s/^version: .*/version: 1.0.1+$BUILD_NO/" pubspec.yaml

echo "Temizlik ve derleme başlıyor..."
flutter clean
flutter pub get
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --export-method app-store

echo "Apple sunucularına gönderiliyor..."
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/*.ipa \
  -u "$APPLE_ID" \
  -p "$APP_SPECIFIC_PASS"

echo "Başarılı! Build $BUILD_NO TestFlight'a gönderildi."
