# 0001 - Arreglar bug: descarga del modelo local termina sin transcribir (UI en blanco)

Prioridad: Alta
Asignado a: @programador

Descripción
-----------
Al iniciar la transcripción la app muestra el visualizador de descarga de Android (se descarga el modelo local), pero al término la pantalla vuelve en blanco y no aparece la transcripción. Al presionar "Transcribir" de nuevo no sucede nada.

Archivos relevantes
- `apps/mobile/lib/core/services/local_whisper_service.dart`
- `apps/mobile/lib/features/recordings/presentation/transcription_provider.dart`
- `apps/mobile/lib/features/recordings/presentation/transcription_screen.dart`
- `apps/mobile/lib/core/services/audio_recorder_service.dart`

Pasos para reproducir
---------------------
1. Abrir la app en un dispositivo Android con conexión (o emulador).
2. Grabar o importar un audio corto.
3. Abrir la pantalla de transcripción y presionar `Transcribir` (motor local seleccionado).
4. Observar la descarga iniciada por el sistema; esperar a que termine.
5. Resultado: la UI vuelve en blanco y no se muestra la transcripción.

Hipótesis de causa
------------------
- La descarga del modelo no actualiza correctamente el estado `isAvailable()` o no se espera a que finalice antes de llamar a `transcribe()`.
- `transcribe()` lanza una excepción que no se propaga con detalles al UI y deja la pantalla en estado inválido.
- `TranscriptionProvider` no muestra errores detallados o no actualiza `isTranscribing`/`transcriptionStatus` apropiadamente.

Solución propuesta
------------------
1. Añadir logs (o logger) en puntos clave: inicio/fin de descarga, `isAvailable()` y antes/después de `transcribe()`.
2. Asegurar que el gestor de modelos devuelva `isAvailable()` verdadero sólo cuando el archivo existe y está íntegro (checksum/versión opcional).
3. Antes de llamar a `transcribe`, comprobar `isAvailable()` y, si no está disponible, mostrar estado de descarga y bloquear la acción hasta completarse.
4. Envolver la llamada a `whisper.transcribe` en `try/catch` y propagar una excepción con mensaje útil; en `TranscriptionProvider` capturarla y actualizar `transcriptionStatus` con el error.
5. Añadir feedback en UI: progreso de descarga, mensajes de error legibles y botón para reintentar.

Criterios de aceptación
----------------------
- Al finalizar la descarga, la app inicia automáticamente la transcripción (si el usuario lo solicitó) o muestra mensaje para iniciar.
- Si `transcribe()` falla, el UI muestra un error legible y permite reintento.
- `TranscriptionProvider.transcriptionStatus` refleja correctamente el estado (descargando, transcribiendo, completado, error).
- Se agregan al menos 3 logs útiles que permitan reproducir el error si vuelve a ocurrir.

Comandos / Verificación
-----------------------
- Ejecutar la app en emulador/real y seguir pasos para reproducir.
- Revisar logs (adb logcat) o consola del emulador para entradas etiquetadas `LocalWhisper` o `TranscriptionProvider`.
- Ejecutar `flutter test` para asegurar que los tests unitarios no rompen el flujo.

Notas
-----
Documentar en el issue cualquier archivo de modelo usado y su ubicación esperada (`getApplicationSupportDirectory()` o `getLibraryDirectory()`).
