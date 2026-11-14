import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Windows TTS. Text is sent as JSON on stdin, never interpolated into commands.
class OrbiVoice {
  Process? _process;
  int _generation = 0;
  final HttpClient _network = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);
  Future<bool> online() async {
    try {
      final request = await _network
          .getUrl(Uri.parse('https://www.msftconnecttest.com/connecttest.txt'))
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

  Future<void> speak(String text, {required bool spanish}) async {
    stop();
    final generation = _generation;
    if (!Platform.isWindows) throw UnsupportedError('Windows TTS required');
    final process = await Process.start('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      script,
    ], mode: ProcessStartMode.normal);
    if (generation != _generation) {
      process.kill();
      return;
    }
    _process = process;
    final output = process.stdout.drain<void>();
    final errors = process.stderr.drain<void>();
    process.stdin.writeln(
      jsonEncode({
        'text': text,
        'voice': spanish
            ? 'Microsoft Sabina Desktop'
            : 'Microsoft Zira Desktop',
      }),
    );
    await process.stdin.close();
    final code = await process.exitCode.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    await Future.wait([output, errors]);
    if (generation != _generation) return;
    _process = null;
    if (code != 0) throw StateError('Windows voice unavailable');
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

  static const script = r"""
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Speech
$data = [Console]::ReadLine() | ConvertFrom-Json
$speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
  $speech.SelectVoice([string]$data.voice)
  $speech.Rate = 0
  $speech.Speak([string]$data.text)
} finally { $speech.Dispose() }
""";
}
