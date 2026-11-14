import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../services/edge_controller.dart';

class OrbiChatScreen extends StatefulWidget {
  const OrbiChatScreen({super.key, required this.controller});
  final EdgeController controller;
  @override
  State<OrbiChatScreen> createState() => _OrbiChatScreenState();
}

class _OrbiChatScreenState extends State<OrbiChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  void send([String? text]) {
    widget.controller.sendDemoMessage(text ?? _text.text, context.lang);
    _text.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final enabled = c.demo && !c.offline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Asistente Orbi', 'Orbi assistant'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              c.offline
                  ? context.tr(
                      'Corte de enlace simulado. Chat en pausa; el simulador de monitoreo continúa.',
                      'Simulated link loss. Chat paused; the monitoring simulator keeps running.',
                    )
                  : c.demo
                  ? context.tr(
                      'Modo demo · Respuestas predefinidas, sin IA ni evaluación médica.',
                      'Demo mode · Canned replies, no AI and no medical assessment.',
                    )
                  : context.tr(
                      'Gemini no está configurado. El backend local registra telemetría y bienestar.',
                      'Gemini is not configured. The local backend records telemetry and wellbeing.',
                    ),
            ),
          ),
        ),
        Expanded(
          child: c.messages.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.blur_circular,
                          size: 70,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('Hola, soy Orbi.', "Hi, I'm Orbi."),
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                            'Explora la conversación en modo demo.',
                            'Try out the conversation in demo mode.',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  itemCount: c.messages.length,
                  itemBuilder: (context, index) {
                    final message = c.messages[index];
                    return Align(
                      alignment: message['role'] == 'user'
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Card(
                          color: message['role'] == 'user'
                              ? const Color(0xFF15354A)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(message['text']!),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
                context.tr('Ver mis signos vitales', 'Show my vital signs'),
                context.tr('Estado del monitoreo', 'Monitoring status'),
              ]
              .map(
                (q) => ActionChip(
                  label: Text(q),
                  onPressed: enabled ? () => send(q) : null,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                enabled: enabled,
                onSubmitted: (_) => send(),
                decoration: InputDecoration(
                  hintText: context.tr('Escribe a Orbi…', 'Message Orbi…'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: enabled ? () => send() : null,
              tooltip: context.tr('Enviar mensaje', 'Send message'),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'Ctrl + O para abrir Orbi · Voz pendiente de integración',
            'Ctrl + O to open Orbi · Voice not integrated yet',
          ),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
