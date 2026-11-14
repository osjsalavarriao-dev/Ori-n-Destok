PRAGMA journal_mode = WAL; -- Mejora concurrencia entre lectura Flutter y escritura FastAPI
PRAGMA foreign_keys = ON;

-- 1. Perfil del Astronauta asignado a la terminal
CREATE TABLE IF NOT EXISTS astronauta (
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
CREATE TABLE IF NOT EXISTS telemetria (
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
CREATE TABLE IF NOT EXISTS alertas_medicas (
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
CREATE TABLE IF NOT EXISTS chat_historial (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc TEXT NOT NULL,
    rol TEXT NOT NULL CHECK (rol IN ('user', 'orbi')),
    mensaje TEXT NOT NULL,
    contexto_biometrico_json TEXT,          -- Snapshot de signos vitales al momento de hablar
    synced INTEGER NOT NULL DEFAULT 0
);

-- 5. Bitácora de Auditoría de Sincronizaciones
CREATE TABLE IF NOT EXISTS sync_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_intento_utc TEXT NOT NULL,
    hash_sha256 TEXT NOT NULL,
    registros_enviados INTEGER NOT NULL,
    estado TEXT NOT NULL CHECK (estado IN ('SUCCESS', 'FAILED_NO_NETWORK', 'FAILED_SERVER'))
);

-- Índices para acelerar consultas de registros pendientes de sincronización
CREATE INDEX IF NOT EXISTS idx_telemetria_synced ON telemetria(synced);
CREATE INDEX IF NOT EXISTS idx_alertas_synced ON alertas_medicas(synced);
CREATE INDEX IF NOT EXISTS idx_chat_synced ON chat_historial(synced);

CREATE TABLE IF NOT EXISTS bienestar (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp_utc TEXT NOT NULL, horas_sueno REAL NOT NULL CHECK(horas_sueno BETWEEN 0 AND 16), agua_ml INTEGER NOT NULL CHECK(agua_ml BETWEEN 0 AND 5000), energia INTEGER NOT NULL CHECK(energia BETWEEN 1 AND 5), animo INTEGER CHECK(animo BETWEEN 1 AND 5), synced INTEGER NOT NULL DEFAULT 0);
CREATE INDEX IF NOT EXISTS idx_bienestar_synced ON bienestar(synced);

-- 6. Mediciones puntuales (tensiómetro, glucómetro, termómetro): manuales o del historial simulado
CREATE TABLE IF NOT EXISTS mediciones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc TEXT NOT NULL,
    metrica TEXT NOT NULL CHECK (metrica IN ('presion_sistolica', 'presion_diastolica', 'glucosa', 'temperatura_corporal')),
    valor REAL NOT NULL,
    origen TEXT NOT NULL CHECK (origen IN ('MANUAL', 'SIMULADO')),
    synced INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_mediciones_synced ON mediciones(synced);
CREATE INDEX IF NOT EXISTS idx_mediciones_metrica ON mediciones(metrica, timestamp_utc);
