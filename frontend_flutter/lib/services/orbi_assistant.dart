import 'dart:io';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import 'api_service.dart';
import 'edge_controller.dart';

/// Turno de la conversación con Orbi.
class OrbiTurn {
  const OrbiTurn(this.fromUser, this.text, {this.local = false});
  final bool fromUser;
  final String text;

  /// Respuesta de las consultas locales (sin IA).
  final bool local;

  Map<String, String> toJson() => {
    'rol': fromUser ? 'user' : 'orbi',
    'mensaje': text,
  };
}

/// Resultado de una consulta. [mode]: IA, LOCAL_CRITICO, SIN_CONEXION,
/// SIN_CLAVE, ERROR o SIN_BACKEND. Sin [text], la app usa las consultas locales.
class OrbiReply {
  const OrbiReply(this.mode, this.text);
  final String mode;
  final String? text;
}

/// Orbi en línea: el backend local guarda la clave de Groq y aplica las
/// reglas de seguridad; la app envía lo que muestra en pantalla (demo o
/// backend), sin datos de identidad.
class OrbiAssistant {
  final ApiService _api = ApiService();

  /// Si el backend tiene IA configurada y el enlace no está cortado.
  Future<bool> available() async {
    try {
      final data = await _api.request(
        '/api/orbi/status',
        null,
        const Duration(seconds: 3),
      );
      return data['configured'] == true && data['offline'] != true;
    } catch (_) {
      return false;
    }
  }

  Future<OrbiReply> chat(
    String message,
    List<OrbiTurn> history,
    EdgeController controller,
    AppLanguage language,
  ) async {
    try {
      final data = await _api.request('/api/orbi/chat', {
        'mensaje': message,
        'idioma': language.name,
        'historial': historyPayload(history),
        'contexto': buildContext(controller, language),
      }, const Duration(seconds: 40));
      return OrbiReply(data['modo'] as String, data['respuesta'] as String?);
    } catch (_) {
      return const OrbiReply('SIN_BACKEND', null);
    }
  }

  /// Últimos 8 turnos de la conversación con IA; las respuestas locales no
  /// se envían (no son parte del diálogo con el modelo).
  static List<Map<String, String>> historyPayload(List<OrbiTurn> history) {
    final turns = history.where((t) => !t.local).toList();
    return [
      for (final turn in turns.skip(turns.length > 8 ? turns.length - 8 : 0))
        turn.toJson(),
    ];
  }

  /// Audio WAV de [text] con la voz natural de Gemini; null si no está
  /// disponible (sin enlace, sin backend o sin GEMINI_API_KEY).
  Future<List<int>?> speech(String text, AppLanguage language) async {
    try {
      final bytes = await _api.postForBytes('/api/orbi/speak', {
        'texto': text.length > 2000 ? text.substring(0, 2000) : text,
        'idioma': language.name,
      });
      return bytes.length > 44 ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  /// Transcribe un WAV con Whisper en Groq; null si no hay servicio.
  Future<String?> transcribe(String wavPath, AppLanguage language) async {
    try {
      final data = await _api.postBytes(
        '/api/orbi/transcribe?idioma=${language.name}',
        await File(wavPath).readAsBytes(),
      );
      final text = (data['texto'] as String?)?.trim();
      return data['modo'] == 'IA' && text != null && text.isNotEmpty
          ? text
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Instantánea de lo que ve el tripulante: valores, estados, alertas,
  /// bienestar, tendencias día a día, síntomas y entorno. Sin nombre ni
  /// identificadores.
  static Map<String, dynamic> buildContext(
    EdgeController c,
    AppLanguage language,
  ) {
    String t(T text) => text.of(language);
    final days = c.history;
    return {
      'datos_simulados': c.demo,
      'entorno': t(c.environment.name),
      'dia_mision': c.missionDay,
      'estado_general': c.assistantStatus.name,
      'ultima_lectura_utc': c.latest?.time.toUtc().toIso8601String(),
      'indicadores': [
        for (final ind in indicators)
          if (ind.id != 'presion_diastolica' && c.valueOf(ind.id) != null)
            {
              'id': ind.id,
              'nombre': t(ind.name),
              'valor': c.displayValue(ind.id),
              'unidad': t(ind.unit),
              'estado': c.displayStatus(ind.id).name,
              'rango_habitual': t(ind.normalRange),
            },
      ],
      'alertas_activas': [
        for (final alert in c.alerts.where((a) => a['atendida'] == 0))
          {
            'metrica': alert['metrica_afectada'],
            'nivel': alert['nivel_severidad'],
            'accion': EdgeController.alertMessage(alert, language),
          },
      ],
      'bienestar_reciente': [
        for (final entry in c.wellbeing.take(5))
          {
            for (final key in [
              'timestamp_utc',
              'horas_sueno',
              'agua_ml',
              'energia',
              'animo',
            ])
              if (entry[key] != null) key: entry[key],
          },
      ],
      // Historial día a día para que Orbi compare fechas concretas.
      'historial_por_dia': [
        for (final day in days.reversed.take(14))
          {
            'fecha': '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}',
            'valores': {
              for (final entry in day.values.entries)
                entry.key: double.parse(entry.value.toStringAsFixed(1)),
            },
          },
      ],
      'sintomas_marcados': [
        for (final region in bodyRegions)
          if (c.symptoms[region.id]?.isNotEmpty ?? false)
            {
              'zona': t(region.name),
              'sintomas': [
                for (final s in region.symptoms)
                  if (c.symptoms[region.id]!.contains(s.id)) t(s.question),
              ],
            },
      ],
    };
  }

  void dispose() => _api.dispose();
}
