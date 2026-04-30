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

**Fase 2 — Sprint 2 implementado, falta importacion y pulido final**

- [x] Proyecto Flutter inicializado
- [x] Base de datos SQLite con sqflite
- [x] Servicio de grabacion de audio
- [x] Pantalla principal con UI completa
- [x] Modo oscuro/claro con persistencia
- [x] Indicador visual de grabacion en tiempo real
- [x] Pantalla de ajustes
- [x] Historial de grabaciones

- [x] Motor de transcripcion local con Whisper
- [x] Configuracion manual para OpenAI compatible y AssemblyAI
- [x] Pantalla de transcripcion con edicion y resumen

Proximo: importar audios externos, exportacion y busqueda local

## Stack

| Capa | Tecnologia |
|---|---|
| Frontend | Flutter 3.x (Dart) |
| Persistencia | SQLite / sqflite |
| Audio | record + audioplayers |
| Estado | Provider |
| Transcripcion | Whisper local + APIs configurables |
| Tema | Material 3 con teal seed |

## Estructura del proyecto

```
apps/mobile/lib/
  app/            # App principal y providers
  core/
    database/     # AppDatabase (sqflite)
    services/     # AudioRecorderService, ThemeService, TranscriptionConfig
    storage/      # LocalPaths
    theme/        # AppTheme (light/dark)
  features/
    recordings/
      data/       # Repositorio SQLite
      domain/     # Modelo Recording y enums
      presentation/  # Screens, widgets, providers
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
