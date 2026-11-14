# Horion Edge · Windows

Proyecto inicial basado en `context/desktop_asistente_orbi.md` y `context/ecosistema_horion_orbi_IA.md`.

## Ejecutar la aplicación

Desde este directorio, en PowerShell:

```powershell
cd frontend_flutter
flutter pub get
flutter run -d windows
```

Se abre en **modo demo**: lecturas sintéticas cada cinco segundos, alertas simuladas, chat de respuestas predefinidas y registros de bienestar en memoria. Los datos demo se pierden al cerrar o cambiar de modo. Usa `Ctrl + O` para abrir Orbi.

## Backend local con persistencia

En otra terminal, desde la raíz:

```powershell
cd backend_fastapi
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Desactiva **Demo** en la aplicación. Ahora la telemetría sintética, las alertas y el bienestar se guardan en `backend_fastapi/horion_edge.db` usando SQLite WAL. Si el backend no responde, se muestra un error; no se sustituye silenciosamente por datos demo. Usa un solo worker de Uvicorn para no duplicar el simulador.

Si `python` abre Microsoft Store, utiliza la ruta de tu instalación Python. En el equipo donde se creó el proyecto se encontró `C:\Users\pc\AppData\Local\Python\pythoncore-3.15-64\python.exe`.

API documentada al iniciar el backend: <http://127.0.0.1:8000/docs>. La dirección del cliente puede cambiarse con `flutter run -d windows --dart-define=API_URL=http://127.0.0.1:8001`. `HORION_DB_PATH` permite cambiar la ruta SQLite. El servidor es de desarrollo local y debe escuchar únicamente en loopback.

## Incluido

- Interfaz en **español e inglés**, con cambio en vivo desde el botón de idioma de la barra superior. Al arrancar usa el idioma del sistema (inglés si no está soportado). Los textos de la app son pares `T('es', 'en')` o `context.tr('es', 'en')` (ver `lib/l10n/language.dart`), y los componentes de Material usan `GlobalMaterialLocalizations`. Para añadir otro idioma, agrégalo a `AppLanguage` y a `T`: el compilador señala lo que falta. En debug, un `T` interpolado sin traducir lanza una aserción.
- Interfaz oscura y seis vistas: monitor, mapa corporal, tendencias, riesgos y entorno, Orbi, historial/sync.
- Tendencias de 7, 14 o 30 días con promedio diario, banda de rango normal y **línea base personal** (promedio de los 3 primeros días de misión). Avisa si los últimos 3 días se alejan de la base más que la tolerancia del indicador.
- Terminología de NASA HRP: **5 peligros** (las causas) y **17 riesgos** para la salud (las consecuencias, en 3 categorías), en `lib/models/hrp_catalog.dart`. La app indica cuáles vigila con indicadores o autoevaluaciones y cuáles son solo informativos.
- Mapa corporal con 8 zonas, entre ellas **ojos y visión (SANS)**, el principal riesgo de salud según NASA, y **oído interno y equilibrio**. Incluye autoevaluación de síntomas (solo en memoria durante la sesión), la investigación de NASA relacionada (ARCHeR, Thigh Cuff, B-Complex, Zero T2…, marcada como estudios y no como tratamientos) y el beneficio en la Tierra según la Agencia Espacial Canadiense.
- Riesgos y entorno: los cinco peligros de NASA HRP, con la exposición según el entorno (estación, nave en tránsito, rover, base lunar o marciana) y la señal de tus indicadores. Incluye la dosis de radiación estimada frente al límite de carrera (600 mSv), el retraso de comunicación y qué cambia al escalar una alerta. El entorno elegido no se guarda al cerrar la app.
- Registro manual de presión arterial, glucosa y temperatura, con instrucciones y vista previa del semáforo. La presión y la glucosa son mediciones puntuales (tabla `mediciones`), no telemetría continua.
- Con una base de datos vacía, el backend crea 13 días de historial simulado para que haya tendencias. Se desactiva con `HORION_SEED_HISTORY=0`. El modo demo genera el mismo historial en memoria.
- Ocho indicadores con semáforo (normal / vigilar / crítico): frecuencia cardíaca, SpO₂, HRV, temperatura, presión arterial, glucosa, sueño y estado de ánimo. Al tocar uno se abre una ficha: qué mide, cómo medirlo a bordo, cómo lo afecta el espacio, riesgos HRP relacionados y qué hacer.
- Mapa corporal interactivo y animado: seis regiones coloreadas según sus indicadores, con función, efecto del vuelo espacial, riesgos NASA y prevención. El corazón late al ritmo de la frecuencia cardíaca.
- Alertas por indicador con nivel de escalado: autocuidado, vigilar o avisar al médico de vuelo. Los rangos están en `backend_fastapi/app/algorithms.py` y `frontend_flutter/lib/models/health_knowledge.dart`, y deben mantenerse iguales.
- Gráfico con ventana de hasta treinta minutos.
- Simulación de corte de enlace y anomalía; reconocimiento de alertas.
- Registro de sueño, agua y energía con validación en el backend.
- Esquema SQLite del contexto, ampliado con `bienestar` porque los documentos solicitan registrar agua y energía.
- Cola local: conteo de registros `synced = 0`. No se marca ningún registro como enviado.
- Runner nativo de Windows generado con Flutter y pruebas de interfaz/API.

## Pendiente del blueprint

Esta entrega es una base funcional de desarrollo, no la implementación clínica completa. No tiene conexión a sensores reales, Gemini, voz/wake word, protocolos médicos validados, Z-score/fatiga, ni sincronización Django/Supabase. El chat demo es temporal; la tabla `chat_historial` está preparada para la integración posterior. El interruptor de enlace solo simula un estado, no detecta conectividad real. La nube necesita definir contrato, autenticación, confirmaciones e idempotencia antes de enviar datos. SHA-256 es un hash de integridad, no cifrado ni autenticación.

Las lecturas y reglas son demostrativas, sin evaluación clínica. JetBrains Mono no está empaquetada; las cifras usan Consolas de Windows. El backend se inicia por separado y no se incluye dentro del ejecutable.

## Verificación y compilación

```powershell
cd frontend_flutter
flutter analyze
flutter test
flutter build windows --release
```

El ejecutable queda en `frontend_flutter/build/windows/x64/runner/Release/horion_edge.exe`. Para distribuir, copia **toda la carpeta Release**, no solo el `.exe`.

Pruebas del backend, desde `backend_fastapi`:

`requirements-lock.txt` contiene las versiones exactas instaladas durante la verificación, incluidas las herramientas de pruebas. Puede instalarse con `pip install -r requirements-lock.txt` para reproducir ese entorno.

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

## Estructura

```text
context/                    Documentos originales
frontend_flutter/lib/
  models/                   Modelo de telemetría
  services/                 HTTP y estado de aplicación
  screens/                  Tres pantallas y navegación
  widgets/                  Tarjetas y gráfico
frontend_flutter/windows/   Runner nativo Windows
backend_fastapi/app/         API, SQLite, simulador y regla demo
backend_fastapi/tests/       Pruebas de persistencia y API
```
