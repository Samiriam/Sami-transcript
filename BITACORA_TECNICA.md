# Bitacora Tecnica — Sami Transcribe

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
