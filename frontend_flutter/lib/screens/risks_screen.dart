import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import '../models/hrp_catalog.dart';
import '../models/mission_environment.dart';
import '../services/edge_controller.dart';
import '../widgets/indicator_detail.dart';

/// Terminología de NASA HRP: 5 peligros (las causas, cuya exposición depende
/// del entorno) y 17 riesgos (las consecuencias para la salud).
class RisksScreen extends StatelessWidget {
  const RisksScreen({super.key, required this.controller});
  final EdgeController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final env = c.environment;
    final monitored = hrpRisks.where(EdgeController.isMonitored).length;
    return ListView(
      children: [
        Text(
          context.tr('Riesgos y entorno', 'Risks & environment'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'NASA distingue 5 peligros del vuelo espacial (las causas) y 17 riesgos para la salud (las consecuencias). Elige dónde estás: la exposición a cada peligro depende del entorno.',
            'NASA distinguishes 5 spaceflight hazards (the causes) from 17 health risks (the consequences). Choose where you are: exposure to each hazard depends on the environment.',
          ),
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in environments)
              ChoiceChip(
                selected: e.id == env.id,
                onSelected: (_) => c.setEnvironment(e),
                avatar: Icon(e.icon, size: 18),
                label: Text(context.t(e.name)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _EnvironmentCard(env: env, missionDay: c.missionDay),
        const SizedBox(height: 24),
        _heading(
          context,
          context.tr('Los 5 peligros del vuelo espacial', 'The 5 spaceflight hazards'),
          context.tr(
            'Los peligros se retroalimentan entre sí: por ejemplo, el aislamiento empeora el sueño y la falta de sueño debilita la inmunidad.',
            'Hazards feed off one another: for example, isolation worsens sleep, and poor sleep weakens immunity.',
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 900 ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final h in SpaceHazard.values)
                  SizedBox(width: width, child: _HazardCard(controller: c, hazard: h)),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _heading(
          context,
          context.tr('Los 17 riesgos para la salud (NASA HRP)', 'The 17 health risks (NASA HRP)'),
          context.tr(
            'La app vigila $monitored con tus indicadores o autoevaluaciones; el resto se explica para que sepas que existen.',
            'The app monitors $monitored with your indicators or self-checks; the rest are explained so you know they exist.',
          ),
        ),
        for (final category in RiskCategory.values) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              context.t(category.label).toUpperCase(),
              style: const TextStyle(color: Color(0xFF38BDF8), letterSpacing: 1, fontSize: 12),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final r in hrpRisks.where((r) => r.category == category))
                  _RiskTile(controller: c, risk: r),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'NASA HRP: nasa.gov/hrp/hazards · nasa.gov/hrp/risks · nasa.gov/hrp/ongoing-hrp-research · CSA: asc-csa.gc.ca',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _heading(BuildContext context, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.white60)),
      ],
    ),
  );
}

/// Un riesgo HRP: estado si la app lo vigila, o "Informativo" si no.
class _RiskTile extends StatelessWidget {
  const _RiskTile({required this.controller, required this.risk});
  final EdgeController controller;
  final HrpRisk risk;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final monitored = EdgeController.isMonitored(risk);
    final status = c.hrpRiskStatus(risk);
    final indicatorIds = risk.indicatorIds.where((id) => id != 'presion_diastolica');
    return ExpansionTile(
      key: PageStorageKey('risk-${risk.officialName}'),
      leading: Icon(
        monitored ? status.icon : Icons.menu_book_outlined,
        color: monitored ? status.color : Colors.white38,
      ),
      title: Text(context.t(risk.name)),
      subtitle: Text(
        monitored
            ? '${context.tr('Vigilado', 'Monitored')} · ${context.t(status.label)}'
            : context.tr('Informativo', 'For information'),
        style: TextStyle(
          color: monitored ? status.color : Colors.white38,
          fontSize: 12,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          risk.officialName,
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 6),
        Text(context.t(risk.description), style: const TextStyle(height: 1.4)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final h in risk.hazards) HazardChip(hazard: h),
            for (final id in indicatorIds)
              ActionChip(
                avatar: Icon(Icons.circle, size: 10, color: c.displayStatus(id).color),
                label: Text(
                  '${context.t(indicator(id).name)}: ${c.displayValue(id)}',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => showIndicatorDetail(
                  context,
                  indicator(id),
                  c.displayValue(id),
                  c.displayStatus(id),
                ),
              ),
            for (final id in risk.regionIds.where((id) => bodyRegion(id).symptoms.isNotEmpty))
              Chip(
                avatar: Icon(Icons.fact_check_outlined, size: 16, color: c.symptomStatus(bodyRegion(id)).color),
                label: Text(
                  '${context.tr('Autoevaluación', 'Self-check')}: ${context.t(bodyRegion(id).name)} (${context.tr('Mapa corporal', 'Body map')})',
                  style: const TextStyle(fontSize: 12),
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  const _EnvironmentCard({required this.env, required this.missionDay});
  final MissionEnvironment env;
  final int? missionDay;

  @override
  Widget build(BuildContext context) {
    final days = missionDay ?? 0;
    final dose = env.doseMsvPerDay * days;
    final share = min(1.0, dose / careerDoseLimitMsv);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(env.icon, size: 32, color: const Color(0xFF38BDF8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.t(env.name),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(context.t(env.description), style: const TextStyle(color: Colors.white70, height: 1.4)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _fact(Icons.south, context.tr('Gravedad', 'Gravity'), context.t(env.gravity)),
                _fact(
                  Icons.schedule_send,
                  context.tr('Retraso con Tierra', 'Delay to Earth'),
                  context.t(env.commDelay),
                ),
                _fact(Icons.emergency, context.tr('Evacuación', 'Evacuation'), context.t(env.evacuation)),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              context.tr(
                'Radiación: ${env.doseMsvPerDay.toStringAsFixed(2)} mSv/día',
                'Radiation: ${env.doseMsvPerDay.toStringAsFixed(2)} mSv/day',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(context.t(env.doseSource), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 10),
            if (missionDay != null) ...[
              Text(
                context.tr(
                  'Dosis estimada en $days días: ${dose.toStringAsFixed(1)} mSv · ${(share * 100).toStringAsFixed(1)} % del límite de carrera NASA (${careerDoseLimitMsv.toStringAsFixed(0)} mSv)',
                  'Estimated dose over $days days: ${dose.toStringAsFixed(1)} mSv · ${(share * 100).toStringAsFixed(1)} % of the NASA career limit (${careerDoseLimitMsv.toStringAsFixed(0)} mSv)',
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 8,
                  color: share > .5
                      ? HealthStatus.critical.color
                      : share > .2
                      ? HealthStatus.watch.color
                      : HealthStatus.good.color,
                  backgroundColor: const Color(0xFF223046),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'Estimación suponiendo toda la misión en este entorno y sin blindaje adicional; usa tu dosímetro personal como referencia.',
                  'Estimate assuming the whole mission in this environment with no extra shielding; use your personal dosimeter as the reference.',
                ),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            if (env.escalationNote != null) ...[
              const SizedBox(height: 14),
              StatusBanner(status: HealthStatus.watch, text: context.t(env.escalationNote!)),
            ],
            const SizedBox(height: 14),
            Text(
              context.tr('Recomendaciones en este entorno', 'Recommendations for this environment'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            for (final t in env.tips)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 16, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.t(t))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fact(IconData icon, String label, String value) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 280),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.white54),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(value),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Uno de los 5 peligros: exposición según el entorno y señal de tus indicadores.
class _HazardCard extends StatelessWidget {
  const _HazardCard({required this.controller, required this.hazard});
  final EdgeController controller;
  final SpaceHazard hazard;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final exposure = c.environment.exposure[hazard]!;
    final health = c.hazardStatus(hazard);
    final related = indicators.where(
      (i) => i.hazards.contains(hazard) && i.id != 'presion_diastolica',
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(hazard.icon, color: const Color(0xFF38BDF8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t(hazard.label),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(
                  '${context.tr('Exposición', 'Exposure')}: ${context.t(exposure.label)}',
                  exposure.color,
                ),
                _badge(
                  '${context.tr('Tus indicadores', 'Your indicators')}: ${context.t(health.label)}',
                  health.color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(context.t(hazard.description), style: const TextStyle(color: Colors.white70, height: 1.4)),
            if (related.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final i in related)
                    ActionChip(
                      avatar: Icon(Icons.circle, size: 10, color: c.displayStatus(i.id).color),
                      label: Text(
                        '${context.t(i.name)}: ${c.displayValue(i.id)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => showIndicatorDetail(
                        context,
                        i,
                        c.displayValue(i.id),
                        c.displayStatus(i.id),
                      ),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                context.tr(
                  'No hay un indicador corporal directo para este peligro: sigue las recomendaciones del entorno.',
                  'There is no direct body indicator for this hazard: follow the environment recommendations.',
                ),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .6)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}
