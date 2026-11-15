import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../services/edge_controller.dart';
import '../widgets/viewport_board.dart';

class HistorySyncScreen extends StatefulWidget {
  const HistorySyncScreen({super.key, required this.controller});
  final EdgeController controller;
  @override
  State<HistorySyncScreen> createState() => _HistorySyncScreenState();
}

class _HistorySyncScreenState extends State<HistorySyncScreen> {
  static const _moods = [
    T('Muy mal', 'Very bad'),
    T('Mal', 'Bad'),
    T('Regular', 'Okay'),
    T('Bien', 'Good'),
    T('Muy bien', 'Very good'),
  ];
  double sleep = 8, water = 1500, energy = 3, mood = 4;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final moodLabel = context.t(_moods[mood.toInt() - 1]);
    return ScreenBoard(
      title: context.tr('Historial y sincronización', 'History and sync'),
      minColumnWidth: 340,
      children: [
        BoardSection(
          title: context.tr('Registro de bienestar', 'Wellbeing log'),
          children: [
            Text(
              context.tr(
                'Sueño: ${sleep.toStringAsFixed(1)} horas',
                'Sleep: ${sleep.toStringAsFixed(1)} hours',
              ),
            ),
            Slider(
              value: sleep,
              min: 0,
              max: 16,
              divisions: 32,
              label: '$sleep h',
              onChanged: (v) => setState(() => sleep = v),
            ),
          ],
        ),
        BoardSection(
          children: [
            Text(
              context.tr(
                'Agua: ${water.toInt()} ml',
                'Water: ${water.toInt()} ml',
              ),
            ),
            Slider(
              value: water,
              min: 0,
              max: 5000,
              divisions: 20,
              label: '${water.toInt()} ml',
              onChanged: (v) => setState(() => water = v),
            ),
          ],
        ),
        BoardSection(
          children: [
            Text(
              context.tr(
                'Energía: ${energy.toInt()} de 5',
                'Energy: ${energy.toInt()} of 5',
              ),
            ),
            Slider(
              value: energy,
              min: 1,
              max: 5,
              divisions: 4,
              label: '${energy.toInt()}',
              onChanged: (v) => setState(() => energy = v),
            ),
          ],
        ),
        BoardSection(
          children: [
            Text(
              context.tr(
                'Estado de ánimo: $moodLabel (${mood.toInt()} de 5)',
                'Mood: $moodLabel (${mood.toInt()} of 5)',
              ),
            ),
            Slider(
              value: mood,
              min: 1,
              max: 5,
              divisions: 4,
              label: moodLabel,
              onChanged: (v) => setState(() => mood = v),
            ),
            FilledButton.icon(
              onPressed: c.busy || (!c.demo && !c.connected)
                  ? null
                  : () async {
                      await c.saveWellbeing(
                        sleep,
                        water.toInt(),
                        energy.toInt(),
                        mood.toInt(),
                      );
                      if (context.mounted && c.error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              c.demo
                                  ? context.tr(
                                      'Registro guardado en memoria demo.',
                                      'Entry saved to demo memory.',
                                    )
                                  : context.tr(
                                      'Registro guardado en SQLite.',
                                      'Entry saved to SQLite.',
                                    ),
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: Text(context.tr('Guardar registro', 'Save entry')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        BoardSection(
          children: [
            Text(
              context.tr(
                '${c.pending} registros pendientes',
                '${c.pending} pending records',
              ),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              c.demo
                  ? context.tr(
                      'Datos temporales. El modo demo se reinicia al cerrar o cambiar de modo.',
                      'Temporary data. Demo mode resets when you close the app or switch modes.',
                    )
                  : context.tr(
                      'Persistencia local en SQLite. Los datos permanecen pendientes.',
                      'Stored locally in SQLite. Data remains pending.',
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Horion Cloud: integración pendiente · No se han enviado datos a la nube.',
                'Horion Cloud: integration pending · No data has been sent to the cloud.',
              ),
              style: const TextStyle(color: Colors.amber),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          context.tr(
            'Últimos registros de bienestar',
            'Latest wellbeing entries',
          ),
          style: const TextStyle(fontSize: 18),
        ),
        if (c.wellbeing.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(context.tr('Aún no hay registros.', 'No entries yet.')),
          ),
        for (final item in c.wellbeing.take(20))
          Card(
            child: ListTile(
              leading: const Icon(Icons.self_improvement),
              title: Text(
                [
                  context.tr(
                    '${item['horas_sueno']} h de sueño',
                    '${item['horas_sueno']} h of sleep',
                  ),
                  context.tr(
                    '${item['agua_ml']} ml de agua',
                    '${item['agua_ml']} ml of water',
                  ),
                  context.tr(
                    'Energía ${item['energia']}/5',
                    'Energy ${item['energia']}/5',
                  ),
                  if (item['animo'] != null)
                    context.tr(
                      'Ánimo ${item['animo']}/5',
                      'Mood ${item['animo']}/5',
                    ),
                ].join(' · '),
              ),
              subtitle: Text(
                DateTime.parse(item['timestamp_utc'] as String)
                    .toLocal()
                    .toString()
                    .split('.')
                    .first,
              ),
            ),
          ),
      ],
    );
  }
}
