#!/usr/bin/env bash
# VPS ilk kurulum scripti — bir kez çalıştırılır.
#
# Kullanım: ssh root@vps "bash -s" < infra/setup.sh
set -euo pipefail

APP_DIR=/var/www/nazar_app
APP_USER=tucibeyin
REPO_URL=https://github.com/tucibeyin/nazar_app.git

echo "▸ Sistem paketleri..."
apt-get update -qq
apt-get install -y python3.12 python3.12-venv nginx certbot python3-certbot-nginx git

echo "▸ Uygulama kullanıcısı oluşturuluyor..."
id "$APP_USER" &>/dev/null || useradd -r -m -d "$APP_DIR" "$APP_USER"

echo "▸ Repo klonlanıyor..."
if [ ! -d "$APP_DIR/.git" ]; then
  git clone "$REPO_URL" "$APP_DIR"
fi
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

echo "▸ Python sanal ortamı kuruluyor..."
sudo -u "$APP_USER" python3.12 -m venv "$APP_DIR/venv"
sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt" -q

echo "▸ .env dosyası oluştur (doldurman gerekiyor)..."
if [ ! -f "$APP_DIR/.env" ]; then
  cat > "$APP_DIR/.env" <<'ENVEOF'
API_KEY=BURAYA_API_KEY_GIR
ALLOWED_ORIGINS=https://nazar.aracabak.com
RATE_LIMIT=30/minute
ENVEOF
  echo "  → $APP_DIR/.env oluşturuldu. API_KEY'i doldurmayı unutma!"
fi

echo "▸ systemd servisi kuruluyor..."
cp "$APP_DIR/infra/nazar-api.service" /etc/systemd/system/nazar.service
systemctl daemon-reload
systemctl enable nazar
systemctl start nazar

echo "▸ Deploy şifresiz reload izni (sudoers)..."
echo "$APP_USER ALL=(ALL) NOPASSWD: /bin/systemctl reload nazar.service, /bin/systemctl status nazar.service" \
  > /etc/sudoers.d/nazar-deploy
chmod 440 /etc/sudoers.d/nazar-deploy

echo "▸ nginx konfigürasyonu..."
cp "$APP_DIR/infra/nginx.conf" /etc/nginx/sites-available/nazar
ln -sf /etc/nginx/sites-available/nazar /etc/nginx/sites-enabled/nazar
nginx -t
systemctl reload nginx

echo "▸ Log dizini hazırlanıyor..."
mkdir -p /var/log/nazar
chown "$APP_USER:$APP_USER" /var/log/nazar

echo "▸ Log rotation..."
cp "$APP_DIR/infra/logrotate-nazar.conf" /etc/logrotate.d/nazar

echo "▸ Disk alarm scripti..."
chmod +x "$APP_DIR/infra/disk-check.sh"
# Her saat başı tüm bölümleri kontrol et
(crontab -u "$APP_USER" -l 2>/dev/null; echo "0 * * * * $APP_DIR/infra/disk-check.sh") \
  | sort -u | crontab -u "$APP_USER" -

echo "▸ SSL sertifikası otomatik yenileme..."
# certbot systemd timer'ı Ubuntu/Debian'da otomatik kurulur; yoksa cron ekle.
if systemctl is-enabled certbot.timer &>/dev/null; then
  echo "  → certbot systemd timer aktif — ek ayar gerekmez."
else
  (crontab -l 2>/dev/null; \
   echo "0 3 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'") \
    | sort -u | crontab -
  echo "  → certbot cron eklendi (systemd timer bulunamadı)."
fi

echo ""
echo "✓ Kurulum tamamlandı!"
echo "  SSL için: certbot --nginx -d nazar.aracabak.com"
echo "  Durum:    systemctl status nazar"
