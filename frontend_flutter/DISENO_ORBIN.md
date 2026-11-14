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

La cara preocupada tiene prioridad sobre hover y gestos conversacionales. Los estados sin datos muestran reposo. El modo de voz sigue sin configurarse; no hay captura de microfono ni llamadas a un proveedor. El interruptor de corte representa una simulacion, no una prueba de conectividad real. La integracion de voz requiere seleccionar proveedor y configurar credenciales en el backend.


## Lectura gratuita en Windows
OrbiVoice reproduce las respuestas locales con Microsoft Sabina Desktop (espanol) o Microsoft Zira Desktop (ingles). El texto viaja como JSON por stdin a un script fijo de PowerShell; no se interpola como codigo ni se envia a un proveedor. No requiere backend para sintetizar voz.

Por la regla de producto, antes de leer se comprueba HTTPS contra el endpoint publico connecttest de Microsoft, sin datos de salud. Se repite cada diez segundos durante la lectura. Un fallo bloquea la voz aunque la causa sea un proxy; las consultas locales quedan disponibles. Cambiar de consulta, salir de pantalla, una variacion de riesgo o un corte simulado interrumpe la reproduccion. El boton Detener cancela tambien la comprobacion pendiente.

Esta entrega incorpora texto a voz, no reconocimiento de microfono ni conversacion generativa. Esos dos componentes siguen pendientes. El movimiento de boca es ilustrativo y no sincronizacion fonetica.
