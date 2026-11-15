import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import httpx

from app import cloud_sync, database
from app.main import record_sample

ENV = {'HORION_CLOUD_URL': 'https://web.test/', 'EDGE_API_KEY': 'clave-prueba'}


class FakeWeb:
    """Imita /api/v1/sync/ingest/: verifica clave y hash, y es idempotente por hash."""

    def __init__(self):
        self.batches = {}
        self.calls = 0
        self.fail_with = None  # 'network', un código HTTP o None

    def handler(self, request):
        self.calls += 1
        if self.fail_with == 'network':
            raise httpx.ConnectError('sin red', request=request)
        if isinstance(self.fail_with, int):
            return httpx.Response(self.fail_with, json={'codigo_astronauta': ['Registra primero al astronauta.']})
        assert request.url.path == '/api/v1/sync/ingest/'
        assert request.headers['X-Edge-Key'] == 'clave-prueba'
        body = json.loads(request.content)
        assert cloud_sync.digest(body['payload']) == body['hash_sha256']
        created = body['hash_sha256'] not in self.batches
        self.batches.setdefault(body['hash_sha256'], body['payload'])
        return httpx.Response(201 if created else 200, json={'created': created})

    def client(self):
        return httpx.Client(transport=httpx.MockTransport(self.handler))


class CloudSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.original_path = database.DB_PATH
        database.DB_PATH = Path(self.temp.name) / 'test.db'
        database.initialize()
        self.web = FakeWeb()
        env = mock.patch.dict(os.environ, ENV)
        env.start()
        self.addCleanup(env.stop)

    def tearDown(self):
        database.DB_PATH = self.original_path
        self.temp.cleanup()

    def count(self, sql):
        with database.connection() as db:
            return db.execute(sql).fetchone()[0]

    def sync(self):
        with self.web.client() as client:
            return cloud_sync.sync_once(client)

    def test_not_configured_sends_nothing(self):
        record_sample()
        with mock.patch.dict(os.environ, {'HORION_CLOUD_URL': ''}):
            self.assertEqual(self.sync()['estado'], 'NO_CONFIGURADO')
        self.assertEqual(self.web.calls, 0)

    def test_sends_queue_and_marks_only_sent_rows(self):
        record_sample(anomaly=True)  # 1 lectura + 3 alertas
        with database.connection() as db:
            db.execute("INSERT INTO chat_historial (timestamp_utc, rol, mensaje, contexto_biometrico_json) "
                       "VALUES ('2026-11-15T10:00:00+00:00', 'user', 'hola', '{\"spo2\": 89}')")
        result = self.sync()
        self.assertEqual(result['estado'], 'SUCCESS')
        payload = next(iter(self.web.batches.values()))
        self.assertEqual(payload['codigo_astronauta'], 'AST-001')
        self.assertEqual(len(payload['registros']), 1)
        self.assertEqual(payload['registros'][0]['spo2'], '89.00')  # Decimales como texto (contrato).
        self.assertIsNone(payload['registros'][0]['horas_sueno'])
        self.assertEqual(len(payload['alertas']), 3)
        self.assertEqual(payload['orbi'][0]['contexto_biometrico_json'], {'spo2': 89})
        for table in cloud_sync.SYNC_TABLES:
            self.assertEqual(self.count(f'SELECT COUNT(*) FROM {table} WHERE synced = 0'), 0)
        self.assertEqual(self.count('SELECT COUNT(*) FROM sync_pendiente'), 0)
        self.assertEqual(self.count("SELECT COUNT(*) FROM sync_logs WHERE estado = 'SUCCESS'"), 1)
        self.assertEqual(self.sync()['estado'], 'SIN_PENDIENTES')
        # Las mediciones y el bienestar no forman parte del contrato.
        self.assertEqual(self.web.calls, 1)

    def test_failed_batch_is_resent_identical(self):
        record_sample()
        self.web.fail_with = 'network'
        self.assertEqual(self.sync()['estado'], 'FAILED_NO_NETWORK')
        record_sample()  # Llega otra lectura mientras no hay red.
        self.web.fail_with = 400
        failed = self.sync()
        self.assertEqual(failed['estado'], 'FAILED_SERVER')
        self.assertIn('Registra primero', failed['detalle'])
        self.web.fail_with = None
        self.assertEqual(self.sync()['estado'], 'SUCCESS')
        first = next(iter(self.web.batches.values()))
        self.assertEqual(len(first['registros']), 1)  # El lote guardado, no uno nuevo.
        self.assertEqual(self.count('SELECT COUNT(*) FROM telemetria WHERE synced = 0'), 1)
        self.assertEqual(self.sync()['estado'], 'SUCCESS')
        self.assertEqual(len(self.web.batches), 2)
        with database.connection() as db:
            states = [r[0] for r in db.execute('SELECT estado FROM sync_logs ORDER BY id')]
        self.assertEqual(states, ['FAILED_NO_NETWORK', 'FAILED_SERVER', 'SUCCESS', 'SUCCESS'])

    def test_lost_response_does_not_duplicate(self):
        record_sample()
        self.sync()
        digest = next(iter(self.web.batches))
        # Simula que la web guardó el lote pero la respuesta no llegó.
        with database.connection() as db:
            payload = self.web.batches[digest]
            db.execute('UPDATE telemetria SET synced = 0')
            db.execute("INSERT INTO sync_pendiente VALUES (1, ?, ?, ?, 'x')",
                       (json.dumps(payload), digest, json.dumps({'telemetria': [1]})))
        self.assertEqual(self.sync()['estado'], 'SUCCESS')
        self.assertEqual(len(self.web.batches), 1)

    def test_batches_are_limited_and_continue(self):
        with database.connection() as db:
            db.executemany('INSERT INTO telemetria (timestamp_utc, frecuencia_cardiaca, spo2, hrv, temperatura_corporal) '
                           'VALUES (?, 70, 98, 50, 36.6)', [(f'2026-11-15T00:00:{i % 60:02d}+00:00',) for i in range(501)])
        first = self.sync()
        self.assertTrue(first['quedan'])
        self.assertEqual(cloud_sync.next_delay(first, 30), 1)
        self.assertFalse(self.sync()['quedan'])
        self.assertEqual(sorted(len(p['registros']) for p in self.web.batches.values()), [1, 500])

    def test_backoff(self):
        with mock.patch.dict(os.environ, {'HORION_SYNC_INTERVAL': '30'}):
            fail = dict(estado='FAILED_NO_NETWORK', quedan=True)
            self.assertEqual(cloud_sync.next_delay(fail, 30), 60)
            self.assertEqual(cloud_sync.next_delay(fail, 200), cloud_sync.MAX_BACKOFF)
            self.assertEqual(cloud_sync.next_delay(dict(estado='SIN_PENDIENTES', quedan=False), 300), 30)


if __name__ == '__main__':
    unittest.main()
