import asyncio
import logging
import os
from contextlib import asynccontextmanager, suppress
from datetime import datetime, timedelta, timezone
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field, model_validator
from . import database
from .algorithms import evaluate
from .sensor_simulator import history, sample, utc_now

logger = logging.getLogger(__name__)
simulation = {'offline': False}
# Con una base vacía, crea 13 días de historial simulado para que haya tendencias.
SEED_HISTORY = os.environ.get('HORION_SEED_HISTORY', '1') == '1'

TABLES = ('telemetria', 'alertas_medicas', 'chat_historial', 'bienestar', 'mediciones')
TELEMETRY_METRICS = ('frecuencia_cardiaca', 'spo2', 'hrv', 'temperatura_corporal')

def _insert_alerts(db, alerts):
    for alert in alerts:
        db.execute('''INSERT INTO alertas_medicas
            (timestamp_utc, nivel_severidad, metrica_afectada, valor_detectado, recomendacion_entregada, modo_generacion)
            VALUES (:timestamp_utc, :nivel_severidad, :metrica_afectada, :valor_detectado, :recomendacion_entregada, :modo_generacion)''', alert)

def record_sample(anomaly=False):
    reading = sample(anomaly)
    with database.connection() as db:
        sleep = db.execute('SELECT horas_sueno FROM bienestar ORDER BY timestamp_utc DESC, id DESC LIMIT 1').fetchone()
        if sleep:
            reading['horas_sueno'] = sleep['horas_sueno']
        db.execute('''INSERT INTO telemetria
            (timestamp_utc, frecuencia_cardiaca, spo2, hrv, temperatura_corporal, horas_sueno)
            VALUES (:timestamp_utc, :frecuencia_cardiaca, :spo2, :hrv, :temperatura_corporal, :horas_sueno)''', reading)
        _insert_alerts(db, evaluate(reading))

def seed_history():
    """Inserta el historial simulado solo si la base no tiene telemetría."""
    with database.connection() as db:
        if db.execute('SELECT 1 FROM telemetria LIMIT 1').fetchone():
            return False
        telemetry, measurements, wellbeing = history()
        db.executemany('''INSERT INTO telemetria
            (timestamp_utc, frecuencia_cardiaca, spo2, hrv, temperatura_corporal, horas_sueno)
            VALUES (:timestamp_utc, :frecuencia_cardiaca, :spo2, :hrv, :temperatura_corporal, :horas_sueno)''', telemetry)
        db.executemany('INSERT INTO mediciones (timestamp_utc, metrica, valor, origen) VALUES (:timestamp_utc, :metrica, :valor, :origen)',
                       measurements)
        db.executemany('''INSERT INTO bienestar (timestamp_utc, horas_sueno, agua_ml, energia, animo)
            VALUES (:timestamp_utc, :horas_sueno, :agua_ml, :energia, :animo)''', wellbeing)
    return True

async def monitor():
    while True:
        await asyncio.sleep(5)
        try:
            record_sample()
        except Exception:
            logger.exception('No se pudo persistir la lectura simulada')

@asynccontextmanager
async def lifespan(app):
    database.initialize()
    simulation['offline'] = False
    if SEED_HISTORY:
        seed_history()
    record_sample()
    task = asyncio.create_task(monitor())
    try:
        yield
    finally:
        task.cancel()
        with suppress(asyncio.CancelledError):
            await task

app = FastAPI(title='Horion Edge · API local de desarrollo', version='0.2.0', lifespan=lifespan)

class OfflineRequest(BaseModel):
    enabled: bool

class WellbeingRequest(BaseModel):
    horas_sueno: float = Field(ge=0, le=16, allow_inf_nan=False)
    agua_ml: int = Field(ge=0, le=5000)
    energia: int = Field(ge=1, le=5)
    animo: int = Field(default=3, ge=1, le=5)

class MeasurementRequest(BaseModel):
    """Medición manual. Los límites solo descartan errores de tecleo, no son rangos clínicos."""
    presion_sistolica: int | None = Field(default=None, ge=50, le=260)
    presion_diastolica: int | None = Field(default=None, ge=30, le=160)
    glucosa: float | None = Field(default=None, ge=20, le=600, allow_inf_nan=False)
    temperatura_corporal: float | None = Field(default=None, ge=30, le=43, allow_inf_nan=False)

    @model_validator(mode='after')
    def check(self):
        if (self.presion_sistolica is None) != (self.presion_diastolica is None):
            raise ValueError('La presión arterial necesita sistólica y diastólica.')
        if self.presion_sistolica is not None and self.presion_sistolica <= self.presion_diastolica:
            raise ValueError('La sistólica debe ser mayor que la diastólica.')
        if not self.model_dump(exclude_none=True):
            raise ValueError('Indica al menos una medición.')
        return self

@app.get('/api/state')
def state():
    since = (datetime.now(timezone.utc) - timedelta(minutes=30)).isoformat()
    with database.connection() as db:
        telemetry = database.rows(db, 'SELECT * FROM telemetria WHERE timestamp_utc >= ? ORDER BY id DESC LIMIT 360', (since,))
        pending = sum(db.execute(f'SELECT COUNT(*) FROM {table} WHERE synced = 0').fetchone()[0] for table in TABLES)
        # Última medición de cada métrica.
        measurements = database.rows(db, '''SELECT m.metrica, m.valor, m.timestamp_utc, m.origen FROM mediciones m
            WHERE m.id = (SELECT id FROM mediciones WHERE metrica = m.metrica ORDER BY timestamp_utc DESC, id DESC LIMIT 1)''')
        start = db.execute('SELECT MIN(timestamp_utc) FROM telemetria').fetchone()[0]
        return dict(telemetry=list(reversed(telemetry)),
                    alerts=database.rows(db, 'SELECT * FROM alertas_medicas WHERE atendida = 0 ORDER BY id DESC'),
                    wellbeing=database.rows(db, 'SELECT * FROM bienestar ORDER BY timestamp_utc DESC, id DESC LIMIT 20'),
                    measurements=measurements, mission_start=start,
                    pending=pending, offline=simulation['offline'], source='simulator', cloud_configured=False,
                    gemini_configured=False)

@app.get('/api/trends')
def trends(days: int = Query(default=30, ge=1, le=90)):
    """Promedio diario (UTC) de cada indicador en los últimos `days` días."""
    since = (datetime.now(timezone.utc) - timedelta(days=days)).date().isoformat()
    by_day = {}
    def put(day, metric, value):
        if value is not None:
            by_day.setdefault(day, {})[metric] = round(value, 2)
    with database.connection() as db:
        averages = ', '.join(f'AVG({m}) AS {m}' for m in TELEMETRY_METRICS)
        for row in db.execute(f'''SELECT substr(timestamp_utc, 1, 10) AS day, {averages}
                FROM telemetria WHERE timestamp_utc >= ? GROUP BY day''', (since,)):
            for m in TELEMETRY_METRICS:
                put(row['day'], m, row[m])
        # Si hay medición manual de temperatura ese día, se promedia con el sensor.
        for row in db.execute('''SELECT substr(timestamp_utc, 1, 10) AS day, metrica, AVG(valor) AS valor
                FROM mediciones WHERE timestamp_utc >= ? GROUP BY day, metrica''', (since,)):
            current = by_day.get(row['day'], {}).get(row['metrica'])
            put(row['day'], row['metrica'], row['valor'] if current is None else (current + row['valor']) / 2)
        for row in db.execute('''SELECT substr(timestamp_utc, 1, 10) AS day, AVG(horas_sueno) AS horas_sueno, AVG(animo) AS animo
                FROM bienestar WHERE timestamp_utc >= ? GROUP BY day''', (since,)):
            put(row['day'], 'horas_sueno', row['horas_sueno'])
            put(row['day'], 'animo', row['animo'])
    return dict(days=[dict(date=day, values=values) for day, values in sorted(by_day.items())])

@app.post('/api/simulation/offline')
def offline(body: OfflineRequest):
    simulation['offline'] = body.enabled
    return {'offline': body.enabled}

@app.post('/api/simulation/anomaly')
def anomaly():
    record_sample(anomaly=True)
    return {'ok': True}

@app.post('/api/alerts/{alert_id}/acknowledge')
def acknowledge(alert_id: int):
    with database.connection() as db:
        result = db.execute('UPDATE alertas_medicas SET atendida = 1, synced = 0 WHERE id = ?', (alert_id,))
        if not result.rowcount:
            raise HTTPException(404, 'Alerta no encontrada')
    return {'ok': True}

@app.post('/api/wellbeing')
def wellbeing(body: WellbeingRequest):
    with database.connection() as db:
        db.execute('INSERT INTO bienestar (timestamp_utc, horas_sueno, agua_ml, energia, animo) VALUES (?, ?, ?, ?, ?)',
                   (utc_now(), body.horas_sueno, body.agua_ml, body.energia, body.animo))
    return {'ok': True}

@app.post('/api/measurements')
def measurements(body: MeasurementRequest):
    values = body.model_dump(exclude_none=True)
    now = utc_now()
    with database.connection() as db:
        db.executemany("INSERT INTO mediciones (timestamp_utc, metrica, valor, origen) VALUES (?, ?, ?, 'MANUAL')",
                       [(now, metric, value) for metric, value in values.items()])
        alerts = evaluate(dict(values, timestamp_utc=now))
        _insert_alerts(db, alerts)
    return {'ok': True, 'alerts': len(alerts)}
