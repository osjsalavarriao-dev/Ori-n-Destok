import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import 'health_knowledge.dart';

/// Nivel de exposición a un riesgo según el entorno (no es un estado de salud).
enum Exposure { low, moderate, high }

extension ExposureInfo on Exposure {
  T get label => switch (this) {
    Exposure.low => const T('Bajo', 'Low'),
    Exposure.moderate => const T('Moderado', 'Moderate'),
    Exposure.high => const T('Alto', 'High'),
  };
  Color get color => switch (this) {
    Exposure.low => HealthStatus.good.color,
    Exposure.moderate => HealthStatus.watch.color,
    Exposure.high => HealthStatus.critical.color,
  };
}

/// Límite de dosis de radiación para toda la carrera de un astronauta (NASA-STD-3001, 2022).
const careerDoseLimitMsv = 600.0;

/// Entorno de la misión. Las tasas de dosis son valores medidos publicados y
/// aproximados; dentro de un hábitat blindado la dosis real es menor.
class MissionEnvironment {
  const MissionEnvironment({
    required this.id,
    required this.name,
    required this.icon,
    required this.gravity,
    required this.doseMsvPerDay,
    required this.doseSource,
    required this.commDelay,
    required this.evacuation,
    required this.description,
    required this.exposure,
    required this.tips,
    this.escalationNote,
  });
  final String id;
  final T name, gravity, doseSource, commDelay, evacuation, description;
  final IconData icon;
  final double doseMsvPerDay;
  final Map<SpaceHazard, Exposure> exposure;
  final List<T> tips;

  /// Qué cambia al escalar un problema cuando Tierra no responde al instante.
  final T? escalationNote;
}

const environments = <MissionEnvironment>[
  MissionEnvironment(
    id: 'iss',
    name: T('Estación espacial (órbita baja)', 'Space station (low Earth orbit)'),
    icon: Icons.satellite_alt,
    gravity: T('Microgravedad (~0 g)', 'Microgravity (~0 g)'),
    doseMsvPerDay: .5,
    doseSource: T(
      'EEI: unos 0,3–0,8 mSv/día; el campo magnético terrestre protege en parte',
      'ISS: about 0.3–0.8 mSv/day; Earth\'s magnetic field offers partial protection',
    ),
    commDelay: T('Menos de 1 s', 'Under 1 s'),
    evacuation: T(
      'Regreso a la Tierra en la cápsula en menos de 1 día',
      'Return to Earth in the capsule in under 1 day',
    ),
    description: T(
      'Hay contacto casi continuo con el control de misión y médicos de vuelo disponibles. El mayor riesgo es la microgravedad prolongada.',
      'Near-continuous contact with Mission Control and flight surgeons on call. The main risk is long-term microgravity.',
    ),
    exposure: {
      SpaceHazard.radiation: Exposure.moderate,
      SpaceHazard.isolation: Exposure.moderate,
      SpaceHazard.distance: Exposure.low,
      SpaceHazard.gravity: Exposure.high,
      SpaceHazard.environment: Exposure.moderate,
    },
    tips: [
      T(
        'Haz unas 2 h diarias de ejercicio (ARED, cinta T2, bicicleta CEVIS) para proteger huesos y corazón.',
        'Exercise about 2 h a day (ARED, T2 treadmill, CEVIS cycle) to protect bones and heart.',
      ),
      T(
        'Aprovecha las conferencias médicas privadas semanales.',
        'Make use of the weekly private medical conferences.',
      ),
      T(
        'Vigila el CO₂: en módulos poco ventilados se acumula alrededor de la cabeza.',
        'Watch CO₂: in poorly ventilated modules it builds up around your head.',
      ),
    ],
  ),
  MissionEnvironment(
    id: 'transit',
    name: T('Nave en tránsito (espacio profundo)', 'Spacecraft in transit (deep space)'),
    icon: Icons.rocket_launch,
    gravity: T('Microgravedad (~0 g)', 'Microgravity (~0 g)'),
    doseMsvPerDay: 1.8,
    doseSource: T(
      'Crucero a Marte: unos 1,8 mSv/día (MSL/RAD)',
      'Cruise to Mars: about 1.8 mSv/day (MSL/RAD)',
    ),
    commDelay: T('Luna: 1,3 s · Marte: 4–24 min', 'Moon: 1.3 s · Mars: 4–24 min'),
    evacuation: T(
      'De días (Luna) a meses (Marte): no hay regreso rápido',
      'Days (Moon) to months (Mars): no quick return',
    ),
    description: T(
      'Fuera de la magnetosfera, la radiación es la más alta. El volumen es pequeño, la tripulación está aislada y la ayuda de Tierra llega con retraso.',
      'Outside the magnetosphere, radiation is at its highest. The living volume is small, the crew is isolated and help from Earth arrives with a delay.',
    ),
    exposure: {
      SpaceHazard.radiation: Exposure.high,
      SpaceHazard.isolation: Exposure.high,
      SpaceHazard.distance: Exposure.high,
      SpaceHazard.gravity: Exposure.high,
      SpaceHazard.environment: Exposure.high,
    },
    tips: [
      T(
        'Ante una tormenta solar, ve al refugio blindado de la nave.',
        'During a solar storm, go to the spacecraft\'s shielded shelter.',
      ),
      T(
        'Haz ejercicio a diario aunque el espacio sea reducido (equipos compactos).',
        'Exercise every day even in tight quarters (compact equipment).',
      ),
      T(
        'Mantén rutinas y contacto diferido con tu familia (mensajes grabados).',
        'Keep routines and delayed contact with your family (recorded messages).',
      ),
    ],
    escalationNote: T(
      'Con el retraso de comunicación, actúa primero con el protocolo a bordo y el oficial médico de la tripulación, e informa a Tierra en paralelo.',
      'Given the communication delay, act first with the onboard protocol and the crew medical officer, and inform Earth in parallel.',
    ),
  ),
  MissionEnvironment(
    id: 'rover',
    name: T('Rover presurizado', 'Pressurized rover'),
    icon: Icons.directions_car,
    gravity: T('Gravedad lunar (0,17 g)', 'Lunar gravity (0.17 g)'),
    doseMsvPerDay: 1.4,
    doseSource: T(
      'Superficie lunar: unos 1,4 mSv/día (Chang\'e-4/LND); el rover tiene poco blindaje',
      'Lunar surface: about 1.4 mSv/day (Chang\'e-4/LND); the rover has little shielding',
    ),
    commDelay: T('1,3 s (con relé)', '1.3 s (via relay)'),
    evacuation: T('Horas hasta la base', 'Hours to the base'),
    description: T(
      'Es una cabina muy pequeña durante días de travesía. Hay polvo lunar y la ayuda médica de la base está lejos.',
      'A very small cabin for days of traverse. There is lunar dust, and medical help at the base is far away.',
    ),
    exposure: {
      SpaceHazard.radiation: Exposure.high,
      SpaceHazard.isolation: Exposure.moderate,
      SpaceHazard.distance: Exposure.moderate,
      SpaceHazard.gravity: Exposure.moderate,
      SpaceHazard.environment: Exposure.high,
    },
    tips: [
      T(
        'Limpia el traje antes de entrar: el polvo lunar irrita ojos y pulmones.',
        'Clean your suit before entering: lunar dust irritates eyes and lungs.',
      ),
      T(
        'Planifica la ruta con refugios por si hay un evento solar.',
        'Plan the route with shelters in case of a solar event.',
      ),
      T('Hidrátate: en la cabina el aire es seco.', 'Stay hydrated: cabin air is dry.'),
    ],
    escalationNote: T(
      'Si un indicador es crítico, valora volver a la base antes de continuar la travesía.',
      'If an indicator is critical, consider returning to base before continuing the traverse.',
    ),
  ),
  MissionEnvironment(
    id: 'moon',
    name: T('Base lunar', 'Lunar base'),
    icon: Icons.nightlight_round,
    gravity: T('Gravedad lunar (0,17 g)', 'Lunar gravity (0.17 g)'),
    doseMsvPerDay: 1.4,
    doseSource: T(
      'Superficie lunar: unos 1,4 mSv/día sin blindaje (Chang\'e-4/LND)',
      'Lunar surface: about 1.4 mSv/day unshielded (Chang\'e-4/LND)',
    ),
    commDelay: T('1,3 s', '1.3 s'),
    evacuation: T('Unos 3–5 días hasta la Tierra', 'About 3–5 days to Earth'),
    description: T(
      'La gravedad parcial protege algo los huesos, pero no hay magnetosfera. El regolito es abrasivo y los ciclos de luz de 14 días alteran el sueño.',
      'Partial gravity protects bones somewhat, but there is no magnetosphere. Regolith is abrasive and 14-day light cycles disrupt sleep.',
    ),
    exposure: {
      SpaceHazard.radiation: Exposure.high,
      SpaceHazard.isolation: Exposure.moderate,
      SpaceHazard.distance: Exposure.moderate,
      SpaceHazard.gravity: Exposure.moderate,
      SpaceHazard.environment: Exposure.moderate,
    },
    tips: [
      T(
        'Usa iluminación circadiana: el día lunar dura unos 14 días terrestres.',
        'Use circadian lighting: a lunar day lasts about 14 Earth days.',
      ),
      T(
        'Limita el tiempo de las actividades extravehiculares (EVA) según el dosímetro.',
        'Limit spacewalk (EVA) time according to your dosimeter.',
      ),
      T(
        'Sigue con el ejercicio de resistencia: 0,17 g no basta para mantener los huesos.',
        'Keep up resistance exercise: 0.17 g is not enough to maintain bone.',
      ),
    ],
  ),
  MissionEnvironment(
    id: 'mars',
    name: T('Base marciana', 'Mars base'),
    icon: Icons.public,
    gravity: T('Gravedad marciana (0,38 g)', 'Martian gravity (0.38 g)'),
    doseMsvPerDay: .64,
    doseSource: T(
      'Superficie de Marte: unos 0,64 mSv/día (Curiosity/RAD)',
      'Martian surface: about 0.64 mSv/day (Curiosity/RAD)',
    ),
    commDelay: T('4–24 min (solo de ida)', '4–24 min (one way)'),
    evacuation: T(
      'No hay evacuación: meses hasta la ventana de regreso',
      'No evacuation: months until the return window',
    ),
    description: T(
      'Es la máxima autonomía: la tripulación debe resolver sola sus emergencias médicas. El polvo contiene percloratos tóxicos.',
      'Maximum autonomy: the crew must handle medical emergencies on its own. The dust contains toxic perchlorates.',
    ),
    exposure: {
      SpaceHazard.radiation: Exposure.moderate,
      SpaceHazard.isolation: Exposure.high,
      SpaceHazard.distance: Exposure.high,
      SpaceHazard.gravity: Exposure.moderate,
      SpaceHazard.environment: Exposure.moderate,
    },
    tips: [
      T(
        'Repasa los protocolos médicos autónomos con tu tripulación.',
        'Review the autonomous medical protocols with your crew.',
      ),
      T(
        'Un sol marciano dura 24 h 39 min: ajusta tu horario de sueño poco a poco.',
        'A Martian sol lasts 24 h 39 min: shift your sleep schedule gradually.',
      ),
      T(
        'Descontamina los trajes: los percloratos del polvo afectan a la tiroides.',
        'Decontaminate suits: perchlorates in the dust affect the thyroid.',
      ),
    ],
    escalationNote: T(
      'Tierra tarda hasta 48 min en responder (ida y vuelta). Actúa primero con el protocolo a bordo; el médico de vuelo revisará después.',
      'Earth can take up to 48 min to respond (round trip). Act first with the onboard protocol; the flight surgeon will review afterwards.',
    ),
  ),
];

MissionEnvironment environmentById(String id) =>
    environments.firstWhere((e) => e.id == id, orElse: () => environments.first);
