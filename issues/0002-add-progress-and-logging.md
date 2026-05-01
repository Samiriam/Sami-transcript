# 0002 - Añadir feedback de progreso y logging durante descarga/transcripción

Prioridad: Alta
Asignado a: @programador

Descripción
-----------
La experiencia actual no muestra suficiente retroalimentación durante la descarga del modelo y la transcripción. Es necesario añadir indicadores de progreso, mensajes claros y logging estructurado para facilitar reproducciones y debugging.

Requisitos
----------
- Mostrar progreso de descarga (barra o porcentaje) durante la descarga del modelo.
- Mostrar mensajes de estado en la pantalla de transcripción (`descargando`, `transcribiendo`, `completado`, `error`).
- Añadir logs con etiqueta `Transcription`/`LocalWhisper` que registren: inicio/fin descarga, resultado de `isAvailable()`, entrada/salida de `transcribe()` y excepciones con stack trace.

Archivos sugeridos para instrumentar
- `apps/mobile/lib/features/recordings/presentation/transcription_screen.dart`
- `apps/mobile/lib/features/recordings/presentation/transcription_provider.dart`
- `apps/mobile/lib/core/services/local_whisper_service.dart`

Implementación mínima sugerida
-----------------------------
1. Añadir un `ValueNotifier<double>` o campo en `TranscriptionProvider` para `downloadProgress` y exponerlo al UI.
2. Mostrar `LinearProgressIndicator(value: provider.downloadProgress)` en la pantalla de transcripción cuando `downloadProgress` > 0 && < 1.
3. Usar `package:logger` o `print` con prefijo `Transcription` para eventos importantes.

Criterios de aceptación
----------------------
- El usuario ve progreso durante descarga y durante transcripción (indicador y texto).
- Los logs contienen al menos: `download_start`, `download_progress`, `download_complete`, `transcribe_start`, `transcribe_end`, `transcribe_error`.
- QA puede reproducir el flujo y enviar logs para el issue 0001.
