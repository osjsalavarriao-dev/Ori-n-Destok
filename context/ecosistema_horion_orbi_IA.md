# Proyecto Horion: Ecosistema Autónomo de Monitoreo Biomédico Espacial y Ciencia Abierta

## 1. ¿Qué es Horion?

**Horion** es una plataforma integral de salud espacial y ciencia abierta diseñada para proteger la vida y el rendimiento de los astronautas en misiones de larga duración, al mismo tiempo que democratiza el acceso a datos biométricos espaciales anonimizados para la comunidad científica mundial.

El sistema resuelve dos grandes desafíos de la exploración espacial moderna:
1. **La intermitencia de comunicaciones en el espacio profundo o en órbita (Loss of Signal - LOS):** Los astronautas no pueden depender de una conexión permanente a Internet para recibir alertas médicas o recomendaciones críticas.
2. **El aislamiento de los datos médicos espaciales:** La información biométrica generada en misión suele quedar encerrada en silos institucionales, retrasando descubrimientos médicos tanto para futuros vuelos espaciales como para la medicina en la Tierra (osteoporosis, trastornos del sueño, salud cardiovascular).

---

## 2. Los Tres Pilares del Ecosistema Horion

Horion funciona como un flujo continuo dividido en tres entornos conectados entre sí:

### Pilar 1: Horion Edge & Asistente "Orbi" (Aplicación de Escritorio en la Nave / EEI)
Es el copiloto médico personal del astronauta, instalado directamente en su computadora de misión.
* **Monitoreo Biométrico en Tiempo Real:** Recibe y registra signos vitales continuos (frecuencia cardíaca, saturación de oxígeno $SpO_2$, variabilidad cardíaca HRV, temperatura corporal y calidad de sueño).
* **Asistente Conversacional "Orbi" (Modo Online):** Cuando hay enlace con la Tierra, el astronauta puede invocar por voz o texto a **Orbi** (impulsado por **Google Gemini API**) para mantener conversaciones naturales sobre cómo se siente, pedir análisis de sus signos vitales o recibir guías personalizadas de nutrición, ejercicio y descanso.
* **Resiliencia Total con Algoritmos Avanzados (Modo Offline):** Si se pierde la conexión a Internet, el chat libre de Orbi entra en pausa, pero un motor de algoritmos matemáticos y médicos locales toma el control al 100%. Detecta anomalías en tiempo real, dispara alertas críticas y entrega recomendaciones médicas inmediatas sin necesidad de red, guardando todo localmente hasta que vuelva la señal.

### Pilar 2: Horion Mission Control (Plataforma Web Privada para la NASA / Control de Misión)
Es el centro de mando médico en Tierra donde los especialistas supervisan a la tripulación y gobiernan la privacidad de los datos.
* **Sincronización Automática e Íntegra:** Cuando Horion Edge recupera conexión, envía automáticamente todos los datos acumulados durante el periodo offline hacia la nube, validando cada paquete mediante firmas criptográficas **SHA-256** para evitar pérdida o corrupción de información.
* **Seguimiento Clínico Confidencial:** Los oficiales médicos visualizan en tiempo real el estado de cada astronauta, las alertas resueltas localmente en órbita y el historial de consultas realizadas a Orbi.
* **Motor Automatizado de Anonimización y Curaduría:** Antes de que cualquier dato salga hacia el público, Horion separa la identidad real del astronauta, la reemplaza por un identificador aleatorio (`UUID`) y ofusca fechas exactas. El equipo médico revisa y aprueba qué lotes están listos para hacerse públicos.

### Pilar 3: Horion Open Science (Portal Web Global de Ciencia Abierta)
Es una plataforma abierta para médicos, universidades e investigadores de todo el mundo.
* **Exploración y Descarga de Datos Espaciales:** Los investigadores pueden filtrar, visualizar gráficas interactivas y descargar datasets biométricos anonimizados (en formato CSV o JSON) sobre cómo responde el cuerpo humano a la microgravedad.
* **Colaboración Científica Bidireccional:** Los científicos pueden publicar en el portal sus propios modelos predictivos, hallazgos médicos o artículos basados en los datos de Horion. Tras ser validados por el equipo médico de la NASA, estos aportes pasan a enriquecer el conocimiento global y los protocolos de futuras misiones.

---

## 3. Flujo Completo de Información (De la Órbita a la Tierra)

```
 [Sensores Astronauta]
          │
          ▼
 ┌────────────────────────────────────────────────────────┐
 │  1. HORION EDGE (Desktop: Flutter + FastAPI + SQLite)  │
 │  • Con Red: Conversación natural con "Orbi" (Gemini)   │
 │  • Sin Red: Alertas y recomendaciones por Algoritmos   │
 │  • Guarda todo localmente (Offline-First)              │
 └────────┬───────────────────────────────────────────────┘
          │ (Al recuperar conexión: Sync cifrado SHA-256)
          ▼
 ┌────────────────────────────────────────────────────────┐
 │  2. HORION CLOUD & MISSION CONTROL (Django + Supabase) │
 │  • Almacena historial clínico privado (nasa_private)   │
 │  • Anonimiza identidad (UUID) y fechas automáticamente │
 │  • Oficial Médico NASA audita y aprueba publicación    │
 └────────┬───────────────────────────────────────────────┘
          │ (Publicación aprobada)
          ▼
 ┌────────────────────────────────────────────────────────┐
 │  3. HORION OPEN SCIENCE (Web Pública: React + Django)  │
 │  • Investigadores exploran y descargan datos (CSV/JSON)│
 │  • Suben estudios y modelos para validación NASA       │
 └────────────────────────────────────────────────────────┘
```

---

## 4. Resumen del Stack Tecnológico

| Entorno | Componente | Tecnologías |
| :--- | :--- | :--- |
| **Desktop (Astronauta)** | Interfaz de Usuario | **Flutter Desktop** (Tema oscuro aeroespacial de alta legibilidad) |
| **Desktop (Astronauta)** | Backend, Algoritmos & IA | **Python (FastAPI)** + **Google Gemini API (Orbi)** + **NumPy/SciPy** |
| **Desktop (Astronauta)** | Base de Datos Local | **SQLite** (Modo WAL para persistencia offline garantizada) |
| **Nube / Backend Central** | API, Seguridad & Anonimización | **Python (Django + Django REST Framework)** |
| **Nube / Base de Datos** | Almacenamiento Relacional | **PostgreSQL en Supabase** (Esquemas separados `nasa_private` y `open_science`) |
| **Plataforma Web** | Frontend Mission Control & Open Science | **React (Vite + TailwindCSS)** |

---

## 5. Impacto y Valor Diferencial del Proyecto

* **Cero Puntos Únicos de Falla:** La salud del astronauta nunca queda desprotegida ante cortes de comunicación satelital gracias a la arquitectura híbrida (IA generativa en la nube + algoritmos deterministas en el borde).
* **Privacidad por Diseño:** Separa estrictamente la telemetría médica confidencial de los datos públicos mediante un pipeline automatizado de pseudoanonimización supervisado por expertos.
* **Aceleración Científica Global:** Convierte cada misión espacial en una fuente viva y estructurada de investigación abierta para la medicina aeroespacial y terrestre.