# 0005 - Preparar release para Play Store (plan, assets, AAB, privacidad)

Prioridad: Alta
Asignado a: @programador / Product

Descripción
-----------
Tareas para preparar la publicación en Play Store manteniendo la estrategia local-first y la opción de fallback a APIs remotas.

Checklist resumida
------------------
1. Revisar `AndroidManifest` y permisos runtime (`RECORD_AUDIO`).
2. Implementar foreground service para grabaciones largas (si procede).
3. Optimizar y reducir polling (`watchAll`).
4. Preparar `AAB` firmado y configure Gradle Play Publisher o proceso manual.
5. Redactar y publicar `Privacy Policy` (tratamiento de audio, datos, almacenamiento, terceros).
6. Preparar capturas, iconos, texto y categorías para la ficha Play Store.
7. Integrar monitoreo (crash reporting) y analytics mínimo.

Deliverables
-----------
- `release/aab` build artifact (por CI) o instrucciones para generar localmente.
- Documento `PRIVACY_POLICY.md` y URL pública donde alojarlo.
- Checklist de subida y pasos de verificación.
