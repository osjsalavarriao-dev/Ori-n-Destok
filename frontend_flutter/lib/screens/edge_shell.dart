import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/language.dart';
import '../widgets/orbin_avatar.dart';
import '../services/edge_controller.dart';
import 'body_map_screen.dart';
import 'risks_screen.dart';
import 'trends_screen.dart';
import 'vital_monitor_screen.dart';
import 'orbi_chat_screen.dart';
import 'history_sync_screen.dart';

class EdgeShell extends StatefulWidget {
  const EdgeShell({super.key});
  @override
  State<EdgeShell> createState() => _EdgeShellState();
}

class _EdgeShellState extends State<EdgeShell> {
  final controller = EdgeController();
  int selected = 0;
  bool motion = true;
  @override
  void initState() {
    super.initState();
    controller.start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
          setState(() => selected = 4),
    },
    child: Focus(
      autofocus: true,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final c = controller;
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              return Scaffold(
                appBar: AppBar(
                  title: const Text(
                    'ORBIN  /  HORION',
                    style: TextStyle(
                      letterSpacing: 3,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: context.tr(
                        'Activar o pausar animaciones',
                        'Enable or pause motion',
                      ),
                      onPressed: () => setState(() => motion = !motion),
                      icon: Icon(
                        motion
                            ? Icons.motion_photos_on
                            : Icons.motion_photos_off,
                      ),
                    ),
                    const LanguageMenu(),
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 20),
                      child: Text(
                        c.demo
                            ? context.tr(
                                'DEMO · DATOS SIMULADOS',
                                'DEMO · SIMULATED DATA',
                              )
                            : c.connected
                            ? context.tr('BACKEND LOCAL', 'LOCAL BACKEND')
                            : context.tr('SIN BACKEND', 'NO BACKEND'),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                body: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations:
                        !motion || MediaQuery.disableAnimationsOf(context),
                  ),
                  child: Row(
                    children: [
                      NavigationRail(
                        extended: wide,
                        selectedIndex: selected,
                        onDestinationSelected: (v) =>
                            setState(() => selected = v),
                        backgroundColor: const Color(0xFF0B1B24),
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: wide
                              ? const Column(
                                  children: [
                                    OrbinAvatar(size: 72),
                                    SizedBox(height: 12),
                                    Text('AST-001'),
                                    Text(
                                      'ARTEMIS-IV',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                )
                              : const Icon(Icons.blur_circular),
                        ),
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(Icons.monitor_heart_outlined),
                            label: Text(
                              context.tr('Monitor vital', 'Vital monitor'),
                            ),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.accessibility_new),
                            label: Text(
                              context.tr('Mapa corporal', 'Body map'),
                            ),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.insights),
                            label: Text(context.tr('Tendencias', 'Trends')),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.shield_outlined),
                            label: Text(
                              context.tr(
                                'Riesgos y entorno',
                                'Risks & environment',
                              ),
                            ),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: Text(
                              context.tr('Asistente Orbi', 'Orbi assistant'),
                            ),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.history),
                            label: Text(
                              context.tr('Historial y sync', 'History & sync'),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              color: const Color(0xFF15303A),
                              child: Text(
                                c.offline
                                    ? context.tr(
                                        '● Corte de enlace simulado · Monitoreo local activo',
                                        '● Simulated link loss · Local monitoring active',
                                      )
                                    : [
                                        '● ${c.demo
                                            ? context.tr('Simulador activo', 'Simulator active')
                                            : c.connected
                                            ? context.tr('Captura simulada en SQLite', 'Simulated capture in SQLite')
                                            : context.tr('Esperando backend', 'Waiting for backend')}',
                                        context.t(c.environment.name),
                                        if (c.missionDay != null)
                                          context.tr(
                                            'Día ${c.missionDay}',
                                            'Day ${c.missionDay}',
                                          ),
                                        context.tr(
                                          '${c.pending} pendientes',
                                          '${c.pending} pending',
                                        ),
                                        context.tr(
                                          'Nube sin configurar',
                                          'Cloud not configured',
                                        ),
                                      ].join(' · '),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (c.error != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                color: const Color(0xFF40222B),
                                child: Text(context.t(c.error!)),
                              ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(wide ? 28 : 16),
                                child: IndexedStack(
                                  index: selected,
                                  children:
                                      [
                                            VitalMonitorScreen(
                                              controller: c,
                                              openOrbi: () =>
                                                  setState(() => selected = 4),
                                              openBodyMap: () =>
                                                  setState(() => selected = 1),
                                            ),
                                            BodyMapScreen(
                                              controller: c,
                                              visible: selected == 1,
                                            ),
                                            TrendsScreen(controller: c),
                                            RisksScreen(controller: c),
                                            OrbiChatScreen(controller: c),
                                            HistorySyncScreen(controller: c),
                                          ]
                                          .asMap()
                                          .entries
                                          .map(
                                            (entry) => TickerMode(
                                              enabled:
                                                                                                    selected == entry.key,
                                              child: entry.value,
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              color: const Color(0xFF0B1B24),
                              child: Wrap(
                                spacing: 20,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch(
                                        value: c.demo,
                                        onChanged: c.busy ? null : c.changeMode,
                                      ),
                                      const Text(
                                        'Demo',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch(
                                        value: c.offline,
                                        onChanged:
                                            c.busy || (!c.demo && !c.connected)
                                            ? null
                                            : c.toggleOffline,
                                      ),
                                      Text(
                                        context.tr(
                                          'Simular corte de enlace',
                                          'Simulate link loss',
                                        ),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  OutlinedButton.icon(
                                    onPressed:
                                        c.busy || (!c.demo && !c.connected)
                                        ? null
                                        : c.anomaly,
                                    icon: const Icon(
                                      Icons.science_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      context.tr(
                                        'Simular anomalía',
                                        'Simulate anomaly',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
