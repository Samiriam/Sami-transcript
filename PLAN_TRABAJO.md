# Plan de Trabajo — Sami Transcribe

> Ultima actualizacion: 2026-04-30  
> Estado: **Fase 2 — Sprint 2 implementado, faltan importacion y exportacion**  
> Enfoque actual: **beta personal de un solo usuario**

---

## 0. Resumen Ejecutivo

**Sami Transcribe** es una aplicación móvil para uso personal que permite grabar, transcribir y gestionar audio de reuniones o notas de voz. El objetivo inmediato es construir una beta privada para un solo usuario, con una ruta clara para escalar luego a multiusuario o comercial.

**Objetivo de la beta personal:** entregar una app funcional en poco tiempo, con grabación, transcripción, organización local y exportación básica sin backend complejo.

---

## 1. Alcance de la beta personal

### Incluido
| # | Funcionalidad | Prioridad | Sprint |
|---|---|---|---|
| F1 | Grabación de audio con inicio/pausa/detener | P0 | S1 |
| F2 | Almacenamiento local del audio y metadatos | P0 | S1 |
| F3 | Transcripción post-grabación | P0 | S2 |
| F4 | Importación de audios externos | P0 | S2 |
| F5 | Vista de transcripción con edición básica | P1 | S3 |
| F6 | Exportación a TXT/PDF | P1 | S3 |
| F7 | Búsqueda local en transcripciones | P2 | S4 |
| F8 | Interfaz minimalista con modo oscuro | P0 | S1 |
| F9 | Ajustes personales y configuración | P1 | S2 |
| F10 | Preparación para futura sincronización | P2 | S4 |

### Excluido de la beta personal (v2.0+)
- Transcripción en tiempo real durante la grabación
- Integración con Zoom/Teams/Meet
- Modo "Descanso" con playlists
- Colaboración en tiempo real con comentarios
- Marcas de agua personalizadas para branding
- Integración con Notion/Evernote/Slack
- Auth multiusuario y permisos por rol
- Billing y suscripciones
- Sync en nube por defecto
- Soporte para 50+ idiomas

---

## 2. Stack Tecnológico

| Capa | Tecnología | Justificación |
|---|---|---|
| Frontend móvil | **Flutter 3.x** (Dart) | Una sola app para iOS y Android |
| Persistencia local | **SQLite / Drift** | Suficiente para uso personal sin backend |
| Storage de archivos | **Archivos locales** | Más simple para beta privada |
| Backend | **No requerido en beta** | Evita complejidad innecesaria |
| IA transcripción | **API externa o local** | Elegir según costo y privacidad |
| Diarización | **Opcional en beta** | Se puede posponer para la fase 2 |
| CI/CD | **GitHub Actions** | Workflows para test, build y deploy |
| Hosting web | **No aplica en beta personal** | No se publica de inicio |
| Monitoreo | **Sentry** | Errores si se decide habilitar reporte |

---

## 3. Arquitectura de Alto Nivel

```
┌───────────────────────────────────────────────┐
│                  CLIENTE                      │
│          Flutter Mobile / Desktop             │
└───────────────┬───────────────────────────────┘
                │
     ┌──────────┴──────────┐
     ▼                     ▼
┌──────────────┐    ┌──────────────┐
│ SQLite/Drift │    │ Archivos     │
│ metadatos    │    │ locales      │
└──────────────┘    └──────────────┘
                │
                ▼
         ┌──────────────┐
         │ API de IA     │
         │ opcional      │
         └──────────────┘
```

---

## 4. Modelo de Datos (Entidades Principales)

```
Recording
├── id: uuid
├── title: string
├── duration_seconds: int
├── audio_path: string (local)
├── source: "app" | "import"
├── status: "recording" | "uploaded" | "transcribing" | "completed" | "failed"
├── created_at: timestamp

Transcription
├── id: uuid
├── recording_id: uuid (FK → Recording)
├── full_text: text
├── language: string ("es", "en")
├── model_used: string
├── created_at: timestamp

Segment (bloques con hablante)
├── id: uuid
├── transcription_id: uuid (FK → Transcription)
├── speaker_label: string
├── speaker_name: string (editable por usuario)
├── start_time: float (segundos)
├── end_time: float
├── text: text

ExportJob
├── id: uuid
├── transcription_id: uuid (FK)
├── format: "pdf" | "docx"
├── options: json (timestamps, speakers, summary)
├── file_url: string
├── status: "pending" | "completed" | "failed"
```

### Extensión futura
Cuando el producto crezca, se agregará `User` y sincronización remota sin romper este modelo local.

---

## 5. Cronograma por Sprints (16 semanas)

### Fase 1 — Base personal (Semanas 1–2)

#### Sprint 1 (Sem 1-2): Setup + Grabacion
- [x] Inicializar proyecto Flutter
- [x] Definir arquitectura local con SQLite/sqflite
- [x] Configurar CI basica
- [x] Implementar pantalla principal con boton de grabacion
- [x] Servicio de grabacion de audio (inicio/pausa/detener)
- [x] Indicador visual de tiempo de grabacion
- [x] Modo oscuro/claro con toggle
- [x] Almacenamiento local del audio grabado
- [x] Tests unitarios y de widget para UI de grabacion

#### Sprint 2 (Sem 3-4): Transcripción + Importación
- [x] Integrar motor de transcripción local por defecto
- [x] Permitir motor configurables (OpenAI compatible / AssemblyAI)
- [x] Guardar transcripción y metadatos en SQLite
- [x] Pantalla de historial de grabaciones
- [x] Pantalla de transcripción con edición básica
- [x] Resumen de transcripciones
- [ ] Importar archivos externos
- [ ] Procesar audio local post-grabación
- [ ] Validar formatos y tamaño
- [ ] Tests de integración para transcripción e importación

---

### Fase 2 — Edición + Exportación (Semanas 3–4)

#### Sprint 3 (Sem 3): Editor de transcripción
- [ ] Pantalla de transcripción con lectura clara
- [ ] Edición básica de texto
- [ ] Guardado local de cambios
- [ ] Búsqueda dentro de la transcripción abierta
- [ ] Tests de widget para editor

#### Sprint 4 (Sem 4): Exportación y búsqueda
- [ ] Exportar a TXT y PDF
- [ ] Búsqueda local en transcripciones
- [ ] Lista de resultados por fecha y título
- [ ] Compartir archivo exportado desde el dispositivo
- [ ] Tests de exportación

---

### Fase 3 — Preparación para escalado (Semanas 5–6)

#### Sprint 5 (Sem 5): Base escalable
- [ ] Aislar capa de persistencia
- [ ] Definir contratos de sincronización futura
- [ ] Separar servicios para local vs remoto
- [ ] Documentar migración a multiusuario

#### Sprint 6 (Sem 6): Opcional de diarización
- [ ] Evaluar diarización solo si es estable y útil para beta
- [ ] Si no aporta valor inmediato, posponerla
- [ ] Documentar decisión y costo

---

## 6. Ruta de escalado comercial o multiusuario

Cuando la beta personal esté estable, el siguiente camino será:

1. Agregar autenticación.
2. Mover persistencia a PostgreSQL/Supabase.
3. Subir audios a storage remoto.
4. Habilitar sincronización multi-dispositivo.
5. Implementar planes y billing.
6. Añadir colaboración y compartición.
7. Activar métricas y monitoreo completo.

## 7. Riesgos de implementación

- Rehacer arquitectura demasiado pronto.
- Meter backend antes de validar el flujo personal.
- Sobreinvertir en monetización antes de tener uso real.
- No guardar el modelo local de forma compatible con migración futura.

## 8. Proxima accion inmediata

- El programador debe reconstruir la estructura Flutter/Android valida del proyecto (`flutter create` o equivalente) sin perder `lib/`, `test/` y `pubspec.yaml` actuales.
- Luego debe reintentar `flutter analyze` y `flutter build apk --debug`.
- Si el build ya genera APK, continuar con prueba en dispositivo Android.
- Despues retomar importacion de audios externos.

## 9. Bitácora

| Fecha | Accion | Resultado |
|---|---|---|
| 2026-04-28 | Se redifinio el proyecto para beta personal | Alcance reducido y mas realista |
| 2026-04-29 | Se instalo Flutter SDK, Android SDK, herramientas | Entorno listo para desarrollo |
| 2026-04-29 | Sprint 1 implementado: DB, grabacion, UI, tema | Codigo funcional pendiente de prueba en dispositivo |
| 2026-04-30 | Sprint 2 implementado: Whisper local y APIs configurables | Base de transcripcion lista |
| 2026-04-30 | Intento de build APK | Bloqueado por estructura Flutter/Android no inicializada |

---

## 6. Wireframes de Pantallas Principales

### 6.1 Pantalla Principal (Home)
```
┌────────────────────────────┐
│  Sami Transcribe    [⚙️]   │
│                            │
│  ┌──────────────────────┐  │
│  │  Última grabación    │  │
│  │  "Reunión equipo"    │  │
│  │  45 min · 3 hablantes│  │
│  └──────────────────────┘  │
│                            │
│        ╭──────────╮        │
│        │  ▶ REC   │        │
│        │  Grabar  │        │
│        ╰──────────╯        │
│                            │
│  📁 Importar audio         │
│                            │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐      │
│  │📋│ │🔍│ │📁│ │👤│      │
│  └──┘ └──┘ └──┘ └──┘      │
│  Grab  Busq  Arch  Perfil  │
└────────────────────────────┘
```

### 6.2 Pantalla de Transcripción
```
┌────────────────────────────┐
│  ← Reunión equipo     [⋯] │
│  45 min · 14 abr 2026      │
│                            │
│  ┌─ Juan ──────────────┐   │
│  │ 00:00 - 02:15       │   │
│  │ Buenos días equipo,  │   │
│  │ revisemos el sprint. │   │
│  └─────────────────────┘   │
│                            │
│  ┌─ María ─────────────┐   │
│  │ 02:16 - 05:30       │   │
│  │ El sprint va bien,   │   │
│  │ completamos el 80%.  │   │
│  └─────────────────────┘   │
│                            │
│  [📄 Exportar] [✏️ Editar] │
└────────────────────────────┘
```

---

## 7. APIs Externas y Costos Estimados

| Servicio | Uso | Costo estimado (mensual, 1000 usuarios) |
|---|---|---|
| AssemblyAI | Transcripción + diarización | ~$300–$500 ($0.0005/seg) |
| Supabase | Auth + DB + Storage | $0–$25 (free tier → pro) |
| Vercel | Hosting web | $0 (hobby) |
| Railway/Render | Backend API | $5–$20 |
| RevenueCat | Pagos móviles | 1% de revenue |
| Sentry | Monitoreo errores | $0 (free tier) |
| PostHog | Analítica | $0 (free tier) |

**Costo total mensual estimado (MVP, 1000 usuarios):** ~$350–$600 USD

---

## 8. Plan de Monetización

| Plan | Precio | Incluido |
|---|---|---|
| **Free** | $0 | 30 min/grabación, 5 grabaciones/mes, transcripción básica, exportar PDF simple |
| **Premium** | $4.99/mes | 2 h/grabación, grabaciones ilimitadas, diarización avanzada, importar ilimitado, exportar PDF+DOCX, resumen IA, soporte prioritario |
| **Team** (v2) | $12.99/mes por usuario | Todo Premium + colaboración, comentarios, sharing, admin panel |

**Meta de conversión estimada:** 8–12% de free → premium

---

## 9. Riesgos y Mitigaciones

| # | Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|---|
| R1 | Precisión baja en diarización con audios ruidosos | Alta | Medio | Comunicar limitación; permitir edición manual; mejorar con feedback de usuarios |
| R2 | Costos de IA escalan rápido con usuarios free | Medio | Alto | Implementar rate limiting agresivo; cachear resultados; evaluar Whisper self-hosted a escala |
| R3 | Latencia alta en transcripciones largas (>1 h) | Medio | Medio | Procesar en chunks paralelos; mostrar progreso; estimar tiempo al usuario |
| R4 | Rechazo de App Store/Play Store por permisos | Bajo | Alto | Documentar uso de micrófono; seguir guías de privacidad desde el diseño |
| R5 | Flutter Web rendimiento insuficiente | Medio | Medio | Evaluar Next.js como alternativa para web; Flutter móvil es seguro |
| R6 | Competencia (Otter.ai, Rev, tl;dv) | Alto | Medio | Diferenciador: enfoque relajante, UX minimalista, mercado hispano underserved |

---

## 10. Criterios de Aceptación del MVP

- [ ] Un usuario puede grabar audio de hasta 2 h desde la app móvil
- [ ] La transcripción se completa en < 5 min para audio de 1 h
- [ ] La diarización identifica al menos 2 hablantes con > 70% de precisión
- [ ] Se puede importar un archivo MP3 y obtener su transcripción
- [ ] Se puede exportar la transcripción a PDF con hablantes y timestamps
- [ ] La búsqueda encuentra resultados en < 2 segundos con 500+ transcripciones
- [ ] El flujo free → premium funciona end-to-end con pago real
- [ ] La app funciona en iOS, Android y web (PWA)
- [ ] Latencia de carga de pantalla principal < 3 segundos
- [ ] Crash rate < 1% en sesiones activas

---

## 11. Equipo Sugerido

| Rol | Responsabilidad | Dedicación |
|---|---|---|
| Product Owner | Priorización, roadmap, stakeholders | Tiempo completo |
| Flutter Dev (senior) | App móvil + web | Tiempo completo |
| Backend Dev (mid-senior) | API, integraciones IA, infra | Tiempo completo |
| UI/UX Designer | Diseño visual, wireframes, usabilidad | Part-time (50%) |
| QA Engineer | Testing manual + automatizado | Part-time (50%) |

**Duración total estimada:** 16 semanas (4 meses)

---

## 12. Hitos y Entregables

| Hito | Semana | Entregable |
|---|---|---|
| **H1 — Alpha** | 4 | App graba audio, auth funciona, almacena en nube |
| **H2 — Beta 1** | 8 | Transcripción e importación funcionan end-to-end |
| **H3 — Beta 2** | 12 | Diarización + exportación PDF/DOCX |
| **H4 — Release Candidate** | 14 | Búsqueda + monetización integrada |
| **H5 — Launch** | 16 | MVP en producción (stores + web) |

---

## 13. Post-MVP (Roadmap v2.0)

1. **Transcripción en tiempo real** (streaming con WebSocket)
2. **Integración con Zoom/Teams/Meet** (captura de audio del sistema)
3. **Modo Descanso** (meditaciones guiadas post-reunión)
4. **Colaboración en tiempo real** (comentarios, edición compartida)
5. **Soporte 50+ idiomas** (expandir modelos de IA)
6. **Plan Team** con admin panel y analytics
7. **Integración Notion/Slack/Evernote**
8. **Marcas de agua y branding corporativo**
9. **Video transcripción** (extraer audio de video)
10. **App para Apple Watch** (control remoto de grabación)

---

## Bitácora de Cambios

| Fecha | Cambio | Autor |
|---|---|---|
| 2026-04-28 | Creación inicial del plan de trabajo | Kilo |
| 2026-04-28 | Pendiente: revisar con equipo y refinar estimaciones | — |
