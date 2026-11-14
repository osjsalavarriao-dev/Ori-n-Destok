import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path

DB_PATH = Path(os.environ.get('HORION_DB_PATH', Path(__file__).resolve().parents[1] / 'horion_edge.db'))

@contextmanager
def connection():
    db = sqlite3.connect(DB_PATH, timeout=10)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys = ON')
    try:
        with db:
            yield db
    finally:
        db.close()

def initialize():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with connection() as db:
        db.executescript(Path(__file__).with_name('schema.sql').read_text(encoding='utf-8'))
        _migrate(db)
        db.execute('''INSERT OR IGNORE INTO astronauta
            (id, codigo_astronauta, codigo_mision, nombre_completo)
            VALUES (1, 'AST-001', 'ARTEMIS-IV', 'Tripulante de demostración')''')

# Columnas añadidas después de la primera versión; CREATE TABLE IF NOT EXISTS
# no las agrega a una base de datos que ya existía.
MIGRATIONS = {
    'bienestar': {'animo': 'INTEGER CHECK(animo BETWEEN 1 AND 5)'},
}

def _migrate(db):
    for table, columns in MIGRATIONS.items():
        existing = {row['name'] for row in db.execute(f'PRAGMA table_info({table})')}
        for column, definition in columns.items():
            if column not in existing:
                db.execute(f'ALTER TABLE {table} ADD COLUMN {column} {definition}')

def rows(db, sql, params=()):
    return [dict(row) for row in db.execute(sql, params).fetchall()]
