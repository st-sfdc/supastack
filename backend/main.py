import os
from contextlib import asynccontextmanager
from typing import Optional

import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "")


def get_conn():
    return psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        conn = get_conn()
        conn.close()
        print("Database connection OK")
    except Exception as e:
        print(f"WARNING: Database connection failed on startup: {e}")
    yield


app = FastAPI(title="SupaStack — Backend API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class ItemIn(BaseModel):
    key: str
    value: str


class ItemPatch(BaseModel):
    key: Optional[str] = None
    value: Optional[str] = None




# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health", tags=["Health"])
def health():
    """Check API and database connectivity."""
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return {"status": "ok", "database": "reachable"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database unreachable: {e}")


# ---------------------------------------------------------------------------
# Key-Value Items
# ---------------------------------------------------------------------------

@app.get("/items", tags=["Items"])
def list_items():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, key, value, created_at FROM key_value_items ORDER BY id ASC")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows


@app.get("/items/{item_id}", tags=["Items"])
def get_item(item_id: int):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, key, value, created_at FROM key_value_items WHERE id = %s", (item_id,))
    row = cur.fetchone()
    cur.close()
    conn.close()
    if row is None:
        raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
    return row


@app.post("/items", status_code=201, tags=["Items"])
def create_item(item: ItemIn):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO key_value_items (key, value) VALUES (%s, %s) RETURNING id, key, value, created_at",
        (item.key, item.value),
    )
    new_row = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    return new_row


@app.patch("/items/{item_id}", tags=["Items"])
def update_item(item_id: int, patch: ItemPatch):
    if patch.key is None and patch.value is None:
        raise HTTPException(status_code=400, detail="Provide at least one of: key, value")
    conn = get_conn()
    cur = conn.cursor()
    fields, params = [], []
    if patch.key is not None:
        fields.append("key = %s")
        params.append(patch.key)
    if patch.value is not None:
        fields.append("value = %s")
        params.append(patch.value)
    params.append(item_id)
    cur.execute(
        f"UPDATE key_value_items SET {', '.join(fields)} WHERE id = %s RETURNING id, key, value, created_at",
        params,
    )
    updated = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    if updated is None:
        raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
    return updated


@app.delete("/items/{item_id}", tags=["Items"])
def delete_item(item_id: int):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "DELETE FROM key_value_items WHERE id = %s RETURNING id, key, value",
        (item_id,),
    )
    deleted = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    if deleted is None:
        raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
    return deleted


