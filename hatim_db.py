"""Sosyal hatim halkaları — SQLite veritabanı katmanı."""

import random
import string
from pathlib import Path

import aiosqlite

DB_PATH = Path(__file__).parent / "hatim.db"

_CHARSET = string.ascii_uppercase + string.digits


async def init_db() -> None:
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            """
            CREATE TABLE IF NOT EXISTS rooms (
                code       TEXT PRIMARY KEY,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
            """
        )
        await db.execute(
            """
            CREATE TABLE IF NOT EXISTS juzler (
                room_code TEXT    NOT NULL REFERENCES rooms(code) ON DELETE CASCADE,
                juz_num   INTEGER NOT NULL CHECK(juz_num BETWEEN 1 AND 30),
                durum     TEXT    NOT NULL DEFAULT 'bos'
                          CHECK(durum IN ('bos', 'alindi', 'okundu')),
                PRIMARY KEY (room_code, juz_num)
            )
            """
        )
        await db.commit()


def _gen_code() -> str:
    return "".join(random.choices(_CHARSET, k=6))


async def create_room() -> dict:
    """Yeni oda + 30 cüz kaydı oluşturur; oda dict'ini döner."""
    async with aiosqlite.connect(DB_PATH) as db:
        for _ in range(10):
            code = _gen_code()
            try:
                await db.execute("INSERT INTO rooms (code) VALUES (?)", (code,))
                await db.executemany(
                    "INSERT INTO juzler (room_code, juz_num) VALUES (?, ?)",
                    [(code, n) for n in range(1, 31)],
                )
                await db.commit()
                return await _fetch_room(db, code)  # type: ignore[return-value]
            except aiosqlite.IntegrityError:
                await db.rollback()
    raise RuntimeError("Oda kodu 10 denemede üretilemedi.")


async def get_room(code: str) -> dict | None:
    async with aiosqlite.connect(DB_PATH) as db:
        return await _fetch_room(db, code)


async def update_juz(room_code: str, juz_num: int, durum: str) -> bool:
    async with aiosqlite.connect(DB_PATH) as db:
        cur = await db.execute(
            "UPDATE juzler SET durum = ? WHERE room_code = ? AND juz_num = ?",
            (durum, room_code, juz_num),
        )
        await db.commit()
        return cur.rowcount > 0


async def _fetch_room(db: aiosqlite.Connection, code: str) -> dict | None:
    async with db.execute(
        "SELECT code, created_at FROM rooms WHERE code = ?", (code,)
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        return None
    async with db.execute(
        "SELECT juz_num, durum FROM juzler WHERE room_code = ? ORDER BY juz_num",
        (code,),
    ) as cur:
        juz_rows = await cur.fetchall()
    return {
        "code": row[0],
        "created_at": row[1],
        "juzler": [{"juz_num": r[0], "durum": r[1]} for r in juz_rows],
    }
