"""
Nazar API endpoint testleri.
Çalıştırmak için:  cd /path/to/nazar_app && pytest tests/ -v
"""
import json
import os
import sys
from pathlib import Path
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

# quran_data.json'un var olduğunu simüle etmek için mock veri
MOCK_AYETLER = [
    {"id": 1, "sure_isim": "Al-Fatiha", "arapca": "بسم", "meal": "Bismillah", "mp3_url": "/audio/001001.mp3"},
    {"id": 2, "sure_isim": "Al-Baqara", "arapca": "الم", "meal": "Elif Lam Mim", "mp3_url": "/audio/002001.mp3"},
    {"id": 3, "sure_isim": "Al-Baqara", "arapca": "ذلك", "meal": "İşte o kitap", "mp3_url": "/audio/002002.mp3"},
]


@pytest.fixture
def client():
    """Test istemcisi — gerçek quran_data.json yerine mock veri kullanır."""
    with (
        patch("builtins.open"),
        patch("pathlib.Path.exists", return_value=True),
        patch("json.load", return_value=MOCK_AYETLER),
    ):
        # main modülünü yeniden yükle (mock veriyle)
        if "main" in sys.modules:
            del sys.modules["main"]

        sys.path.insert(0, str(Path(__file__).parent.parent))

        # ALLOWED_ORIGINS'i test için genişlet
        os.environ.setdefault("ALLOWED_ORIGINS", "http://testclient")

        import main as app_module  # noqa: PLC0415

        app_module.AYETLER = MOCK_AYETLER
        return TestClient(app_module.app)


class TestHealthEndpoint:
    def test_health_returns_ok(self, client):
        r = client.get("/health")
        assert r.status_code == 200
        data = r.json()
        assert data["status"] == "ok"
        assert data["ayet_count"] == len(MOCK_AYETLER)

    def test_health_version_present(self, client):
        r = client.get("/health")
        assert "version" in r.json()


class TestNazarEndpoint:
    def test_hash_0_returns_first_ayet(self, client):
        r = client.get("/api/nazar/0")
        assert r.status_code == 200
        assert r.json()["id"] == MOCK_AYETLER[0]["id"]

    def test_modulo_wraps_correctly(self, client):
        count = len(MOCK_AYETLER)
        r = client.get(f"/api/nazar/{count}")
        assert r.status_code == 200
        assert r.json()["id"] == MOCK_AYETLER[0]["id"]

    def test_large_hash_does_not_crash(self, client):
        r = client.get("/api/nazar/9999999999")
        assert r.status_code == 200

    def test_response_has_required_fields(self, client):
        r = client.get("/api/nazar/1")
        assert r.status_code == 200
        data = r.json()
        for field in ("id", "sure_isim", "arapca", "meal", "mp3_url"):
            assert field in data, f"Eksik alan: {field}"

    def test_negative_hash_returns_422(self, client):
        r = client.get("/api/nazar/-1")
        assert r.status_code == 422

    def test_string_hash_returns_422(self, client):
        r = client.get("/api/nazar/abc")
        assert r.status_code == 422
