# Checklist de PR / Release

Use este checklist para PRs grandes relacionados con el flujo de transcripción y la publicación en Play Store.

- [ ] Incluye descripción clara del cambio y issue asociado.
- [ ] Tests nuevos o actualizados incluidos y `flutter test` pasa.
- [ ] Logs y mensajes de error útiles añadidos para debugging.
- [ ] UI muestra estados: `descargando` / `transcribiendo` / `completado` / `error`.
- [ ] Si hay cambios en Android nativo, `flutter analyze` pasa y `flutter build apk`/`aab` se prueba localmente.
- [ ] Privacy Policy y texto de Play Store actualizados si procede.
- [ ] Documentación de cómo reproducir cambios/bugs añadida al issue.

Instrucciones de verificación (rápido)
-----------------------------------
1. Ejecutar `flutter analyze` en `apps/mobile`.
2. Ejecutar `flutter test`.
3. En dispositivo/emulador: probar grabación, transcripción local y fallback a API remota.
4. Revisar logs (adb logcat) para entradas `Transcription`.
