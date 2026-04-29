#!/usr/bin/env bash
# VPS'te sıfır-kesinti backend deployment — health check + otomatik rollback
#
# Kullanım (local makineden):
#   ssh user@vps "cd /var/www/nazar_app && bash infra/deploy.sh"
#
# Ön koşullar (ilk kurulum için infra/setup.sh çalıştır):
#   - /var/www/nazar_app dizininde git repo klonlanmış
#   - /var/www/nazar_app/venv Python sanal ortamı oluşturulmuş
#   - /var/www/nazar_app/.env dosyası doldurulmuş
#   - nazar.service systemd'ye kurulmuş
set -euo pipefail

APP_DIR=/var/www/nazar_app
SERVICE=nazar
HEALTH_URL=http://127.0.0.1:8014/health
HEALTH_RETRIES=6
HEALTH_WAIT=5

cd "$APP_DIR"

# ─── Mevcut commit'i kaydet (rollback için) ───────────────────────────────────
PREV_COMMIT=$(git rev-parse HEAD)
echo "▸ Mevcut sürüm: $PREV_COMMIT"

# ─── [1/4] Kod güncelleniyor ─────────────────────────────────────────────────
echo "▸ [1/4] Kod güncelleniyor..."
git pull origin main
NEW_COMMIT=$(git rev-parse HEAD)
echo "  → Yeni sürüm: $NEW_COMMIT"

if [ "$PREV_COMMIT" = "$NEW_COMMIT" ]; then
  echo "  → Zaten güncel, deploy atlanıyor."
  exit 0
fi

# ─── [2/4] Bağımlılıklar ─────────────────────────────────────────────────────
echo "▸ [2/4] Bağımlılıklar kuruluyor..."
source venv/bin/activate
pip install -r requirements.txt --quiet

# ─── [3/4] Sıfır-kesinti yeniden yükleme ─────────────────────────────────────
echo "▸ [3/4] Sıfır-kesinti yeniden yükleme (SIGHUP → graceful restart)..."
sudo systemctl reload "$SERVICE"

# ─── [4/4] Health check ───────────────────────────────────────────────────────
echo "▸ [4/4] Health check ($HEALTH_RETRIES deneme × ${HEALTH_WAIT}s)..."
for i in $(seq 1 "$HEALTH_RETRIES"); do
  sleep "$HEALTH_WAIT"
  if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
    echo "  ✓ Health check başarılı (deneme $i)"
    break
  fi
  echo "  ✗ Deneme $i/$HEALTH_RETRIES başarısız..."
  if [ "$i" -eq "$HEALTH_RETRIES" ]; then
    echo ""
    echo "✗ Health check $HEALTH_RETRIES denemede başarısız — rollback başlıyor..."
    git reset --hard "$PREV_COMMIT"
    pip install -r requirements.txt --quiet
    sudo systemctl reload "$SERVICE"
    echo "✗ Rollback tamamlandı: $PREV_COMMIT"
    echo "  Servisi kontrol et: sudo systemctl status $SERVICE"
    exit 1
  fi
done

echo ""
echo "✓ Deploy tamamlandı: $NEW_COMMIT ($(date))"
sudo systemctl status "$SERVICE" --no-pager -l | head -10
