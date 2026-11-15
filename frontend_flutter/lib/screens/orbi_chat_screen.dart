import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/orbi_voice.dart';
import '../models/health_knowledge.dart';

import '../l10n/language.dart';
import '../widgets/orbin_avatar.dart';
import '../widgets/viewport_board.dart';
import '../services/edge_controller.dart';
import '../services/local_guidance.dart';

class OrbiChatScreen extends StatefulWidget {
  const OrbiChatScreen({super.key, required this.controller});
  final EdgeController controller;
  @override
  State<OrbiChatScreen> createState() => _OrbiChatScreenState();
}

class _OrbiChatScreenState extends State<OrbiChatScreen> {
  LocalRequest? selected;
  final voice = OrbiVoice();
  bool speaking = false, checking = false;
  int generation = 0;
  String? voiceError;
  Timer? connectionWatch;
  HealthStatus? spokenStatus;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(onState);
  }

  void onState() {
    if (widget.controller.offline ||
        (speaking && spokenStatus != widget.controller.assistantStatus)) {
      stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) {
      voice.stop();
      connectionWatch?.cancel();
      speaking = false;
      checking = false;
      generation++;
    }
  }

  void stop() {
    generation++;
    voice.stop();
    connectionWatch?.cancel();
    if (mounted) {
      setState(() {
        speaking = false;
        checking = false;
      });
    }
  }

  Future<void> read() async {
    if (selected == null || widget.controller.offline) return;
    final token = ++generation;
    setState(() {
      checking = true;
      voiceError = null;
    });
    final online = await voice.online();
    if (!mounted || token != generation) return;
    if (!online) {
      setState(() {
        checking = false;
        voiceError = context.tr(
          'Sin conexion a internet. Usa las consultas locales.',
          'No internet connection. Use local guidance.',
        );
      });
      return;
    }
    spokenStatus = widget.controller.assistantStatus;
    setState(() {
      checking = false;
      speaking = true;
    });
    connectionWatch = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!await voice.online() && mounted && token == generation) stop();
    });
    try {
      await voice.speak(
        LocalGuidance.answer(widget.controller, selected!, context.lang),
        spanish: context.lang == AppLanguage.es,
      );
    } catch (_) {
      if (mounted && token == generation) {
        setState(
          () => voiceError = context.tr(
            'No se pudo reproducir la voz instalada en Windows.',
            'Could not play the installed Windows voice.',
          ),
        );
      }
    } finally {
      if (mounted && token == generation) stop();
    }
  }

  @override
  void dispose() {
    generation++;
    widget.controller.removeListener(onState);
    connectionWatch?.cancel();
    voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ScreenBoard(
      key: ValueKey(selected),
      title: context.tr('Asistente Orbi', 'Orbi assistant'),
      minColumnWidth: 330,
      controls: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final request in LocalRequest.values)
            ChoiceChip(
              label: Text(context.t(LocalGuidance.label(request))),
              selected: selected == request,
              onSelected: (_) {
                stop();
                setState(() {
                  selected = request;
                  voiceError = null;
                });
              },
            ),
        ],
      ),
      children: [
        Row(
          children: [
            OrbinAvatar(
              size: 72,
              status: c.assistantStatus,
              mood: speaking
                  ? OrbinMood.speaking
                  : selected == null
                  ? OrbinMood.idle
                  : OrbinMood.reading,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Asistente Orbi', 'Orbi assistant'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    context.tr(
                      'Consulta local guiada',
                      'Guided local assistance',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.mic_off_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.offline
                        ? context.tr(
                            'Corte de enlace simulado. Voz deshabilitada; las consultas locales siguen disponibles.',
                            'Simulated link loss. Voice disabled; local guidance remains available.',
                          )
                        : context.tr(
                            'Voz gratuita de Windows. Orbi puede leer la consulta seleccionada. Conversacion por microfono e IA aun no disponibles.',
                            'Free Windows voice. Orbi can read the selected guidance. Microphone conversation and AI are not available yet.',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: selected == null || c.offline || speaking || checking
                  ? null
                  : read,
              icon: Icon(
                checking ? Icons.hourglass_top : Icons.volume_up_outlined,
              ),
              label: Text(
                checking
                    ? context.tr('Comprobando conexion', 'Checking connection')
                    : context.tr('Escuchar respuesta', 'Listen to response'),
              ),
            ),
            if (speaking || checking)
              OutlinedButton.icon(
                onPressed: stop,
                icon: const Icon(Icons.stop),
                label: Text(context.tr('Detener', 'Stop')),
              ),
          ],
        ),
        if (voiceError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(voiceError!, semanticsLabel: voiceError),
          ),

        if (selected == null)
          BoardSection(
            children: [
              OrbinAvatar(size: 80, status: c.assistantStatus),
              Text(
                context.tr(
                  'Selecciona una consulta para ver tus datos y los siguientes pasos.',
                  'Choose a request to see your data and next steps.',
                ),
              ),
            ],
          )
        else
          for (final paragraph in LocalGuidance.answer(
            c,
            selected!,
            context.lang,
          ).split('\n').where((p) => p.trim().isNotEmpty))
            BoardSection(
              children: [Text(paragraph, style: const TextStyle(height: 1.4))],
            ),
      ],
    );
  }
}
