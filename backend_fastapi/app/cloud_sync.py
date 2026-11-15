"""Envío de la cola local (synced = 0) a Horion Web.

Contrato: HORIO_WEB/docs/edge-api.md → POST {HORION_CLOUD_URL}/api/v1/sync/ingest/
con cabecera X-Edge-Key. La app siempre inicia la conexión; la web nunca llama a
esta máquina.

Garantías:
- Un lote armado se guarda en `sync_pendiente` y se reenvía idéntico (mismo hash)
  hasta que la web lo confirme. Si la respuesta se pierde, el reintento devuelve
  `created=false` en la web y no duplica nada.
- Solo se marcan `synced = 1` las filas de ese lote, en la misma transacción que
  borra el lote pendiente y escribe `sync_logs`.
- `bienestar` y `mediciones` no forman parte del contrato actual y no se envían.
"""

import hashlib
import json
import logging
import os
from datetime import datetime, timezone

import httpx

from . import database

logger = logging.getLogger(__name__)

# Límite por tabla y lote. La web acepta hasta 10.000 lecturas y 1.000 alertas/mensajes.
BATCH_LIMIT = 500
SYNC_TABLES = ('telemetria', 'alertas_medicas', 'chat_historial')
MAX_BACKOFF = 300

# Último resultado, para mostrarlo en /api/state. Solo vive en memoria.
status = {'estado': None, 'detalle': None, 'ultimo_intento_utc': None, 'ultimo_exito_utc': None}


def cloud_url():
    return os.environ.get('HORION_CLOUD_URL', '').strip().rstrip('/')


def edge_key():
    return os.environ.get('EDGE_API_KEY', '').strip()


def configured():
    return bool(cloud_url() and edge_key())


def interval():
    try:
        return max(5, int(os.environ.get('HORION_SYNC_INTERVAL', '30')))
    except ValueError:
        return 30


def digest(payload):
    """Misma canonicalización que exige la web (edge-api.md)."""
    canonical = json.dumps(payload, sort_keys=True, separators=(',', ':'), ensure_ascii=False)
    return hashlib.sha256(canonical.encode('utf-8')).hexdigest()


def _decimal(value):
    # La web valida 2 decimales; se envían como texto para que el hash no dependa
    # de cómo cada lenguaje imprime los flotantes.
    return None if value is None else f'{float(value):.2f}'


def _context(raw):
    if not raw:
        return {}
    try:
        value = json.loads(raw)
    except ValueError:
        return {}
    return value if isinstance(value, dict) else {}


def build_batch(db):
    """Arma el siguiente lote, o None si no hay telemetría pendiente.

    La web exige al menos una lectura por lote; las alertas y los mensajes de Orbi
    esperan a la siguiente lectura (el monitor genera una cada 5 s).
    """
    telemetry = db.execute('SELECT * FROM telemetria WHERE synced = 0 ORDER BY id LIMIT ?', (BATCH_LIMIT,)).fetchall()
    if not telemetry:
        return None
    alerts = db.execute('SELECT * FROM alertas_medicas WHERE synced = 0 ORDER BY id LIMIT ?', (BATCH_LIMIT,)).fetchall()
    chat = db.execute('SELECT * FROM chat_historial WHERE synced = 0 ORDER BY id LIMIT ?', (BATCH_LIMIT,)).fetchall()
    astronaut = db.execute('SELECT codigo_astronauta FROM astronauta WHERE id = 1').fetchone()
    payload = {
        'codigo_astronauta': astronaut['codigo_astronauta'],
        'registros': [dict(
            timestamp_utc=r['timestamp_utc'],
            frecuencia_cardiaca=int(r['frecuencia_cardiaca']),
            spo2=_decimal(r['spo2']),
            hrv=_decimal(r['hrv']),
            temperatura_corporal=_decimal(r['temperatura_corporal']),
            horas_sueno=_decimal(r['horas_sueno']),
        ) for r in telemetry],
        'alertas': [dict(
            timestamp_utc=r['timestamp_utc'],
            nivel_severidad=r['nivel_severidad'],
            metrica_afectada=r['metrica_afectada'],
            valor_detectado=_decimal(r['valor_detectado']),
            recomendacion_entregada=r['recomendacion_entregada'],
            modo_generacion=r['modo_generacion'],
        ) for r in alerts],
        'orbi': [dict(
            timestamp_utc=r['timestamp_utc'],
            rol=r['rol'],
            mensaje=r['mensaje'],
            contexto_biometrico_json=_context(r['contexto_biometrico_json']),
        ) for r in chat],
    }
    ids = {'telemetria': [r['id'] for r in telemetry],
           'alertas_medicas': [r['id'] for r in alerts],
           'chat_historial': [r['id'] for r in chat]}
    return payload, ids


def _now():
    return datetime.now(timezone.utc).isoformat()


def _record(estado, detalle=None, hash_sha256='', enviados=0):
    now = _now()
    status.update(estado=estado, detalle=detalle, ultimo_intento_utc=now)
    if estado == 'SUCCESS':
        status['ultimo_exito_utc'] = now
    if estado in ('SUCCESS', 'FAILED_NO_NETWORK', 'FAILED_SERVER'):
        with database.connection() as db:
            db.execute('INSERT INTO sync_logs (timestamp_intento_utc, hash_sha256, registros_enviados, estado) VALUES (?, ?, ?, ?)',
                       (now, hash_sha256, enviados, estado))


def _error_detail(response):
    try:
        body = response.json()
    except ValueError:
        return f'HTTP {response.status_code}'
    return f'HTTP {response.status_code}: {json.dumps(body, ensure_ascii=False)[:500]}'


def sync_once(client=None):
    """Envía un lote. Devuelve {'estado', 'detalle', 'quedan'}.

    `estado`: NO_CONFIGURADO, SIN_PENDIENTES, SUCCESS, FAILED_NO_NETWORK o FAILED_SERVER.
    """
    if not configured():
        status.update(estado='NO_CONFIGURADO', detalle=None)
        return dict(estado='NO_CONFIGURADO', detalle=None, quedan=False)

    with database.connection() as db:
        row = db.execute('SELECT * FROM sync_pendiente WHERE id = 1').fetchone()
        if row:
            payload, hash_sha256, ids = json.loads(row['payload_json']), row['hash_sha256'], json.loads(row['ids_json'])
        else:
            batch = build_batch(db)
            if batch is None:
                status.update(estado='SIN_PENDIENTES', detalle=None)
                return dict(estado='SIN_PENDIENTES', detalle=None, quedan=False)
            payload, ids = batch
            hash_sha256 = digest(payload)
            db.execute('INSERT INTO sync_pendiente (id, payload_json, hash_sha256, ids_json, creado_utc) VALUES (1, ?, ?, ?, ?)',
                       (json.dumps(payload, ensure_ascii=False), hash_sha256, json.dumps(ids), _now()))

    sent = len(payload['registros'])
    own_client = client is None
    # 60 s: el plan gratuito de Render tarda ~50 s en despertar tras estar inactivo.
    client = client or httpx.Client(timeout=60)
    try:
        response = client.post(f'{cloud_url()}/api/v1/sync/ingest/',
                               json={'payload': payload, 'hash_sha256': hash_sha256},
                               headers={'X-Edge-Key': edge_key()})
    except httpx.HTTPError as error:
        detail = f'{type(error).__name__}: {error}'
        logger.warning('Sync sin red: %s', detail)
        _record('FAILED_NO_NETWORK', detail, hash_sha256, sent)
        return dict(estado='FAILED_NO_NETWORK', detalle=detail, quedan=True)
    finally:
        if own_client:
            client.close()

    if response.status_code not in (200, 201):
        # El lote se conserva: tras corregir la causa en la web (astronauta no
        # registrado, fecha de inicio de misión, clave) se reenvía el mismo.
        detail = _error_detail(response)
        logger.warning('Sync rechazado: %s', detail)
        _record('FAILED_SERVER', detail, hash_sha256, sent)
        return dict(estado='FAILED_SERVER', detalle=detail, quedan=True)

    with database.connection() as db:
        for table, table_ids in ids.items():
            if table in SYNC_TABLES and table_ids:
                db.executemany(f'UPDATE {table} SET synced = 1 WHERE id = ?', [(i,) for i in table_ids])
        db.execute('DELETE FROM sync_pendiente WHERE id = 1')
        more = any(db.execute(f'SELECT 1 FROM {t} WHERE synced = 0 LIMIT 1').fetchone() for t in SYNC_TABLES)
    _record('SUCCESS', None, hash_sha256, sent)
    return dict(estado='SUCCESS', detalle=None, quedan=more)


def next_delay(result, previous):
    """Inmediato si quedan lotes, intervalo normal si todo va bien, backoff si falla."""
    base = interval()
    if result['estado'] == 'SUCCESS' and result['quedan']:
        return 1
    if result['estado'] in ('FAILED_NO_NETWORK', 'FAILED_SERVER', 'ERROR'):
        return min(max(previous * 2, base), MAX_BACKOFF)
    return base
