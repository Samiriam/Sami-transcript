# Plan de Implementación — Sami Transcribe

> Fecha: 2026-04-30  
> Estado: Fase de arranque
> Enfoque: beta personal primero, escalado después

## 1. Objetivo

Convertir el plan de trabajo y el diseño técnico en una ruta ejecutable para construir una beta personal de Sami Transcribe de forma incremental, verificable y reversible.

## 2. Relación con el Plan de Trabajo

Este plan de implementación desglosa el `PLAN_TRABAJO.md` en entregables concretos, ordenados por dependencias técnicas.

- El plan de trabajo define el alcance y los hitos.
- Este documento define el orden de construcción.
- Ambos deben mantenerse sincronizados.

## 3. Principios de ejecución

- Empezar por lo mínimo viable.
- No introducir backend ni auth hasta que la beta personal lo necesite.
- Procesar audio de forma local o con servicio externo simple.
- Mantener la UI simple y estable.
- Validar cada fase antes de avanzar.

## 4. Fases de Implementación

### Fase 0 — Preparación
**Meta:** dejar listo el terreno técnico.

- Definir stack final: Flutter + SQLite + almacenamiento local.
- Crear estructura del proyecto Flutter.
- Configurar lint, formatter y tests.
- Configurar variables de entorno y secretos.
- Preparar CI básica.

**Entregable:** repositorio base listo para desarrollo.

### Fase 1 — Base de la beta personal
**Meta:** permitir que el usuario entre y vea la app.

- Implementar navegación base.
- Crear layout principal.
- Crear modelo local de grabaciones.
- Definir estados de sesión local.

**Entregable:** app local-first con home, ajustes y grabaciones persistidas.

### Fase 2 — Grabación e importación
**Meta:** capturar audio de manera confiable.

- Implementar grabación.
- Guardar audio localmente.
- Importar archivos externos.
- Validar formatos y tamaño.

**Entregable:** audio capturado o importado y persistido.

### Fase 3 — Transcripción
**Meta:** obtener texto útil desde el audio.

- Crear tarea de transcripción simple.
- Integrar proveedor de IA.
- Normalizar respuesta.
- Guardar transcripción y segmentos.
- Mostrar progreso y estado.
- Permitir motor local por defecto y APIs configurables.

**Entregable:** audio convertido en transcripción consultable.

### Fase 4 — Diarización y edición
**Meta:** distinguir hablantes y corregirlos.

- Agrupar segmentos por hablante.
- Renombrar etiquetas.
- Editar bloques de texto.
- Unir o dividir segmentos.

**Entregable:** transcripción organizada por hablante.

### Fase 5 — Exportación y búsqueda
**Meta:** hacer que el contenido sea reutilizable.

- Exportar PDF.
- Exportar DOCX.
- Implementar búsqueda por texto.
- Filtrar por fecha, duración y hablante.

**Entregable:** salida lista para compartir y consultar.

### Fase 6 — Escalado futuro
**Meta:** preparar el salto a comercial o multiusuario.

- Diseñar autenticación.
- Diseñar sincronización remota.
- Diseñar límites por plan.
- Diseñar pago y suscripciones.

**Entregable:** monetización funcional.

## 5. Orden recomendado de desarrollo

1. Estructura Flutter.
2. Grabación local.
3. Persistencia SQLite.
4. Transcripción.
5. Exportación.
6. Búsqueda.
7. Preparación de escalado.

## 6. Criterios de avance por fase

Una fase solo se considera terminada si:

- La funcionalidad principal funciona.
- Tiene validación mínima.
- Tiene pruebas básicas.
- No rompe la fase anterior.

## 7. Riesgos de implementación

- Cambiar de stack a mitad del proceso.
- Integrar IA demasiado pronto.
- Subestimar costos de procesamiento.
- No dejar una ruta limpia hacia el escalado.

## 8. Próxima acción inmediata

- Completar importacion de audios externos.
- Cerrar exportacion TXT/PDF.
- Refinar diarizacion cuando el motor lo permita.
- Preparar pruebas de integracion de transcripcion.

## 9. Seguimiento obligatorio

- Cada avance técnico debe quedar reflejado en `BITACORA_TECNICA.md`.
- Cada cambio de alcance debe actualizar `PLAN_TRABAJO.md`.
- Cada cambio de secuencia o fase debe actualizar este documento.
- Si se agrega o cambia estructura, documentarlo también en `ESTRUCTURA_PROYECTO.md`.

## 10. Bitácora

| Fecha | Acción | Resultado |
|---|---|---|
| 2026-04-28 | Se creó el plan de implementación | Base de fases lista |
| 2026-04-28 | Pendiente | Confirmar Flutter + SQLite como base personal |
