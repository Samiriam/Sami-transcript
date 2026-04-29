# Sami Transcribe

Aplicacion movil personal para grabar, transcribir y gestionar audios con una experiencia simple, minimalista y orientada a productividad.

## Vision

Sami Transcribe permite grabar audios, transcribirlos automaticamente y exportar resultados de forma local. La meta actual es una beta privada para un solo usuario.

## Funcionalidades clave

- Grabacion de reuniones desde el dispositivo.
- Importacion de audios externos.
- Transcripcion automatica.
- Separacion de hablantes como fase posterior.
- Exportacion a PDF y DOCX.
- Busqueda en transcripciones.
- Preparacion para escalado futuro.

## Estado del proyecto

**Fase 1 — Sprint 1 completado**

- [x] Proyecto Flutter inicializado
- [x] Base de datos SQLite con sqflite
- [x] Servicio de grabacion de audio
- [x] Pantalla principal con UI completa
- [x] Modo oscuro/claro con persistencia
- [x] Indicador visual de grabacion en tiempo real
- [x] Pantalla de ajustes
- [x] Historial de grabaciones

Proximo: Sprint 2 — Transcripcion + importacion

## Stack

| Capa | Tecnologia |
|---|---|
| Frontend | Flutter 3.x (Dart) |
| Persistencia | SQLite / sqflite |
| Audio | record + audioplayers |
| Estado | Provider |
| Tema | Material 3 con teal seed |

## Estructura del proyecto

```
apps/mobile/lib/
  app/            # App principal y providers
  core/
    database/     # AppDatabase (sqflite)
    services/     # AudioRecorderService, ThemeService
    storage/      # LocalPaths
    theme/        # AppTheme (light/dark)
  features/
    recordings/
      data/       # Repositorio SQLite
      domain/     # Modelo Recording
      presentation/  # Screens, widgets, provider
```

## Como ejecutar

```bash
cd apps/mobile
flutter pub get
flutter run
```

## Documentacion

- `PLAN_TRABAJO.md` — Roadmap y sprints.
- `SDD.md` — Diseno tecnico.
- `PLAN_IMPLEMENTACION.md` — Secuencia de trabajo.
- `BITACORA_TECNICA.md` — Registro de cambios tecnicos.
