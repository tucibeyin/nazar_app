"""Nazar API — Pydantic response modelleri."""

from pydantic import BaseModel, field_validator


class AyetResponse(BaseModel):
    id: int
    sure_isim: str
    arapca: str
    meal: str
    mp3_url: str

    @field_validator("mp3_url")
    @classmethod
    def mp3_url_not_empty(cls, v: str) -> str:
        if not v:
            raise ValueError("mp3_url boş olamaz")
        return v


class HatimAyetResponse(AyetResponse):
    index: int
    total: int


class PackageResponse(BaseModel):
    id: str
    isim: str
    aciklama: str
    icon: str
    ayet_sayisi: int


class PackageDetailResponse(BaseModel):
    id: str
    isim: str
    aciklama: str
    icon: str
    ayetler: list[AyetResponse]


class HealthResponse(BaseModel):
    status: str
    ayet_count: int
    version: str
