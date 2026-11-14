import random
from datetime import datetime, timedelta, timezone

def utc_now():
    return datetime.now(timezone.utc).isoformat()

def sample(anomaly=False):
    """Datos sintéticos exclusivamente; no hay sensores físicos conectados.

    La anomalía simula hipoxia leve con estrés: SpO₂ baja, taquicardia y HRV baja.
    La presión arterial y la glucosa no son continuas: van en la tabla mediciones.
    """
    return dict(timestamp_utc=utc_now(), frecuencia_cardiaca=112 if anomaly else random.randint(64, 72),
                spo2=89.0 if anomaly else round(random.uniform(97, 99), 1),
                hrv=24.0 if anomaly else round(random.uniform(45, 55), 1),
                temperatura_corporal=round(random.uniform(36.6, 36.9), 1), horas_sueno=None)


def history(days=13, now=None, seed=7):
    """Historial sintético de los días previos de misión, con tendencias plausibles
    de vuelo espacial: HRV y presión bajan, glucosa sube, sueño corto y un bajón
    de ánimo a mitad de misión. Mismas fórmulas que lib/services/demo_history.dart.

    Devuelve (telemetria, mediciones, bienestar) como listas de diccionarios.
    """
    rng = random.Random(seed)
    now = now or datetime.now(timezone.utc)
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    telemetry, measurements, wellbeing = [], [], []
    for d in range(days):
        day = today - timedelta(days=days - d)
        p = d / max(1, days - 1)
        for hour in (2, 8, 14, 20):
            telemetry.append(dict(
                timestamp_utc=(day + timedelta(hours=hour)).isoformat(),
                frecuencia_cardiaca=round(68 - 4 * p + rng.uniform(-2, 2)),
                spo2=round(98 + rng.uniform(-.5, .5), 1),
                hrv=round(55 - 11 * p + rng.uniform(-3, 3), 1),
                temperatura_corporal=round(36.7 + .2 * p + rng.uniform(-.1, .1), 1),
                horas_sueno=None))
        at = (day + timedelta(hours=7)).isoformat()
        for metric, value in (('presion_sistolica', round(120 - 8 * p + rng.uniform(-3, 3))),
                              ('presion_diastolica', round(78 - 5 * p + rng.uniform(-2, 2))),
                              ('glucosa', round(88 + 8 * p + rng.uniform(-3, 3)))):
            measurements.append(dict(timestamp_utc=at, metrica=metric, valor=value, origen='SIMULADO'))
        sleep = 5.2 if d == days - 4 else round(6.6 - .5 * p + rng.uniform(-.5, .5), 1)
        mood = 3 if .6 <= p <= .85 else 4
        wellbeing.append(dict(timestamp_utc=(day + timedelta(hours=6, minutes=30)).isoformat(),
                              horas_sueno=sleep, agua_ml=rng.choice((1500, 2000, 2500)),
                              energia=mood, animo=mood))
    return telemetry, measurements, wellbeing
