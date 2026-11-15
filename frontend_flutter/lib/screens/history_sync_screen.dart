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
                      'Persistencia local en SQLite. Telemetría, alertas y conversaciones con Orbi se suben a Horion Web; bienestar y mediciones se quedan en este equipo.',
                      'Stored locally in SQLite. Telemetry, alerts and Orbi conversations are uploaded to Horion Web; wellbeing and measurements stay on this device.',
                    ),
            ),
            const SizedBox(height: 8),
            _CloudStatus(controller: c),
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

/// Estado del envío a Horion Web, según lo que informa el backend en /api/state.
class _CloudStatus extends StatelessWidget {
  const _CloudStatus({required this.controller});
  final EdgeController controller;

  String _time(String? iso) => iso == null
      ? '—'
      : DateTime.parse(iso).toLocal().toString().split('.').first;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.demo) {
      return Text(
        context.tr(
          'Horion Web: el modo demo no envía datos.',
          'Horion Web: demo mode does not send data.',
        ),
        style: const TextStyle(color: Colors.amber),
      );
    }
    if (!c.cloudConfigured) {
      return Text(
        context.tr(
          'Horion Web: sin configurar. Define HORION_CLOUD_URL y EDGE_API_KEY en backend_fastapi/.env y reinicia el backend.',
          'Horion Web: not configured. Set HORION_CLOUD_URL and EDGE_API_KEY in backend_fastapi/.env and restart the backend.',
        ),
        style: const TextStyle(color: Colors.amber),
      );
    }
    final state = c.cloudSync['estado'] as String?;
    final detail = c.cloudSync['detalle'] as String?;
    final lastOk = _time(c.cloudSync['ultimo_exito_utc'] as String?);
    final failed = state == 'FAILED_NO_NETWORK' || state == 'FAILED_SERVER';
    final message = switch (state) {
      'FAILED_NO_NETWORK' => context.tr(
        'Horion Web: sin conexión. Se reintentará; los datos siguen en la cola local. Último envío correcto: $lastOk',
        'Horion Web: no connection. It will retry; data stays in the local queue. Last successful upload: $lastOk',
      ),
      'FAILED_SERVER' => context.tr(
        'Horion Web rechazó el lote: ${detail ?? ''}',
        'Horion Web rejected the batch: ${detail ?? ''}',
      ),
      null => context.tr(
        'Horion Web: configurado, esperando el primer envío.',
        'Horion Web: configured, waiting for the first upload.',
      ),
      _ => context.tr(
        'Horion Web: conectado. Último envío correcto: $lastOk',
        'Horion Web: connected. Last successful upload: $lastOk',
      ),
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: failed ? Colors.amber : Colors.greenAccent),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: c.busy || c.offline ? null : c.syncNow,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text(context.tr('Sincronizar ahora', 'Sync now')),
        ),
      ],
    );
  }
}
