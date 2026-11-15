"""Orbi en línea: conversación (Groq) con el contexto biométrico de la app.

Reglas fijas, aplicadas antes de llamar a la IA:
- Con una alerta crítica activa responde la regla local, nunca el modelo.
- Con el enlace caído (corte simulado) o sin clave no se llama a la IA; la app
  vuelve a las consultas locales.
- Al modelo solo llegan valores, estados y contexto de misión, sin identidad.

La clave se lee de GROQ_API_KEY (variable de entorno o backend_fastapi/.env).
"""
import base64
import json
import os
from pathlib import Path

import httpx

ENV_FILE = Path(__file__).resolve().parents[1] / '.env'
GROQ_BASE = 'https://api.groq.com/openai/v1'
MAX_AUDIO_BYTES = 10 * 1024 * 1024


def load_env(path=ENV_FILE):
    """Carga KEY=valor de .env sin pisar variables ya definidas."""
    if not path.exists():
        return
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


load_env()


def api_key():
    return os.environ.get('GROQ_API_KEY', '').strip()


def configured():
    return bool(api_key())


def chat_model():
    return os.environ.get('GROQ_CHAT_MODEL', 'openai/gpt-oss-120b')


def stt_model():
    return os.environ.get('GROQ_STT_MODEL', 'whisper-large-v3-turbo')


SYSTEM_PROMPT = {
    'es': """Eres Orbi, el asistente de salud de Horion Edge, una app de monitoreo biométrico para tripulantes en misiones espaciales. Hablas con el tripulante como un compañero cercano que conoce su historial día a día.

Reglas:
- Responde en español, breve (2 a 5 frases), en tono cercano y calmado. Tu respuesta se leerá en voz alta: sin listas, tablas, markdown ni emojis.
- Recibes DATOS ACTUALES, HISTORIAL DIARIO (promedios de cada día), ALERTAS PASADAS, SÍNTOMAS REGISTRADOS, MEDICIONES MANUALES y CONVERSACIONES ANTERIORES. Basa todo en esos datos; si un dato no está, dilo; no lo inventes.
- Sé conversacional y específico con las fechas. En vez de "tus signos están bien", di algo como "el martes tu frecuencia estaba en 82 y hoy bajó a 71, eso es buena señal". Cita días concretos cuando hables de tendencias.
- Compara activamente entre días y conecta métricas entre sí. Si el sueño bajó y al día siguiente el HRV cayó o el ánimo empeoró, menciónalo: "llevas tres días durmiendo menos de 6 horas y tu variabilidad cardíaca lo refleja".
- Si el tripulante pregunta por un día concreto o quiere comparar fechas, busca en el historial diario y responde con los datos de ese día.
- Si notas un patrón (mejora progresiva, empeoramiento gradual, correlación entre indicadores), coméntalo aunque no te lo pregunten.
- Si hay conversaciones anteriores en el contexto, recuérdalas: por ejemplo "la vez pasada mencionaste que dormías mal, veo que hoy registraste 7 horas, eso es un avance".
- No diagnostiques enfermedades. No indiques medicamentos, dosis, cargas de ejercicio ni dietas concretas: si los piden, remite al plan aprobado de la misión o al médico de vuelo.
- Si el tripulante describe síntomas preocupantes (dolor en el pecho, dificultad para respirar, confusión, desmayo, sangrado), dile que avise ya al médico de vuelo.
- Si el estado de ánimo está bajo o habla de aislamiento, responde con empatía, valida lo que siente y sugiere algo concreto y sencillo (una pausa de respiración, contactar a la familia o al equipo de apoyo psicológico).
- Si te preguntan algo ajeno a su salud, bienestar o la misión, responde en una frase y vuelve al tema.
- Los datos pueden ser simulados (modo demostración); si lo son, no hace falta repetirlo en cada respuesta.""",
    'en': """You are Orbi, the health assistant of Horion Edge, a biometric monitoring app for crew members on space missions. You talk to the crew member like a close companion who knows their day-by-day history.

Rules:
- Answer in English, briefly (2 to 5 sentences), in a warm, calm tone. Your answer will be read aloud: no lists, tables, markdown or emojis.
- You receive CURRENT DATA, DAILY HISTORY (daily averages), PAST ALERTS, RECORDED SYMPTOMS, MANUAL MEASUREMENTS and PREVIOUS CONVERSATIONS. Base everything on those; if something is missing, say so; never make it up.
- Be conversational and cite specific dates. Instead of "your signs are fine", say something like "on Tuesday your heart rate was 82 and today it dropped to 71, that is a good sign". Mention concrete days when discussing trends.
- Actively compare across days and connect metrics. If sleep dropped and the next day HRV fell or mood worsened, point it out: "you have slept under 6 hours for three days and your heart rate variability shows it".
- If the crew member asks about a specific day or wants to compare dates, look it up in the daily history and answer with that day's data.
- If you spot a pattern (steady improvement, gradual decline, correlation between indicators), mention it even if not asked.
- If there are previous conversations in the context, recall them: for example "last time you mentioned you were sleeping poorly, I see you logged 7 hours today, that is progress".
- Do not diagnose diseases. Do not give medications, doses, exercise loads or specific diets: if asked, refer to the approved mission plan or the flight surgeon.
- If the crew member describes worrying symptoms (chest pain, shortness of breath, confusion, fainting, bleeding), tell them to contact the flight surgeon now.
- If mood is low or they talk about isolation, answer with empathy, validate their feelings and suggest something simple and concrete (a breathing break, contacting family or the psychological support team).
- If asked about something unrelated to their health, wellbeing or the mission, answer in one sentence and steer back.
- Data may be simulated (demo mode); no need to repeat that in every answer.""",
}

CRITICAL_REPLY = {
    'es': ('Tienes una alerta crítica activa, así que ahora mando la regla de seguridad, no la conversación: '
           '{acciones} Avisa al médico de vuelo. Cuando la alerta esté atendida podemos seguir hablando.'),
    'en': ('You have an active critical alert, so the safety rule takes over, not the conversation: '
           '{acciones} Contact the flight surgeon. Once the alert is handled we can keep talking.'),
}


class OrbiUnavailable(Exception):
    """La IA no puede responder; `mode` explica por qué."""

    def __init__(self, mode, detail=''):
        super().__init__(detail or mode)
        self.mode = mode


def critical_reply(context, language):
    """Respuesta local si el contexto trae una alerta crítica; si no, None."""
    critical = [a for a in context.get('alertas_activas', []) if a.get('nivel') == 'CRITICAL']
    if not critical and context.get('estado_general') != 'critical':
        return None
    actions = ' '.join(dict.fromkeys(a['accion'] for a in critical if a.get('accion')))
    return CRITICAL_REPLY[language].format(acciones=actions or '').replace('  ', ' ')


def build_messages(message, history, context, language):
    # Separar los datos del historial de la base de datos para que el modelo
    # distinga lo que ve ahora en pantalla del registro acumulado.
    db_keys = ('historial_diario', 'alertas_historicas', 'sintomas_historicos',
               'mediciones_historicas', 'conversaciones_previas')
    historical = {k: context.pop(k) for k in db_keys if k in context}
    messages = [
        {'role': 'system', 'content': SYSTEM_PROMPT[language]},
        {'role': 'system', 'content': 'DATOS ACTUALES EN PANTALLA (JSON):\n' + json.dumps(context, ensure_ascii=False)},
    ]
    if historical:
        label = {'es': 'HISTORIAL DE LA BASE DE DATOS', 'en': 'DATABASE HISTORY'}
        messages.append({'role': 'system', 'content': label[language] + ' (JSON):\n' + json.dumps(historical, ensure_ascii=False)})
    # Las conversaciones anteriores de la base de datos ya están en `historical`;
    # aquí solo van los turnos de la sesión actual de la app.
    for turn in history[-10:]:
        role = 'assistant' if turn['rol'] == 'orbi' else 'user'
        messages.append({'role': role, 'content': turn['mensaje']})
    messages.append({'role': 'user', 'content': message})
    return messages


async def _post(path, **kwargs):
    if not configured():
        raise OrbiUnavailable('SIN_CLAVE')
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(25, connect=5)) as client:
            response = await client.post(
                f'{GROQ_BASE}{path}', headers={'Authorization': f'Bearer {api_key()}'}, **kwargs)
    except httpx.HTTPError as error:
        raise OrbiUnavailable('ERROR', f'Groq no responde: {type(error).__name__}') from error
    if response.status_code >= 400:
        # No se reenvía el cuerpo: puede repetir datos de la petición.
        raise OrbiUnavailable('ERROR', f'Groq respondió {response.status_code}')
    return response.json()


async def complete(messages):
    data = await _post('/chat/completions', json={
        'model': chat_model(),
        'messages': messages,
        'temperature': 0.4,
        'max_completion_tokens': 1000,
        'reasoning_effort': 'low',
    })
    text = (data['choices'][0]['message'].get('content') or '').strip()
    if not text:
        raise OrbiUnavailable('ERROR', 'Respuesta vacía')
    return text


# --- Voz de Orbi (Gemini TTS) ------------------------------------------------

GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta'
MAX_SPEECH_CHARS = 2000

def gemini_key():
    return os.environ.get('GEMINI_API_KEY', '').strip()


def speech_configured():
    return bool(gemini_key())


def speech_model():
    return os.environ.get('GEMINI_TTS_MODEL', 'gemini-3.8-flash-lite-tts')


def speech_voice():
    return os.environ.get('GEMINI_TTS_VOICE', 'Sulafat')


def pcm_to_wav(pcm, rate=24000, channels=1, bits=16):
    """Envuelve PCM lineal en una cabecera WAV."""
    block = channels * bits // 8
    header = b''.join([
        b'RIFF', (36 + len(pcm)).to_bytes(4, 'little'), b'WAVEfmt ',
        (16).to_bytes(4, 'little'), (1).to_bytes(2, 'little'), channels.to_bytes(2, 'little'),
        rate.to_bytes(4, 'little'), (rate * block).to_bytes(4, 'little'),
        block.to_bytes(2, 'little'), bits.to_bytes(2, 'little'),
        b'data', len(pcm).to_bytes(4, 'little'),
    ])
    return header + pcm


async def speech(text, language):
    """Audio WAV de `text` con la voz de Gemini (`language` queda para registro; el modelo detecta el idioma)."""
    if not speech_configured():
        raise OrbiUnavailable('SIN_CLAVE')
    body = {
        # Solo el texto: los modelos TTS leen en voz alta cualquier instrucción
        # de estilo y no admiten instrucciones de sistema. El tono lo da la voz.
        'contents': [{'parts': [{'text': text[:MAX_SPEECH_CHARS]}]}],
        'generationConfig': {
            'responseModalities': ['AUDIO'],
            'speechConfig': {'voiceConfig': {'prebuiltVoiceConfig': {'voiceName': speech_voice()}}},
        },
    }
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(60, connect=5)) as client:
            response = await client.post(f'{GEMINI_BASE}/models/{speech_model()}:generateContent',
                                         headers={'x-goog-api-key': gemini_key()}, json=body)
    except httpx.HTTPError as error:
        raise OrbiUnavailable('ERROR', f'Gemini no responde: {type(error).__name__}') from error
    if response.status_code >= 400:
        raise OrbiUnavailable('ERROR', f'Gemini respondió {response.status_code}')
    try:
        part = response.json()['candidates'][0]['content']['parts'][0]['inlineData']
        audio = base64.b64decode(part['data'])
    except (KeyError, IndexError, ValueError) as error:
        raise OrbiUnavailable('ERROR', 'Gemini no devolvió audio') from error
    if audio[:4] == b'RIFF':
        return audio
    # PCM crudo (audio/L16;rate=24000 o audio/pcm): se añade la cabecera WAV.
    mime = part.get('mimeType', '')
    rate = int(mime.split('rate=')[1].split(';')[0]) if 'rate=' in mime else 24000
    return pcm_to_wav(audio, rate=rate)


async def transcribe(audio, language):
    if len(audio) > MAX_AUDIO_BYTES:
        raise OrbiUnavailable('ERROR', 'Audio demasiado grande')
    data = await _post(
        '/audio/transcriptions',
        files={'file': ('orbi.wav', audio, 'audio/wav')},
        data={'model': stt_model(), 'language': language, 'response_format': 'json', 'temperature': '0'},
    )
    return (data.get('text') or '').strip()
