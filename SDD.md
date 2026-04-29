# SDD — Sami Transcribe

> Documento de diseño técnico
> Fecha: 2026-04-28
> Estado: Borrador para implementación

## 1. Propósito

Definir la arquitectura y decisiones técnicas para construir **Sami Transcribe**, una app móvil y web para grabación, transcripción, diarización y exportación de reuniones.

## 2. Objetivos

- Capturar audio de forma simple y confiable.
- Transcribir reuniones con buena precisión.
- Separar hablantes y permitir corrección manual.
- Exportar resultados en formatos útiles.
- Mantener una experiencia minimalista y rápida.

## 3. Alcance

### Incluido
- App móvil iOS/Android.
- PWA/web.
- Grabación local.
- Importación de audios externos.
- Transcripción diferida.
- Diarización básica.
- Exportación PDF/DOCX.
- Plan free y premium.

### Excluido por ahora
- Video.
- Transcripción en tiempo real.
- Integraciones con videollamadas.
- Edición colaborativa simultánea.
- Soporte masivo multi-idioma.

## 4. Requisitos No Funcionales

- Disponibilidad objetivo: 99.5% para API.
- Latencia de UI: < 3 s en pantalla principal.
- Seguridad: cifrado en tránsito y almacenamiento.
- Escalabilidad: procesamiento asíncrono de transcripciones.
- Privacidad: consentimiento explícito para grabación y procesamiento.

## 5. Arquitectura Propuesta

### Frontend
- **Flutter** para móvil.
- **Flutter Web** o **Next.js PWA** para navegador.

### Backend
- **API Node.js** con Fastify o Express.
- **Worker asíncrono** para transcripción y exportación.
- **PostgreSQL** como base principal.
- **Object storage** para audio y documentos.

### IA
- Proveedor externo para transcripción y diarización.
- Interfaz desacoplada para permitir cambiar de proveedor.

## 6. Componentes

### 6.1 App Cliente
Responsable de:
- Autenticación.
- Grabación e importación.
- Exploración de grabaciones.
- Visualización y edición de transcripciones.

### 6.2 API Principal
Responsable de:
- Usuarios y planes.
- CRUD de grabaciones.
- Orquestación de jobs.
- Exposición de estados de procesamiento.

### 6.3 Worker
Responsable de:
- Enviar audio al proveedor de IA.
- Recibir y normalizar resultados.
- Generar exportaciones.
- Reintentos y manejo de fallas.

### 6.4 Storage
- Audio original.
- Archivos transcritos.
- PDFs y DOCX generados.

## 7. Flujo Principal

1. El usuario graba o importa audio.
2. El cliente sube el archivo al storage.
3. La API crea un job de transcripción.
4. El worker procesa el audio.
5. La API guarda transcripción y segmentos.
6. El cliente muestra el resultado.
7. El usuario exporta o comparte.

## 8. Modelo de Dominio

### User
- id
- email
- plan
- created_at

### Recording
- id
- user_id
- title
- source
- duration_seconds
- audio_url
- status

### Transcription
- id
- recording_id
- language
- full_text
- model_used

### Segment
- id
- transcription_id
- speaker_label
- speaker_name
- start_time
- end_time
- text

### ExportJob
- id
- transcription_id
- format
- options
- status
- file_url

## 9. API de Alto Nivel

- `POST /auth/login`
- `POST /auth/register`
- `GET /recordings`
- `POST /recordings`
- `GET /recordings/:id`
- `DELETE /recordings/:id`
- `POST /recordings/:id/transcribe`
- `GET /transcriptions/:id`
- `PATCH /segments/:id`
- `POST /exports`
- `GET /exports/:id`

## 10. Estado de Procesamiento

- `recording`
- `uploaded`
- `transcribing`
- `completed`
- `failed`

## 11. Decisiones Técnicas

### 11.1 Flutter
Se elige por reutilización de UI y velocidad de entrega. Mantiene coherencia entre móvil y web.

### 11.2 Procesamiento Asíncrono
Las transcripciones pueden tardar varios minutos. Un worker evita bloquear solicitudes HTTP.

### 11.3 PostgreSQL
Permite consultas de búsqueda, relaciones claras y futuras extensiones analíticas.

### 11.4 Proveedor de IA desacoplado
Evita dependencia rígida con un solo vendor y permite optimizar costo/calidad.

## 12. Seguridad y Privacidad

- Autenticación obligatoria para grabaciones.
- URLs firmadas para acceso a archivos.
- Cifrado TLS en tránsito.
- Eliminación programada de archivos temporales.
- Consentimiento visible antes de grabar.
- Políticas separadas para free y premium.

## 13. Riesgos Técnicos

- Audio ruidoso degrada precisión.
- Costos de IA pueden crecer rápido.
- Flutter Web puede requerir optimización extra.
- Diarización automática puede fallar en reuniones mixtas.

## 14. Estrategia de Pruebas

- Unit tests para parsing y reglas de negocio.
- Integration tests para API y worker.
- E2E para grabación, importación y exportación.
- Tests de regresión visual para pantallas clave.

## 15. Plan de Implementación

### Fase 1
- Base del monorepo.
- Auth.
- Grabación.
- Storage.

### Fase 2
- Transcripción.
- Importación.
- Estados y monitoreo.

### Fase 3
- Diarización.
- Edición de hablantes.
- Exportación.

### Fase 4
- Búsqueda.
- Monetización.
- Release.

## 16. Criterios de Aceptación Técnica

- El usuario puede crear y revisar una grabación sin errores críticos.
- La transcripción queda persistida en la base de datos.
- Los segmentos de hablantes se pueden editar.
- La exportación genera archivos válidos.
- Los límites de plan se aplican correctamente.

## 17. Preguntas Abiertas

- ¿Se usará Flutter Web o Next.js para web?
- ¿Se prioriza costo o precisión en el motor de IA?
- ¿La transcripción real-time queda fuera del MVP definitivo?
- ¿Se requiere soporte offline parcial?

## 18. Próximos Pasos

1. Confirmar stack final.
2. Definir esquema SQL inicial.
3. Crear repositorio y estructura base.
4. Implementar grabación y subida.
5. Integrar proveedor de IA.
