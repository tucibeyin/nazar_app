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

# sure_no / ayet_no alanları eklendi — _ayet_lookup bunlara ihtiyaç duyar.
MOCK_AYETLER = [
    {
        "id": 1, "sure_no": 1, "ayet_no": 1,
        "sure_isim": "Fatiha", "arapca": "بِسْمِ اللَّهِ",
        "meal": "Rahman ve Rahim olan Allah'ın adıyla",
        "mp3_url": "/audio/001001.mp3",
    },
    {
        "id": 2, "sure_no": 1, "ayet_no": 2,
        "sure_isim": "Fatiha", "arapca": "الْحَمْدُ لِلَّهِ",
        "meal": "Hamd alemlerin Rabbi Allah'a",
        "mp3_url": "/audio/001002.mp3",
    },
    {
        "id": 255, "sure_no": 2, "ayet_no": 255,
        "sure_isim": "Bakara", "arapca": "اللَّهُ لَا إِلَهَ",
        "meal": "Allah; O'ndan başka ilah yoktur",
        "mp3_url": "/audio/002255.mp3",
    },
]


def _make_client(api_key: str = "", ayetler: list = None) -> TestClient:
    """Test istemcisi — gerçek quran_data.json yerine mock veri kullanır."""
    data = ayetler if ayetler is not None else MOCK_AYETLER
    with (
        patch("builtins.open", create=True),
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

    def test_health_has_request_id_header(self, client: TestClient) -> None:
        r = client.get("/health")
        assert "x-request-id" in r.headers

    def test_health_accessible_without_api_key(self, client_with_key: TestClient) -> None:
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

    def test_response_has_cache_control(self, client: TestClient) -> None:
        r = client.get("/api/nazar/0")
        assert "public" in r.headers.get("cache-control", "")

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


# ─── Hatim Endpoint ───────────────────────────────────────────────────────────

class TestHatimEndpoint:
    def test_returns_index_and_total(self, client: TestClient) -> None:
        r = client.get("/api/hatim/0")
        assert r.status_code == 200
        data = r.json()
        assert data["index"] == 0
        assert data["total"] == len(MOCK_AYETLER)

    def test_modulo_wraps(self, client: TestClient) -> None:
        r = client.get(f"/api/hatim/{len(MOCK_AYETLER)}")
        assert r.json()["index"] == 0

    def test_negative_returns_422(self, client: TestClient) -> None:
        assert client.get("/api/hatim/-1").status_code == 422

    def test_cache_control_present(self, client: TestClient) -> None:
        r = client.get("/api/hatim/0")
        assert "public" in r.headers.get("cache-control", "")


# ─── Packages Endpoint ────────────────────────────────────────────────────────

class TestPackagesEndpoint:
    def test_returns_list(self, client: TestClient) -> None:
        r = client.get("/api/packages")
        assert r.status_code == 200
        assert isinstance(r.json(), list)
        assert len(r.json()) > 0

    def test_package_has_required_fields(self, client: TestClient) -> None:
        data = client.get("/api/packages").json()[0]
        for field in ("id", "isim", "aciklama", "icon", "ayet_sayisi"):
            assert field in data, f"Eksik alan: {field}"

    def test_cache_control_present(self, client: TestClient) -> None:
        r = client.get("/api/packages")
        assert "public" in r.headers.get("cache-control", "")

    def test_known_package_detail(self, client: TestClient) -> None:
        r = client.get("/api/packages/fatiha")
        assert r.status_code == 200
        data = r.json()
        assert data["id"] == "fatiha"
        assert "ayetler" in data

    def test_fatiha_ayetler_from_mock(self, client: TestClient) -> None:
        # MOCK_AYETLER'de (1,1) ve (1,2) var — fatiha paketi bunları bulmalı.
        r = client.get("/api/packages/fatiha")
        assert r.status_code == 200
        assert len(r.json()["ayetler"]) == 2

    def test_unknown_package_returns_404(self, client: TestClient) -> None:
        assert client.get("/api/packages/bilinmeyen-paket").status_code == 404

    def test_package_detail_cache_control(self, client: TestClient) -> None:
        r = client.get("/api/packages/fatiha")
        assert "public" in r.headers.get("cache-control", "")


# ─── Boş Veritabanı ───────────────────────────────────────────────────────────

class TestEmptyDatabase:
    def test_empty_db_returns_503(self) -> None:
        c = _make_client(ayetler=[])
        r = c.get("/api/nazar/0")
        assert r.status_code == 503
