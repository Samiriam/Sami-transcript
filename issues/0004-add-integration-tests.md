# 0004 - Añadir tests de integración para flujo completo (descarga → transcribir → mostrar)

Prioridad: Media
Asignado a: @programador / QA

Objetivo
--------
Agregar pruebas automáticas o scripts de QA que cubran el flujo: asegurar modelo → ejecutar transcripción local → persistir y mostrar resultado.

Qué probar
-----------
- Flujo con motor local (simulando descarga si es necesario).
- Flujo con fallback a API remota (simular respuestas de OpenAI/AssemblyAI).
- Manejo de errores (modelo corrupto, transcribe falla) y verificación de estado en UI.

Herramientas sugeridas
---------------------
- `integration_test` de Flutter para e2e simple.
- Mocks para servicios remotos.

Checklist de verificación
------------------------
- Test que simule descarga y verifique que `TranscriptionProvider` pasa por estados: downloading → transcribing → done.
- Test que fuerce una excepción en `transcribe()` y verifique que el estado es `failed` y que se muestra mensaje de error.
