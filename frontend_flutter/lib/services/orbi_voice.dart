import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Motor que pronunció la última respuesta.
enum VoiceEngine { gemini, piper, windows }

/// Voz de Orbi, de la más natural a la más básica:
/// 1. Gemini (en línea, vía backend): la más humana.
/// 2. Piper (neuronal, local, sin conexión): tools/setup_piper.ps1.
/// 3. Voz clásica de Windows (SAPI): último recurso.
/// El texto viaja siempre por stdin o en archivos temporales; nunca se
/// interpola en comandos.
class OrbiVoice {
  Process? _process;
  int _generation = 0;
  final HttpClient _network = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);

  /// Comprobación de internet (endpoint público de Microsoft, sin datos de
  /// salud). Es HTTP a propósito: por HTTPS su certificado no coincide.
  Future<bool> online() async {
    try {
      final request = await _network
          .getUrl(Uri.parse('http://www.msftconnecttest.com/connecttest.txt'))
          .timeout(const Duration(seconds: 4));
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200 &&
          body.trim() == 'Microsoft Connect Test';
    } catch (_) {
      return false;
    }
  }

  /// Busca piper.exe y la voz del idioma: HORION_PIPER_DIR, una carpeta
  /// `piper` junto al ejecutable o %LOCALAPPDATA%\HorionEdge\piper.
  static ({String exe, String model})? findPiper({required bool spanish}) {
    final env = Platform.environment;
    final dirs = [
      ?env['HORION_PIPER_DIR'],
      '${File(Platform.resolvedExecutable).parent.path}\\piper',
      if (env['LOCALAPPDATA'] case final local?) '$local\\HorionEdge\\piper',
    ];
    final prefix = spanish ? 'es_' : 'en_';
    for (final dir in dirs) {
      final exe = [
        '$dir\\piper\\piper.exe',
        '$dir\\piper.exe',
      ].where((p) => File(p).existsSync()).firstOrNull;
      final voices = Directory('$dir\\voices');
      if (exe == null || !voices.existsSync()) continue;
      final models =
          voices.listSync().whereType<File>().map((f) => f.path).where((p) {
            final name = p.split('\\').last;
            return name.startsWith(prefix) && name.endsWith('.onnx');
          }).toList()..sort();
      // Prefiere calidad alta (…-high) si hay varias voces.
      final model =
          models.where((p) => p.contains('-high')).firstOrNull ??
          models.firstOrNull;
      if (model != null) return (exe: exe, model: model);
    }
    return null;
  }

  /// Pronuncia [text]. [cloud] obtiene el WAV de Gemini (o null). [onPlay]
  /// avisa cuando empieza a sonar y con qué motor. Lanza si ningún motor
  /// pudo hablar; termina sin error si se canceló con [stop].
  Future<VoiceEngine?> speak(
    String text, {
    required bool spanish,
    Future<List<int>?> Function()? cloud,
    void Function(VoiceEngine engine)? onPlay,
  }) async {
    stop();
    final generation = _generation;
    if (!Platform.isWindows) throw UnsupportedError('Windows voice required');
    final wav =
        '${Directory.systemTemp.path}\\orbi_voice_${DateTime.now().microsecondsSinceEpoch}.wav';
    try {
      // 1. Gemini.
      if (cloud != null) {
        final audio = await cloud();
        if (generation != _generation) return null;
        if (audio != null) {
          await File(wav).writeAsBytes(audio, flush: true);
          onPlay?.call(VoiceEngine.gemini);
          if (await _play(generation, wav)) return VoiceEngine.gemini;
          if (generation != _generation) return null;
        }
      }
      // 2. Piper.
      final piper = findPiper(spanish: spanish);
      if (piper != null) {
        final code = await _run(generation, piper.exe, [
          '--model',
          piper.model,
          '--output_file',
          wav,
        ], stdin: text.replaceAll('\n', ' '));
        if (generation != _generation) return null;
        if (code == 0 && File(wav).existsSync()) {
          onPlay?.call(VoiceEngine.piper);
          if (await _play(generation, wav)) return VoiceEngine.piper;
          if (generation != _generation) return null;
        }
      }
      // 3. Voz clásica de Windows.
      onPlay?.call(VoiceEngine.windows);
      final code = await _run(
        generation,
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', sapiScript],
        stdin: jsonEncode({
          'text': text,
          'voice': spanish
              ? 'Microsoft Sabina Desktop'
              : 'Microsoft Zira Desktop',
          'culture': spanish ? 'es' : 'en',
        }),
      );
      if (generation != _generation) return null;
      if (code != 0) throw StateError('Windows voice unavailable');
      return VoiceEngine.windows;
    } finally {
      try {
        File(wav).deleteSync();
      } catch (_) {}
    }
  }

  /// Reproduce un WAV hasta el final (o hasta [stop]).
  Future<bool> _play(int generation, String wav) async {
    final code = await _run(generation, 'powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      playScript,
    ], stdin: wav);
    return code == 0;
  }

  Future<int> _run(
    int generation,
    String executable,
    List<String> arguments, {
    String? stdin,
  }) async {
    if (generation != _generation) return -1;
    final process = await Process.start(executable, arguments);
    if (generation != _generation) {
      process.kill();
      return -1;
    }
    _process = process;
    final output = process.stdout.drain<void>();
    final errors = process.stderr.drain<void>();
    // Los scripts y Piper leen UTF-8; el valor por defecto estropeaba tildes.
    process.stdin.encoding = utf8;
    if (stdin != null) process.stdin.writeln(stdin);
    await process.stdin.close();
    final code = await process.exitCode.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    await Future.wait([output, errors]);
    if (generation == _generation) _process = null;
    return code;
  }

  void stop() {
    _generation++;
    _process?.kill();
    _process = null;
  }

  void dispose() {
    stop();
    _network.close(force: true);
  }

  static const playScript = r"""
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
$path = [Console]::ReadLine().Trim()
$player = New-Object System.Media.SoundPlayer $path
try { $player.PlaySync() } finally { $player.Dispose() }
""";

  static const sapiScript = r"""
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Speech
$data = [Console]::ReadLine() | ConvertFrom-Json
$speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
  # Preferred voice, else any installed voice for the language (e.g. Helena
  # es-ES when Sabina es-MX is missing). Fails only if none exists.
  $voices = $speech.GetInstalledVoices() | Where-Object { $_.Enabled } | ForEach-Object { $_.VoiceInfo }
  $pick = $voices | Where-Object { $_.Name -eq [string]$data.voice } | Select-Object -First 1
  if (-not $pick) {
    $pick = $voices | Where-Object { $_.Culture.TwoLetterISOLanguageName -eq [string]$data.culture } | Select-Object -First 1
  }
  if (-not $pick) { throw "No installed voice for $($data.culture)" }
  $speech.SelectVoice($pick.Name)
  $speech.Rate = 0
  $speech.Speak([string]$data.text)
} finally { $speech.Dispose() }
""";
}
