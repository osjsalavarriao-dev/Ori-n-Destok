import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'local_guidance.dart';

/// Live stage of a listen: starting the engine, capturing audio (with a
/// level), or transcribing with Whisper.
enum ListenPhase { preparing, listening, transcribing }

enum ListenFailure {
  noRecognizer,
  noMicrophone,
  noSpeech,
  notUnderstood,
  unavailable,
}

class ListenResult {
  const ListenResult({
    this.request,
    this.heard,
    this.failure,
    this.level = 0,
    this.engine = 'Windows',
  });
  final LocalRequest? request;

  /// Which engine produced [heard]: "Whisper" or "Windows".
  final String engine;
  final String? heard;
  final ListenFailure? failure;

  /// Peak microphone level seen while listening (0-100).
  final int level;
}

/// Offline Windows speech recognition (System.Speech). Command phrases per
/// [LocalRequest] are tried first; free dictation is a fallback whose text is
/// mapped to a request by keywords. Phrases travel as JSON on stdin and are
/// never interpolated into commands. No audio leaves the machine.
class OrbiListener {
  Process? _process;
  int _generation = 0;

  static const _phrases = {
    'es': {
      LocalRequest.status: [
        'signos vitales',
        'mis signos vitales',
        'ver mis signos vitales',
        'cómo estoy',
        'mi estado',
        'estado de salud',
        'mis datos',
      ],
      LocalRequest.exercise: [
        'ejercicio',
        'ejercicios',
        'rutina',
        'rutina de ejercicios',
        'qué ejercicio hago',
      ],
      LocalRequest.food: [
        'comida',
        'comida e hidratación',
        'hidratación',
        'alimentación',
        'qué como',
        'agua',
      ],
      LocalRequest.monitoring: [
        'monitoreo',
        'estado del monitoreo',
        'conexión',
        'estado del sistema',
      ],
    },
    'en': {
      LocalRequest.status: [
        'vital signs',
        'my vital signs',
        'show my vital signs',
        'how am i',
        'my status',
        'health status',
      ],
      LocalRequest.exercise: ['exercise', 'exercise routine', 'workout'],
      LocalRequest.food: ['food', 'food and hydration', 'hydration', 'water'],
      LocalRequest.monitoring: [
        'monitoring',
        'monitoring status',
        'connection',
        'system status',
      ],
    },
  };

  /// Keyword stems (accent-free, lowercase) used to map dictated text.
  /// Monitoring is checked first because "estado del monitoreo" contains
  /// "estado".
  static const _keywords = [
    (
      LocalRequest.monitoring,
      ['monitor', 'conexion', 'sistema', 'sensor', 'connection'],
    ),
    (
      LocalRequest.exercise,
      ['ejercic', 'rutina', 'entren', 'deporte', 'exercis', 'workout'],
    ),
    (
      LocalRequest.food,
      [
        'comida',
        'comer',
        'hidrat',
        'agua',
        'aliment',
        'nutri',
        'menu',
        'beber',
        'food',
        'water',
        'eat',
        'drink',
      ],
    ),
    (
      LocalRequest.status,
      [
        'vital',
        'sign',
        'salud',
        'como estoy',
        'mi estado',
        'pulso',
        'corazon',
        'ritmo',
        'temperatura',
        'oxigeno',
        'presion',
        'datos',
        'status',
        'health',
        'heart',
        'how am i',
      ],
    ),
  ];

  static String _normalize(String text) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunAEIOUUN';
    final buffer = StringBuffer();
    for (final ch in text.split('')) {
      final i = from.indexOf(ch);
      buffer.write(i >= 0 ? to[i] : ch);
    }
    return buffer.toString().toLowerCase();
  }

  /// Maps free text to a request by keyword, or null.
  static LocalRequest? match(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final normalized = _normalize(text);
    for (final (request, stems) in _keywords) {
      if (stems.any(normalized.contains)) return request;
    }
    return null;
  }

  /// Locates whisper.cpp and a model: HORION_WHISPER_DIR, a `whisper`
  /// folder next to the executable, or %LOCALAPPDATA%\HorionEdge\whisper
  /// (where tools/setup_whisper.ps1 installs it). Prefers the small model.
  static ({String cli, String model})? findWhisper() {
    final env = Platform.environment;
    final dirs = [
      ?env['HORION_WHISPER_DIR'],
      '${File(Platform.resolvedExecutable).parent.path}\\whisper',
      if (env['LOCALAPPDATA'] case final local?) '$local\\HorionEdge\\whisper',
    ];
    for (final dir in dirs) {
      final cli = [
        '$dir\\bin\\Release\\whisper-cli.exe',
        '$dir\\bin\\whisper-cli.exe',
        '$dir\\whisper-cli.exe',
      ].where((p) => File(p).existsSync()).firstOrNull;
      final model = [
        '$dir\\ggml-small.bin',
        '$dir\\ggml-base.bin',
      ].where((p) => File(p).existsSync()).firstOrNull;
      if (cli != null && model != null) return (cli: cli, model: model);
    }
    return null;
  }

  /// Listens once (up to [seconds] of initial silence) and maps the phrase.
  /// With a transcriber ([remoteTranscribe], e.g. Whisper on Groq, or local
  /// Whisper) the microphone is recorded directly and transcribed; otherwise
  /// Windows recognition decides alone. Returns null when cancelled with
  /// [stop]. [waveFile] replaces the microphone, for diagnostics.
  Future<ListenResult?> listen({
    required bool spanish,
    int seconds = 8,
    String? waveFile,
    void Function(ListenPhase phase, int level)? onProgress,
    Future<String?> Function(String wavPath)? remoteTranscribe,
  }) async {
    stop();
    final generation = _generation;
    void progress(ListenPhase phase, int level) {
      if (generation == _generation) onProgress?.call(phase, level);
    }

    progress(ListenPhase.preparing, 0);
    if (!Platform.isWindows) {
      return const ListenResult(failure: ListenFailure.unavailable);
    }
    final culture = spanish ? 'es' : 'en';
    final phrases = _phrases[culture]!;
    final whisper = findWhisper();
    // With Whisper: record the microphone directly (energy-based cut) and
    // transcribe. Without it: Windows recognition decides alone.
    final transcriber = whisper != null || remoteTranscribe != null;
    final direct = transcriber && waveFile == null;
    final recording = !transcriber
        ? null
        : waveFile ??
              '${Directory.systemTemp.path}\\orbi_${DateTime.now().microsecondsSinceEpoch}.wav';
    try {
      final output = await _run(
        generation,
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          direct ? recordScript : script,
        ],
        Duration(seconds: seconds + 25),
        stdin: jsonEncode({
          'culture': culture,
          'seconds': seconds,
          'wav': waveFile,
          'save': direct ? recording : null,
          'intents': {
            for (final entry in phrases.entries) entry.key.name: entry.value,
          },
        }),
        // Live lines from the script: "R" = ready, "L <0-100>" = mic level.
        onLine: (line) {
          if (line == 'R') {
            progress(ListenPhase.listening, 0);
          } else if (line.startsWith('L ')) {
            final level = int.tryParse(line.substring(2));
            if (level != null) progress(ListenPhase.listening, level);
          }
        },
      );
      if (generation != _generation) return null;
      if (output == null) {
        return const ListenResult(failure: ListenFailure.unavailable);
      }
      final Map<String, dynamic> data;
      try {
        final line = output
            .split('\n')
            .map((l) => l.replaceAll('﻿', '').trim())
            .lastWhere((l) => l.startsWith('{'));
        data = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        return const ListenResult(failure: ListenFailure.unavailable);
      }
      if (recording != null &&
          (data['audio'] == true || waveFile != null) &&
          File(recording).existsSync()) {
        progress(ListenPhase.transcribing, 0);
        String? text;
        var engine = 'Whisper';
        if (remoteTranscribe != null) {
          text = await remoteTranscribe(recording);
          if (generation != _generation) return null;
          if (text != null) engine = 'Groq';
        }
        if (text == null && whisper != null) {
          final transcript = await _run(generation, whisper.cli, [
            ...['-m', whisper.model, '-f', recording, '-l', culture],
            ...['-nt', '-np', '-sns'],
          ], const Duration(seconds: 40));
          if (generation != _generation) return null;
          text = cleanTranscript(transcript);
        }
        if (text != null) {
          // The transcript decides; the grammar guess is dropped.
          data['text'] = text;
          data['intent'] = null;
        }
        // Direct recording has no other text: report it as unclear if empty.
        if (text != null || direct) data['engine'] = engine;
      }
      return parse(data);
    } finally {
      if (recording != null && waveFile == null) {
        try {
          File(recording).deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Joins Whisper's output lines, dropping noise tags like "[Música]".
  static String? cleanTranscript(String? output) {
    if (output == null) return null;
    final text = output
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), '').trim())
        .where((l) => l.isNotEmpty)
        .join(' ')
        .trim();
    return text.isEmpty ? null : text;
  }

  /// Runs a process and returns its stdout, or null if it was cancelled,
  /// failed or timed out.
  Future<String?> _run(
    int generation,
    String executable,
    List<String> arguments,
    Duration timeout, {
    String? stdin,
    void Function(String line)? onLine,
  }) async {
    if (generation != _generation) return null;
    final process = await Process.start(executable, arguments);
    if (generation != _generation) {
      process.kill();
      return null;
    }
    _process = process;
    final lines = <String>[];
    final output = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .forEach((line) {
          final clean = line.replaceAll('﻿', '').trim();
          lines.add(clean);
          onLine?.call(clean);
        })
        .then((_) => lines.join('\n'));
    final errors = process.stderr.drain<void>();
    process.stdin.encoding = utf8;
    if (stdin != null) process.stdin.writeln(stdin);
    await process.stdin.close();
    final code = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    final text = await output;
    await errors;
    if (generation != _generation) return null;
    _process = null;
    return code == 0 ? text : null;
  }

  static ListenResult parse(Map<String, dynamic> data) {
    switch (data['error']) {
      case 'no_recognizer':
        return const ListenResult(failure: ListenFailure.noRecognizer);
      case 'no_microphone':
        return const ListenResult(failure: ListenFailure.noMicrophone);
    }
    final level = (data['level'] as num?)?.round() ?? 0;
    final heard = (data['text'] as String?)?.trim();
    final intent = data['intent'] as String?;
    final engine = data['engine'] as String? ?? 'Windows';
    final request =
        LocalRequest.values.where((r) => r.name == intent).firstOrNull ??
        match(heard);
    if (request != null) {
      return ListenResult(
        request: request,
        heard: heard,
        level: level,
        engine: engine,
      );
    }
    return ListenResult(
      heard: heard == null || heard.isEmpty ? null : heard,
      level: level,
      engine: engine,
      failure: heard == null || heard.isEmpty
          ? ListenFailure.noSpeech
          : ListenFailure.notUnderstood,
    );
  }

  void stop() {
    _generation++;
    _process?.kill();
    _process = null;
  }

  void dispose() => stop();

  /// Records the default microphone directly (winmm, 16 kHz mono 16-bit) and
  /// cuts the utterance by energy: starts when the level rises above the
  /// noise floor and stops after ~1 s of silence. It does not depend on any
  /// recognizer understanding the speech. Prints "R" when recording starts,
  /// "L <0-100>" every 50 ms and a final JSON line {audio, level}.
  static const recordScript = r"""
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
$data = [Console]::ReadLine() | ConvertFrom-Json
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

public static class OrbiRecorder {
  [StructLayout(LayoutKind.Sequential)]
  struct WaveFormat { public ushort tag, channels; public uint rate, avgBytes; public ushort align, bits, size; }
  [StructLayout(LayoutKind.Sequential)]
  struct WaveHdr { public IntPtr data; public uint length, recorded; public IntPtr user; public uint flags, loops; public IntPtr next, reserved; }
  [DllImport("winmm.dll")] static extern int waveInOpen(out IntPtr h, uint dev, ref WaveFormat f, IntPtr cb, IntPtr inst, uint flags);
  [DllImport("winmm.dll")] static extern int waveInPrepareHeader(IntPtr h, IntPtr hdr, uint size);
  [DllImport("winmm.dll")] static extern int waveInUnprepareHeader(IntPtr h, IntPtr hdr, uint size);
  [DllImport("winmm.dll")] static extern int waveInAddBuffer(IntPtr h, IntPtr hdr, uint size);
  [DllImport("winmm.dll")] static extern int waveInStart(IntPtr h);
  [DllImport("winmm.dll")] static extern int waveInReset(IntPtr h);
  [DllImport("winmm.dll")] static extern int waveInClose(IntPtr h);

  const int Rate = 16000, Chunk = 800, Count = 10; // 50 ms buffers

  static int Level(byte[] b) {
    int n = b.Length / 2;
    if (n == 0) return 0;
    double sum = 0;
    for (int i = 0; i < n; i++) { double s = BitConverter.ToInt16(b, i * 2); sum += s * s; }
    double rms = Math.Sqrt(sum / n);
    if (rms < 1) return 0;
    double db = 20 * Math.Log10(rms / 32768.0); // -60 dBFS -> 0, 0 dBFS -> 100
    return (int)Math.Max(0, Math.Min(100, (db + 60) * 100 / 60));
  }

  public static string Run(string path, int initialSeconds) {
    var fmt = new WaveFormat { tag = 1, channels = 1, rate = Rate, avgBytes = Rate * 2, align = 2, bits = 16, size = 0 };
    IntPtr h;
    int err = waveInOpen(out h, 0xFFFFFFFF, ref fmt, IntPtr.Zero, IntPtr.Zero, 0);
    if (err != 0) return "{\"error\":\"no_microphone\",\"detail\":\"waveInOpen " + err + "\"}";
    uint hs = (uint)Marshal.SizeOf(typeof(WaveHdr));
    int offFlags = (int)Marshal.OffsetOf(typeof(WaveHdr), "flags");
    int offRec = (int)Marshal.OffsetOf(typeof(WaveHdr), "recorded");
    var hdrs = new IntPtr[Count];
    for (int i = 0; i < Count; i++) {
      var hd = new WaveHdr { data = Marshal.AllocHGlobal(Chunk * 2), length = Chunk * 2 };
      hdrs[i] = Marshal.AllocHGlobal((int)hs);
      Marshal.StructureToPtr(hd, hdrs[i], false);
      waveInPrepareHeader(h, hdrs[i], hs);
      waveInAddBuffer(h, hdrs[i], hs);
    }
    var pre = new Queue<byte[]>();
    var speech = new List<byte[]>();
    var recent = new Queue<int>();
    bool talking = false;
    int idx = 0, elapsed = 0, silentMs = 0, speechMs = 0, peak = 0, loud = 0, calibrated = 0;
    double floor = -1;
    var clock = Stopwatch.StartNew();
    try {
      waveInStart(h);
      Console.Out.WriteLine("R");
      while (clock.ElapsedMilliseconds < (initialSeconds + 20) * 1000L) {
        IntPtr p = hdrs[idx];
        if ((Marshal.ReadInt32(p, offFlags) & 1) == 0) { Thread.Sleep(5); continue; }
        int got = Marshal.ReadInt32(p, offRec);
        var chunk = new byte[got];
        Marshal.Copy(Marshal.ReadIntPtr(p, 0), chunk, 0, got);
        waveInUnprepareHeader(h, p, hs);
        Marshal.WriteInt32(p, offFlags, 0);
        Marshal.WriteInt32(p, offRec, 0);
        waveInPrepareHeader(h, p, hs);
        waveInAddBuffer(h, p, hs);
        idx = (idx + 1) % Count;
        elapsed += 50;
        int level = Level(chunk);
        if (level > peak) peak = level;
        Console.Out.WriteLine("L " + level);
        // Decisions use a 200 ms average: background noise jumps around.
        recent.Enqueue(level);
        while (recent.Count > 4) recent.Dequeue();
        double sum = 0;
        foreach (var r in recent) sum += r;
        double smooth = sum / recent.Count;
        // The device returns silence while it warms up; calibrate the noise
        // floor on the first non-zero 300 ms instead.
        if (floor < 0 && level == 0) { recent.Clear(); continue; }
        if (calibrated < 6) { floor = floor < 0 ? smooth : (floor * calibrated + smooth) / (calibrated + 1); calibrated++; pre.Enqueue(chunk); continue; }
        if (!talking) {
          pre.Enqueue(chunk);
          while (pre.Count > 10) pre.Dequeue(); // keep 500 ms before speech
          if (smooth >= floor + 10) {
            if (++loud >= 2) { talking = true; speech.AddRange(pre); pre.Clear(); }
          } else {
            loud = 0;
            floor = floor * 0.9 + smooth * 0.1; // follow slow noise changes
            if (elapsed >= initialSeconds * 1000) break;
          }
        } else {
          speech.Add(chunk);
          speechMs += 50;
          if (smooth < floor + 5) silentMs += 50; else silentMs = 0;
          if (silentMs >= 800 || speechMs >= 10000) break;
        }
      }
    } finally {
      waveInReset(h);
      foreach (var p in hdrs) {
        waveInUnprepareHeader(h, p, hs);
        Marshal.FreeHGlobal(Marshal.ReadIntPtr(p, 0));
        Marshal.FreeHGlobal(p);
      }
      waveInClose(h);
    }
    if (!talking) return "{\"audio\":false,\"level\":" + peak + "}";
    int bytes = 0;
    foreach (var c in speech) bytes += c.Length;
    using (var w = new BinaryWriter(File.Create(path))) {
      w.Write(new char[] { 'R', 'I', 'F', 'F' }); w.Write(36 + bytes);
      w.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' }); w.Write(16);
      w.Write((short)1); w.Write((short)1); w.Write(Rate); w.Write(Rate * 2);
      w.Write((short)2); w.Write((short)16);
      w.Write(new char[] { 'd', 'a', 't', 'a' }); w.Write(bytes);
      foreach (var c in speech) w.Write(c);
    }
    return "{\"audio\":true,\"level\":" + peak + "}";
  }
}
'@
[Console]::Out.WriteLine([OrbiRecorder]::Run([string]$data.save, [int]$data.seconds))
exit 0
""";

  static const script = r"""
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
Add-Type -AssemblyName System.Speech
$data = [Console]::ReadLine() | ConvertFrom-Json
$info = [System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers() |
  Where-Object { $_.Culture.TwoLetterISOLanguageName -eq [string]$data.culture } |
  Select-Object -First 1
if (-not $info) { [Console]::Out.WriteLine('{"error":"no_recognizer"}'); exit 0 }
$engine = New-Object System.Speech.Recognition.SpeechRecognitionEngine($info)
try {
  try {
    if ($data.wav) { $engine.SetInputToWaveFile([string]$data.wav) }
    else { $engine.SetInputToDefaultAudioDevice() }
  } catch {
    [Console]::Out.WriteLine((@{ error = 'no_microphone'; detail = "$_" } | ConvertTo-Json -Compress))
    exit 0
  }
  foreach ($intent in $data.intents.PSObject.Properties) {
    $choices = New-Object System.Speech.Recognition.Choices
    foreach ($phrase in $intent.Value) { $choices.Add([string]$phrase) }
    $builder = New-Object System.Speech.Recognition.GrammarBuilder
    $builder.Culture = $info.Culture
    $builder.Append('Orbi', 0, 1)
    $builder.Append($choices)
    $grammar = New-Object System.Speech.Recognition.Grammar($builder)
    $grammar.Name = $intent.Name
    $engine.LoadGrammar($grammar)
  }
  try {
    $dictation = New-Object System.Speech.Recognition.DictationGrammar
    $dictation.Name = 'dictation'
    $dictation.Weight = 0.3
    $engine.LoadGrammar($dictation)
  } catch { }
  $engine.InitialSilenceTimeout = [TimeSpan]::FromSeconds([int]$data.seconds)
  $engine.BabbleTimeout = [TimeSpan]::FromSeconds(6)
  $engine.EndSilenceTimeout = [TimeSpan]::FromMilliseconds(900)
  $engine.EndSilenceTimeoutAmbiguous = [TimeSpan]::FromMilliseconds(1200)
  $null = Register-ObjectEvent $engine SpeechRecognized -SourceIdentifier rec
  $null = Register-ObjectEvent $engine SpeechRecognitionRejected -SourceIdentifier rej
  $null = Register-ObjectEvent $engine RecognizeCompleted -SourceIdentifier done
  $null = Register-ObjectEvent $engine AudioLevelUpdated -SourceIdentifier lvl
  $level = 0; $recognized = $null; $rejected = $null
  $deadline = (Get-Date).AddSeconds([int]$data.seconds + 15)
  $engine.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Single)
  [Console]::Out.WriteLine('R')
  $lastSent = -1
  $finished = $false
  while (-not $finished -and (Get-Date) -lt $deadline) {
    $ev = Wait-Event -Timeout 1
    if (-not $ev) { continue }
    Remove-Event -EventIdentifier $ev.EventIdentifier
    switch ($ev.SourceIdentifier) {
      'lvl'  {
        $now = $ev.SourceEventArgs.AudioLevel
        if ($now -gt $level) { $level = $now }
        if ($now -ne $lastSent) { [Console]::Out.WriteLine("L $now"); $lastSent = $now }
      }
      'rec'  { $recognized = $ev.SourceEventArgs.Result }
      'rej'  { $rejected = $ev.SourceEventArgs.Result }
      'done' { $finished = $true }
    }
  }
  if (-not $finished) { $engine.RecognizeAsyncCancel() }
  $out = @{ level = $level; intent = $null; text = $null; confidence = 0 }
  $best = if ($recognized) { $recognized } else { $rejected }
  if ($best) {
    if ($best.Alternates.Count -gt 0) {
      $out.text = $best.Alternates[0].Text
      $out.confidence = $best.Alternates[0].Confidence
    } else {
      $out.text = $best.Text
      $out.confidence = $best.Confidence
    }
    # Prefer any command phrase among the alternates over free dictation.
    $command = $best.Alternates |
      Where-Object { $_.Grammar -and $_.Grammar.Name -ne 'dictation' -and $_.Confidence -ge 0.2 } |
      Sort-Object Confidence -Descending | Select-Object -First 1
    if ($command) {
      $out.intent = $command.Grammar.Name
      $out.text = $command.Text
      $out.confidence = $command.Confidence
    }
  }
  # Save the detected utterance so Whisper can transcribe it.
  $out.audio = $false
  if ($data.save -and $best -and $best.Audio) {
    $stream = [System.IO.File]::Create([string]$data.save)
    try { $best.Audio.WriteToWaveStream($stream); $out.audio = $true }
    finally { $stream.Dispose() }
  }
  [Console]::Out.WriteLine(($out | ConvertTo-Json -Compress))
} finally {
  Get-EventSubscriber | Unregister-Event
  $engine.Dispose()
}
exit 0
""";
}
