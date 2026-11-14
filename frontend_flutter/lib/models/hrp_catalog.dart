import '../l10n/language.dart';
import 'health_knowledge.dart';

/// Catálogo de NASA HRP: los 17 riesgos para la salud y el rendimiento
/// (https://www.nasa.gov/hrp/risks/) y la investigación en curso que los
/// estudia (https://www.nasa.gov/hrp/ongoing-hrp-research/).
///
/// Los 5 peligros (las causas) son [SpaceHazard]; estos riesgos son sus
/// consecuencias. Los nombres oficiales se dejan en inglés.

enum RiskCategory { physiology, behavior, radiation }

extension RiskCategoryInfo on RiskCategory {
  T get label => switch (this) {
    RiskCategory.physiology => const T('Fisiología humana', 'Human physiology'),
    RiskCategory.behavior => const T(
      'Comportamiento y factores humanos',
      'Behavioral performance and human factors',
    ),
    RiskCategory.radiation => const T('Radiación espacial', 'Space radiation'),
  };
}

class HrpRisk {
  const HrpRisk({
    required this.officialName,
    required this.name,
    required this.category,
    required this.description,
    required this.hazards,
    this.indicatorIds = const [],
    this.regionIds = const [],
  });

  /// Nombre oficial de NASA, sin traducir.
  final String officialName;
  final T name, description;
  final RiskCategory category;
  final List<SpaceHazard> hazards;

  /// Indicadores con los que la app vigila este riesgo.
  final List<String> indicatorIds;

  /// Zonas del mapa corporal relacionadas (con autoevaluación o información).
  final List<String> regionIds;
}

const hrpRisks = <HrpRisk>[
  // Fisiología humana (11)
  HrpRisk(
    officialName: 'Risk of Altered Immune System Responses',
    name: T('Respuesta inmunitaria alterada', 'Altered immune response'),
    category: RiskCategory.physiology,
    description: T(
      'El estrés del vuelo espacial puede reactivar virus latentes y causar sarpullidos y otros síntomas.',
      'Spaceflight stress can reactivate dormant viruses, causing rashes and other symptoms.',
    ),
    hazards: [SpaceHazard.radiation, SpaceHazard.isolation, SpaceHazard.environment],
    indicatorIds: ['temperatura_corporal'],
    regionIds: ['immune'],
  ),
  HrpRisk(
    officialName: 'Risk of Altered Sensorimotor and Vestibular Function',
    name: T('Función sensoriomotora y vestibular alterada', 'Altered sensorimotor and vestibular function'),
    category: RiskCategory.physiology,
    description: T(
      'Mareo, problemas de coordinación y vértigo durante los cambios de gravedad.',
      'Motion sickness, coordination problems and dizziness during gravity changes.',
    ),
    hazards: [SpaceHazard.gravity],
    regionIds: ['vestibular'],
  ),
  HrpRisk(
    officialName: 'Risk of Cardiovascular Adaptations',
    name: T('Adaptaciones cardiovasculares', 'Cardiovascular adaptations'),
    category: RiskCategory.physiology,
    description: T(
      'La ingravidez cambia la circulación y el funcionamiento del corazón y los vasos, y puede aumentar el riesgo de eventos cardiovasculares.',
      'Weightlessness changes circulation and heart and vessel function, and may raise the risk of cardiovascular events.',
    ),
    hazards: [SpaceHazard.gravity, SpaceHazard.radiation],
    indicatorIds: ['frecuencia_cardiaca', 'presion_sistolica', 'presion_diastolica', 'hrv'],
    regionIds: ['heart'],
  ),
  HrpRisk(
    officialName: 'Risk of Decompression Sickness',
    name: T('Enfermedad por descompresión', 'Decompression sickness'),
    category: RiskCategory.physiology,
    description: T(
      'Al pasar a la baja presión del traje espacial, el nitrógeno disuelto puede formar burbujas en los tejidos.',
      'When moving to the lower pressure of a spacesuit, dissolved nitrogen can form bubbles in the tissues.',
    ),
    hazards: [SpaceHazard.environment],
  ),
  HrpRisk(
    officialName: 'Risk of Host-Microorganism Interactions',
    name: T('Interacción con microorganismos', 'Host-microorganism interactions'),
    category: RiskCategory.physiology,
    description: T(
      'Los microbios de la piel y del intestino cambian en el espacio, lo que puede aumentar el riesgo de enfermar.',
      'Skin and gut microbiomes change in space, which may increase the risk of illness.',
    ),
    hazards: [SpaceHazard.environment],
    regionIds: ['immune'],
  ),
  HrpRisk(
    officialName: 'Risk of Hypoxia',
    name: T('Hipoxia', 'Hypoxia'),
    category: RiskCategory.physiology,
    description: T(
      'Falta leve de oxígeno en los tejidos, un efecto secundario de las medidas para evitar la descompresión en las caminatas espaciales.',
      'Mild lack of oxygen in the tissues, a side effect of the steps taken to avoid decompression sickness during spacewalks.',
    ),
    hazards: [SpaceHazard.environment],
    indicatorIds: ['spo2'],
    regionIds: ['lungs'],
  ),
  HrpRisk(
    officialName: 'Risk of Inadequate Food and Nutrition',
    name: T('Alimentación y nutrición inadecuadas', 'Inadequate food and nutrition'),
    category: RiskCategory.physiology,
    description: T(
      'Una dieta deficiente afecta la salud y el rendimiento de la tripulación.',
      'A poor diet affects crew health and performance.',
    ),
    hazards: [SpaceHazard.distance, SpaceHazard.environment],
    indicatorIds: ['glucosa'],
    regionIds: ['metabolism'],
  ),
  HrpRisk(
    officialName: 'Risk of Injury and Compromised Performance from Spacewalks',
    name: T('Lesiones y bajo rendimiento en caminatas espaciales', 'Injury and compromised performance from spacewalks'),
    category: RiskCategory.physiology,
    description: T(
      'Fatiga cognitiva, lesiones y peligros del traje, como poco oxígeno o mucho CO₂.',
      'Cognitive fatigue, injury and spacesuit hazards such as low oxygen or high CO₂.',
    ),
    hazards: [SpaceHazard.environment, SpaceHazard.gravity],
  ),
  HrpRisk(
    officialName: 'Risk of Reduced Cardiorespiratory and Musculoskeletal Fitness',
    name: T('Menor forma física cardiorrespiratoria y musculoesquelética', 'Reduced cardiorespiratory and musculoskeletal fitness'),
    category: RiskCategory.physiology,
    description: T(
      'Pérdida de densidad ósea, de fuerza muscular y de rendimiento del corazón y los vasos.',
      'Loss of bone density, muscle strength, and heart and vessel performance.',
    ),
    hazards: [SpaceHazard.gravity],
    regionIds: ['bones', 'heart'],
  ),
  HrpRisk(
    officialName: 'Risk of Spaceflight Associated Neuro-ocular Syndrome (SANS)',
    name: T('Síndrome neuro-ocular (SANS)', 'Neuro-ocular syndrome (SANS)'),
    category: RiskCategory.physiology,
    description: T(
      'Cambios en la estructura del ojo y del cerebro. NASA lo considera su principal riesgo de salud del vuelo espacial.',
      'Changes to eye and brain structure. NASA calls it its leading spaceflight-related health risk.',
    ),
    hazards: [SpaceHazard.gravity],
    regionIds: ['eyes'],
  ),
  HrpRisk(
    officialName: 'Risk of Spaceflight-Induced Bone Changes',
    name: T('Cambios óseos', 'Bone changes'),
    category: RiskCategory.physiology,
    description: T(
      'Sin gravedad, los huesos se debilitan y se fracturan con más facilidad.',
      'Without gravity, bones weaken and break more easily.',
    ),
    hazards: [SpaceHazard.gravity],
    regionIds: ['bones'],
  ),
  // Comportamiento y factores humanos (5)
  HrpRisk(
    officialName: 'Risk of Behavioral Changes and Psychiatric Disorders',
    name: T('Cambios de conducta y trastornos psiquiátricos', 'Behavioral changes and psychiatric disorders'),
    category: RiskCategory.behavior,
    description: T(
      'El aislamiento, la radiación y la distancia a la Tierra pueden afectar la salud mental de la tripulación.',
      'Isolation, radiation and distance from Earth can affect crew mental health.',
    ),
    hazards: [SpaceHazard.isolation, SpaceHazard.radiation, SpaceHazard.distance],
    indicatorIds: ['animo', 'hrv'],
    regionIds: ['brain'],
  ),
  HrpRisk(
    officialName: 'Risk of Inadequate Teamwork',
    name: T('Trabajo en equipo inadecuado', 'Inadequate teamwork'),
    category: RiskCategory.behavior,
    description: T(
      'La selección de la tripulación y su funcionamiento como equipo en aislamiento afectan el éxito y la seguridad de la misión.',
      'Crew selection and how the team works together in isolation affect mission success and safety.',
    ),
    hazards: [SpaceHazard.isolation],
  ),
  HrpRisk(
    officialName: 'Risk of Inadequate Sleep and Irregular Schedules',
    name: T('Sueño insuficiente y horarios irregulares', 'Inadequate sleep and irregular schedules'),
    category: RiskCategory.behavior,
    description: T(
      'Falta crónica de sueño, exigencias de trabajo constantes y reloj biológico alterado.',
      'Chronic sleep loss, constant work demands and a disrupted body clock.',
    ),
    hazards: [SpaceHazard.isolation, SpaceHazard.environment],
    indicatorIds: ['horas_sueno'],
    regionIds: ['brain'],
  ),
  HrpRisk(
    officialName: 'Risk of Inadequate Systems Operations Support',
    name: T('Apoyo insuficiente para operar sistemas', 'Inadequate systems operations support'),
    category: RiskCategory.behavior,
    description: T(
      'La tripulación puede enfrentarse a fallos inesperados del software o del vehículo sin información o formación suficientes.',
      'The crew may face unexpected software or vehicle problems without enough information or training.',
    ),
    hazards: [SpaceHazard.distance],
  ),
  HrpRisk(
    officialName: 'Risk of Injury from Dynamic Loads',
    name: T('Lesiones por cargas dinámicas', 'Injury from dynamic loads'),
    category: RiskCategory.behavior,
    description: T(
      'Riesgo de lesión durante el aterrizaje.',
      'Risk of injury during landing.',
    ),
    hazards: [SpaceHazard.gravity],
  ),
  // Radiación espacial (1)
  HrpRisk(
    officialName: 'Risk of Radiation-Induced Cancers',
    name: T('Cáncer inducido por radiación', 'Radiation-induced cancers'),
    category: RiskCategory.radiation,
    description: T(
      'La exposición a la radiación puede aumentar la probabilidad de cáncer. La app estima tu dosis acumulada en «Riesgos y entorno».',
      'Radiation exposure may increase the likelihood of cancer. The app estimates your accumulated dose under "Risks & environment".',
    ),
    hazards: [SpaceHazard.radiation],
  ),
];

enum StudyStatus { artemis, ongoing, completed }

extension StudyStatusInfo on StudyStatus {
  T get label => switch (this) {
    StudyStatus.artemis => const T('Artemis II', 'Artemis II'),
    StudyStatus.ongoing => const T('En curso en la EEI', 'Ongoing on the ISS'),
    StudyStatus.completed => const T('Finalizado', 'Completed'),
  };
}

/// Investigación de NASA HRP. Son estudios, no tratamientos probados.
class ResearchStudy {
  const ResearchStudy(this.name, this.status, this.description, this.regionIds);
  final String name;
  final StudyStatus status;
  final T description;
  final List<String> regionIds;
}

const researchStudies = <ResearchStudy>[
  ResearchStudy('ARCHeR', StudyStatus.artemis, T(
    'Pulsera de actigrafía que mide movimiento, sueño y exposición a la luz para seguir el bienestar de la tripulación.',
    'Wrist-worn actigraphy device that measures motion, sleep and light exposure to track crew well-being.',
  ), ['brain']),
  ResearchStudy('Immune Biomarkers', StudyStatus.artemis, T(
    'Analiza sangre y saliva para estudiar los cambios del sistema inmunitario en el espacio profundo.',
    'Analyzes blood and saliva to study immune system changes in deep space.',
  ), ['immune']),
  ResearchStudy('Thigh Cuff', StudyStatus.ongoing, T(
    'Prueba si unos brazaletes en los muslos retienen líquido en las piernas para prevenir problemas oculares.',
    'Tests whether thigh cuffs keep fluid in the legs to help prevent eye problems.',
  ), ['eyes']),
  ResearchStudy('B-Complex', StudyStatus.ongoing, T(
    'Prueba si un suplemento diario de vitaminas B previene o reduce los cambios en ojos y cerebro.',
    'Tests whether a daily B-vitamin supplement can prevent or reduce eye and brain changes.',
  ), ['eyes']),
  ResearchStudy('Brain Fluid Pressure', StudyStatus.ongoing, T(
    'Estudia la presión del líquido dentro del cráneo y su relación con los cambios en ojos y cerebro.',
    'Studies fluid pressure inside the skull and its link to eye and brain changes.',
  ), ['eyes']),
  ResearchStudy('Simulating Manual Piloting for Moon Landings', StudyStatus.ongoing, T(
    'Evalúa cómo los cambios de gravedad afectan la capacidad de pilotar.',
    'Assesses how gravity transitions affect piloting ability.',
  ), ['vestibular']),
  ResearchStudy('Venous Haemostasis', StudyStatus.ongoing, T(
    'Estudia los factores físicos que afectan el flujo sanguíneo y la coagulación.',
    'Studies physical factors that affect blood flow and clotting.',
  ), ['heart']),
  ResearchStudy('Zero T2', StudyStatus.ongoing, T(
    'Estudia el ejercicio sin cinta de correr, para preparar misiones al espacio profundo.',
    'Studies exercise without a treadmill to prepare for deep space missions.',
  ), ['bones', 'heart']),
  ResearchStudy('Standard Measures', StudyStatus.ongoing, T(
    'Recoge mediciones fisiológicas y psicológicas estandarizadas de cada tripulante, como hace esta app.',
    'Collects standardized physiological and psychological measurements from every crew member, like this app does.',
  ), ['brain', 'heart', 'metabolism']),
  ResearchStudy('Altered Immunity', StudyStatus.completed, T(
    'Analizó sangre, saliva y orina para estudiar los efectos del vuelo espacial en la inmunidad.',
    'Analyzed blood, saliva and urine to study how spaceflight affects immunity.',
  ), ['immune']),
  ResearchStudy('Food Physiology', StudyStatus.completed, T(
    'Probó si una dieta mejorada ayuda a los astronautas a adaptarse al vuelo espacial.',
    'Tested whether an enhanced diet helps astronauts adapt to spaceflight.',
  ), ['metabolism']),
  ResearchStudy('Space Gardening', StudyStatus.completed, T(
    'Evaluó si cultivar verduras reduce el estrés del aislamiento y el confinamiento.',
    'Evaluated whether growing vegetables reduces the stress of isolation and confinement.',
  ), ['brain']),
  ResearchStudy('Spinal Health', StudyStatus.completed, T(
    'Usó escáneres de columna para diseñar estrategias contra la pérdida de hueso y músculo.',
    'Used spine scans to inform strategies against bone and muscle loss.',
  ), ['bones']),
];

List<ResearchStudy> researchFor(String regionId) =>
    researchStudies.where((s) => s.regionIds.contains(regionId)).toList();
