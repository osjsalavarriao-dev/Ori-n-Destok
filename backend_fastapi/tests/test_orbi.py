import tempfile
import unittest
from pathlib import Path
from unittest import mock

from fastapi.testclient import TestClient

from app import database, main, orbi_ai
from app.main import app

CONTEXT = {
    'estado_general': 'watch',
    'indicadores': [{'id': 'hrv', 'nombre': 'Variabilidad cardíaca', 'valor': '38', 'estado': 'watch'}],
    'alertas_activas': [],
}


class OrbiChatTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.original_path = database.DB_PATH
        database.DB_PATH = Path(self.temp.name) / 'test.db'
        main.SEED_HISTORY = False
        self.client = TestClient(app)
        self.client.__enter__()

    def tearDown(self):
        self.client.__exit__(None, None, None)
        database.DB_PATH = self.original_path
        self.temp.cleanup()

    def chat(self, **overrides):
        body = dict(mensaje='¿Cómo estoy?', idioma='es', contexto=CONTEXT) | overrides
        response = self.client.post('/api/orbi/chat', json=body)
        response.raise_for_status()
        return response.json()

    def test_ai_reply_is_saved_with_context(self):
        with mock.patch.object(orbi_ai, 'complete', mock.AsyncMock(return_value='Estás bien.')) as complete:
            result = self.chat(historial=[{'rol': 'orbi', 'mensaje': 'Hola'}])
        self.assertEqual(result, {'modo': 'IA', 'respuesta': 'Estás bien.'})
        messages = complete.call_args.args[0]
        self.assertEqual(messages[0]['role'], 'system')
        self.assertIn('Variabilidad cardíaca', messages[1]['content'])
        # El historial de la base va en su propio mensaje de sistema, antes de
        # los turnos de la sesión actual.
        self.assertEqual(messages[2]['role'], 'system')
        self.assertIn('HISTORIAL DE LA BASE DE DATOS', messages[2]['content'])
        self.assertIn('historial_diario', messages[2]['content'])
        self.assertEqual(messages[3], {'role': 'assistant', 'content': 'Hola'})
        self.assertEqual(messages[-1], {'role': 'user', 'content': '¿Cómo estoy?'})
        with database.connection() as db:
            rows = database.rows(db, 'SELECT rol, mensaje, contexto_biometrico_json FROM chat_historial ORDER BY id')
        self.assertEqual([r['rol'] for r in rows], ['user', 'orbi'])
        self.assertIn('hrv', rows[0]['contexto_biometrico_json'])

    def test_critical_alert_bypasses_ai(self):
        context = dict(CONTEXT, estado_general='critical', alertas_activas=[
            {'metrica': 'spo2', 'nivel': 'CRITICAL', 'accion': 'Verifica la lectura del sensor.'}])
        with mock.patch.object(orbi_ai, 'complete', mock.AsyncMock()) as complete:
            result = self.chat(contexto=context)
        complete.assert_not_called()
        self.assertEqual(result['modo'], 'LOCAL_CRITICO')
        self.assertIn('Verifica la lectura del sensor.', result['respuesta'])

    def test_offline_and_missing_key_fall_back(self):
        self.client.post('/api/simulation/offline', json={'enabled': True}).raise_for_status()
        self.assertEqual(self.chat(), {'modo': 'SIN_CONEXION', 'respuesta': None})
        self.client.post('/api/simulation/offline', json={'enabled': False}).raise_for_status()
        with mock.patch.object(orbi_ai, 'api_key', return_value=''):
            self.assertEqual(self.chat(), {'modo': 'SIN_CLAVE', 'respuesta': None})
            self.assertFalse(self.client.get('/api/orbi/status').json()['configured'])
        with database.connection() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM chat_historial').fetchone()[0], 0)

    def test_provider_error_returns_mode(self):
        failing = mock.AsyncMock(side_effect=orbi_ai.OrbiUnavailable('ERROR', 'Groq respondió 500'))
        with mock.patch.object(orbi_ai, 'complete', failing):
            self.assertEqual(self.chat(), {'modo': 'ERROR', 'respuesta': None})

    def test_validation(self):
        self.assertEqual(self.client.post('/api/orbi/chat', json={'mensaje': ''}).status_code, 422)
        big = {'x': 'a' * 25000}
        self.assertEqual(self.client.post('/api/orbi/chat', json={'mensaje': 'hola', 'contexto': big}).status_code, 422)

    def test_transcribe(self):
        with mock.patch.object(orbi_ai, 'transcribe', mock.AsyncMock(return_value='signos vitales')) as transcribe:
            response = self.client.post('/api/orbi/transcribe?idioma=es', content=b'RIFF....WAVE')
        self.assertEqual(response.json(), {'modo': 'IA', 'texto': 'signos vitales'})
        self.assertEqual(transcribe.call_args.args, (b'RIFF....WAVE', 'es'))
        self.assertEqual(self.client.post('/api/orbi/transcribe', content=b'').status_code, 422)


    def test_speak(self):
        wav = orbi_ai.pcm_to_wav(b'\x00\x00' * 10)
        with mock.patch.object(orbi_ai, 'speech', mock.AsyncMock(return_value=wav)) as speech:
            response = self.client.post('/api/orbi/speak', json={'texto': 'Hola', 'idioma': 'es'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers['content-type'], 'audio/wav')
        self.assertEqual(response.content, wav)
        self.assertEqual(speech.call_args.args, ('Hola', 'es'))
        failing = mock.AsyncMock(side_effect=orbi_ai.OrbiUnavailable('SIN_CLAVE'))
        with mock.patch.object(orbi_ai, 'speech', failing):
            response = self.client.post('/api/orbi/speak', json={'texto': 'Hola'})
        self.assertEqual((response.status_code, response.json()['detail']), (503, 'SIN_CLAVE'))
        self.client.post('/api/simulation/offline', json={'enabled': True}).raise_for_status()
        self.assertEqual(self.client.post('/api/orbi/speak', json={'texto': 'Hola'}).status_code, 503)
        self.assertEqual(self.client.post('/api/orbi/speak', json={'texto': ''}).status_code, 422)


class WavTests(unittest.TestCase):
    def test_pcm_to_wav_header(self):
        wav = orbi_ai.pcm_to_wav(b'\x01\x00' * 24000, rate=24000)
        self.assertEqual(wav[:4], b'RIFF')
        self.assertEqual(wav[8:16], b'WAVEfmt ')
        self.assertEqual(int.from_bytes(wav[24:28], 'little'), 24000)
        self.assertEqual(int.from_bytes(wav[40:44], 'little'), 48000)
        self.assertEqual(len(wav), 44 + 48000)


class EnvFileTests(unittest.TestCase):
    def test_load_env_does_not_override(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / '.env'
            path.write_text('# comentario\nORBI_TEST_A="uno"\nORBI_TEST_B=dos\n', encoding='utf-8')
            with mock.patch.dict('os.environ', {'ORBI_TEST_B': 'ya'}, clear=False):
                orbi_ai.load_env(path)
                import os
                self.assertEqual(os.environ['ORBI_TEST_A'], 'uno')
                self.assertEqual(os.environ['ORBI_TEST_B'], 'ya')
                os.environ.pop('ORBI_TEST_A', None)


if __name__ == '__main__':
    unittest.main()
