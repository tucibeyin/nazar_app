"""
Nazar API endpoint testleri.
Çalıştırmak için:  cd /path/to/nazar_app && pytest tests/ -v
"""
import os
import sys
from pathlib import Path
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

MOCK_AYETLER = [
    {"id": 0, "sure_isim": "Al-Fatiha 1", "arapca": "بسم", "meal": "Bismillah", "mp3_url": "/audio/001001.mp3"},
    {"id": 1, "sure_isim": "Al-Baqara 1", "arapca": "الم", "meal": "Elif Lam Mim", "mp3_url": "/audio/002001.mp3"},
    {"id": 2, "sure_isim": "Al-Baqara 2", "arapca": "ذلك", "meal": "İşte o kitap", "mp3_url": "/audio/002002.mp3"},
]


def _make_client(api_key: str = "", ayetler: list = None) -> TestClient:
    """Test istemcisi — gerçek quran_data.json yerine mock veri kullanır."""
    data = ayetler if ayetler is not None else MOCK_AYETLER
    with (
        patch("builtins.open"),
        patch("pathlib.Path.exists", return_value=True),
        patch("json.load", return_value=data),
    ):
        if "main" in sys.modules:
            del sys.modules["main"]

        sys.path.insert(0, str(Path(__file__).parent.parent))
        os.environ.setdefault("ALLOWED_ORIGINS", "http://testclient")

        if api_key:
            os.environ["API_KEY"] = api_key
        else:
            os.environ.pop("API_KEY", None)

        import main as app_module  # noqa: PLC0415

        app_module.AYETLER = data
        return TestClient(app_module.app)


@pytest.fixture
def client() -> TestClient:
    return _make_client()


@pytest.fixture
def client_with_key() -> TestClient:
    return _make_client(api_key="test-secret-key")


# ─── Health ───────────────────────────────────────────────────────────────────

class TestHealthEndpoint:
    def test_health_returns_ok(self, client: TestClient) -> None:
        r = client.get("/health")
        assert r.status_code == 200
        assert r.json()["status"] == "ok"
        assert r.json()["ayet_count"] == len(MOCK_AYETLER)

    def test_health_version_present(self, client: TestClient) -> None:
        assert "version" in client.get("/health").json()

    def test_health_has_timing_header(self, client: TestClient) -> None:
        r = client.get("/health")
        assert "x-response-time" in r.headers

    def test_health_accessible_without_api_key(self, client_with_key: TestClient) -> None:
        """Sağlık endpoint'i API key olmadan erişilebilir olmalı."""
        r = client_with_key.get("/health")
        assert r.status_code == 200


# ─── API Key Auth ─────────────────────────────────────────────────────────────

class TestApiKeyAuth:
    def test_missing_api_key_returns_401(self, client_with_key: TestClient) -> None:
        r = client_with_key.get("/api/nazar/0")
        assert r.status_code == 401

    def test_wrong_api_key_returns_401(self, client_with_key: TestClient) -> None:
        r = client_with_key.get("/api/nazar/0", headers={"X-API-Key": "yanlis-key"})
        assert r.status_code == 401

    def test_correct_api_key_returns_200(self, client_with_key: TestClient) -> None:
        r = client_with_key.get("/api/nazar/0", headers={"X-API-Key": "test-secret-key"})
        assert r.status_code == 200

    def test_no_api_key_env_allows_open_access(self, client: TestClient) -> None:
        """API_KEY env boşken endpoint herkese açık."""
        r = client.get("/api/nazar/0")
        assert r.status_code == 200


# ─── Nazar Endpoint ───────────────────────────────────────────────────────────

class TestNazarEndpoint:
    def test_hash_0_returns_first_ayet(self, client: TestClient) -> None:
        r = client.get("/api/nazar/0")
        assert r.status_code == 200
        assert r.json()["id"] == MOCK_AYETLER[0]["id"]

    def test_modulo_wraps_correctly(self, client: TestClient) -> None:
        count = len(MOCK_AYETLER)
        r = client.get(f"/api/nazar/{count}")
        assert r.status_code == 200
        assert r.json()["id"] == MOCK_AYETLER[0]["id"]

    def test_large_hash_does_not_crash(self, client: TestClient) -> None:
        assert client.get("/api/nazar/9999999999").status_code == 200

    def test_response_has_required_fields(self, client: TestClient) -> None:
        data = client.get("/api/nazar/1").json()
        for field in ("id", "sure_isim", "arapca", "meal", "mp3_url"):
            assert field in data, f"Eksik alan: {field}"

    def test_negative_hash_returns_422(self, client: TestClient) -> None:
        assert client.get("/api/nazar/-1").status_code == 422

    def test_string_hash_returns_422(self, client: TestClient) -> None:
        assert client.get("/api/nazar/abc").status_code == 422

    def test_response_has_timing_header(self, client: TestClient) -> None:
        r = client.get("/api/nazar/0")
        assert "x-response-time" in r.headers

    def test_mp3_url_not_empty(self, client: TestClient) -> None:
        data = client.get("/api/nazar/0").json()
        assert data["mp3_url"], "mp3_url boş olmamalı"

    def test_boundary_max_int(self, client: TestClient) -> None:
        r = client.get("/api/nazar/9223372036854775807")
        assert r.status_code == 200

    def test_each_ayet_reachable(self, client: TestClient) -> None:
        ids_seen = set()
        for i in range(len(MOCK_AYETLER)):
            data = client.get(f"/api/nazar/{i}").json()
            ids_seen.add(data["id"])
        assert ids_seen == {a["id"] for a in MOCK_AYETLER}


# ─── Boş Veritabanı ───────────────────────────────────────────────────────────

class TestEmptyDatabase:
    def test_empty_db_returns_503(self) -> None:
        c = _make_client(ayetler=[])
        r = c.get("/api/nazar/0")
        assert r.status_code == 503
