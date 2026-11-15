# Installs Piper (offline neural text-to-speech) and its voices for Orbi.
# Orbi uses it when Gemini's voice is unavailable (no link, no backend or no
# key). Nothing is sent anywhere at runtime; this only downloads once.
#
# Usage (from frontend_flutter):
#   powershell -ExecutionPolicy Bypass -File tools\setup_piper.ps1
param(
  [string]$Target = (Join-Path $env:LOCALAPPDATA 'HorionEdge\piper'),
  [string]$Release = '2023.11.14-2',
  [string[]]$Voices = @('es/es_MX/claude/high/es_MX-claude-high', 'en/en_US/lessac/medium/en_US-lessac-medium')
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

New-Item -ItemType Directory -Force -Path $Target | Out-Null

$exe = Get-ChildItem -Path $Target -Recurse -Filter 'piper.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) {
  $zip = Join-Path $env:TEMP "piper_windows_amd64-$Release.zip"
  Write-Host "Descargando Piper $Release..."
  Invoke-WebRequest -UseBasicParsing -OutFile $zip `
    -Uri "https://github.com/rhasspy/piper/releases/download/$Release/piper_windows_amd64.zip"
  Expand-Archive -Path $zip -DestinationPath $Target -Force
  Remove-Item $zip
  $exe = Get-ChildItem -Path $Target -Recurse -Filter 'piper.exe' | Select-Object -First 1
  if (-not $exe) { throw 'piper.exe no esta en el paquete descargado.' }
}
Write-Host "piper: $($exe.FullName)"

$voiceDir = Join-Path $Target 'voices'
New-Item -ItemType Directory -Force -Path $voiceDir | Out-Null
foreach ($voice in $Voices) {
  $name = Split-Path $voice -Leaf
  foreach ($ext in '.onnx', '.onnx.json') {
    $file = Join-Path $voiceDir "$name$ext"
    if (-not (Test-Path $file)) {
      Write-Host "Descargando voz $name$ext..."
      Invoke-WebRequest -UseBasicParsing -OutFile "$file.part" `
        -Uri "https://huggingface.co/rhasspy/piper-voices/resolve/main/$voice$ext"
      Move-Item "$file.part" $file -Force
    }
  }
  Write-Host "Voz: $name"
}
Write-Host 'Listo. Reinicia Horion Edge para usar Piper.'
