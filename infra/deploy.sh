#!/usr/bin/env bash
# VPS'te sıfır-kesinti backend deployment
#
# Kullanım (local makineden):
#   ssh user@vps "cd /var/www/nazar_app && bash infra/deploy.sh"
#
# Ön koşullar (ilk kurulum için infra/setup.sh çalıştır):
#   - /var/www/nazar_app dizininde git repo klonlanmış
#   - /var/www/nazar_app/venv Python sanal ortamı oluşturulmuş
#   - /var/www/nazar_app/.env dosyası doldurulmuş
#   - nazar.service systemd'ye kurulmuş
#   - sudoers: infra/setup.sh veya aşağıdaki tek satır ile şifresiz reload izni verilmiş:
#     echo "tucibeyin ALL=(ALL) NOPASSWD: /bin/systemctl reload nazar.service, /bin/systemctl status nazar.service" | sudo tee /etc/sudoers.d/nazar-deploy
set -euo pipefail

APP_DIR=/var/www/nazar_app
SERVICE=nazar

echo "▸ [1/4] Kod güncelleniyor..."
cd "$APP_DIR"
git pull origin main

echo "▸ [2/4] Bağımlılıklar kuruluyor..."
source venv/bin/activate
pip install -r requirements.txt --quiet

echo "▸ [3/4] Sıfır-kesinti yeniden yükleme (SIGHUP → graceful restart)..."
# Gunicorn SIGHUP aldığında yeni worker'lar spawn edilir,
# eskiler mevcut istekleri tamamladıktan sonra kapanır.
sudo systemctl reload "$SERVICE"

echo "▸ [4/4] Servis durumu:"
sudo systemctl status "$SERVICE" --no-pager -l | head -15

echo ""
echo "✓ Deploy tamamlandı: $(date)"
