import asyncio
import json
import logging
import os
import re
from contextlib import asynccontextmanager, suppress
from datetime import datetime, timedelta, timezone
from typing import Literal
from fastapi import FastAPI, HTTPException, Query, Request, Response
from pydantic import BaseModel, Field, field_validator, model_validator
from . import cloud_sync, database, orbi_ai
from .algorithms import evaluate
from .sensor_simulator import history, sample, utc_now

logger = logging.getLogger(__name__)
simulation = {'offline': False}
# Con una base vacía, crea 13 días de historial simulado para que haya tendencias.
SEED_HISTORY = os.environ.get('HORION_SEED_HISTORY', '1') == '1'

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

async def cloud_sync_loop():
    """Sube la cola a Horion Web. Sin HORION_CLOUD_URL/EDGE_API_KEY no envía nada."""
    delay = cloud_sync.interval()
    while True:
        await asyncio.sleep(delay)
        if simulation['offline']:  # Corte de enlace simulado: la cola espera.
            continue
        try:
            result = await asyncio.to_thread(cloud_sync.sync_once)
        except Exception:
            logger.exception('Fallo inesperado al sincronizar')
            result = dict(estado='ERROR', quedan=True)
        delay = cloud_sync.next_delay(result, delay)

@asynccontextmanager
async def lifespan(app):
    database.initialize()
    simulation['offline'] = False
    if SEED_HISTORY:
        seed_history()
    record_sample()
    tasks = [asyncio.create_task(monitor()), asyncio.create_task(cloud_sync_loop())]
    try:
        yield
    finally:
        for task in tasks:
            task.cancel()
        for task in tasks:
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
        # Solo lo que se sube a Horion Web; bienestar y mediciones aún no están en el contrato.
        pending = sum(db.execute(f'SELECT COUNT(*) FROM {table} WHERE synced = 0').fetchone()[0]
                      for table in cloud_sync.SYNC_TABLES)
        # Última medición de cada métrica.
        measurements = database.rows(db, '''SELECT m.metrica, m.valor, m.timestamp_utc, m.origen FROM mediciones m
            WHERE m.id = (SELECT id FROM mediciones WHERE metrica = m.metrica ORDER BY timestamp_utc DESC, id DESC LIMIT 1)''')
        start = db.execute('SELECT MIN(timestamp_utc) FROM telemetria').fetchone()[0]
        # Última autoevaluación de síntomas de cada zona del mapa corporal.
        checks = [dict(zona=r['zona'], sintomas=json.loads(r['sintomas_json']), timestamp_utc=r['timestamp_utc'])
                  for r in db.execute('''SELECT a.zona, a.sintomas_json, a.timestamp_utc FROM autoevaluaciones a
                      WHERE a.id = (SELECT id FROM autoevaluaciones WHERE zona = a.zona ORDER BY timestamp_utc DESC, id DESC LIMIT 1)''')]
        return dict(telemetry=list(reversed(telemetry)), symptom_checks=checks,
                    alerts=database.rows(db, 'SELECT * FROM alertas_medicas WHERE atendida = 0 ORDER BY id DESC'),
                    wellbeing=database.rows(db, 'SELECT * FROM bienestar ORDER BY timestamp_utc DESC, id DESC LIMIT 20'),
                    measurements=measurements, mission_start=start,
                    pending=pending, offline=simulation['offline'], source='simulator',
                    cloud_configured=cloud_sync.configured(), cloud_sync=dict(cloud_sync.status),
                    gemini_configured=False, ai_configured=orbi_ai.configured())

@app.post('/api/sync/now')
def sync_now():
    """Envía un lote a Horion Web ahora, sin esperar al intervalo."""
    if simulation['offline']:
        return dict(estado='SIN_CONEXION', detalle=None, quedan=True)
    return cloud_sync.sync_once()

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
        # No vuelve a encolar la alerta: la web no recibe `atendida` y la duplicaría.
        result = db.execute('UPDATE alertas_medicas SET atendida = 1 WHERE id = ?', (alert_id,))
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

SLUG = r'^[a-z][a-z0-9_]{0,39}$'

class SymptomCheckRequest(BaseModel):
    """Autoevaluación de una zona del mapa corporal. `sintomas` vacío = «no tengo ninguno».
    Los ids los define la app (health_knowledge.dart); aquí solo se valida su forma."""
    zona: str = Field(pattern=SLUG)
    sintomas: list[str] = Field(default_factory=list, max_length=12)

    @field_validator('sintomas')
    @classmethod
    def valid_ids(cls, value):
        if any(not re.match(SLUG, item) for item in value):
            raise ValueError('Identificador de síntoma no válido.')
        return sorted(set(value))

@app.post('/api/symptoms')
def symptoms(body: SymptomCheckRequest):
    with database.connection() as db:
        db.execute('INSERT INTO autoevaluaciones (timestamp_utc, zona, sintomas_json) VALUES (?, ?, ?)',
                   (utc_now(), body.zona, json.dumps(body.sintomas)))
    return {'ok': True}

# --- Orbi en línea (Groq) ---------------------------------------------------

class ChatTurn(BaseModel):
    rol: Literal['user', 'orbi']
    mensaje: str = Field(max_length=2000)

class OrbiChatRequest(BaseModel):
    mensaje: str = Field(min_length=1, max_length=1000)
    idioma: Literal['es', 'en'] = 'es'
    historial: list[ChatTurn] = Field(default_factory=list, max_length=12)
    # Instantánea de lo que muestra la app (demo o backend): valores, estados,
    # alertas, bienestar, tendencias y entorno. Sin datos de identidad.
    contexto: dict = Field(default_factory=dict)

    @field_validator('contexto')
    @classmethod
    def small_context(cls, value):
        if len(json.dumps(value, ensure_ascii=False)) > 20000:
            raise ValueError('Contexto demasiado grande.')
        return value

def _save_chat(message, reply, context):
    now = utc_now()
    snapshot = json.dumps(context, ensure_ascii=False)
    with database.connection() as db:
        db.executemany('INSERT INTO chat_historial (timestamp_utc, rol, mensaje, contexto_biometrico_json) VALUES (?, ?, ?, ?)',
                       [(now, 'user', message, snapshot), (now, 'orbi', reply, None)])

@app.get('/api/orbi/status')
def orbi_status():
    return dict(configured=orbi_ai.configured(), offline=simulation['offline'], model=orbi_ai.chat_model(),
                speech=orbi_ai.speech_configured())

@app.post('/api/orbi/chat')
async def orbi_chat(body: OrbiChatRequest):
    """Respuesta de Orbi. `modo`: IA, LOCAL_CRITICO, SIN_CONEXION, SIN_CLAVE o ERROR
    (en los tres últimos `respuesta` es null y la app usa las consultas locales)."""
    if simulation['offline']:
        return dict(modo='SIN_CONEXION', respuesta=None)
    reply = orbi_ai.critical_reply(body.contexto, body.idioma)
    mode = 'LOCAL_CRITICO'
    if reply is None:
        messages = orbi_ai.build_messages(body.mensaje, [t.model_dump() for t in body.historial], body.contexto, body.idioma)
        try:
            reply = await orbi_ai.complete(messages)
            mode = 'IA'
        except orbi_ai.OrbiUnavailable as error:
            logger.warning('Orbi sin IA: %s', error)
            return dict(modo=error.mode, respuesta=None)
    _save_chat(body.mensaje, reply, body.contexto)
    return dict(modo=mode, respuesta=reply)

@app.post('/api/orbi/transcribe')
async def orbi_transcribe(request: Request, idioma: Literal['es', 'en'] = Query(default='es')):
    """Transcribe un WAV (cuerpo binario) con Whisper en Groq."""
    if simulation['offline']:
        return dict(modo='SIN_CONEXION', texto=None)
    audio = await request.body()
    if not audio:
        raise HTTPException(422, 'Audio vacío')
    try:
        return dict(modo='IA', texto=await orbi_ai.transcribe(audio, idioma))
    except orbi_ai.OrbiUnavailable as error:
        logger.warning('Transcripción no disponible: %s', error)
        return dict(modo=error.mode, texto=None)

class SpeakRequest(BaseModel):
    texto: str = Field(min_length=1, max_length=orbi_ai.MAX_SPEECH_CHARS)
    idioma: Literal['es', 'en'] = 'es'

@app.post('/api/orbi/speak', responses={200: {'content': {'audio/wav': {}}}})
async def orbi_speak(body: SpeakRequest):
    """Voz natural de Orbi (Gemini). 503 con `modo` si no está disponible:
    la app usa entonces la voz local (Piper)."""
    if simulation['offline']:
        raise HTTPException(503, 'SIN_CONEXION')
    try:
        audio = await orbi_ai.speech(body.texto, body.idioma)
    except orbi_ai.OrbiUnavailable as error:
        logger.warning('Voz Gemini no disponible: %s', error)
        raise HTTPException(503, error.mode) from error
    return Response(content=audio, media_type='audio/wav')
