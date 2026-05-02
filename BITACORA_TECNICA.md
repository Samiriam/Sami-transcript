# Bitacora Tecnica — Sami Transcribe

## 2026-05-02 (Mejoras de estabilidad, indicadores y logging)

### Cambios implementados

1. **AppLogger** (`core/services/app_logger.dart`)
   - Servicio de logging persistente con rotacion automatica (512 KB max).
   - Niveles: INFO, WARN, ERROR con timestamps.
   - Buffer en memoria (500 entradas) + archivo `logs/app.log`.
   - Integrado en `main.dart` como handler global de errores Dart/Platform.
   - Viewer de logs accesible desde Ajustes > Depuracion > Ver Logs.
   - Opcion de limpiar logs desde UI.

2. **Resumen con fallback y timeout** (`transcription_provider.dart`)
   - `generateSummary()` ahora tiene estados: idle, connecting, generating, done, doneWithFallback, error.
   - Timeout de 5 minutos para APIs de resumen.
   - Si la API falla, genera resumen local como alternativa automatica (estado `doneWithFallback`).
   - Mensajes de estado en tiempo real: "Conectando...", "Generando resumen...", "Conexion exitosa."
   - Boton "Reintentar" visible cuando hay error o fallback.

3. **Badge de motor mejorado** (`transcription_screen.dart`)
   - Badge con color coding: verde para IA cloud, azul/tertiary para local.
   - Contenedor con fondo semitransparente y borde.
   - Iconos diferenciados: `cloud_done_outlined` para IA, `phone_android` para local.
   - Labels descriptivos: "Motor local (Whisper)", "Transcripcion con IA (OpenAI)".

4. **Indicadores de resumen**
   - Chip con motor de resumen (Local / IA OpenAI / IA AssemblyAI).
   - Barra de progreso durante conexion.
   - Tarjeta de error con icono y detalle del error HTTP.
   - Aviso naranja cuando se uso fallback a resumen local.

5. **Motor local con logging mejorado** (`local_whisper_service.dart`)
   - `_log()` ahora usa `AppLogger` en vez de `debugPrint`.

### Verificacion
- `flutter analyze`: 0 errores, 6 infos (deprecation warnings pre-existentes de Flutter SDK).

### Archivos modificados
- `core/services/app_logger.dart` (nuevo)
- `core/services/local_whisper_service.dart` (logging)
- `main.dart` (integracion logger + error handlers)
- `features/recordings/presentation/transcription_provider.dart` (summary status, fallback, timeout)
- `features/recordings/presentation/transcription_screen.dart` (badges, status UI, retry)
- `features/recordings/presentation/settings_screen.dart` (log viewer, clear logs)

### Pendiente
- Build APK con todos los cambios.
- Prueba en dispositivo real.
- Push a GitHub.

## 2026-05-02 (Ajuste final: reactivar modelo base y mantener API de resumen separada)

### Cambio solicitado
- El usuario pidio no eliminar `base`, porque puede servir en telefonos con mejores recursos que el dispositivo actual.

### Ajuste aplicado
- `base` vuelve a estar disponible en el selector local.
- Se mantiene la recomendacion de usar `tiny` en equipos antiguos.
- Se reduce la agresividad de Whisper local por modelo:
  - `tiny`: `threads=2`
  - `base` y superiores: `threads=1`, `nProcessors=1`
- La configuracion de API para resumen sigue separada de la transcripcion.

### Resultado
- No se bloquea el uso de `base` en otros telefonos.
- Se intenta que `base` tenga mas probabilidad de funcionar incluso en equipos justos al bajar concurrencia CPU.

### Verificacion
- `flutter analyze`: sin errores; persisten 4 infos por `RadioListTile` deprecado.
- `flutter test`: exitoso.

## 2026-05-02 (Defectos finales: modelos locales pesados y API separada de resumen)

### Problema reportado
- En dispositivo real el modelo local mas pequeno funciona pero con baja calidad.
- El modelo local intermedio vuelve a producir pantallazo blanco/cierre.
- No existia forma visible de ingresar una API separada para resumen; parecia compartir la de transcripcion.

### Decision aplicada
- En Android se deshabilitan para uso local los modelos Whisper mayores a `tiny`.
- Motivo: la evidencia real del dispositivo muestra cierre repetido por recursos; es preferible forzar estabilidad local y derivar mejor calidad a APIs cloud.

### Fix aplicado
- `TranscriptionConfig`:
  - agrega configuracion independiente para resumen:
    - `summaryOpenAiKey`
    - `summaryOpenAiBaseUrl`
    - `summaryOpenAiModel`
    - `summaryAssemblyAiKey`
  - en Android, si habia un modelo local distinto de `tiny`, se normaliza a `tiny` al cargar configuracion.
- `SettingsScreen`:
  - el selector de modelo local en Android deja solo `tiny`.
  - se agregan campos propios para API de resumen OpenAI/OpenRouter y AssemblyAI.
  - se deja nota clara: OpenRouter es adecuado para resumen via `/chat/completions`; para transcripcion solo sirve si el proveedor expone `/audio/transcriptions`.

### Resultado funcional
- La transcripcion local en Android queda orientada a estabilidad, no a maxima calidad.
- Para mejor calidad de transcripcion o resumen, la ruta recomendada es cloud/API.
- La API de resumen ya no depende de reutilizar obligatoriamente la de transcripcion.

### Verificacion
- `flutter analyze`: sin errores, 4 infos por `RadioListTile` deprecado.
- `flutter test`: exitoso.

## 2026-05-02 (Exportacion PDF/TXT, resumen configurable y reemplazo de modelo local)

### Problema reportado
- Al cambiar modelo local, se esperaba descargar automaticamente el nuevo y eliminar el anterior.
- La exportacion solo generaba TXT en carpeta interna fija; el plan original pedia PDF y permitir elegir ubicacion.
- El resumen local era pobre y no habia configuracion independiente para usar API cloud de resumen.
- Se pidio poder guardar transcripcion + resumen y borrar una transcripcion anterior.
- Se pidio compatibilidad con APIs tipo OpenRouter.

### Cambios aplicados
- Modelo local:
  - `replaceLocalModel()` descarga el modelo nuevo, guarda la preferencia y elimina el modelo anterior solo si el nuevo queda listo.
  - Se conserva la persistencia del modelo ya descargado en primer uso; no se borra salvo cambio explicito de modelo.
- Exportacion:
  - Se agrego dependencia `pdf`.
  - Exportacion ahora soporta `PDF` y `TXT`.
  - En Android/iOS se usa `FilePicker.platform.saveFile(...)` con bytes para permitir al usuario elegir ubicacion/nombre.
  - Se permite incluir o excluir resumen en el documento exportado.
- Resumen:
  - Se agrego `SummaryEngine` independiente (`local`, `openai`, `assemblyai`).
  - El resumen local ahora genera estructura: resumen ejecutivo, temas principales, acciones/pendientes y nota de limitacion.
  - El prompt OpenAI fue reforzado para corregir redaccion evidente sin inventar datos y producir secciones profesionales.
- API compatible/OpenRouter:
  - Se mantiene URL base OpenAI-compatible.
  - Se aclaro en ajustes que OpenRouter sirve normalmente para resumen via `/chat/completions`; para transcripcion de audio el proveedor debe exponer `/audio/transcriptions`.
- Borrado:
  - Se agrego `deleteTranscription()` para eliminar transcripcion y segmentos, conservando el audio original.
  - La pantalla de transcripcion ahora tiene accion de borrar transcripcion.

### Verificacion
- `flutter pub get`: exitoso, con avisos no bloqueantes de advisories de pub.dev.
- `dart format`: aplicado.
- `flutter test`: exitoso.
- `flutter analyze`: sin errores; quedan 4 infos por API de `RadioListTile` deprecada.
- `flutter build apk --debug`: Gradle genero `apps/mobile/build/app/outputs/apk/debug/app-debug.apk` con timestamp `2026-05-02 15:39:02`, pero fallo la copia final a `build/app/outputs/flutter-apk/app-debug.apk` por archivo abierto.

### Pendiente
- Liberar/cerrar el proceso que bloquea `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` y repetir build para actualizar esa ruta final si se requiere instalar desde ahi.
- Probar en dispositivo el selector de guardado SAF de Android para PDF/TXT.

## 2026-05-02 (Auditoria post-crash, modelos Whisper e icono externo)

### Problema reportado
- La ultima prueba volvio a cerrar la app/pantallazo blanco.
- Se pidio revisar mas debug, posibles errores y oportunidades de mejora.
- Se consulto si el modelo Whisper afecta tiempo de transcripcion y si cambiar modelo borra el anterior.
- Se reporto que el icono externo de la APK no habia cambiado.

### Hallazgos
- No hay dispositivo ADB conectado al equipo, por lo que no se pudo extraer `logcat` real del crash.
- La causa mas probable del cierre sigue siendo nativa/recursos durante Whisper local: el plugin usa codigo nativo y puede terminar el proceso sin pasar por `try/catch` de Dart.
- `TranscribeRequest` del plugin trae por defecto `threads: 6`; eso es agresivo para telefonos modestos.
- El modelo seleccionado impacta fuertemente tiempo, RAM y CPU:
  - `tiny`: mas rapido y menor RAM, recomendado para beta local.
  - `base`: mas lento y mas pesado.
  - `small`: mucho mas pesado, mayor riesgo de cierre por memoria/CPU.
- Cambiar modelo en ajustes **no borra** modelos previos. Los modelos se guardan como `ggml-tiny.bin`, `ggml-base.bin`, etc. Solo se eliminan si se llama explicitamente `deleteModel()`, cosa que el selector no hace.
- El icono externo seguia apuntando a `@mipmap/ic_launcher`, generado por Flutter por defecto.

### Fix aplicado
- `transcription_config.dart` y fallbacks relacionados:
  - `tiny` queda como default nuevo para instalaciones sin preferencia previa.
  - No se toca la preferencia ya guardada ni se eliminan modelos existentes.
- `local_whisper_service.dart`:
  - Whisper local se invoca con `threads: 2` y `nProcessors: 1` para bajar presion CPU/RAM.
- `settings_screen.dart`:
  - se agrego aviso explicito de rendimiento local y persistencia de modelos.
- `main.dart`:
  - se agregaron handlers de errores Dart/Flutter para capturar errores no fatales en debug logs. Nota: un crash nativo/OOM puede no pasar por estos handlers.
- Android icon:
  - se agrego `android/app/src/main/res/drawable/ic_launcher_gothic.xml`.
  - `AndroidManifest.xml` ahora usa `android:icon="@drawable/ic_launcher_gothic"` y `android:roundIcon="@drawable/ic_launcher_gothic"`.

### Verificacion
- `flutter test`: exitoso.
- `flutter analyze`: sin errores; persisten 2 infos por `Radio` deprecado.
- `flutter build apk --debug`: Gradle genero `apps/mobile/build/app/outputs/apk/debug/app-debug.apk` con timestamp `2026-05-02 14:59:49`, pero fallo la copia final a `build/app/outputs/flutter-apk/app-debug.apk` porque ese archivo esta bloqueado por otro proceso.
- Reintento tras liberar el archivo bloqueado: `flutter build apk --debug` exitoso y `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` generado a las `2026-05-02 15:02:37`.

### Riesgo residual
- Sin `logcat` real no se puede confirmar si el cierre fue OOM, crash nativo del plugin o watchdog/ANR.
- Whisper local sigue siendo la ruta de mayor riesgo en telefonos con poca RAM. Para estabilidad, usar `tiny` o API cloud.

### Pendiente
- Cerrar cualquier visor/instalador que tenga abierto `flutter-apk/app-debug.apk` y recompilar para actualizar la ruta final habitual.
- Repetir prueba con dispositivo conectado y capturar `logcat` si vuelve a cerrarse.

## 2026-05-02 (Fix de transcripción colgada, recuperación tras crash y share de audio)

### Problema reportado
- En dispositivo real, una transcripción de audio de ~3 minutos quedó más de 10 minutos en estado `Transcribiendo`.
- La app llegó a mostrar pantallazo blanco / cierre y, al volver a abrir, la grabación seguía marcada como `Transcribiendo` sin evidencia clara de que el proceso siguiera vivo.
- El usuario también pidió poder compartir/exportar el audio original a otras apps.

### Causa raiz confirmada
- La UI de listado no estaba suscrita al stream `watchAll()`, por lo que los cambios de estado no se reflejaban en tiempo real fuera de la pantalla puntual.
- Si la app se cerraba/crasheaba durante la transcripción, no existía recuperación del estado; el registro quedaba persistido como `transcribing` aunque ya no había tarea viva.
- No había timeout de seguridad para abortar transcripciones claramente colgadas.
- La normalización WAV pesada ya se había movido a isolate, pero seguía faltando gestión de ciclo de vida/estado.

### Fix aplicado
- `recording_provider.dart`:
  - suscripción real a `watchAll()` para auto-refresco del listado.
  - recuperación en arranque: cualquier grabación en `transcribing` pasa a `failed` si la app se reinicia, porque la tarea no persiste en background.
- `transcription_provider.dart`:
  - ticker visible de tiempo transcurrido durante transcripción.
  - timeout dinámico por duración/audio y motor, para no quedar indefinidamente en `transcribing`.
  - mensaje de estado adicional antes de guardar el resultado.
- `transcription_screen.dart`:
  - muestra tiempo transcurrido y aviso explícito de que la tarea no continúa si la app se cierra o se cae.
- `recording_detail_screen.dart`:
  - se agregó `Compartir audio` usando `share_plus`.

### Verificacion
- `flutter test`: exitoso.
- `flutter analyze`: sin errores; persisten 2 infos preexistentes por `Radio` deprecado en `settings_screen.dart`.
- `flutter build apk --debug`: exitoso.
- APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Timestamp: `2026-05-02 14:41:32`.

### Limitacion actual conocida
- La app no implementa ejecución persistente de transcripción en segundo plano. Si Android mata el proceso o la app se cierra, la transcripción se interrumpe y el estado se recupera como `failed` al abrir nuevamente.

### Pendiente
- Probar en dispositivo real si el timeout necesita ajuste fino para equipos lentos.
- Si se requiere transcripción real en background, diseñar un worker/foreground service Android específico; hoy no existe.

## 2026-05-02 (Fix WAV 16 kHz, audios importados y prevención de bloqueo UI)

### Causa raiz confirmada
- La grabacion local se estaba generando como `WAV` pero con defaults del plugin `record`: `44100 Hz` y `2 canales`.
- Whisper local exige `WAV PCM mono 16 kHz`, por eso fallaba con `Exception: wav file must be 16 Khz`.
- Adicionalmente, la normalizacion WAV corria completa en el isolate UI, lo que podia congelar la app en audios largos.

### Fix aplicado
- `audio_recorder_service.dart`:
  - grabacion local configurada como `AudioEncoder.wav`, `sampleRate: 16000`, `numChannels: 1`.
- `wav_audio_preparer.dart`:
  - parser/normalizador WAV en Dart para aceptar WAV PCM 16-bit externos y remuestrear a `16 kHz mono` cuando haga falta.
  - normalizacion movida a `Isolate.run(...)` para evitar bloqueo del hilo UI.
- `local_whisper_service.dart`:
  - usa `WavAudioPreparer` antes de invocar Whisper local.
  - limpia el WAV temporal normalizado al terminar.
- `recording_provider.dart` + `home_screen.dart`:
  - importacion real de audio con `file_picker`.
  - copia del archivo importado al storage interno de la app y alta en SQLite.
- `transcription_provider.dart`:
  - guardado de segmentos optimizado con `batch` SQLite e indice directo, evitando `indexOf` O(n²).
- `model_manager.dart`:
  - operaciones de archivo pequeñas cambiadas a variantes async para reducir trabajo sync en UI.

### Compatibilidad resultante
- Grabaciones nuevas de la app: compatibles con Whisper local.
- WAV externos PCM 16-bit de otra grabadora: compatibles; si no vienen a `16 kHz mono`, la app los normaliza antes de transcribir localmente.
- Audios importados no-WAV (`m4a`, `mp3`, etc.): se pueden importar y transcribir con OpenAI/AssemblyAI; Whisper local sigue requiriendo WAV.

### Verificacion
- `flutter test`: exitoso, incluyendo pruebas nuevas para `WavAudioPreparer`.
- `flutter analyze`: sin errores; quedan 2 infos preexistentes en `settings_screen.dart` por API de `Radio` deprecada.
- `flutter build apk --debug`: exitoso.
- APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Timestamp: `2026-05-02 14:07:43`.

### Riesgo residual
- La pantalla de transcripcion aun renderiza texto completo y lista de segmentos en la misma vista. No deberia bloquear durante la transcripcion, pero con transcripciones extremadamente largas todavia puede haber jank al abrirlas.

### Pendiente
- Probar manualmente en dispositivo Android:
  - grabacion nueva local + transcripcion Whisper.
  - WAV externo 44.1 kHz importado + normalizacion local.
  - `m4a/mp3` importado + transcripcion via OpenAI/AssemblyAI.

## 2026-05-02 (Flujo de audio WAV, exportacion de transcripcion y compatibilidad API)

### Hecho
- Se elimino la dependencia `ffmpeg_kit_flutter_full_gpl` porque rompia `flutter build` por resolucion de Maven.
- Se cambio la grabacion local a `WAV` desde origen con `record` para que el motor local Whisper reciba un formato compatible sin conversion adicional.
- Se simplifico `LocalWhisperService` para enviar el archivo directamente al motor local.
- Se agrego exportacion de transcripcion a TXT desde `TranscriptionProvider` y acciones de descargar/compartir en `TranscriptionScreen`.
- Se conecto la accion de exportacion desde `RecordingDetailScreen` para no dejarla como placeholder.

### Verificacion
- `flutter pub get`: exitoso, con retiro de `ffmpeg_kit_flutter_full_gpl`.
- `flutter analyze`: sin errores; quedaron 2 infos preexistentes en `settings_screen.dart` sobre `Radio` deprecado.
- `flutter build apk --debug`: el APK se genero en `apps/mobile/build/app/outputs/apk/debug/app-debug.apk`, pero fallo el paso final de copia a `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` por bloqueo de archivo en uso.

### No funciono / Riesgos
- `ffmpeg_kit_flutter_full_gpl` no era una ruta viable en este entorno por dependencia Maven faltante.
- El artefacto `flutter-apk/app-debug.apk` quedo bloqueado por otro proceso durante la copia final.

### Pendiente
- Probar en dispositivo real que el WAV grabado se transcribe localmente sin el error de apertura de archivo.
- Confirmar que la exportacion TXT se guarda donde el usuario espera en Android.

## 2026-05-02 (Logo gótico y nueva APK debug)

### Hecho
- Se creo `apps/mobile/lib/core/widgets/gothic_logo.dart` con un logo reusable estilo gótico para la app.
- Se integro el logo en la `HomeScreen` y en el `AppBar` principal.
- Se regenero la APK debug actualizada con el nuevo branding visual.

### Verificacion
- `flutter analyze`: sin errores, solo 2 infos preexistentes en `settings_screen.dart`.
- `flutter build apk --debug`: exitoso.
- Artefacto: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Timestamp: `2026-05-02 13:45:59`.

### Pendiente
- Probar visualmente en dispositivo que el logo mantenga legibilidad en pantallas pequenas.

## 2026-05-02 (Revision de SkillsMP para trabajo diario)

### Hecho
- Se ejecuto `skillsmp-sync` en modo lectura contra el repo para revisar skills candidatos desde la nube.
- Consulta base: `python $HOME/.codex/skills/skillsmp-sync/scripts/skillsmp_sync.py --project-dir . --max-install 6 --json`
- Consulta ampliada con enfoque Flutter/movil: `python $HOME/.codex/skills/skillsmp-sync/scripts/skillsmp_sync.py --project-dir . --max-install 6 --extra-query "flutter android mobile audio transcription sqlite" --json`

### Resultado
- Los candidatos de mayor puntaje fueron, en su mayoria, duplicados funcionales de skills ya instaladas:
  - `testing` -> solapa con `e2e-testing` y `test-tui`
  - `documentation-lookup` -> solapa con `context7-docs-lookup`
  - `e2e-testing-patterns` -> solapa con `e2e-testing`
- Los demas candidatos devueltos por SkillsMP no aportan al flujo diario de este repo o no son relevantes para Flutter mobile.
- No se instalo ni reemplazo ninguna skill.

### Conclusion
- El set actual de skills locales ya cubre lo esencial para este proyecto: Flutter, arquitectura, migraciones, pruebas, docs, CI/CD, debug y revision.
- Recomendacion actual: no agregar skills nuevas por ahora; revisar otra vez solo cuando aparezcan necesidades concretas de Play Store, testing de integracion o tooling documental mas exigente.

## 2026-05-01 (Issues 0001-0005: Bug fixes, ModelManager, Play Store prep)

### Hecho
- **Issue 0001 (resuelto):** Bug UI en blanco tras transcripcion. Causa raiz: descarga del modelo no tenia verificacion ni manejo de error visible.
  - Solucion: Pantalla de error con reintento, `lastError` expuesto al UI, verificacion de modelo antes de transcribir.
- **Issue 0002 (resuelto):** Feedback de progreso y logging estructurado.
  - Solucion: `LinearProgressIndicator` durante descarga, logs `[LocalWhisper]` y `[TranscriptionProvider]` con download_start, download_progress, download_complete, transcribe_start, transcribe_end, transcribe_error.
- **Issue 0003 (resuelto):** ModelManager implementado (`model_manager.dart`).
  - `isAvailable()`: verifica existencia y tamano minimo del archivo modelo.
  - `ensureModel()`: descarga con callback de progreso y eliminacion de corruptos.
  - `deleteModel()`, `getModelInfo()`, `ModelInfo`.
  - `LocalWhisperService` delega a `ModelManager`.
- **Issue 0005 (parcial):** Preparacion Play Store.
  - Namespace cambiado de `com.example.sami_transcribe` a `com.sami.transcribe`.
  - `MainActivity.kt` movida al paquete `com.sami.transcribe`.
  - `PRIVACY_POLICY.md` creada.
  - Pendiente: signing config release, AAB, capturas de pantalla, crash reporting.

### No aplica / Pendiente
- Issue 0004 (tests de integracion): no implementado. Requiere `integration_test/` y mocks.
- Issue 0005: falta signing config, AAB build, capturas, ficha Play Store.

### Archivos nuevos
- `apps/mobile/lib/core/services/model_manager.dart`
- `PRIVACY_POLICY.md`
- `issues/0001` a `0005`

### Archivos modificados
- `local_whisper_service.dart`: delega a ModelManager
- `transcription_provider.dart`: usa ensureModel con progreso real, lastError, WhisperModel
- `transcription_screen.dart`: pantalla error con reintento, progress bar descarga
- `audio_recorder_service.dart`: crea directorio antes de grabar
- `android/app/build.gradle.kts`: namespace y applicationId
- `android/app/src/main/kotlin/com/sami/transcribe/MainActivity.kt`

### Verificacion
- `flutter analyze`: 0 errores, 0 warnings, 2 infos (deprecated Radio)
- `flutter build apk --debug`: exitoso en 164s (primera build con nuevo namespace)

## 2026-05-01 (Build APK de prueba Android)

### Hecho
- Se localizo Flutter instalado en `C:\Users\informatica\flutter` y se uso `flutter.bat` por ruta absoluta porque no esta en el `PATH` de la terminal.
- Se verifico el toolchain Android con `flutter doctor -v` usando `JAVA_HOME=C:\Users\informatica\.jdks\ms-21.0.9`.
- Se regenero la estructura nativa Android faltante con `flutter create --platforms=android .` dentro de `apps/mobile`.
- Se actualizo `record` de `^5.2.0` a `^6.2.0` para resolver la incompatibilidad entre `record_linux 0.7.2` y `record_platform_interface 1.5.0` que bloqueaba la compilacion.
- Se agrego `android.permission.RECORD_AUDIO` al manifiesto Android y se ajusto el label a `Sami Transcribe` para que la APK de prueba pueda solicitar grabacion de audio.
- Se compilo APK debug con `flutter build apk --debug`.

### Evidencia
- Comando exitoso: `flutter build apk --debug`.
- Resultado: `Built build\app\outputs\flutter-apk\app-debug.apk`.
- Ruta del APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Tiempo reportado por Gradle: `125,5s` en primera compilacion exitosa y `13,5s` en recompilacion posterior al ajuste de manifiesto.

### No funciono / Intentos
- `flutter` no resolvia desde `PATH`; se uso ruta absoluta.
- `choco install temurin17 -y` fallo por falta de permisos sobre `C:\ProgramData\chocolatey` en terminal no elevada.
- Primer build fallo por incompatibilidad de dependencias `record` antes de actualizar a `^6.2.0`.

### Estado
- APK debug generado y listo para prueba manual en dispositivo Android.
- Se agregara el APK al repositorio por instruccion explicita del usuario usando Git LFS, porque el archivo pesa aproximadamente 150 MB y supera el limite normal de GitHub para archivos versionados directamente.

## 2026-04-30 (Sprint 2 — Transcripcion + Configuracion API)

### Hecho
- Se creo interfaz abstracta `TranscriptionService` con soporte para multiples motores.
- Se implemento **Whisper local** (`whisper_flutter_new`) como motor por defecto.
- Se implemento **cliente OpenAI compatible** con soporte para URL base personalizable.
- Se implemento **cliente AssemblyAI** con diarizacion de hablantes.
- Se creo `TranscriptionConfig` con persistencia de:
  - Motor seleccionado (local/openai/assemblyai)
  - API keys (OpenAI, AssemblyAI)
  - URL base personalizable para OpenAI-compatible (ej: LM Studio, Ollama)
  - Modelo Whisper (tiny/base/small)
- Se creo servicio de **resumen de transcripciones** (local para Whisper, API para OpenAI/AssemblyAI).
- Se creo `TranscriptionProvider` con flujo completo de transcripcion.
- Se creo pantalla de **Transcripcion** con:
  - Vista de texto completo
  - Vista de segmentos con hablantes y timestamps
  - Edicion de texto
  - Generacion de resumen
  - Badge del motor utilizado
- Se actualizo la pantalla de **Ajustes** con:
  - Selector de motor (radio buttons con descripcion)
  - Configuracion de API key por motor
  - URL base personalizable para OpenAI-compatible
  - Selector de modelo Whisper
- Se conecto la transcripcion desde la pantalla de detalle.
- Se agrego dependencia `http` para llamadas API y `whisper_flutter_new`.

### Decision tecnica
- Se eligio `sqflite` en vez de `drift` para evitar code generation pesado.
- Las API keys se guardan en SharedPreferences (suficiente para beta personal).
- La URL base de OpenAI es personalizable para soportar proveedores compatibles (Ollama, LM Studio, etc.).
- El resumen local usa extraccion de primeras oraciones como fallback.

### Pendiente
- Verificar `flutter analyze` sin errores.
- Probar en dispositivo/emulador.
- Implementar importacion de audios externos.
- Exportacion a PDF/TXT.

### Build Android intentado
- Se ejecuto `flutter doctor -v`.
- Resultado: Flutter OK, pero Android reporta `cmdline-tools component is missing` y `Android license status unknown`.
- Se ejecuto `flutter build apk --debug`.
- Resultado: fallo inmediato con mensaje `Your app is using an unsupported Gradle project`.
- Evidencia observada: `apps/mobile` contiene `lib/`, `test/`, `pubspec.yaml` y metadatos de Dart, pero no contiene la estructura nativa Flutter/Android (`android/`, `gradle/`, `settings.gradle`, etc.).

### Bloqueo para programador
- El codigo Dart esta avanzado, pero el proyecto movil no fue inicializado originalmente con la plantilla Flutter completa para Android.
- Antes de generar APK, el programador debe reconstruir la base nativa con una estructura Flutter valida y luego reinyectar el codigo existente.
- No se continuo con esa reparacion por instruccion del usuario.

### Documentacion actualizada
- Se alineo `README.md` con el estado actual del proyecto.
- Se actualizo `PLAN_TRABAJO.md` con Sprint 2 implementado y pendientes reales.
- Se corrigio `PLAN_IMPLEMENTACION.md` para reflejar el orden real de trabajo en beta personal.
- Se ajusto `SDD.md` y `docs/architecture/flutter-beta.md` a la arquitectura local-first vigente.
- Se actualizo `HERRAMIENTAS_NECESARIAS.md` con el stack de transcripcion local + APIs opcionales.

### Verificacion documental
- La documentacion ahora coincide con el estado real del codigo: grabacion, persistencia local, Whisper local, configuracion de APIs y pantalla de transcripcion.

---

## 2026-04-29 (Sprint 1 — Implementacion)

### Hecho
- Se reemplazo el repositorio en memoria por **SQLite (sqflite)** con persistencia real.
- Se cambio de Drift a sqflite para evitar dependencia de `build_runner` y code generation.
- Se creo la tabla `recordings` con campos: id, title, audio_path, duration_seconds, source, status, created_at, updated_at.
- Se creo la tabla `transcriptions` con FK a recordings.
- Se creo la tabla `segments` con FK a transcriptions.
- Se implemento `AudioRecorderService` con record package (inicio/pausa/detener).
- Se implemento `RecordingProvider` con Provider para estado reactivo.
- Se creo la pantalla principal completa con:
  - Boton de grabar/detener.
  - Indicador visual de grabacion con punto pulsante.
  - Timer en tiempo real durante la grabacion.
  - Lista de grabaciones recientes con cards.
  - Boton de importar audio (placeholder).
  - Toggle de tema claro/oscuro en AppBar.
  - Acceso a ajustes.
- Se implemento **modo oscuro/claro** con persistencia via SharedPreferences.
- Se creo la pantalla de **Ajustes** con secciones: Apariencia, Grabacion, Transcripcion, Datos.
- Se creo `RecordingCard` con status icon, status chip, duracion formateada y fecha.
- Se creo `AppTheme` con tema Material 3 basado en teal.
- Se implemento dialogo de confirmacion para eliminar grabaciones.
- Se agregaron tests unitarios para `Recording` (formattedDuration, copyWith) y enum.
- Se actualizo `pubspec.yaml` con dependencias: sqflite, record, provider, intl, shared_preferences, path_provider, uuid, audioplayers, share_plus.
- Se ejecuto `flutter pub get` exitosamente.
- Se actualizo `.gitignore` para excluir pubspec.lock y artifacts.

### Funciona
- `flutter pub get` resuelve dependencias correctamente.
- Estructura de carpetas clean architecture: core/database, core/services, core/theme, features/recordings/data, features/recordings/domain, features/recordings/presentation.

### Pendiente
- Ejecutar `flutter analyze` completo para verificar que no hay errores de compilacion.
- Probar la app en un dispositivo/emulador.
- Implementar la transcripcion (Sprint 2).
- Integrar motor de transcripcion (Whisper, AssemblyAI u otro).

---

## 2026-04-29 (Herramientas)

### Hecho
- Se instaló **Chocolatey** (gestor de paquetes para Windows).
- Se instaló **Android SDK** sin Android Studio en `C:\Android\android-sdk`.
- Se verificó **Java JDK 1.8.0_211** instalado en `C:\Program Files\Java`.
- Se instaló **Flutter SDK 3.38.9** en `C:\tools\flutter` (vía Chocolatey).
- Se instaló **pnpm** globalmente via npm.
- Se configuraron variables de entorno:
  - `ANDROID_HOME=C:\Android\android-sdk`
  - `ANDROID_SDK_ROOT=C:\Android\android-sdk`
  - `JAVA_HOME=C:\Program Files\Java\jdk1.8.0_211`
  - `PATH` incluye `C:\tools\flutter\bin`
- Se actualizó `HERRAMIENTAS_NECESARIAS.md` con el estado de instalación.

### Funciona
- Chocolatey responde a comandos.
- Android SDK base instalado con platform-tools.
- Java disponible desde línea de comandos.
- Flutter SDK instalado y disponible.
- pnpm instalado globalmente.

### No funcionó
- La instalación de componentes adicionales de Android SDK (platforms, build-tools) requiere interacción que no funciona bien desde esta terminal.

### Falta
- Completar instalación de Android SDK (platforms;android-34, build-tools;34.0.0)
- Ejecutar `flutter doctor` para verificar configuración completa
- Configurar licencias de Android SDK

---

## 2026-04-28

### Hecho
- Se creó el plan de trabajo inicial.
- Se creó el SDD del proyecto.
- Se creó el plan de implementación.
- Se definió la estructura principal del repositorio.
- Se creó el árbol físico de carpetas base.
- Se añadieron marcadores `.gitkeep` para mantener las carpetas en el repositorio.
- Se agregó `.gitignore` inicial.
- Se redefinió el alcance a una beta personal de un solo usuario.
- Se ajustó la ruta de escalado para futura versión comercial o multiusuario.
- Se creó el esqueleto inicial de Flutter en `apps/mobile`.
- Se añadió una base local-first con dominio, repositorio en memoria y pantalla principal.
- Se agregaron documentos de arquitectura y decisión técnica para la beta personal.

### Funciona
- La estructura base del proyecto ya existe en disco.
- Los documentos de planificación están disponibles para consulta.

### No funcionó
- No se ha inicializado el SDK Flutter en esta maquina.
- No se pudo verificar compilacion local con `flutter` porque el comando no esta disponible.

### Falta
- Instalar Flutter SDK en la maquina de desarrollo.
- Reemplazar el repositorio en memoria por SQLite/Drift.
- Completar la persistencia local y el flujo de transcripcion.

### 2026-04-29 — Diagnóstico de herramientas

#### Hecho
- Se verificaron las herramientas instaladas en la máquina.
- Se actualizó `HERRAMIENTAS_NECESARIAS.md` para reflejar el stack real de la beta personal.
- Se eliminó Docker y Android Studio del plan (PC de bajos recursos, trabajo 100% desde VS Code).

#### Funciona
- Git v2.53.0 instalado.
- Node.js v22.14.0 instalado.

#### No funciona / Pendiente
- Flutter SDK no está en el PATH. Se necesita instalar manualmente.
- Android SDK CLI tools no instalado.
- pnpm no instalado (PowerShell tiene ExecutionPolicy restrictiva).
- VS Code extensions Flutter/Dart no instaladas.

#### Próxima acción
- Usuario instala Flutter SDK + Android SDK CLI + extensiones VS Code.
- Una vez instalado Flutter, ejecutar `flutter doctor` y verificar.
- Reanudar implementación del Sprint 1.

### Próxima acción (general)
- Instalar herramientas pendientes y verificar con `flutter doctor`.

## Regla operativa

- Todo avance, deuda, bloqueo, decisión técnica y cambio de alcance debe quedar registrado en los archivos de seguimiento del proyecto.
- Prioridad de documentación: `BITACORA_TECNICA.md`, `PLAN_TRABAJO.md`, `PLAN_IMPLEMENTACION.md` y `README.md` cuando aplique.
- Si cambia el enfoque del proyecto, el ajuste debe reflejarse primero en la documentación antes de seguir construyendo.
## 2026-05-02 (Configuracion profesional de resumen OpenAI/OpenRouter y mitigacion final de Whisper)

### Objetivo
- Permitir configuracion robusta de resumen IA con URL base dinamica, API key, presets conocidos y discovery real de modelos desde `/models`.
- Investigar y corregir el fallo de pantalla blanca en Whisper local con `base/small` al finalizar y devolver la transcripcion.

### Implementado
- Se agrego `openai_compatible_model_discovery_service.dart` con:
  - directorio interno de presets: OpenAI, OpenRouter y personalizado;
  - normalizacion de URL base;
  - validacion de credenciales;
  - discovery de modelos via `GET /models`;
  - priorizacion de modelos `:free` en OpenRouter.
- En ajustes de resumen:
  - se reemplazo ingreso manual de modelo por selector dinamico poblado tras validacion;
  - se prohibe guardar configuracion si no hubo validacion y modelo seleccionado;
  - se mantiene URL base editable, sin hardcode operativo.
- La configuracion de resumen OpenAI/OpenRouter queda independiente de la transcripcion.

### Investigacion de crash Whisper
- Hipotesis mas fuerte: el plugin `whisper_flutter_new` devuelve demasiado payload al finalizar con `base/small` y/o tiene fragilidad FFI al liberar la respuesta nativa.
- Evidencia funcional: el fallo se da al final de la inferencia y no con `tiny`.

### Mitigacion aplicada
- Para `base` y superiores en Whisper local:
  - `threads=1`, `nProcessors=1`;
  - `isNoTimestamps=true` para reducir segmentos/timestamps en el payload devuelto.
- `tiny` conserva segmentos/timestamps locales.

### Verificacion
- `flutter analyze`: sin errores; quedaron 6 infos deprecadas en widgets de formulario/radio del framework actual.
- `flutter test`: exitoso.
- `flutter build apk --debug`: compilo y genero el artefacto fuente `apps/mobile/build/app/outputs/apk/debug/app-debug.apk`, pero la copia final a `build/app/outputs/flutter-apk/app-debug.apk` volvio a fallar por archivo abierto/bloqueado.

### Riesgo residual
- La mitigacion reduce fuertemente el payload final y deberia ayudar con `base`, pero si el problema dominante es el bug FFI del paquete de terceros, el crash puede seguir ocurriendo en algunos equipos o modelos superiores.

### Pendiente
- Si el crash persiste con `base`, el siguiente paso serio es reemplazar o parchear el plugin Whisper nativo/FFI.
