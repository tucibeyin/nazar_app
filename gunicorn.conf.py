"""Gunicorn production configuration for Nazar API."""

import multiprocessing

# 2 × CPU çekirdek + 1 — tipik VPS için uygun kural; 9'da kırp.
workers = min(multiprocessing.cpu_count() * 2 + 1, 9)
worker_class = "uvicorn.workers.UvicornWorker"

bind = "127.0.0.1:8014"
timeout = 30
keepalive = 5

# Her worker N istek sonra yeniden başlar — uzun süreli bellek sızıntılarını engeller.
max_requests = 1000
max_requests_jitter = 100  # thundering herd'i önlemek için rastgele offset

# nginx X-Forwarded-For gönderdiğinden güvenilir kabul et (aynı makinede).
forwarded_allow_ips = "*"

# Uygulama fork öncesi yükle — CoW sayesinde worker başına bellek tasarrufu.
preload_app = True

accesslog = "-"
errorlog = "-"
loglevel = "info"
