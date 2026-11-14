# Ejecutar en Windows (PowerShell)

El entorno Python está en `backend_fastapi/.venv`. Las dependencias del backend
se instalaron desde `requirements-lock.txt`; las de Flutter, con `flutter pub get`.

## Terminal 1: backend

Desde la raíz del proyecto:

```powershell
cd backend_fastapi
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Documentación de la API: <http://127.0.0.1:8000/docs>.
No necesitas activar el entorno virtual. Usa un solo worker para el simulador.

## Terminal 2: aplicación

Desde la raíz del proyecto, en otra terminal:

```powershell
cd frontend_flutter
flutter run -d windows
```

La aplicación empieza en modo Demo. Desactiva **Demo** para conectarla al backend.
Los datos persistentes se guardan en `backend_fastapi/horion_edge.db`.
Usa `Ctrl+C` en cada terminal para detener los procesos.

## Skill UI UX Pro Max

Instalada para este proyecto en `.agents/skills/ui-ux-pro-max` mediante:

```powershell
npm.cmd exec --yes --package=ui-ux-pro-max-cli -- uipro init --ai codex
```

Estará disponible para Codex en el siguiente turno. Si no aparece, reabre la sesión.
Fuente: <https://github.com/nextlevelbuilder/ui-ux-pro-max-skill>.

## Verificación

Desde `backend_fastapi`:

```powershell
.\.venv\Scripts\python.exe -m pip check
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Desde `frontend_flutter`:

```powershell
flutter analyze
flutter test
flutter build windows --release
```

El ejecutable compilado queda en
`frontend_flutter/build/windows/x64/runner/Release/horion_edge.exe`.
Para distribuirlo, copia toda la carpeta `Release`.
