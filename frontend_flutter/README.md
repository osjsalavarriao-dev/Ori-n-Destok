# Horion Edge · Flutter Windows

Interfaz de escritorio basada en los documentos de `../context/`.

## Ejecutar

```powershell
flutter pub get
flutter run -d windows
```

La aplicación inicia en modo demo. Para conectar SQLite, inicia el backend local y desactiva el interruptor **Demo**.

Consulta [la documentación del proyecto](../README.md) para configurar FastAPI, ejecutar pruebas y conocer las integraciones pendientes.

Flutter 3.50 / Dart 3.14. Se conserva `material_ui`, generado por la plantilla del SDK instalado. El cliente HTTP usa `dart:io` y está destinado a escritorio.
