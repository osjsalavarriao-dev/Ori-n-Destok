import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import '../models/hrp_catalog.dart';
import '../models/mission_environment.dart';
import '../services/edge_controller.dart';
import '../widgets/indicator_detail.dart';
import '../widgets/viewport_board.dart';

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
    final days = c.missionDay ?? 0;
    final dose = env.doseMsvPerDay * days;
    final share = min(1.0, dose / careerDoseLimitMsv);
    return ScreenBoard(
      key: ValueKey(env.id),
      title: context.tr('Riesgos y entorno', 'Risks & environment'),
      controls: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 1000
            ? DropdownButton<MissionEnvironment>(
                value: env,
                isExpanded: true,
                items: [
                  for (final e in environments)
                    DropdownMenuItem(value: e, child: Text(context.t(e.name))),
                ],
                onChanged: (e) {
                  if (e != null) c.setEnvironment(e);
                },
              )
            : Wrap(
                spacing: 8,
                runSpacing: 4,
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
      ),
      minColumnWidth: 380,
      children: [
        BoardSection(
          title: context.t(env.name),
          children: [
            Text(context.t(env.description)),
            const SizedBox(height: 8),
            Text(
              '${context.tr('Gravedad', 'Gravity')}: ${context.t(env.gravity)}',
            ),
            Text(
              '${context.tr('Retraso con Tierra', 'Delay to Earth')}: ${context.t(env.commDelay)}',
            ),
            Text(
              '${context.tr('Evacuación', 'Evacuation')}: ${context.t(env.evacuation)}',
            ),
          ],
        ),
        BoardSection(
          title: context.tr(
            'Radiación: ${env.doseMsvPerDay.toStringAsFixed(2)} mSv/día',
            'Radiation: ${env.doseMsvPerDay.toStringAsFixed(2)} mSv/day',
          ),
          children: [
            Text(
              context.t(env.doseSource),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            if (c.missionDay != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Dosis estimada en $days días: ${dose.toStringAsFixed(1)} mSv · ${(share * 100).toStringAsFixed(1)} % del límite de carrera NASA (${careerDoseLimitMsv.toStringAsFixed(0)} mSv)',
                  'Estimated dose over $days days: ${dose.toStringAsFixed(1)} mSv · ${(share * 100).toStringAsFixed(1)} % of the NASA career limit (${careerDoseLimitMsv.toStringAsFixed(0)} mSv)',
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: share),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Estimación suponiendo toda la misión en este entorno y sin blindaje adicional; usa tu dosímetro personal como referencia.',
                  'Estimate assuming the whole mission in this environment with no extra shielding; use your personal dosimeter as the reference.',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        if (env.escalationNote != null)
          StatusBanner(
            status: HealthStatus.watch,
            text: context.t(env.escalationNote!),
          ),
        BoardSection(
          title: context.tr(
            'Recomendaciones en este entorno',
            'Recommendations for this environment',
          ),
          children: [
            for (final tip in env.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${context.t(tip)}'),
              ),
          ],
        ),
        BoardSection(
          title: context.tr(
            'Los 5 peligros del vuelo espacial',
            'The 5 spaceflight hazards',
          ),
          children: [
            Text(
              context.tr(
                'Los peligros se retroalimentan entre sí: por ejemplo, el aislamiento empeora el sueño y la falta de sueño debilita la inmunidad.',
                'Hazards feed off one another: for example, isolation worsens sleep, and poor sleep weakens immunity.',
              ),
            ),
          ],
        ),
        for (final h in SpaceHazard.values)
          _HazardCard(controller: c, hazard: h),
        BoardSection(
          title: context.tr(
            'Los 17 riesgos para la salud (NASA HRP)',
            'The 17 health risks (NASA HRP)',
          ),
          children: [
            Text(
              context.tr(
                'La app vigila $monitored con tus indicadores o autoevaluaciones; selecciona un riesgo para ver sus detalles.',
                'The app monitors $monitored with your indicators or self-checks; select a risk to see its details.',
              ),
            ),
          ],
        ),
        for (final r in hrpRisks)
          Card(
            margin: EdgeInsets.zero,
            child: _RiskTile(controller: c, risk: r),
          ),
        const Text(
          'NASA HRP: nasa.gov/hrp/hazards · nasa.gov/hrp/risks · nasa.gov/hrp/ongoing-hrp-research · CSA: asc-csa.gc.ca',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
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
    final indicatorIds = risk.indicatorIds.where(
      (id) => id != 'presion_diastolica',
    );
    return ListTile(
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
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => showBoardDetails(
        context,
        title: context.t(risk.name),
        children: [
          Text(
            risk.officialName,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(risk.description),
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in risk.hazards) HazardChip(hazard: h),
              for (final id in indicatorIds)
                ActionChip(
                  avatar: Icon(
                    Icons.circle,
                    size: 10,
                    color: c.displayStatus(id).color,
                  ),
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
              for (final id in risk.regionIds.where(
                (id) => bodyRegion(id).symptoms.isNotEmpty,
              ))
                Chip(
                  avatar: Icon(
                    Icons.fact_check_outlined,
                    size: 16,
                    color: c.symptomStatus(bodyRegion(id)).color,
                  ),
                  label: Text(
                    '${context.tr('Autoevaluación', 'Self-check')}: ${context.t(bodyRegion(id).name)} (${context.tr('Mapa corporal', 'Body map')})',
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
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
    return BoardSection(
      title: context.t(hazard.label),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
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
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(
            context.tr(
              'Ver indicadores relacionados',
              'View related indicators',
            ),
          ),
          onPressed: () => showBoardDetails(
            context,
            title: context.t(hazard.label),
            children: [
              BoardSection(children: [Text(context.t(hazard.description))]),
              if (related.isEmpty)
                Text(
                  context.tr(
                    'No hay un indicador corporal directo para este peligro: sigue las recomendaciones del entorno.',
                    'There is no direct body indicator for this hazard: follow the environment recommendations.',
                  ),
                ),
              for (final i in related)
                BoardSection(
                  children: [
                    ListTile(
                      leading: Icon(i.icon, color: c.displayStatus(i.id).color),
                      title: Text(context.t(i.name)),
                      subtitle: Text(
                        '${c.displayValue(i.id)} ${context.t(i.unit)} · ${context.t(c.displayStatus(i.id).label)}',
                      ),
                      onTap: () => showIndicatorDetail(
                        context,
                        i,
                        c.displayValue(i.id),
                        c.displayStatus(i.id),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .6)),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}
