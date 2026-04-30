# SDD — Sami Transcribe

> Documento de diseño técnico
> Fecha: 2026-04-30
> Estado: Borrador para implementación

## 1. Propósito

Definir la arquitectura y decisiones técnicas para construir **Sami Transcribe**, una app móvil local-first para grabación, transcripción, configuración de motor IA y exportación de reuniones.

## 2. Objetivos

- Capturar audio de forma simple y confiable.
- Transcribir reuniones con buena precisión.
- Separar hablantes y permitir corrección manual.
- Exportar resultados en formatos útiles.
- Mantener una experiencia minimalista y rápida.

## 3. Alcance

### Incluido
- App móvil iOS/Android.
- Grabación local.
- Transcripción diferida.
- Configuración de motor local o API externa.
- Diarización básica cuando el proveedor la soporte.
- Exportación PDF/TXT/DOCX.
- Beta personal sin backend.

### Excluido por ahora
- Video.
- Transcripción en tiempo real.
- Integraciones con videollamadas.
- Edición colaborativa simultánea.
- Soporte masivo multi-idioma.
- Multiusuario y billing.

## 4. Requisitos No Funcionales

- Disponibilidad objetivo: 99.5% para API.
- Latencia de UI: < 3 s en pantalla principal.
- Seguridad: cifrado en tránsito y almacenamiento.
- Escalabilidad: procesamiento asíncrono de transcripciones.
- Privacidad: consentimiento explícito para grabación y procesamiento.

## 5. Arquitectura Propuesta

### Frontend
- **Flutter** para móvil.

### Persistencia
- **SQLite / sqflite** para metadatos.
- **Filesystem local** para audio y exportaciones.

### IA
- Whisper local como opción por defecto.
- OpenAI-compatible o AssemblyAI como alternativas configurables.
- Interfaz desacoplada para permitir cambiar de proveedor.

## 6. Componentes

### 6.1 App Cliente
Responsable de:
- Autenticación.
- Grabación e importación.
- Exploración de grabaciones.
- Visualización y edición de transcripciones.

### 6.2 Servicios locales
Responsables de:
- Persistencia SQLite.
- Grabación de audio.
- Configuración del motor de transcripción.
- Resumen local cuando no hay API.

### 6.3 IA externa opcional
Responsable de:
- Enviar audio al proveedor de IA.
- Recibir y normalizar resultados.
- Generar resúmenes cuando la API lo permita.

### 6.4 Storage
- Audio original.
- Transcripciones persistidas.
- Exportaciones futuras.

## 7. Flujo Principal

1. El usuario graba audio.
2. La app guarda el archivo localmente.
3. El usuario elige motor local o API externa.
4. La app procesa la transcripción.
5. Se persisten texto y segmentos en SQLite.
6. El cliente muestra el resultado y permite edición.
7. El usuario genera resumen o exporta.

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
- Base de la app Flutter.
- Grabación.
- Storage local.

### Fase 2
- Transcripción.
- Configuración de motor IA.
- Estados y monitoreo.

### Fase 3
- Diarización.
- Edición de hablantes.
- Exportación.

### Fase 4
- Búsqueda.
- Escalado futuro.
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

1. Importación de audios externos.
2. Exportación TXT/PDF.
3. Búsqueda local en transcripciones.
4. Mejorar manejo de diarización cuando haya proveedor compatible.
