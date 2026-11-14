import tempfile
import unittest
from pathlib import Path
from fastapi.testclient import TestClient
from app import database
from app import main
from app.main import app, record_sample, seed_history

class EdgeApiTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.original_path = database.DB_PATH
        database.DB_PATH = Path(self.temp.name) / 'test.db'
        main.SEED_HISTORY = False  # Conteos exactos; el historial tiene su propia prueba.
        self.client = TestClient(app)
        self.client.__enter__()

    def tearDown(self):
        self.client.__exit__(None, None, None)
        database.DB_PATH = self.original_path
        self.temp.cleanup()

    def test_offline_anomaly_persists_and_acknowledges(self):
        self.client.post('/api/simulation/offline', json={'enabled': True}).raise_for_status()
        self.client.post('/api/simulation/anomaly', json={}).raise_for_status()
        state = self.client.get('/api/state').json()
        self.assertTrue(state['offline'])
        self.assertEqual(state['telemetry'][-1]['spo2'], 89)
        # SpO₂ 89 y HRV 24 son críticos; FC 112 es de vigilancia.
        levels = {a['metrica_afectada']: a['nivel_severidad'] for a in state['alerts']}
        self.assertEqual(levels, {'spo2': 'CRITICAL', 'hrv': 'CRITICAL', 'frecuencia_cardiaca': 'WARNING'})
        self.assertEqual(state['pending'], 5)
        for alert in state['alerts']:
            self.client.post(f"/api/alerts/{alert['id']}/acknowledge", json={}).raise_for_status()
        self.assertEqual(self.client.get('/api/state').json()['alerts'], [])
        database.initialize()  # Reabrir/inicializar no elimina los datos.
        with database.connection() as db:
            self.assertEqual(db.execute('SELECT MIN(atendida) FROM alertas_medicas').fetchone()[0], 1)
            self.assertEqual(db.execute('SELECT COUNT(*) FROM telemetria WHERE synced=0').fetchone()[0], 2)

    def test_wellbeing_validation_and_sensor_context(self):
        result = self.client.post('/api/wellbeing', json={'horas_sueno': 7.5, 'agua_ml': 1500, 'energia': 4, 'animo': 2})
        self.assertEqual(result.status_code, 200)
        record_sample()
        state = self.client.get('/api/state').json()
        self.assertEqual(state['wellbeing'][0]['horas_sueno'], 7.5)
        self.assertEqual(state['wellbeing'][0]['animo'], 2)
        self.assertEqual(self.client.post('/api/wellbeing', json={'horas_sueno': 7, 'agua_ml': 0, 'energia': 3, 'animo': 6}).status_code, 422)
        self.assertEqual(state['telemetry'][-1]['horas_sueno'], 7.5)
        self.assertEqual(self.client.post('/api/wellbeing', json={'horas_sueno': -1, 'agua_ml': 0, 'energia': 9}).status_code, 422)
        self.assertEqual(self.client.post('/api/alerts/999/acknowledge', json={}).status_code, 404)

    def test_status_bands_and_migration_of_old_database(self):
        from app.algorithms import status
        self.assertEqual(status('presion_sistolica', 118), 'good')
        self.assertEqual(status('presion_sistolica', 135), 'watch')
        self.assertEqual(status('presion_sistolica', 150), 'critical')
        self.assertEqual(status('glucosa', 50), 'critical')
        self.assertIsNone(status('glucosa', None))
        # Una base creada con el esquema anterior recibe las columnas nuevas.
        old = Path(self.temp.name) / 'old.db'
        import sqlite3
        db = sqlite3.connect(old)
        db.execute('CREATE TABLE telemetria (id INTEGER PRIMARY KEY, timestamp_utc TEXT NOT NULL, frecuencia_cardiaca INTEGER NOT NULL, spo2 REAL NOT NULL, hrv REAL NOT NULL, temperatura_corporal REAL NOT NULL, horas_sueno REAL, synced INTEGER NOT NULL DEFAULT 0)')
        db.execute('CREATE TABLE bienestar (id INTEGER PRIMARY KEY, timestamp_utc TEXT NOT NULL, horas_sueno REAL NOT NULL, agua_ml INTEGER NOT NULL, energia INTEGER NOT NULL, synced INTEGER NOT NULL DEFAULT 0)')
        db.commit()
        db.close()
        database.DB_PATH = old
        database.initialize()
        record_sample()
        with database.connection() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM mediciones').fetchone()[0], 0)
            self.assertIn('animo', {r['name'] for r in db.execute('PRAGMA table_info(bienestar)')})

    def test_manual_measurements_validate_and_alert(self):
        post = lambda body: self.client.post('/api/measurements', json=body)
        self.assertEqual(post({}).status_code, 422)
        self.assertEqual(post({'presion_sistolica': 120}).status_code, 422)  # Falta la diastólica.
        self.assertEqual(post({'presion_sistolica': 70, 'presion_diastolica': 80}).status_code, 422)
        self.assertEqual(post({'glucosa': 5000}).status_code, 422)
        result = post({'presion_sistolica': 150, 'presion_diastolica': 95, 'glucosa': 90})
        self.assertEqual(result.json(), {'ok': True, 'alerts': 2})
        state = self.client.get('/api/state').json()
        latest = {m['metrica']: m for m in state['measurements']}
        self.assertEqual(latest['presion_sistolica']['valor'], 150)
        self.assertEqual(latest['glucosa']['origen'], 'MANUAL')
        self.assertEqual({a['metrica_afectada'] for a in state['alerts']}, {'presion_sistolica', 'presion_diastolica'})
        # 1 lectura de arranque + 3 mediciones + 2 alertas.
        self.assertEqual(state['pending'], 6)

    def test_seeded_history_and_daily_trends(self):
        self.assertFalse(seed_history())  # Ya hay telemetría del arranque: no se duplica.
        with database.connection() as db:
            db.execute('DELETE FROM telemetria')
        self.assertTrue(seed_history())
        self.assertFalse(seed_history())
        record_sample()
        self.client.post('/api/measurements', json={'glucosa': 95}).raise_for_status()
        days = self.client.get('/api/trends?days=30').json()['days']
        self.assertEqual(len(days), 14)  # 13 días simulados + hoy.
        self.assertEqual(days, sorted(days, key=lambda d: d['date']))
        first, today = days[0]['values'], days[-1]['values']
        self.assertEqual(set(first), {'frecuencia_cardiaca', 'spo2', 'hrv', 'temperatura_corporal',
                                      'presion_sistolica', 'presion_diastolica', 'glucosa', 'horas_sueno', 'animo'})
        self.assertEqual(today['glucosa'], 95)
        self.assertGreater(first['hrv'], days[-2]['values']['hrv'])  # La HRV simulada baja en la misión.
        state = self.client.get('/api/state').json()
        self.assertEqual(state['mission_start'][:10], days[0]['date'])
        self.assertEqual(self.client.get('/api/trends?days=0').status_code, 422)

if __name__ == '__main__':
    unittest.main()
