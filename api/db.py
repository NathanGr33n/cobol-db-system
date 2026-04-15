"""Database connection pool for the COBOL-DB-SYSTEM REST API.

Uses the same PostgreSQL database as the COBOL programs, enabling
true legacy-modern coexistence.
"""

import os
from contextlib import contextmanager

import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor

_pool: pool.SimpleConnectionPool | None = None


def get_pool() -> pool.SimpleConnectionPool:
    """Return the global connection pool, creating it on first call."""
    global _pool
    if _pool is None or _pool.closed:
        _pool = pool.SimpleConnectionPool(
            minconn=1,
            maxconn=10,
            host=os.getenv("DB_HOST", "localhost"),
            port=int(os.getenv("DB_PORT", "5432")),
            dbname=os.getenv("DB_NAME", "coboldb"),
            user=os.getenv("DB_USER", "coboluser"),
            password=os.getenv("DB_PASSWORD", ""),
        )
    return _pool


def close_pool() -> None:
    """Close all connections in the pool."""
    global _pool
    if _pool is not None and not _pool.closed:
        _pool.closeall()
        _pool = None


@contextmanager
def get_connection():
    """Yield a connection from the pool. Auto-returns on exit."""
    p = get_pool()
    conn = p.getconn()
    try:
        yield conn
    finally:
        p.putconn(conn)


@contextmanager
def get_cursor(commit: bool = False):
    """Yield a RealDictCursor. Commits on success if requested."""
    with get_connection() as conn:
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        try:
            yield cursor
            if commit:
                conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
