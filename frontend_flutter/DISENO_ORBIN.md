# Orbin: arquitectura visual

La aplicaci?n conserva las capas existentes: API y simulaci?n en services, modelos de telemetr?a y reglas en models, navegaci?n en EdgeShell y vistas en screens. El tema compartido en main.dart aplica superficies oscuras, bordes finos y tarjetas redondeadas a todas las pantallas.

## Componentes
- OrbinAvatar: dibujo vectorial inspirado en la referencia, con expresi?n nominal, alerta o sin datos. Integrado en navegaci?n, resumen y chat.
- VitalCard: indicador, valor monoespaciado, unidad y estado textual con icono.
- TelemetryMotion: latido a 60000/BPM milisegundos, halo sem?ntico y anillo de SpO2 interpolado.
- RhythmTrace: onda ilustrativa continua; no representa un ECG adquirido.
- TelemetryChart: historial de lecturas reales del simulador.

Los controladores de animaci?n se liberan al desmontar los componentes. RepaintBoundary a?sla el repintado. TickerMode detiene las pantallas ocultas. MediaQuery.disableAnimations y el bot?n de movimiento permiten detener los efectos.

## Datos y l?mites
Las lecturas del simulador siguen llegando cada cinco segundos. La animaci?n entre lecturas no agrega mediciones ni convierte el sistema en adquisici?n de milisegundos. Para esa adquisici?n se necesita un contrato de sensores y transporte de streaming. El chat mantiene sus respuestas de demostraci?n; el personaje no implica una integraci?n de IA.

## Pendiente de una segunda revisi?n visual
Las pantallas de mapa, riesgos, tendencias e historial heredan el nuevo tema, pero conservan su organizaci?n funcional. No se ha realizado todav?a una inspecci?n visual con capturas ni una evaluaci?n con usuarios astronautas. La mascota tiene expresiones est?ticas por estado; no implementa los doce estados animados de la referencia.


## Actualizacion: interfaz compacta y personaje animado
El monitor reduce el espacio de las tarjetas y oculta el historial largo en un desplegable. La figura corporal pasa a 440 px en escritorio y 320 px en ventanas compactas. El brillo se limita a la region seleccionada o critica, evitando desenfocar cada organo por fotograma.

Orbin usa un controlador de cinco segundos y CustomPainter con repaint directo, aislado por RepaintBoundary: flotacion, parpadeo y antenas. Se alegra al pasar el cursor; en chat escucha al escribir, descansa cuando el chat esta inhabilitado y sonrie tras conversar. En el resumen, pulsarlo abre el asistente. Los estados de salud activan su expresion preocupada. La preferencia de movimiento reducido detiene el controlador; TickerMode evita trabajo en pantallas ocultas.

Estas animaciones expresan estados de interfaz; no agregan capacidades de escucha por microfono ni IA. La validacion automatizada incluye navegacion, formularios, ventana compacta y ciclo de vida del personaje. No se ha medido rendimiento en hardware de vuelo.


## Consulta local guiada
La pantalla de Orbi usa LocalGuidance y LocalRequest en lugar de texto libre. Las consultas se calculan con los datos disponibles de la sesion y funcionan sin backend o internet. Una lectura de mas de 30 segundos se considera antigua para este prototipo. Una alerta critica pendiente mantiene la prioridad incluso si el ultimo valor se normaliza. Los planes de ejercicio y nutricion aun no estan cargados: se indica su ausencia, sin inventar prescripciones.

La cara preocupada tiene prioridad sobre hover y gestos conversacionales. Los estados sin datos muestran reposo. La captura de microfono es local (ver "Escucha local en Windows"); no hay llamadas a un proveedor de IA. El interruptor de corte representa una simulacion, no una prueba de conectividad real. Una conversacion generativa requiere seleccionar proveedor y configurar credenciales en el backend.


## Lectura gratuita en Windows
OrbiVoice reproduce las respuestas locales con Microsoft Sabina Desktop (espanol) o Microsoft Zira Desktop (ingles); si esa voz no esta instalada usa cualquier voz del mismo idioma (por ejemplo Helena es-ES). El texto viaja como JSON UTF-8 por stdin a un script fijo de PowerShell; no se interpola como codigo ni se envia a un proveedor. No requiere backend para sintetizar voz.

(Historico) Antes se exigia internet para leer en voz alta; desde la voz natural ya no: sin enlace habla Piper. Ver "Voz natural de Orbi".

## Escucha local en Windows
OrbiListener usa System.Speech.Recognition (reconocedor instalado en Windows, sin internet) con una gramatica cerrada de frases por LocalRequest, por ejemplo "signos vitales", "ejercicio", "comida" o "monitoreo", con "Orbi" opcional delante. Si la frase no coincide (o el motor la descarta por baja confianza), un dictado local de respaldo transcribe el texto y se asigna a una consulta por palabras clave ("agua", "vital", "rutina"...); la respuesta sigue siendo la consulta determinista, nunca texto generado. Se escucha una vez, hasta 8 s de silencio inicial; una frase de la gramatica con confianza de 0.3 o mas se acepta directamente. Se informa el nivel maximo del microfono (0-100) para diagnosticar volumen bajo. El audio no sale del equipo. Requiere un reconocedor del idioma (este equipo solo tiene es-ES; en ingles se muestra un aviso).

### Whisper local (recomendado)
El reconocedor clasico de Windows solo trae es-ES y entiende mal el acento latinoamericano. Si whisper.cpp esta instalado, la app graba el microfono directamente (winmm, 16 kHz mono) y corta la frase por energia: calibra el ruido de fondo, empieza cuando el nivel promedio de 200 ms supera el ruido en 10 puntos y termina tras 0.8 s de silencio (maximo 10 s). No depende de que ningun reconocedor entienda la voz (el reconocedor clasico a veces no detectaba la frase y Whisper nunca se ejecutaba). La pantalla muestra el nivel en vivo. El WAV temporal se pasa a Whisper sin lista de pistas (con ruido inventaba frases con esas palabras) y con supresion de etiquetas como "[Musica]"; whisper-cli (modelo base, o small si existe) la transcribe sin internet en 2-3 s y el texto se asigna por palabras clave. El WAV se borra al terminar. Sin Whisper se usa el reconocedor de Windows como antes. La pantalla indica que motor transcribio ("Whisper" o "Windows").

Instalacion (una vez, descarga ~150 MB; con `-Model small` ~470 MB y mas precision):

    powershell -ExecutionPolicy Bypass -File tools\setup_whisper.ps1

Se instala en `%LOCALAPPDATA%\HorionEdge\whisper`. Tambien se busca en `HORION_WHISPER_DIR` o en una carpeta `whisper` junto al ejecutable (para distribuir la app con Whisper incluido).

## Orbi con IA (Groq), fase 1
Con enlace, Orbi conversa libremente por texto o voz. La app arma una instantanea de lo que muestra en pantalla (indicadores con valor y estado, alertas activas, ultimos registros de bienestar, promedios de dias anteriores frente a los ultimos 3 dias, sintomas marcados y entorno de mision; sin nombre ni codigos) y la envia al backend local. El backend guarda la clave (GROQ_API_KEY en `backend_fastapi/.env`, ver `.env.example`), aplica las reglas y llama a Groq (`openai/gpt-oss-120b` por defecto). Funciona en modo demo y con datos reales, pero requiere FastAPI en marcha.

Endpoints: `GET /api/orbi/status`, `POST /api/orbi/chat` (respuesta y `modo`) y `POST /api/orbi/transcribe` (WAV binario, Whisper `whisper-large-v3-turbo` en Groq). Cada pregunta y respuesta se guarda en `chat_historial` con la instantanea usada.

Reglas fijas:
- Alerta critica activa: responde la regla local (`LOCAL_CRITICO`), nunca el modelo.
- Corte de enlace, sin clave o sin backend: Orbi responde con las consultas locales (por palabras clave) e indica por que. Durante el corte el chat se oculta.
- El modelo no diagnostica ni indica medicamentos, dosis, cargas ni dietas; remite al plan aprobado o al medico de vuelo. Ante sintomas de alarma pide avisar al medico de vuelo. Ante animo bajo o aislamiento responde con empatia y sugiere apoyo.
- Respuestas de 2 a 5 frases, sin formato, pensadas para leerse en voz alta.

Voz: con IA disponible, la grabacion se transcribe con Groq (mas preciso con acentos) y, si falla, con el Whisper local. La pregunta hablada se responde en voz alta.

Pantalla: la caja de texto, el microfono y las cuatro consultas rapidas van arriba; la conversacion se muestra por intercambios, el mas reciente primero, repartida en paginas (sin listas con desplazamiento).

## Voz natural de Orbi
OrbiVoice prueba tres motores, del mas natural al mas basico, y la pantalla indica cual hablo:
1. **Gemini** (con IA en linea): `POST /api/orbi/speak` en el backend pide el audio a Gemini TTS (`gemini-3.8-flash-lite-tts`, voz `Sulafat`; `GEMINI_API_KEY` en `.env`) y devuelve WAV. Tarda ~3-5 s en empezar. Se envia solo el texto: estos modelos leen en voz alta cualquier instruccion de estilo y no admiten instrucciones de sistema, asi que el tono lo da la voz elegida.
2. **Piper** (local, sin conexion): voz neuronal `es_MX-claude-high` (o `en_US-lessac-medium`), ~1,5 s en empezar. Instalacion: `powershell -ExecutionPolicy Bypass -File tools\setup_piper.ps1` (en `%LOCALAPPDATA%\HorionEdge\piper`, ~130 MB).
3. **Voz clasica de Windows** (SAPI): ultimo recurso.

El WAV se reproduce con System.Media.SoundPlayer; Detener mata el proceso. Ya no se exige internet para leer en voz alta: sin enlace habla Piper, tambien durante el corte simulado (boton de altavoz junto a las consultas rapidas). La voz se interrumpe al entrar en corte o si cambia el riesgo.

Pendiente: diario de bienestar hablado (fase 2), informe semanal y chequeo emocional guiado (fase 3). El movimiento de boca es ilustrativo y no sincronizacion fonetica.
