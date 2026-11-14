import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';

/// Base de conocimiento de indicadores y regiones del cuerpo, en español e inglés.
///
/// Los rangos son orientativos para adultos sanos en reposo (AHA para presión
/// arterial, ADA para glucosa) y se usan solo como demostración; no son
/// criterios clínicos validados. Los mismos rangos están en
/// backend_fastapi/app/algorithms.py; si cambias uno, cambia el otro.

enum HealthStatus { good, watch, critical, unknown }

extension HealthStatusInfo on HealthStatus {
  Color get color => switch (this) {
    HealthStatus.good => const Color(0xFF4ADE80),
    HealthStatus.watch => const Color(0xFFFACC15),
    HealthStatus.critical => const Color(0xFFF87171),
    HealthStatus.unknown => const Color(0xFF64748B),
  };
  T get label => switch (this) {
    HealthStatus.good => const T('Normal', 'Normal'),
    HealthStatus.watch => const T('Vigilar', 'Watch'),
    HealthStatus.critical => const T('Crítico', 'Critical'),
    HealthStatus.unknown => const T('Sin datos', 'No data'),
  };
  IconData get icon => switch (this) {
    HealthStatus.good => Icons.check_circle_outline,
    HealthStatus.watch => Icons.error_outline,
    HealthStatus.critical => Icons.warning_amber_rounded,
    HealthStatus.unknown => Icons.help_outline,
  };

  /// Qué hacer según el nivel: autocuidado, vigilar o escalar a Tierra.
  T get escalation => switch (this) {
    HealthStatus.good => const T(
      'Sin acción: mantén tu rutina.',
      'No action needed: keep your routine.',
    ),
    HealthStatus.watch => const T(
      'Autocuidado: aplica las recomendaciones y repite la medición. Si se mantiene 24 h, coméntalo en la conferencia médica privada.',
      'Self-care: follow the recommendations and repeat the measurement. If it persists for 24 h, raise it at your private medical conference.',
    ),
    HealthStatus.critical => const T(
      'Avisa ahora a tu compañero de tripulación y al médico de vuelo (flight surgeon). Repite la medición para descartar un error del sensor.',
      'Tell a crewmate and the flight surgeon now. Repeat the measurement to rule out a sensor error.',
    ),
    HealthStatus.unknown => const T(
      'Registra una medición para evaluar este indicador.',
      'Log a measurement to assess this indicator.',
    ),
  };
  int get severity => index == 3 ? -1 : index;
}

HealthStatus worstOf(Iterable<HealthStatus> statuses) {
  var worst = HealthStatus.unknown;
  for (final s in statuses) {
    if (s.severity > worst.severity) worst = s;
  }
  return worst;
}

/// Los 5 peligros (hazards) del vuelo espacial según el Programa de Investigación
/// Humana (HRP) de la NASA: las causas. Los 17 riesgos (consecuencias para la
/// salud) están en hrp_catalog.dart.
enum SpaceHazard { radiation, isolation, distance, gravity, environment }

extension SpaceHazardInfo on SpaceHazard {
  T get label => switch (this) {
    SpaceHazard.radiation => const T('Radiación espacial', 'Space radiation'),
    SpaceHazard.isolation => const T('Aislamiento y confinamiento', 'Isolation and confinement'),
    SpaceHazard.distance => const T('Distancia de la Tierra', 'Distance from Earth'),
    SpaceHazard.gravity => const T('Campos gravitatorios alterados', 'Altered gravity fields'),
    SpaceHazard.environment => const T('Entorno cerrado y hostil', 'Hostile, closed environment'),
  };
  T get description => switch (this) {
    SpaceHazard.radiation => const T(
      'Partículas de alta energía (rayos cósmicos y eventos solares) que dañan el ADN. Aumentan el riesgo de cáncer, cataratas, enfermedad cardiovascular y daño en el sistema nervioso.',
      'High-energy particles (cosmic rays and solar events) that damage DNA. They raise the risk of cancer, cataracts, cardiovascular disease and nervous system damage.',
    ),
    SpaceHazard.isolation => const T(
      'Vivir meses en un espacio pequeño con pocas personas causa estrés, mal sueño, cambios de ánimo y conflictos. Afecta al rendimiento y a la toma de decisiones.',
      'Living for months in a small space with few people causes stress, poor sleep, mood changes and conflict. It affects performance and decision-making.',
    ),
    SpaceHazard.distance => const T(
      'Cuanto más lejos de la Tierra, más retraso en las comunicaciones y menos posibilidad de evacuación. Marte está en promedio a unos 225 millones de km y una misión duraría unos 3 años, frente a 3 días para llegar a la Luna. La tripulación debe ser autónoma en lo médico.',
      'The farther from Earth, the longer the communication delay and the fewer the evacuation options. Mars is on average about 140 million miles away, and a mission would take about 3 years, compared with 3 days to reach the Moon. The crew must be medically self-reliant.',
    ),
    SpaceHazard.gravity => const T(
      'La microgravedad o la gravedad parcial causan pérdida de hueso y músculo, desplazan líquidos hacia la cabeza, alteran la visión y desacondicionan el corazón.',
      'Microgravity or partial gravity cause bone and muscle loss, shift fluids toward the head, affect vision and decondition the heart.',
    ),
    SpaceHazard.environment => const T(
      'Aire, agua y temperatura controlados por máquinas: acumulación de CO₂, ruido, microbios y polvo. Un fallo del soporte vital afecta a toda la tripulación.',
      'Air, water and temperature are controlled by machines: CO₂ buildup, noise, microbes and dust. A life-support failure affects the whole crew.',
    ),
  };
  IconData get icon => switch (this) {
    SpaceHazard.radiation => Icons.flare,
    SpaceHazard.isolation => Icons.person_off_outlined,
    SpaceHazard.distance => Icons.public,
    SpaceHazard.gravity => Icons.south,
    SpaceHazard.environment => Icons.air,
  };
}

typedef Band = (double, double);

class HealthIndicator {
  const HealthIndicator({
    required this.id,
    required this.name,
    required this.unit,
    required this.icon,
    required this.color,
    required this.good,
    required this.watch,
    required this.normalRange,
    required this.what,
    required this.howToMeasure,
    required this.spaceEffect,
    required this.hazards,
    required this.actions,
    this.decimals = 0,
    this.baselineTolerance = .1,
  });
  final String id;
  final T name, unit, normalRange, what, howToMeasure, spaceEffect;
  final IconData icon;
  final Color color;
  final Band good, watch;
  final List<SpaceHazard> hazards;
  final List<T> actions;
  final int decimals;

  /// Cambio relativo frente a la línea base personal que merece atención.
  final double baselineTolerance;

  HealthStatus status(double? value) {
    if (value == null) return HealthStatus.unknown;
    if (value >= good.$1 && value <= good.$2) return HealthStatus.good;
    if (value >= watch.$1 && value <= watch.$2) return HealthStatus.watch;
    return HealthStatus.critical;
  }

  String format(double? value) =>
      value == null ? '—' : value.toStringAsFixed(decimals);
}

const indicators = <HealthIndicator>[
  HealthIndicator(
    id: 'frecuencia_cardiaca',
    name: T('Frecuencia cardíaca', 'Heart rate'),
    unit: T('BPM', 'BPM'),
    icon: Icons.favorite_outline,
    color: Color(0xFF38BDF8),
    good: (50, 100),
    watch: (40, 120),
    normalRange: T('50–100 BPM en reposo', '50–100 BPM at rest'),
    what: T(
      'Cuántas veces late tu corazón por minuto.',
      'How many times your heart beats per minute.',
    ),
    howToMeasure: T(
      'Sensor de pecho o de muñeca, o contando el pulso en la muñeca durante 30 s y multiplicando por 2. Mide en reposo, sentado, 5 minutos después de cualquier ejercicio.',
      'Chest or wrist sensor, or count your wrist pulse for 30 s and multiply by 2. Measure at rest, seated, 5 minutes after any exercise.',
    ),
    spaceEffect: T(
      'En microgravedad los líquidos suben hacia la cabeza y el corazón trabaja con menos carga, así que se atrofia ligeramente. Al volver a la gravedad aparece taquicardia al ponerse de pie (intolerancia ortostática).',
      'In microgravity, fluids shift toward the head and the heart works under less load, so it atrophies slightly. Back in gravity, standing up can cause a racing heart (orthostatic intolerance).',
    ),
    hazards: [SpaceHazard.gravity, SpaceHazard.isolation],
    actions: [
      T(
        'Respira lento: 4 s inspirar, 6 s espirar, durante 2 minutos.',
        'Breathe slowly: 4 s in, 6 s out, for 2 minutes.',
      ),
      T(
        'Hidrátate y revisa si tomaste cafeína.',
        'Drink water and check whether you had caffeine.',
      ),
      T(
        'Cumple tu sesión diaria de ejercicio aeróbico (bicicleta o cinta).',
        'Complete your daily aerobic exercise session (cycle or treadmill).',
      ),
    ],
  ),
  HealthIndicator(
    id: 'spo2',
    name: T('Oxigenación', 'Oxygen saturation'),
    unit: T('SpO₂ %', 'SpO₂ %'),
    icon: Icons.water_drop_outlined,
    color: Color(0xFF62DDB0),
    good: (95, 100),
    watch: (92, 94.9),
    normalRange: T('95–100 %', '95–100 %'),
    what: T(
      'Porcentaje de hemoglobina de tu sangre que transporta oxígeno.',
      'Percentage of the hemoglobin in your blood that is carrying oxygen.',
    ),
    howToMeasure: T(
      'Oxímetro de pulso en el dedo, con la mano quieta y caliente. Retira el esmalte de uñas.',
      'Pulse oximeter on a finger, with the hand still and warm. Remove any nail polish.',
    ),
    spaceEffect: T(
      'Una SpO₂ baja puede indicar un problema en tu cuerpo o en la cabina: fallo del soporte vital, acumulación de CO₂ o hipoxia en una actividad extravehicular.',
      'Low SpO₂ may point to a problem in your body or in the cabin: a life-support failure, CO₂ buildup or hypoxia during a spacewalk.',
    ),
    hazards: [SpaceHazard.environment, SpaceHazard.distance],
    actions: [
      T(
        'Repite la medición para descartar un error del sensor.',
        'Repeat the measurement to rule out a sensor error.',
      ),
      T(
        'Revisa los niveles de O₂ y CO₂ de la cabina y la ventilación de tu zona.',
        'Check cabin O₂ and CO₂ levels and the ventilation in your area.',
      ),
      T(
        'Si tienes falta de aire o confusión, usa la máscara de oxígeno según el protocolo.',
        'If you are short of breath or confused, use the oxygen mask per protocol.',
      ),
    ],
    decimals: 1,
    baselineTolerance: .02,
  ),
  HealthIndicator(
    id: 'hrv',
    name: T('Variabilidad cardíaca', 'Heart rate variability'),
    unit: T('HRV · ms', 'HRV · ms'),
    icon: Icons.monitor_heart_outlined,
    color: Color(0xFFA99AFB),
    good: (40, 200),
    watch: (25, 39.9),
    normalRange: T(
      '≥ 40 ms (RMSSD; compárala con tu propia línea base)',
      '≥ 40 ms (RMSSD; compare it with your own baseline)',
    ),
    what: T(
      'Variación del tiempo entre latidos. Una HRV alta indica que tu cuerpo se recupera bien; una baja indica estrés o fatiga.',
      'Variation in the time between heartbeats. High HRV means your body is recovering well; low HRV points to stress or fatigue.',
    ),
    howToMeasure: T(
      'Sensor de pecho, acostado y al despertar, durante 2–5 minutos. Compara siempre con tus propios valores, no con los de otra persona.',
      'Chest sensor, lying down right after waking, for 2–5 minutes. Always compare with your own values, not someone else\'s.',
    ),
    spaceEffect: T(
      'El estrés, la mala calidad del sueño y el confinamiento reducen la HRV. Sirve como alerta temprana de fatiga y sobrecarga.',
      'Stress, poor sleep and confinement lower HRV. It works as an early warning of fatigue and overload.',
    ),
    hazards: [SpaceHazard.isolation, SpaceHazard.environment],
    actions: [
      T(
        'Haz una pausa de respiración guiada de 5 minutos.',
        'Take a 5-minute guided breathing break.',
      ),
      T(
        'Prioriza el sueño esta noche y reduce la carga de trabajo si puedes.',
        'Prioritize sleep tonight and lighten your workload if you can.',
      ),
      T(
        'Habla con tu tripulación o pide una conferencia psicológica privada.',
        'Talk to your crew or request a private psychological conference.',
      ),
    ],
    baselineTolerance: .15,
  ),
  HealthIndicator(
    id: 'temperatura_corporal',
    name: T('Temperatura', 'Temperature'),
    unit: T('°C', '°C'),
    icon: Icons.thermostat_outlined,
    color: Color(0xFFF3C784),
    good: (36.1, 37.5),
    watch: (35.5, 38.0),
    normalRange: T('36,1–37,5 °C', '36.1–37.5 °C'),
    what: T('Temperatura interna del cuerpo.', 'Core body temperature.'),
    howToMeasure: T(
      'Termómetro de oído o sensor frontal, en reposo y lejos del ejercicio.',
      'Ear thermometer or forehead sensor, at rest and away from exercise.',
    ),
    spaceEffect: T(
      'En el espacio la temperatura corporal tiende a subir porque el calor se disipa peor sin convección natural ("fiebre espacial"). Además, el sistema inmunitario se debilita y algunos virus latentes, como el herpes, pueden reactivarse.',
      'In space, body temperature tends to rise because heat dissipates poorly without natural convection ("space fever"). The immune system also weakens, and some latent viruses, such as herpes, can reactivate.',
    ),
    hazards: [SpaceHazard.environment, SpaceHazard.radiation],
    actions: [
      T(
        'Hidrátate y ajusta tu ropa o la ventilación.',
        'Drink water and adjust your clothing or ventilation.',
      ),
      T('Repite la medición en 30 minutos.', 'Repeat the measurement in 30 minutes.'),
      T(
        'Si tienes fiebre, usa mascarilla y limita el contacto para proteger a la tripulación.',
        'If you have a fever, wear a mask and limit contact to protect the crew.',
      ),
    ],
    decimals: 1,
    baselineTolerance: .01,
  ),
  HealthIndicator(
    id: 'presion_sistolica',
    name: T('Presión arterial', 'Blood pressure'),
    unit: T('mmHg', 'mmHg'),
    icon: Icons.speed,
    color: Color(0xFFFB7185),
    good: (90, 129),
    watch: (80, 139),
    normalRange: T(
      'Menos de 130/80 mmHg, y sistólica de al menos 90',
      'Below 130/80 mmHg, with systolic of at least 90',
    ),
    what: T(
      'Fuerza de la sangre contra las arterias: sistólica (cuando el corazón late) y diastólica (cuando descansa).',
      'Force of blood against the arteries: systolic (when the heart beats) and diastolic (when it rests).',
    ),
    howToMeasure: T(
      'Tensiómetro de brazo. Siéntate 5 minutos antes, apoya el brazo a la altura del corazón y no hables durante la medición.',
      'Upper-arm cuff. Sit for 5 minutes first, rest your arm at heart level and don\'t talk during the measurement.',
    ),
    spaceEffect: T(
      'La redistribución de líquidos y la rigidez arterial causada por la radiación pueden alterar la presión arterial. La presión baja al ponerse de pie es un riesgo al volver a la gravedad o al llegar a otro planeta.',
      'Fluid shifts and radiation-induced arterial stiffness can change blood pressure. Low pressure on standing is a risk when returning to gravity or landing on another planet.',
    ),
    hazards: [SpaceHazard.gravity, SpaceHazard.radiation],
    actions: [
      T(
        'Repite la medición tras 5 minutos de reposo.',
        'Repeat the measurement after 5 minutes of rest.',
      ),
      T(
        'Reduce la sal: la comida espacial suele contener mucha.',
        'Cut down on salt: space food is often high in it.',
      ),
      T(
        'Si la tienes baja, hidrátate y levántate despacio.',
        'If it is low, drink water and stand up slowly.',
      ),
    ],
  ),
  HealthIndicator(
    id: 'presion_diastolica',
    name: T('Presión diastólica', 'Diastolic pressure'),
    unit: T('mmHg', 'mmHg'),
    icon: Icons.speed,
    color: Color(0xFFFB7185),
    good: (60, 79),
    watch: (50, 89),
    normalRange: T('60–79 mmHg', '60–79 mmHg'),
    what: T('Presión en las arterias entre latidos.', 'Pressure in the arteries between heartbeats.'),
    howToMeasure: T(
      'Se obtiene en la misma medición que la sistólica.',
      'Taken in the same measurement as the systolic value.',
    ),
    spaceEffect: T('Ver presión arterial.', 'See blood pressure.'),
    hazards: [SpaceHazard.gravity],
    actions: [
      T('Ver recomendaciones de presión arterial.', 'See the blood pressure recommendations.'),
    ],
  ),
  HealthIndicator(
    id: 'glucosa',
    name: T('Glucosa en sangre', 'Blood glucose'),
    unit: T('mg/dL', 'mg/dL'),
    icon: Icons.bloodtype_outlined,
    color: Color(0xFFFDBA74),
    good: (70, 99),
    watch: (54, 125),
    normalRange: T('70–99 mg/dL en ayunas', '70–99 mg/dL fasting'),
    what: T(
      'Cantidad de azúcar en tu sangre, la principal fuente de energía.',
      'Amount of sugar in your blood, your main source of energy.',
    ),
    howToMeasure: T(
      'Glucómetro con una gota de sangre del dedo, en ayunas (8 h sin comer) o 2 h después de comer.',
      'Glucose meter with a drop of blood from a finger, fasting (8 h without food) or 2 h after a meal.',
    ),
    spaceEffect: T(
      'La inactividad muscular en microgravedad reduce la sensibilidad a la insulina. El estrés y la dieta de misión también alteran la glucosa.',
      'Muscle inactivity in microgravity reduces insulin sensitivity. Stress and the mission diet also affect glucose.',
    ),
    hazards: [SpaceHazard.gravity, SpaceHazard.distance],
    actions: [
      T(
        'Si es baja (< 70): toma 15 g de carbohidratos rápidos y repite la medición en 15 minutos.',
        'If low (< 70): take 15 g of fast-acting carbohydrates and measure again in 15 minutes.',
      ),
      T(
        'Si es alta: revisa tu última comida y cumple el ejercicio programado.',
        'If high: review your last meal and do your scheduled exercise.',
      ),
      T(
        'Sigue el plan de comidas para tus calorías objetivo.',
        'Follow the meal plan for your calorie target.',
      ),
    ],
  ),
  HealthIndicator(
    id: 'horas_sueno',
    name: T('Sueño', 'Sleep'),
    unit: T('horas', 'hours'),
    icon: Icons.bedtime_outlined,
    color: Color(0xFF818CF8),
    good: (7, 9),
    watch: (6, 10),
    normalRange: T('7–9 horas', '7–9 hours'),
    what: T('Horas que dormiste la noche anterior.', 'Hours you slept last night.'),
    howToMeasure: T(
      'Regístralo cada mañana en «Historial y sync». Un reloj con actigrafía puede medirlo de forma automática.',
      'Log it every morning in "History & sync". An actigraphy watch can measure it automatically.',
    ),
    spaceEffect: T(
      'En órbita hay unas 16 salidas de sol al día, ruido constante y estrés. Los astronautas en la EEI duermen en promedio unas 6 horas, y la falta de sueño aumenta los errores.',
      'In orbit there are about 16 sunrises a day, constant noise and stress. Astronauts on the ISS sleep about 6 hours on average, and sleep loss increases errors.',
    ),
    hazards: [SpaceHazard.isolation, SpaceHazard.environment],
    actions: [
      T(
        'Usa antifaz y tapones, y evita las pantallas 1 hora antes de dormir.',
        'Use an eye mask and earplugs, and avoid screens for 1 hour before bed.',
      ),
      T(
        'Mantén un horario fijo y usa la iluminación de la cabina que regula el ritmo circadiano.',
        'Keep a fixed schedule and use the cabin\'s circadian lighting.',
      ),
      T('Evita la cafeína después de mediodía.', 'Avoid caffeine after midday.'),
    ],
    decimals: 1,
    baselineTolerance: .15,
  ),
  HealthIndicator(
    id: 'animo',
    name: T('Estado de ánimo', 'Mood'),
    unit: T('de 1 a 5', '1 to 5'),
    icon: Icons.mood,
    color: Color(0xFF2DD4BF),
    good: (4, 5),
    watch: (3, 3),
    normalRange: T('4–5', '4–5'),
    what: T(
      'Cómo te sientes hoy, del 1 (muy mal) al 5 (muy bien).',
      'How you feel today, from 1 (very bad) to 5 (very good).',
    ),
    howToMeasure: T(
      'Regístralo con sinceridad cada día en «Historial y sync». La tendencia importa más que un solo día.',
      'Log it honestly every day in "History & sync". The trend matters more than any single day.',
    ),
    spaceEffect: T(
      'El aislamiento, el confinamiento y la lejanía de la familia pueden causar ánimo bajo, irritabilidad y conflictos. Detectarlo pronto es clave en misiones largas.',
      'Isolation, confinement and distance from family can cause low mood, irritability and conflict. Catching it early is key on long missions.',
    ),
    hazards: [SpaceHazard.isolation, SpaceHazard.distance],
    actions: [
      T(
        'Llama o escribe a tu familia en el próximo enlace disponible.',
        'Call or write to your family at the next available link.',
      ),
      T(
        'Haz una actividad de ocio: música, mirar la Tierra, fotografía.',
        'Do something you enjoy: music, Earth-gazing, photography.',
      ),
      T(
        'Si el ánimo bajo dura 3 días o más, pide una conferencia psicológica privada.',
        'If low mood lasts 3 days or more, request a private psychological conference.',
      ),
    ],
    baselineTolerance: .2,
  ),
];

HealthIndicator indicator(String id) => indicators.firstWhere((i) => i.id == id);

/// Síntoma de una autoevaluación. Si el astronauta lo marca, la zona pasa a
/// "Vigilar" y se muestra [advice].
class Symptom {
  const Symptom(this.id, this.question, this.advice);
  final String id;
  final T question, advice;
}

/// Región del cuerpo interactiva en el mapa corporal.
class BodyRegion {
  const BodyRegion({
    required this.id,
    required this.name,
    required this.function,
    required this.spaceEffect,
    required this.prevention,
    required this.indicatorIds,
    required this.hazards,
    this.symptoms = const [],
    this.earthBenefit,
  });
  final String id;
  final T name, function, spaceEffect;
  final List<T> prevention;
  final List<String> indicatorIds;
  final List<SpaceHazard> hazards;

  /// Autoevaluación para zonas sin sensor (p. ej. visión, equilibrio).
  final List<Symptom> symptoms;

  /// Qué aporta estudiar esta zona en el espacio a la medicina en la Tierra
  /// (Agencia Espacial Canadiense).
  final T? earthBenefit;
}

const bodyRegions = <BodyRegion>[
  BodyRegion(
    id: 'brain',
    name: T('Cerebro y salud mental', 'Brain and mental health'),
    function: T(
      'Controla el pensamiento, las emociones y el sueño.',
      'Controls thinking, emotions and sleep.',
    ),
    spaceEffect: T(
      'El aislamiento, el confinamiento, la radiación y la distancia a la Tierra pueden afectar la salud mental. La falta crónica de sueño y los horarios irregulares alteran el reloj biológico.',
      'Isolation, confinement, radiation and distance from Earth can affect mental health. Chronic sleep loss and irregular schedules disrupt the body clock.',
    ),
    prevention: [
      T('Duerme de 7 a 9 horas con un horario fijo.', 'Sleep 7 to 9 hours on a fixed schedule.'),
      T(
        'Mantén el contacto con tu familia y tu tripulación.',
        'Stay in touch with your family and your crew.',
      ),
      T(
        'Reserva tiempo diario para el ocio y la autoevaluación del ánimo.',
        'Set aside daily time for leisure and a mood check-in.',
      ),
    ],
    indicatorIds: ['animo', 'horas_sueno'],
    hazards: [SpaceHazard.isolation, SpaceHazard.radiation, SpaceHazard.distance],
  ),
  BodyRegion(
    id: 'eyes',
    name: T('Ojos y visión (SANS)', 'Eyes and vision (SANS)'),
    function: T(
      'Captan la imagen; el nervio óptico la lleva al cerebro.',
      'Capture images; the optic nerve carries them to the brain.',
    ),
    spaceEffect: T(
      'El síndrome neuro-ocular asociado al vuelo espacial (SANS) cambia la estructura del ojo y del cerebro. NASA lo considera su principal riesgo de salud del vuelo espacial. Se relaciona con el desplazamiento de líquidos hacia la cabeza en microgravedad.',
      'Spaceflight Associated Neuro-ocular Syndrome (SANS) changes the structure of the eye and brain. NASA calls it its leading spaceflight-related health risk. It is linked to fluids shifting toward the head in microgravity.',
    ),
    prevention: [
      T(
        'Haz la autoevaluación de visión cada semana y en cada examen ocular programado.',
        'Do the vision self-check every week and at every scheduled eye exam.',
      ),
      T(
        'Usa las gafas de visión de cerca de reserva si lo indica el médico de vuelo.',
        'Use the spare near-vision glasses if the flight surgeon tells you to.',
      ),
      T(
        'Sigue las contramedidas que te asignen (en estudio: brazaletes de muslo, vitaminas B).',
        'Follow any assigned countermeasures (under study: thigh cuffs, B vitamins).',
      ),
    ],
    indicatorIds: [],
    hazards: [SpaceHazard.gravity],
    symptoms: [
      Symptom(
        'blurred_near',
        T('¿Ves borroso de cerca (leer, pantallas)?', 'Is your near vision blurry (reading, screens)?'),
        T(
          'Visión de cerca borrosa: es un signo típico de SANS. Coméntalo con el médico de vuelo en la próxima conferencia.',
          'Blurry near vision: a typical sign of SANS. Raise it with the flight surgeon at the next conference.',
        ),
      ),
      Symptom(
        'visual_spots',
        T('¿Notas manchas, sombras o una zona ciega?', 'Do you notice spots, shadows or a blind area?'),
        T(
          'Manchas o zonas ciegas: avisa al médico de vuelo para un examen ocular.',
          'Spots or blind areas: tell the flight surgeon so they can schedule an eye exam.',
        ),
      ),
      Symptom(
        'headache',
        T('¿Tienes dolor de cabeza persistente?', 'Do you have a persistent headache?'),
        T(
          'Dolor de cabeza persistente: revisa el CO₂ de la cabina y coméntalo al médico de vuelo.',
          'Persistent headache: check cabin CO₂ and tell the flight surgeon.',
        ),
      ),
    ],
  ),
  BodyRegion(
    id: 'vestibular',
    name: T('Oído interno y equilibrio', 'Inner ear and balance'),
    function: T(
      'El oído interno detecta la gravedad y el movimiento para mantener el equilibrio y la coordinación.',
      'The inner ear senses gravity and motion to keep balance and coordination.',
    ),
    spaceEffect: T(
      'En cada cambio de gravedad (llegar a la órbita, a la Luna o a Marte, o volver a la Tierra) pueden aparecer mareo, náuseas y problemas de coordinación.',
      'Every gravity change (reaching orbit, the Moon or Mars, or returning to Earth) can bring motion sickness, nausea and coordination problems.',
    ),
    prevention: [
      T(
        'Durante los primeros días tras un cambio de gravedad, muévete despacio y evita girar la cabeza bruscamente.',
        'In the first days after a gravity change, move slowly and avoid sudden head turns.',
      ),
      T(
        'No hagas tareas críticas (pilotaje, EVA) si tienes mareo.',
        'Avoid critical tasks (piloting, EVA) while you feel dizzy.',
      ),
      T(
        'Usa la medicación contra el mareo según el protocolo de la misión.',
        'Use motion-sickness medication according to the mission protocol.',
      ),
    ],
    indicatorIds: [],
    hazards: [SpaceHazard.gravity],
    symptoms: [
      Symptom(
        'dizziness',
        T('¿Sientes mareo o vértigo?', 'Do you feel dizzy or have vertigo?'),
        T(
          'Mareo: evita tareas críticas hasta que pase y avisa a tu tripulación.',
          'Dizziness: avoid critical tasks until it passes and tell your crew.',
        ),
      ),
      Symptom(
        'nausea',
        T('¿Tienes náuseas?', 'Do you feel nauseous?'),
        T(
          'Náuseas: hidrátate en pequeños sorbos y sigue el protocolo contra el mareo.',
          'Nausea: drink small sips of water and follow the motion-sickness protocol.',
        ),
      ),
      Symptom(
        'coordination',
        T('¿Te cuesta coordinar movimientos o calcular distancias?', 'Is it hard to coordinate movements or judge distances?'),
        T(
          'Problemas de coordinación: no pilotes ni salgas a una EVA; repite la evaluación más tarde.',
          'Coordination problems: do not pilot or go on an EVA; check again later.',
        ),
      ),
    ],
    earthBenefit: T(
      'Ayuda a entender los problemas de equilibrio, por ejemplo en personas mayores.',
      'Helps us understand balance problems, for example in older adults.',
    ),
  ),
  BodyRegion(
    id: 'lungs',
    name: T('Pulmones y oxigenación', 'Lungs and oxygenation'),
    function: T(
      'Llevan oxígeno a la sangre y eliminan el CO₂.',
      'Bring oxygen into the blood and remove CO₂.',
    ),
    spaceEffect: T(
      'El aire de la cabina se recicla y un CO₂ alto causa dolor de cabeza y fatiga. En las EVA hay riesgo de hipoxia leve, un efecto de las medidas para evitar la descompresión. El polvo lunar o marciano irrita los pulmones.',
      'Cabin air is recycled, and high CO₂ causes headaches and fatigue. During EVAs there is a risk of mild hypoxia, a side effect of the steps taken to avoid decompression sickness. Lunar or Martian dust irritates the lungs.',
    ),
    prevention: [
      T('Mantén ventilada tu zona de descanso.', 'Keep your sleeping area ventilated.'),
      T(
        'Informa de síntomas como dolor de cabeza o falta de aire.',
        'Report symptoms such as headache or shortness of breath.',
      ),
      T(
        'Usa protección respiratoria al manipular regolito.',
        'Wear respiratory protection when handling regolith.',
      ),
    ],
    indicatorIds: ['spo2'],
    hazards: [SpaceHazard.environment],
  ),
  BodyRegion(
    id: 'heart',
    name: T('Corazón y circulación', 'Heart and circulation'),
    function: T(
      'Bombea sangre con oxígeno y nutrientes a todo el cuerpo.',
      'Pumps oxygen- and nutrient-rich blood through the whole body.',
    ),
    spaceEffect: T(
      'La ingravidez cambia la circulación y el funcionamiento del corazón y los vasos, y puede aumentar el riesgo de eventos cardiovasculares. También se pierde capacidad aeróbica.',
      'Weightlessness changes circulation and how the heart and vessels work, and may raise the risk of cardiovascular events. Aerobic fitness also declines.',
    ),
    prevention: [
      T(
        'Haz ejercicio aeróbico a diario (bicicleta CEVIS o cinta T2).',
        'Do aerobic exercise every day (CEVIS cycle or T2 treadmill).',
      ),
      T(
        'Toma una dieta baja en sal y bebe suficiente agua.',
        'Eat a low-salt diet and drink enough water.',
      ),
      T(
        'Mide la presión y la frecuencia cardíaca cada día en reposo.',
        'Measure blood pressure and heart rate at rest every day.',
      ),
    ],
    indicatorIds: ['frecuencia_cardiaca', 'presion_sistolica', 'presion_diastolica', 'hrv'],
    hazards: [SpaceHazard.gravity, SpaceHazard.radiation],
    earthBenefit: T(
      'Aporta conocimiento sobre enfermedades cardiovasculares.',
      'Adds to our knowledge of cardiovascular disease.',
    ),
  ),
  BodyRegion(
    id: 'metabolism',
    name: T('Metabolismo y nutrición', 'Metabolism and nutrition'),
    function: T(
      'Convierte los alimentos en energía y regula el azúcar en sangre.',
      'Turns food into energy and regulates blood sugar.',
    ),
    spaceEffect: T(
      'La inactividad reduce la sensibilidad a la insulina. Una alimentación inadecuada afecta la salud y el rendimiento, y con una dieta de misión limitada es fácil comer menos de lo necesario.',
      'Inactivity reduces insulin sensitivity. Inadequate nutrition affects health and performance, and with a limited mission diet it is easy to eat less than you need.',
    ),
    prevention: [
      T('Cumple tus calorías objetivo (unas 2800 kcal).', 'Meet your calorie target (about 2800 kcal).'),
      T('Toma vitamina D: no hay luz solar directa.', 'Take vitamin D: there is no direct sunlight.'),
      T(
        'Mide la glucosa en ayunas según el calendario de la misión.',
        'Measure fasting glucose on the mission schedule.',
      ),
    ],
    indicatorIds: ['glucosa'],
    hazards: [SpaceHazard.gravity, SpaceHazard.distance],
    earthBenefit: T(
      'Ayuda a estudiar la diabetes tipo 2 y los efectos del sedentarismo.',
      'Helps research into type 2 diabetes and the effects of a sedentary lifestyle.',
    ),
  ),
  BodyRegion(
    id: 'immune',
    name: T('Sistema inmunitario y temperatura', 'Immune system and temperature'),
    function: T(
      'Defiende al cuerpo de infecciones y mantiene la temperatura estable.',
      'Defends the body against infection and keeps temperature stable.',
    ),
    spaceEffect: T(
      'El estrés del vuelo espacial puede reactivar virus latentes y causar sarpullidos y otros síntomas. Los microbios de la piel y del intestino cambian, y en un entorno cerrado una infección se contagia a toda la tripulación.',
      'The stress of spaceflight can reactivate dormant viruses, causing rashes and other symptoms. Skin and gut microbes change, and in a closed environment an infection spreads to the whole crew.',
    ),
    prevention: [
      T(
        'Lávate las manos y desinfecta las superficies compartidas.',
        'Wash your hands and disinfect shared surfaces.',
      ),
      T('Duerme bien y controla el estrés.', 'Sleep well and manage stress.'),
      T('Mide tu temperatura si notas malestar.', 'Take your temperature if you feel unwell.'),
    ],
    indicatorIds: ['temperatura_corporal'],
    hazards: [SpaceHazard.environment, SpaceHazard.radiation, SpaceHazard.isolation],
    symptoms: [
      Symptom(
        'rash',
        T('¿Tienes sarpullido, ampollas o herpes labial?', 'Do you have a rash, blisters or cold sores?'),
        T(
          'Sarpullido o herpes: puede ser un virus latente reactivado. Evita compartir objetos y avisa al médico de vuelo.',
          'Rash or cold sores: this may be a reactivated dormant virus. Avoid sharing items and tell the flight surgeon.',
        ),
      ),
      Symptom(
        'slow_healing',
        T('¿Alguna herida tarda en cicatrizar?', 'Is any wound slow to heal?'),
        T(
          'Cicatrización lenta: limpia y cubre la herida, y vigila si aparecen signos de infección.',
          'Slow healing: clean and cover the wound, and watch for signs of infection.',
        ),
      ),
    ],
  ),
  BodyRegion(
    id: 'bones',
    name: T('Huesos y músculos', 'Bones and muscles'),
    function: T(
      'Sostienen el cuerpo, permiten el movimiento y protegen los órganos.',
      'Support the body, allow movement and protect the organs.',
    ),
    spaceEffect: T(
      'Sin carga, los huesos se debilitan y se fracturan con más facilidad, y se pierde fuerza muscular. Los huesos de cadera y piernas pierden entre un 1 y un 1,5 % de densidad al mes.',
      'Without load, bones weaken and break more easily, and muscle strength is lost. Hip and leg bones lose 1 to 1.5 % of their density per month.',
    ),
    prevention: [
      T(
        'Haz unas 2 horas diarias de ejercicio de resistencia (ARED) y de impacto.',
        'Do about 2 hours of resistance (ARED) and impact exercise a day.',
      ),
      T(
        'Toma suficiente calcio, vitamina D y proteína.',
        'Get enough calcium, vitamin D and protein.',
      ),
      T(
        'Bebe al menos 2 L de agua al día para prevenir cálculos renales.',
        'Drink at least 2 L of water a day to prevent kidney stones.',
      ),
    ],
    indicatorIds: [],
    hazards: [SpaceHazard.gravity],
    earthBenefit: T(
      'Ayuda a combatir la osteoporosis: los efectos en astronautas se parecen a un envejecimiento acelerado.',
      'Helps fight osteoporosis: the effects seen in astronauts resemble accelerated aging.',
    ),
  ),
];

BodyRegion bodyRegion(String id) => bodyRegions.firstWhere((r) => r.id == id);
