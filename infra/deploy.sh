#!/usr/bin/env bash
# VPS'te sıfır-kesinti backend deployment
#
# Kullanım (local makineden):
#   ssh user@vps "cd /opt/nazar && bash infra/deploy.sh"
#
# Ön koşullar (ilk kurulum için infra/setup.sh çalıştır):
#   - /opt/nazar dizininde git repo klonlanmış
#   - /opt/nazar/venv Python sanal ortamı oluşturulmuş
#   - /opt/nazar/.env dosyası doldurulmuş
#   - nazar-api.service systemd'ye kurulmuş
set -euo pipefail

APP_DIR=/opt/nazar
SERVICE=nazar-api

echo "▸ [1/4] Kod güncelleniyor..."
cd "$APP_DIR"
git pull origin main

echo "▸ [2/4] Bağımlılıklar kuruluyor..."
source venv/bin/activate
pip install -r requirements.txt --quiet

echo "▸ [3/4] Sıfır-kesinti yeniden yükleme (SIGHUP → graceful restart)..."
# Gunicorn SIGHUP aldığında yeni worker'lar spawn edilir,
# eskiler mevcut istekleri tamamladıktan sonra kapanır.
systemctl reload "$SERVICE"

echo "▸ [4/4] Servis durumu:"
systemctl status "$SERVICE" --no-pager -l | head -15

echo ""
echo "✓ Deploy tamamlandı: $(date)"
