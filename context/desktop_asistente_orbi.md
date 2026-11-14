# Blueprint de Desarrollo Desktop: Horion Edge & Asistente Médico "Orbi"

Este documento define la arquitectura técnica, el esquema de base de datos SQLite compatible con la nube, el funcionamiento del asistente **Orbi** (Google Gemini API + Wake Word *"Orbi"*), el motor de algoritmos avanzados para operación **Offline** y el diseño de interfaz simple e intuitiva para la aplicación de escritorio **Horion Edge**.

---

## 1. Stack Tecnológico de Horion Edge (Desktop)

| Capa | Tecnología | Propósito Principal |
| :--- | :--- | :--- |
| **Interfaz Gráfica (UI)** | **Flutter Desktop (Windows / Linux)** | Interfaz limpia, moderna, de alto contraste y respuesta instantánea en tiempo real. |
| **Motor Backend & IA** | **Python 3.11+ / FastAPI** | Orquestación local, ingesta de sensores, algoritmos médicos avanzados, integración con Gemini API y worker de sincronización. |
| **Base de Datos Local** | **SQLite (`horion_edge.db`)** | Almacenamiento relacional persistente, tolerante a fallos y cola de sincronización *Offline-First*. |
| **IA Conversacional (Online)** | **Google Gemini API (`gemini-2.5-flash` / `pro`)** | Cerebro conversacional de **Orbi** para diálogo natural empático y contextualizado con biométricos. |
| **Motor Autónomo (Offline)** | **Python (`NumPy` / `SciPy` / Reglas Heurísticas)** | Evaluación continua de signos vitales, detección de anomalías y recomendaciones médicas sin depender de Internet. |
| **Reconocimiento de Invocación** | **Voz / Texto (`"Orbi"`)** | Activación por palabra clave (*Wake Word* *"Orbi"*) mediante STT ligero o invocación rápida por teclado/botón. |

---

## 2. Esquema de Base de Datos Local (`horion_edge.db` - SQLite)

Esta estructura está diseñada en espejo con el esquema `nasa_private` de **PostgreSQL (Supabase)** para garantizar una sincronización rápida, atómica y sin transformaciones complejas.

```sql
PRAGMA journal_mode = WAL; -- Mejora concurrencia entre lectura Flutter y escritura FastAPI
PRAGMA foreign_keys = ON;

-- 1. Perfil del Astronauta asignado a la terminal
CREATE TABLE astronauta (
    id INTEGER PRIMARY KEY CHECK (id = 1), -- Un perfil activo por laptop de misión
    codigo_astronauta TEXT UNIQUE NOT NULL, -- Llave maestra en Supabase (ej. 'AST-001')
    codigo_mision TEXT NOT NULL,            -- Ej. 'ARTEMIS-IV'
    nombre_completo TEXT NOT NULL,
    grupo_sanguineo TEXT,
    alergias TEXT,
    calorias_objetivo INTEGER DEFAULT 2800,
    hr_basal INTEGER DEFAULT 65,            -- Frecuencia cardíaca en reposo personalizada
    spo2_basal REAL DEFAULT 98.0
);

-- 2. Telemetría Biométrica Continua
CREATE TABLE telemetria (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc TEXT NOT NULL,            -- Formato ISO-8601 UTC (ej. '2026-11-13T23:45:00Z')
    frecuencia_cardiaca INTEGER NOT NULL,
    spo2 REAL NOT NULL,
    hrv REAL NOT NULL,                      -- Variabilidad de frecuencia cardíaca (ms)
    temperatura_corporal REAL NOT NULL,
    horas_sueno REAL,
    synced INTEGER NOT NULL DEFAULT 0       -- 0: Pendiente de subir | 1: Confirmado por Django/Supabase
);

-- 3. Alertas y Recomendaciones (Generadas por Algoritmos Offline u Orbi Online)
CREATE TABLE alertas_medicas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc TEXT NOT NULL,
    nivel_severidad TEXT NOT NULL CHECK (nivel_severidad IN ('INFO', 'WARNING', 'CRITICAL')),
    metrica_afectada TEXT NOT NULL,         -- 'frecuencia_cardiaca', 'spo2', 'hrv', 'fatiga_compuesta'
    valor_detectado REAL NOT NULL,
    recomendacion_entregada TEXT NOT NULL,
    modo_generacion TEXT NOT NULL CHECK (modo_generacion IN ('OFFLINE_ALGO', 'ONLINE_GEMINI')),
    atendida INTEGER NOT NULL DEFAULT 0,    -- 0: Activa en pantalla | 1: Reconocida por astronauta
    synced INTEGER NOT NULL DEFAULT 0
);

-- 4. Historial de Conversaciones con "Orbi"
CREATE TABLE chat_historial (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc TEXT NOT NULL,
    rol TEXT NOT NULL CHECK (rol IN ('user', 'orbi')),
    mensaje TEXT NOT NULL,
    contexto_biometrico_json TEXT,          -- Snapshot de signos vitales al momento de hablar
    synced INTEGER NOT NULL DEFAULT 0
);

-- 5. Bitácora de Auditoría de Sincronizaciones
CREATE TABLE sync_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_intento_utc TEXT NOT NULL,
    hash_sha256 TEXT NOT NULL,
    registros_enviados INTEGER NOT NULL,
    estado TEXT NOT NULL CHECK (estado IN ('SUCCESS', 'FAILED_NO_NETWORK', 'FAILED_SERVER'))
);

-- Índices para acelerar consultas de registros pendientes de sincronización
CREATE INDEX idx_telemetria_synced ON telemetria(synced);
CREATE INDEX idx_alertas_synced ON alertas_medicas(synced);
CREATE INDEX idx_chat_synced ON chat_historial(synced);
```

---

## 3. Arquitectura Híbrida: Asistente "Orbi" (Online) vs. Motor Algorítmico (Offline)

El backend en **FastAPI** ejecuta un **Monitor de Conectividad (*Heartbeat Service*)** cada 5 segundos que verifica el enlace con el servidor **Horion Django Cloud**. Según el estado de la red, el sistema cambia automáticamente de modo sin interrumpir la experiencia del astronauta:

### 3.1. Modo Online: Asistente Conversacional "Orbi" (Google Gemini API)
* **Invocación por Nombre (`"Orbi"`):**
  * **Por Voz (Hands-Free):** Un escuchador ligero local detecta la palabra clave **"Orbi"** (ej. *"Orbi, ¿cómo está mi ritmo cardíaco hoy?"* o *"Orbi, me siento un poco mareado"*), transcribe la consulta y abre automáticamente el panel del asistente.
  * **Por Texto / Botón:** El astronauta puede escribir directamente o pulsar el botón central **"Hablar con Orbi"**.
* **Personalidad y Contexto Médico Inyectado:**
  * Antes de enviar el mensaje a **Google Gemini API**, FastAPI consulta en SQLite los últimos 15 minutos de `telemetria`, las `alertas_medicas` recientes y el perfil de `astronauta`.
  * **System Prompt de Orbi:**
    > *"Eres Orbi, el asistente médico inteligente a bordo de la nave/estación espacial dentro del ecosistema Horion. Responde de forma cálida, clara, concisa y profesional. Tienes acceso en tiempo real a los signos vitales del astronauta. Analiza sus métricas actuales, brinda recomendaciones prácticas de hidratación, ejercicio resistivo, descanso o nutrición en microgravedad, y alerta si detectas alguna tendencia de riesgo."*
* **Conversación Continua:** Mantiene el hilo de la conversación en memoria y guarda cada intercambio en `chat_historial` (`synced = 0`) para que los médicos en Tierra puedan auditarlo tras la sincronización.

### 3.2. Modo Offline (Sin Conexión): Motor Algorítmico Avanzado
Cuando se pierde el enlace satelital o la conexión a Internet:
1. **Orbi (Chat Libre en Lenguaje Natural) entra en Pausa Controlada:** La interfaz muestra un indicador claro: *"Enlace con Tierra interrumpido. El chat libre de Orbi está en pausa, pero el monitoreo algorítmico autónomo está 100% activo"*.
2. **Motor Algorítmico Avanzado (Siempre Activo en Python):**
   * **Análisis de Tendencias (Media Móvil y Z-Score):** No solo evalúa umbrales fijos; compara las lecturas actuales contra la línea base personal del astronauta (`hr_basal`, `spo2_basal`) usando ventanas deslizantes de 5 y 15 minutos.
   * **Índice Compuesto de Fatiga y Estrés en Microgravedad:** Combina caída de `HRV` + elevación de `frecuencia_cardiaca` + déficit en `horas_sueno` para detectar fatiga antes de que sea crítica.
   * **Árbol de Recomendaciones Médicas Deterministas:** Al detectar una desviación, genera una alerta en `alertas_medicas` (`modo_generacion = 'OFFLINE_ALGO'`) con pasos accionables inmediatos (ej. protocolos de respiración, ingesta de electrolitos, pausa de actividad extravehicular, ejercicios de descompresión lumbar).
3. **Almacenamiento Ininterrumpido:** Todos los datos biométricos y alertas generadas durante el apagón de red se guardan localmente en SQLite con `synced = 0`.

---

## 4. Pipeline de Sincronización Automática con la Nube (Django + Supabase)

Cuando el *Heartbeat Service* de FastAPI detecta que regresó la conexión a Internet:

1. **Recolección en Lote (*Batching*):** Extrae de SQLite todos los registros con `synced = 0` de `telemetria`, `alertas_medicas` y `chat_historial` (en bloques de máximo 500 registros para evitar timeouts en enlaces satelitales lentos).
2. **Empaquetado y Firma Criptográfica:** Construye el JSON exactamente con la estructura esperada por Django (`POST /api/v1/sync/ingest/`) y calcula su hash **SHA-256**.
3. **Transmisión Segura:** Envía el paquete vía HTTPS con el header `X-Payload-SHA256`.
4. **Confirmación Atómica:** Solo cuando Django responde `HTTP 200 OK`, FastAPI ejecuta `UPDATE ... SET synced = 1` en los IDs enviados y actualiza el indicador visual en Flutter a **"Todo Sincronizado con Horion Cloud"**.

---

## 5. Diseño de Interfaz Simple e Intuitiva (Flutter Desktop)

La interfaz en **Flutter** sigue el principio de **"Cero Fricción Cognitiva"**: un astronauta en misión o con fatiga debe entender todo de un vistazo sin navegar por menús complejos.

### 5.1. Estilo Visual (Coherente con Horion Web)
* **Tema Oscuro Aeroespacial (`#060913`):** Reduce el deslumbramiento en cabina y resalta los indicadores de estado.
* **Tipografía Clara:** Números grandes y legibles (`JetBrains Mono`) para signos vitales; colores semánticos inequívocos (Verde = Nominal, Ámbar = Precaución, Rojo = Alerta Crítica).

### 5.2. Estructura de Navegación (Solo 3 Vistas Principales)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  [LOGO HORION EDGE]   AST-001 (ARTEMIS-IV)   │ ● ONLINE (Orbi Activo) | Sync: 0 pendientes │
├──────────────┬───────────────────────────────────────────────────────────────┤
│              │                                                               │
│  1. MONITOR  │   [ Tarjeta BPM ]   [ Tarjeta SpO2 ]   [ Tarjeta HRV ]        │
│     VITAL    │                                                               │
│              │   [ Gráfico en Tiempo Real (Últimos 30 min) ]                 │
│  2. ASISTENTE│                                                               │
│     ORBI     │   ┌───────────────────────────────────────────────────────┐   │
│              │   │ ⚠️ ALERTA / RECOMENDACIÓN ACTIVA (Motor Algorítmico)   │   │
│  3. HISTORIAL│   │ "HRV bajo (-18% vs basal). Realizar 5 min de respiración│   │
│     & SYNC   │   │  pausada e hidratar con 250ml de agua."   [Entendido] │   │
│              │   └───────────────────────────────────────────────────────┘   │
│              │                                                               │
│ [Simulador]  │                   ( (  🎤 Invocar a "Orbi"  ) )               │
└──────────────┴───────────────────────────────────────────────────────────────┘
```

#### Vista 1: Monitor Vital (Pantalla Principal)
* **4 Tarjetas Grandes de Signos Vitales:** Frecuencia Cardíaca (`BPM`), Oxigenación (`SpO2 %`), Variabilidad Cardíaca (`HRV ms`) y Temperatura (`°C`), con flecha de tendencia ($\uparrow$, $\rightarrow$, $\downarrow$).
* **Banner Superior de Alertas y Recomendaciones:** Si el motor algorítmico (offline) u Orbi (online) detecta una anomalía, aparece una tarjeta destacada en la parte superior con la recomendación médica clara y un botón grande **`Marcar como Atendida`**.
* **Botón Flotante / Escucha Activa `"Orbi"`:** Muestra una onda sonora sutil cuando detecta la palabra *"Orbi"* o al hacer clic para iniciar una consulta rápida sin salir del monitor.

#### Vista 2: Asistente Médico "Orbi" (Chat Natural)
* **Cuando está Online:**
  * Burbujas de conversación amplias y limpias entre el Astronauta y **Orbi** (con avatar orbital en cyan `#38BDF8`).
  * **Botones de Consulta Rápida (1 Clic):** *"¿Cómo está mi salud ahora?"*, *"Recomendación de ejercicio hoy"*, *"Me cuesta conciliar el sueño"*, *"Plan de hidratación"*.
  * Barra inferior con micrófono (activado por voz diciendo *"Orbi"* o pulsando) y caja de texto.
* **Cuando está Offline:**
  * Muestra un banner informativo sereno: *"Sin conexión a Tierra — Chat libre de Orbi en pausa"*.
  * Permite leer el historial de conversaciones previas almacenadas en SQLite y consultar las **Guías de Protocolos Médicos Offline** integradas.

#### Vista 3: Historial, Bitácora y Estado de Sincronización
* **Registro Rápido de Bienestar:** 3 controles simples para que el astronauta registre manualmente sus **Horas de Sueño**, **Ingesta de Agua (ml)** y **Nivel de Energía (1-5)** (se guarda en SQLite y alimenta los algoritmos offline y a Orbi).
* **Monitor de Cola de Sincronización:** Muestra cuántos registros locales están pendientes (`synced = 0`), la fecha de la última subida exitosa a Supabase y un botón **`Forzar Sincronización Ahora`**.
* **Panel de Simulación (Solo para Demo/MVP):** Interruptores discretos en la esquina inferior izquierda para probar el sistema en vivo:
  * Switch **`Simular Corte de Internet (Modo Offline)`**
  * Botón **`Simular Anomalía Cardíaca / Hipoxia`** (dispara inmediatamente el algoritmo offline y la alerta en pantalla).

---

## 6. Estructura de Carpetas del Proyecto Desktop (`horion-edge`)

```text
horion-edge/
├── backend_fastapi/                 # Cerebro local en Python
│   ├── app/
│   │   ├── main.py                  # Servidor FastAPI, CORS local y ciclo de vida (lifespan)
│   │   ├── database.py              # Conexión SQLite (WAL mode) y creación de tablas
│   │   ├── algorithms.py            # Motor algorítmico avanzado (Z-Score, Fatiga, Reglas Offline)
│   │   ├── orbi_gemini.py           # Cliente Google Gemini API + Inyección de contexto SQLite
│   │   ├── sync_worker.py           # Worker asíncrono de detección de red y envío SHA-256 a Django
│   │   └── sensor_simulator.py      # Generador de telemetría realista e inyector de anomalías
│   ├── horion_edge.db               # Base de datos SQLite generada automáticamente
│   └── requirements.txt             # fastapi, uvicorn, google-genai, httpx, numpy
│
└── frontend_flutter/                # Interfaz de Escritorio en Flutter
    ├── lib/
    │   ├── main.dart                # Punto de entrada y tema oscuro aeroespacial Horion
    │   ├── models/                  # Modelos Dart (Telemetry, Alert, ChatMessage, SyncStatus)
    │   ├── services/
    │   │   ├── api_service.dart     # Comunicación HTTP/WebSocket con FastAPI (localhost:8000)
    │   │   └── wake_word_service.dart # Detección de invocación "Orbi" por voz/atajo
    │   ├── screens/
    │   │   ├── vital_monitor_screen.dart   # Vista 1: Signos vitales + Alertas algorítmicas
    │   │   ├── orbi_chat_screen.dart       # Vista 2: Conversación con Orbi (Online/Offline)
    │   │   └── history_sync_screen.dart    # Vista 3: Bitácora manual y cola de sincronización
    │   └── widgets/
    │       ├── status_header.dart   # Barra superior (Online/Offline + Estado Sync)
    │       └── vital_card.dart      # Tarjetas biométricas de alta legibilidad
    └── pubspec.yaml                 # fl_chart, http, speech_to_text, provider/riverpod
```

---

## 7. Flujo Completo de Demostración del MVP (Prueba Punta a Punta)

1. **Inicio Normal (Online):** Se abre **Horion Edge**. La barra superior muestra **`ONLINE - Orbi Activo`**. El astronauta dice *"Orbi, ¿cómo ves mis signos vitales?"* y Orbi responde usando Gemini API leyendo sus BPM y SpO2 reales desde SQLite.
2. **Simulación de Pérdida de Señal (Offline):** Se activa el switch **`Simular Corte de Internet`**. El chat libre de Orbi se bloquea elegantemente indicando modo autónomo.
3. **Detección Algorítmica Autónoma:** Se pulsa **`Simular Anomalía (Bajo SpO2)`**. En menos de 1 segundo, el motor algorítmico en Python detecta la caída respecto al basal, guarda la alerta en SQLite (`synced = 0`) y despliega en Flutter la recomendación médica inmediata sin usar Internet.
4. **Recuperación de Conexión y Sincronización Web:** Se desactiva el corte de red. El `sync_worker` detecta conexión, empaqueta toda la telemetría, las alertas generadas offline y el historial de Orbi con firma **SHA-256**, y los envía a **Horion Django Cloud (Supabase)**. Al instante, los datos aparecen en la plataforma web **Horion Mission Control**.