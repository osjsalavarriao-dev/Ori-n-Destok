import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import '../services/edge_controller.dart';
import '../services/local_guidance.dart';
import '../services/orbi_assistant.dart';
import '../services/orbi_listener.dart';
import '../services/orbi_voice.dart';
import '../widgets/orbin_avatar.dart';
import '../widgets/viewport_board.dart';

class OrbiChatScreen extends StatefulWidget {
  const OrbiChatScreen({super.key, required this.controller});
  final EdgeController controller;
  @override
  State<OrbiChatScreen> createState() => _OrbiChatScreenState();
}

class _OrbiChatScreenState extends State<OrbiChatScreen> {
  final voice = OrbiVoice();
  final listener = OrbiListener();
  final assistant = OrbiAssistant();
  final input = TextEditingController();

  /// Conversación de esta sesión, del más antiguo al más reciente.
  final List<OrbiTurn> turns = [];
  LocalRequest? selected;

  /// null: aún sin comprobar.
  bool? aiOnline;
  bool speaking = false, checking = false, listening = false, thinking = false;
  String? heard;
  int micLevel = 0;
  String engine = '';
  ListenPhase phase = ListenPhase.preparing;
  int liveLevel = 0, peakLevel = 0;
  int generation = 0;
  String? notice;
  VoiceEngine? voiceEngine;
  bool wasOffline = false;
  HealthStatus? spokenStatus;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(onState);
    checkAi();
  }

  Future<void> checkAi() async {
    final online = !widget.controller.offline && await assistant.available();
    if (mounted) setState(() => aiOnline = online);
  }

  void onState() {
    final offline = widget.controller.offline;
    // Se interrumpe al cortarse el enlace (no en cada refresco durante el
    // corte, para que la voz local pueda leer) o si cambia el riesgo.
    if ((offline && !wasOffline) ||
        (speaking && spokenStatus != widget.controller.assistantStatus)) {
      stop();
    }
    wasOffline = offline;
    if (widget.controller.offline && aiOnline == true) {
      setState(() => aiOnline = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) {
      voice.stop();
      listener.stop();
      speaking = false;
      checking = false;
      listening = false;
      thinking = false;
      generation++;
    }
  }

  void stop() {
    generation++;
    voice.stop();
    listener.stop();
    if (mounted) {
      setState(() {
        speaking = false;
        checking = false;
        listening = false;
        thinking = false;
      });
    }
  }

  bool get busy => speaking || checking || listening || thinking;

  /// Consulta rápida: respuesta local determinista, sin IA.
  void askLocal(LocalRequest request, {bool speak = false}) {
    stop();
    final answer = LocalGuidance.answer(
      widget.controller,
      request,
      context.lang,
    );
    setState(() {
      selected = request;
      notice = null;
      turns
        ..add(OrbiTurn(true, context.t(LocalGuidance.label(request))))
        ..add(OrbiTurn(false, answer, local: true));
    });
    if (speak) say(answer);
  }

  /// Pregunta libre: IA si está disponible; si no, consulta local por
  /// palabras clave.
  Future<void> ask(String text, {bool speak = false}) async {
    final question = text.trim();
    if (question.isEmpty || busy) return;
    stop();
    final token = generation;
    final history = List<OrbiTurn>.of(turns);
    setState(() {
      turns.add(OrbiTurn(true, question));
      thinking = true;
      notice = null;
      selected = null;
      input.clear();
    });
    final reply = widget.controller.offline
        ? const OrbiReply('SIN_CONEXION', null)
        : await assistant.chat(
            question,
            history,
            widget.controller,
            context.lang,
          );
    if (!mounted || token != generation) return;
    final answer = reply.text;
    if (answer != null) {
      setState(() {
        thinking = false;
        aiOnline = true;
        turns.add(OrbiTurn(false, answer));
      });
      if (speak) await say(answer);
      return;
    }
    // Sin IA: la consulta local más parecida, o una explicación.
    final request = OrbiListener.match(question);
    setState(() {
      thinking = false;
      aiOnline = false;
      notice = switch (reply.mode) {
        'SIN_CONEXION' => context.tr(
          'Sin enlace: respondo con las consultas locales.',
          'No link: answering with local guidance.',
        ),
        'SIN_CLAVE' => context.tr(
          'La IA no esta configurada (falta GROQ_API_KEY en el backend). Respondo con las consultas locales.',
          'AI is not configured (GROQ_API_KEY missing in the backend). Answering with local guidance.',
        ),
        'SIN_BACKEND' => context.tr(
          'No encuentro el backend local (FastAPI). Respondo con las consultas locales.',
          'Local backend (FastAPI) not found. Answering with local guidance.',
        ),
        _ => context.tr(
          'La IA no respondio. Respondo con las consultas locales.',
          'The AI did not answer. Answering with local guidance.',
        ),
      };
    });
    if (request != null) {
      final local = LocalGuidance.answer(
        widget.controller,
        request,
        context.lang,
      );
      setState(() {
        selected = request;
        turns.add(OrbiTurn(false, local, local: true));
      });
      if (speak) await say(local);
    } else {
      setState(
        () => turns.add(
          OrbiTurn(
            false,
            context.tr(
              'Sin IA solo puedo responder las consultas rapidas: signos vitales, ejercicio, comida o monitoreo.',
              'Without AI I can only answer the quick requests: vital signs, exercise, food or monitoring.',
            ),
            local: true,
          ),
        ),
      );
    }
  }

  /// Escucha una pregunta hablada y la responde en voz alta.
  Future<void> listen() async {
    if (widget.controller.offline) return;
    stop();
    final token = generation;
    setState(() {
      listening = true;
      heard = null;
      notice = null;
      phase = ListenPhase.preparing;
      liveLevel = 0;
      peakLevel = 0;
    });
    final language = context.lang;
    final online = await assistant.available();
    if (!mounted || token != generation) return;
    final result = await listener.listen(
      spanish: language == AppLanguage.es,
      remoteTranscribe: online
          ? (path) => assistant.transcribe(path, language)
          : null,
      onProgress: (p, level) {
        if (!mounted || token != generation) return;
        setState(() {
          phase = p;
          liveLevel = p == ListenPhase.listening ? level : 0;
          if (level > peakLevel) peakLevel = level;
        });
      },
    );
    if (!mounted || token != generation || result == null) return;
    setState(() {
      listening = false;
      aiOnline = online;
      heard = result.heard;
      micLevel = result.level;
      engine = result.engine;
      notice = switch (result.failure) {
        null || ListenFailure.notUnderstood => null,
        ListenFailure.noRecognizer => context.tr(
          'No hay reconocimiento de voz de Windows instalado para este idioma.',
          'No Windows speech recognizer is installed for this language.',
        ),
        ListenFailure.noMicrophone => context.tr(
          'No se encontro un microfono. Revisa la configuracion de sonido de Windows.',
          'No microphone found. Check the Windows sound settings.',
        ),
        ListenFailure.noSpeech =>
          result.level < 5
              ? context.tr(
                  'No llega sonido del microfono (nivel ${result.level}/100). Revisa en Windows cual es el microfono predeterminado y su volumen.',
                  'No sound from the microphone (level ${result.level}/100). Check the default Windows microphone and its volume.',
                )
              : context.tr(
                  'Te oi (nivel ${result.level}/100) pero no reconoci palabras. Habla un poco mas cerca y despacio.',
                  'I heard you (level ${result.level}/100) but did not recognize words. Speak a bit closer and slower.',
                ),
        ListenFailure.unavailable => context.tr(
          'No se pudo usar el microfono.',
          'Could not use the microphone.',
        ),
      };
    });
    final text = result.heard;
    if (text == null) return;
    if (online) {
      await ask(text, speak: true);
    } else if (result.request != null) {
      askLocal(result.request!, speak: true);
    } else {
      setState(
        () => notice = context.tr(
          'No te entendi. Prueba con: "signos vitales", "ejercicio", "comida" o "monitoreo".',
          'I did not understand. Try: "vital signs", "exercise", "food" or "monitoring".',
        ),
      );
    }
  }

  /// Lee un texto con la voz de Windows (solo con conexión, regla de producto).
  /// Lee [text] en voz alta: Gemini si la IA está en línea; si no, Piper
  /// (local, también sin enlace) y, como último recurso, la voz de Windows.
  Future<void> say(String text) async {
    final token = ++generation;
    final language = context.lang;
    final cloud = aiOnline == true && !widget.controller.offline;
    setState(() {
      checking = true;
      notice = null;
    });
    spokenStatus = widget.controller.assistantStatus;
    try {
      final engine = await voice.speak(
        text,
        spanish: language == AppLanguage.es,
        cloud: cloud ? () => assistant.speech(text, language) : null,
        onPlay: (engine) {
          if (!mounted || token != generation) return;
          setState(() {
            checking = false;
            speaking = true;
            voiceEngine = engine;
          });
        },
      );
      if (engine != null && mounted && token == generation) {
        setState(() => voiceEngine = engine);
      }
    } catch (_) {
      if (mounted && token == generation) {
        setState(
          () => notice = context.tr(
            'No se pudo reproducir ninguna voz.',
            'Could not play any voice.',
          ),
        );
      }
    } finally {
      if (mounted && token == generation) stop();
    }
  }

  String _engineName(BuildContext context) => switch (voiceEngine) {
    VoiceEngine.gemini => 'Gemini',
    VoiceEngine.piper => context.tr('local (Piper)', 'local (Piper)'),
    VoiceEngine.windows => 'Windows',
    null => '',
  };

  String? get lastAnswer {
    for (final turn in turns.reversed) {
      if (!turn.fromUser) return turn.text;
    }
    return null;
  }

  /// Medidor del micrófono: fase y nivel actual/máximo, para saber si la app
  /// recibe sonido.
  Widget _levelMeter(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label) = switch (phase) {
      ListenPhase.preparing => (
        Icons.hourglass_top,
        context.tr(
          'Preparando microfono... espera',
          'Preparing microphone... wait',
        ),
      ),
      ListenPhase.listening => (
        Icons.mic,
        context.tr('Habla ahora', 'Speak now'),
      ),
      ListenPhase.transcribing => (
        Icons.text_snippet_outlined,
        context.tr('Transcribiendo...', 'Transcribing...'),
      ),
    };
    final color = liveLevel < 5
        ? scheme.outline
        : liveLevel < 20
        ? Colors.amber
        : Colors.greenAccent.shade400;
    final hint = phase != ListenPhase.listening
        ? null
        : peakLevel < 5
        ? context.tr(
            'No llega sonido. Si estas hablando, revisa el microfono de Windows.',
            'No sound arriving. If you are speaking, check the Windows microphone.',
          )
        : peakLevel < 20
        ? context.tr(
            'Sonido debil: acercate o sube el volumen del microfono.',
            'Weak sound: move closer or raise the microphone volume.',
          )
        : context.tr('Te escucho bien.', 'I hear you well.');
    return BoardSection(
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(
              '${context.tr('Nivel', 'Level')} $liveLevel · '
              '${context.tr('max', 'peak')} $peakLevel',
              semanticsLabel: context.tr(
                'Nivel de microfono $liveLevel de 100, maximo $peakLevel',
                'Microphone level $liveLevel of 100, peak $peakLevel',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: phase == ListenPhase.listening
                ? (liveLevel / 100).clamp(0.0, 1.0)
                : null,
            minHeight: 12,
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  /// Secciones de un turno. Las respuestas locales largas se dividen por
  /// párrafo para que cada sección quepa en la pantalla.
  List<Widget> _turnSections(BuildContext context, OrbiTurn turn) {
    final theme = Theme.of(context);
    final title = turn.fromUser
        ? context.tr('Tu', 'You')
        : turn.local
        ? context.tr('Orbi · consulta local', 'Orbi · local guidance')
        : 'Orbi';
    final paragraphs = turn.local
        ? turn.text.split('\n').where((p) => p.trim().isNotEmpty).toList()
        : [turn.text];
    return [
      for (var i = 0; i < paragraphs.length; i++)
        BoardSection(
          title: i == 0 ? title : null,
          children: [
            Text(
              paragraphs[i],
              style: turn.fromUser
                  ? theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    )
                  : const TextStyle(height: 1.4),
            ),
          ],
        ),
    ];
  }

  @override
  void dispose() {
    generation++;
    widget.controller.removeListener(onState);
    voice.dispose();
    listener.dispose();
    assistant.dispose();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final ai = aiOnline == true && !c.offline;
    // Intercambios del más reciente al más antiguo: el último siempre queda
    // en la primera página.
    final exchanges = <List<OrbiTurn>>[];
    for (final turn in turns) {
      if (turn.fromUser || exchanges.isEmpty) {
        exchanges.add([turn]);
      } else {
        exchanges.last.add(turn);
      }
    }
    final answer = lastAnswer;
    return ScreenBoard(
      key: ValueKey(turns.length),
      title: context.tr('Asistente Orbi', 'Orbi assistant'),
      minColumnWidth: 330,
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Con el enlace cortado el chat queda bloqueado: solo consultas rápidas.
          if (!c.offline) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    enabled: !busy,
                    textInputAction: TextInputAction.send,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      border: const OutlineInputBorder(),
                      hintText: ai
                          ? context.tr(
                              'Preguntale a Orbi lo que quieras sobre tu salud...',
                              'Ask Orbi anything about your health...',
                            )
                          : context.tr(
                              'Escribe: signos vitales, ejercicio, comida o monitoreo',
                              'Type: vital signs, exercise, food or monitoring',
                            ),
                    ),
                    onSubmitted: (text) => ask(text),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.tr('Hablar con Orbi', 'Talk to Orbi'),
                  onPressed: busy ? null : listen,
                  icon: Icon(listening ? Icons.graphic_eq : Icons.mic),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  tooltip: context.tr('Enviar', 'Send'),
                  onPressed: busy ? null : () => ask(input.text),
                  icon: const Icon(Icons.send),
                ),
                if (busy)
                  IconButton.outlined(
                    tooltip: context.tr('Detener', 'Stop'),
                    onPressed: stop,
                    icon: const Icon(Icons.stop),
                  )
                else if (answer != null)
                  IconButton.outlined(
                    tooltip: context.tr(
                      'Escuchar respuesta',
                      'Listen to response',
                    ),
                    onPressed: () => say(answer),
                    icon: const Icon(Icons.volume_up_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final request in LocalRequest.values)
                ChoiceChip(
                  label: Text(context.t(LocalGuidance.label(request))),
                  selected: selected == request,
                  onSelected: busy ? null : (_) => askLocal(request),
                ),
              // Sin enlace no hay barra de chat: la voz local se controla aquí.
              if (c.offline && busy)
                IconButton.outlined(
                  tooltip: context.tr('Detener', 'Stop'),
                  onPressed: stop,
                  icon: const Icon(Icons.stop),
                )
              else if (c.offline && answer != null)
                IconButton.outlined(
                  tooltip: context.tr(
                    'Escuchar respuesta',
                    'Listen to response',
                  ),
                  onPressed: () => say(answer),
                  icon: const Icon(Icons.volume_up_outlined),
                ),
            ],
          ),
        ],
      ),
      children: [
        BoardSection(
          children: [
            Row(
              children: [
                OrbinAvatar(
                  size: 44,
                  status: c.assistantStatus,
                  mood: listening
                      ? OrbinMood.listening
                      : speaking
                      ? OrbinMood.speaking
                      : thinking || turns.isNotEmpty
                      ? OrbinMood.reading
                      : OrbinMood.idle,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.offline
                            ? context.tr(
                                'Corte de enlace: solo consultas rapidas',
                                'Link loss: quick requests only',
                              )
                            : ai
                            ? context.tr(
                                'IA en linea (Groq)',
                                'AI online (Groq)',
                              )
                            : aiOnline == null
                            ? context.tr('Comprobando IA...', 'Checking AI...')
                            : context.tr(
                                'Sin IA: consultas rapidas',
                                'No AI: quick requests',
                              ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        thinking
                            ? context.tr(
                                'Orbi esta pensando...',
                                'Orbi is thinking...',
                              )
                            : checking
                            ? context.tr(
                                'Preparando voz...',
                                'Preparing voice...',
                              )
                            : speaking
                            ? context.tr(
                                'Hablando con voz ${_engineName(context)}',
                                'Speaking with ${_engineName(context)} voice',
                              )
                            : c.offline
                            ? context.tr(
                                'Chat y microfono deshabilitados; la voz local sigue activa.',
                                'Chat and microphone disabled; local voice still works.',
                              )
                            : ai
                            ? context.tr(
                                'Habla o escribe. No diagnostica ni receta.',
                                'Speak or type. It does not diagnose or prescribe.',
                              )
                            : context.tr(
                                'Usa las consultas rapidas o el microfono.',
                                'Use the quick requests or the microphone.',
                              ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        if (listening) _levelMeter(context),
        if (notice != null || (heard != null && !listening))
          BoardSection(
            children: [
              if (heard != null && !listening)
                Text(
                  '${context.tr('Escuche', 'Heard')}: "$heard"  '
                  '(${context.tr('microfono', 'microphone')} $micLevel/100, $engine)',
                ),
              if (notice != null) Text(notice!, semanticsLabel: notice),
            ],
          ),
        if (turns.isEmpty)
          BoardSection(
            children: [
              Text(
                ai
                    ? context.tr(
                        'Preguntame, por ejemplo: "¿como estoy hoy?", "¿por que duermo mal?" o "me siento solo".',
                        'Ask me, for example: "how am I today?", "why am I sleeping badly?" or "I feel lonely".',
                      )
                    : context.tr(
                        'Selecciona una consulta para ver tus datos y los siguientes pasos.',
                        'Choose a request to see your data and next steps.',
                      ),
              ),
            ],
          ),
        for (final exchange in exchanges.reversed)
          for (final turn in exchange) ..._turnSections(context, turn),
      ],
    );
  }
}
