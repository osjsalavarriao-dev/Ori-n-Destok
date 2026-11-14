"""Reglas de semáforo por indicador.

Rangos orientativos para adultos sanos en reposo, tomados de guías clínicas
generales (AHA para presión arterial, ADA para glucosa) y adaptados a la
demostración. No es un algoritmo clínico validado. Los mismos rangos están en
frontend_flutter/lib/models/health_knowledge.dart; si cambias uno, cambia el otro.
"""

GOOD, WATCH, CRITICAL = 'good', 'watch', 'critical'


def _band(value, good, watch):
    """good/watch son tuplas (mín, máx) inclusivas; fuera de watch es crítico."""
    if value is None:
        return None
    if good[0] <= value <= good[1]:
        return GOOD
    if watch[0] <= value <= watch[1]:
        return WATCH
    return CRITICAL


RULES = {
    'frecuencia_cardiaca': dict(good=(50, 100), watch=(40, 120),
        watch_msg='Frecuencia cardíaca fuera del rango habitual. Descansa 5 minutos sentado y repite la medición.',
        critical_msg='Frecuencia cardíaca muy alterada. Detén la actividad, repite la medición y avisa al médico de vuelo.'),
    'spo2': dict(good=(95, 100), watch=(92, 94.9),
        watch_msg='Oxigenación algo baja. Respira profundo, revisa el sensor y verifica el nivel de CO₂ de la cabina.',
        critical_msg='Oxigenación crítica. Verifica la lectura, revisa el soporte vital de cabina y avisa al médico de vuelo.'),
    'hrv': dict(good=(40, 200), watch=(25, 39.9),
        watch_msg='Variabilidad cardíaca reducida: posible estrés o fatiga. Prioriza descanso y una pausa de respiración.',
        critical_msg='Variabilidad cardíaca muy baja: estrés o fatiga elevados. Reduce la carga de trabajo y repórtalo en la conferencia médica.'),
    'temperatura_corporal': dict(good=(36.1, 37.5), watch=(35.5, 38.0),
        watch_msg='Temperatura fuera de lo habitual. Hidrátate, ajusta la ropa y repite la medición en 30 minutos.',
        critical_msg='Temperatura crítica (posible fiebre o hipotermia). Aísla síntomas, repite la medición y avisa al médico de vuelo.'),
    'presion_sistolica': dict(good=(90, 129), watch=(80, 139),
        watch_msg='Presión sistólica elevada o baja. Repite sentado tras 5 minutos de reposo y reduce la sal.',
        critical_msg='Presión sistólica en rango de riesgo. Repite la medición y avisa al médico de vuelo.'),
    'presion_diastolica': dict(good=(60, 79), watch=(50, 89),
        watch_msg='Presión diastólica fuera del rango ideal. Repite la medición en reposo.',
        critical_msg='Presión diastólica en rango de riesgo. Repite la medición y avisa al médico de vuelo.'),
    'glucosa': dict(good=(70, 99), watch=(54, 125),
        watch_msg='Glucosa fuera del rango en ayunas. Revisa tu última comida y repite la medición.',
        critical_msg='Glucosa crítica. Si es baja, toma 15 g de carbohidratos rápidos; en ambos casos avisa al médico de vuelo.'),
}


def status(metric, value):
    rule = RULES.get(metric)
    return _band(value, rule['good'], rule['watch']) if rule else None


def evaluate(sample):
    """Devuelve una alerta por cada métrica fuera del rango verde."""
    alerts = []
    for metric, rule in RULES.items():
        level = status(metric, sample.get(metric))
        if level in (WATCH, CRITICAL):
            alerts.append(dict(
                timestamp_utc=sample['timestamp_utc'],
                nivel_severidad='CRITICAL' if level == CRITICAL else 'WARNING',
                metrica_afectada=metric,
                valor_detectado=sample[metric],
                recomendacion_entregada=rule['critical_msg' if level == CRITICAL else 'watch_msg'],
                modo_generacion='OFFLINE_ALGO'))
    return alerts
