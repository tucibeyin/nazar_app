#!/usr/bin/env bash
# Disk kullanımı eşiği aşarsa syslog'a uyarı yazar.
#
# Cron (setup.sh tarafından eklenir — her saat başı çalışır):
#   0 * * * * /var/www/nazar_app/infra/disk-check.sh
set -euo pipefail

THRESHOLD=85

while IFS= read -r line; do
    usage=$(echo "$line" | awk '{gsub(/%/,"",$5); print $5}')
    mount=$(echo "$line" | awk '{print $6}')

    if [ -n "$usage" ] && [ "$usage" -ge "$THRESHOLD" ]; then
        logger -t nazar-disk-alarm \
            "UYARI: Disk %${usage} dolu — eşik %${THRESHOLD} (bölüm: ${mount})"
    fi
done < <(df -P | awk 'NR>1 && $5 ~ /[0-9]/ {print}')
