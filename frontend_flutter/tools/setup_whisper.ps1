# Installs whisper.cpp (CPU, x64) and a Whisper model for Orbi's offline
# speech recognition. Nothing is sent anywhere at runtime; this script only
# downloads the binaries and the model once.
#
# Usage (from frontend_flutter):
#   powershell -ExecutionPolicy Bypass -File tools\setup_whisper.ps1
#   powershell -ExecutionPolicy Bypass -File tools\setup_whisper.ps1 -Model small
param(
  [ValidateSet('base', 'small')]
  [string]$Model = 'base',
  [string]$Target = (Join-Path $env:LOCALAPPDATA 'HorionEdge\whisper'),
  [string]$Release = 'b5454'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

New-Item -ItemType Directory -Force -Path $Target | Out-Null

$cli = Get-ChildItem -Path $Target -Recurse -Filter 'whisper-cli.exe' -ErrorAction SilentlyContinue |
  Select-Object -First 1
if (-not $cli) {
  $zip = Join-Path $env:TEMP "whisper-bin-x64-$Release.zip"
  $url = "https://github.com/ggml-org/whisper.cpp/releases/download/$Release/whisper-bin-x64.zip"
  Write-Host "Descargando whisper.cpp $Release..."
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath (Join-Path $Target 'bin') -Force
  Remove-Item $zip
  $cli = Get-ChildItem -Path $Target -Recurse -Filter 'whisper-cli.exe' | Select-Object -First 1
  if (-not $cli) { throw 'whisper-cli.exe no esta en el paquete descargado.' }
}
Write-Host "whisper-cli: $($cli.FullName)"

$modelFile = Join-Path $Target "ggml-$Model.bin"
if (-not (Test-Path $modelFile)) {
  $url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$Model.bin"
  Write-Host "Descargando modelo $Model..."
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile "$modelFile.part"
  Move-Item "$modelFile.part" $modelFile -Force
}
Write-Host "Modelo: $modelFile ($([math]::Round((Get-Item $modelFile).Length / 1MB)) MB)"
Write-Host 'Listo. Reinicia Horion Edge para usar Whisper.'
