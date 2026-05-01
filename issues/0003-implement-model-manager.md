# 0003 - Implementar gestor de modelos on-device (descarga, verificación, versiones)

Prioridad: Alta
Asignado a: @programador

Descripción
-----------
Crear un componente responsable de manejar los modelos locales: comprobar existencia, descargar, validar integridad (checksum/size/version), y eliminar/actualizar.

Requisitos funcionales
---------------------
- Interface `ModelManager` con métodos: `isAvailable(WhisperModel)`, `ensureModel(WhisperModel, onProgress)`, `deleteModel(WhisperModel)`, `getModelPath(WhisperModel)`.
- Descarga segura con retries y verificación (sha256 o size).
- Ubicación de modelos: `getApplicationSupportDirectory()` en Android, `getLibraryDirectory()` en iOS.
- Exponer progreso al `TranscriptionProvider`.

Integración
-----------
- `LocalWhisperService` debe usar `ModelManager` para `isAvailable()` y para obtener la ruta del modelo.
- `TranscriptionProvider` debe llamar a `ModelManager.ensureModel()` antes de transcribir y mostrar progreso.

Pruebas
------
- Tests unitarios para `ModelManager` simulando descarga y verificación.

Aceptación
---------
- ModelManager implementado y usado por `LocalWhisperService`.
- Descarga con progreso y verificación funciona en el emulador.
