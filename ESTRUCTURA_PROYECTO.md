# Estructura Principal — Sami Transcribe

## 1. Estructura sugerida del repositorio

```text
sami-transcribe/
├─ apps/
│  ├─ mobile/
│  └─ web/
├─ services/
│  └─ api/
├─ packages/
│  ├─ shared/
│  ├─ ui/
│  └─ types/
├─ docs/
│  ├─ architecture/
│  ├─ decisions/
│  └─ product/
├─ infra/
│  ├─ docker/
│  └─ github-actions/
├─ scripts/
├─ tests/
└─ README.md
```

## 2. Responsabilidad por carpeta

### `apps/mobile`
App Flutter para iOS y Android.

### `apps/web`
Interfaz web o PWA.

### `services/api`
API principal, auth, grabaciones, exportaciones y orquestación.

### `packages/shared`
Utilidades compartidas, constantes y helpers.

### `packages/ui`
Componentes reutilizables de interfaz.

### `packages/types`
Tipos y contratos compartidos.

### `docs/architecture`
Documentos de arquitectura y flujos.

### `docs/decisions`
Decisiones técnicas importantes.

### `docs/product`
Documentación de producto, roadmap y alcance.

### `infra/docker`
Archivos de contenedores y desarrollo local.

### `infra/github-actions`
Workflows de CI/CD.

## 3. Módulos iniciales

1. Autenticación.
2. Grabaciones.
3. Transcripción.
4. Exportación.
5. Búsqueda.
6. Suscripciones.

## 4. Primeros archivos a crear

- `package.json` o equivalente raíz.
- `pubspec.yaml` en Flutter.
- `.env.example`.
- `PLAN_TRABAJO.md`.
- `PLAN_IMPLEMENTACION.md`.
- `SDD.md`.
- `README.md`.
- `docs/decisions/001-stack.md`.

## 5. Convenciones

- Un módulo por responsabilidad.
- Tipos compartidos en un solo lugar.
- Las integraciones externas deben aislarse.
- La lógica de negocio no debe vivir en UI.

## 6. Siguiente fase

Después de definir la estructura, se debe crear el esqueleto técnico real del repositorio con carpetas y archivos iniciales.
