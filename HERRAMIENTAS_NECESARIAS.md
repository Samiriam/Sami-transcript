# Herramientas Necesarias — Sami Transcribe

> Actualizado: 2026-04-30
> Restricciones: PC de bajos recursos. Sin Docker, sin Android Studio. Todo desde VS Code.

## 1. Desarrollo

- **Flutter SDK** (incluye Dart): app móvil. Instalado en `C:\tools\flutter`.
- **Node.js LTS**: scripts y utilidades. Ya instalado (v22.14.0).
- **pnpm**: gestión de paquetes Node. Instalado globalmente.
- **Git**: control de versiones. Ya instalado (v2.53.0).

## 2. Android SDK (sin Android Studio)

- **Android SDK command-line tools only**: para compilar APKs desde Flutter.
- Instalado en `C:\Android\android-sdk`.
- `flutter doctor` guía la configuración y licencias.

## 3. Editor

- **VS Code**: IDE único. Extensiones necesarias:
  - Flutter (incluye Dart)
  - Awesome Flutter Snippets (opcional)

## 4. Persistencia local (beta personal)

- **SQLite / sqflite**: ya incluido en pubspec. No requiere instalación separada.

## 5. IA y transcripción

- **Whisper local**: motor por defecto sobre el dispositivo, sin internet.
- **API externa** (OpenAI-compatible o AssemblyAI): opcional, se consume por HTTP.

## 6. Calidad

- **Dart analyze / flutter analyze**: viene con Flutter SDK.
- **Flutter test**: widget tests y tests unitarios. Viene con Flutter SDK.

## 7. CI/CD

- **GitHub Actions**: workflows para test y build. Se configura cuando haya código funcional.

## 8. Estado de instalación

| Herramienta | Estado | Nota |
|---|---|---|
| Git | ✅ Instalado | v2.53.0 |
| Node.js | ✅ Instalado | v22.14.0 |
| pnpm | ✅ Instalado | Global via npm |
| Flutter SDK | ✅ Instalado | v3.38.9 en C:\tools\flutter |
| Android SDK | ✅ Instalado | C:\Android\android-sdk |
| Chocolatey | ✅ Instalado | v2.7.1 |
| Java JDK | ✅ Instalado | 1.8.0_211 |
| whisper_flutter_new | ✅ Integrado | Motor local de transcripcion |
| http | ✅ Integrado | Cliente para APIs de transcripcion/resumen |

## 9. Rutas de entorno

```
ANDROID_HOME=C:\Android\android-sdk
ANDROID_SDK_ROOT=C:\Android\android-sdk
JAVA_HOME=C:\Program Files\Java\jdk1.8.0_211
Path+=C:\tools\flutter\bin
Path+=C:\Android\android-sdk\platform-tools
```

## 10. Componentes Android SDK instalados

- **platform-tools**: ✅ Instalado
- **tools**: ✅ Instalado (versión 2017)
- **licenses**: ✅ Instalado

### Componentes faltantes (por instalar)

- **platforms;android-XX** (platform Android API)
- **build-tools;XX.X.X** (build tools)
- **cmdline-tools;latest** (command-line tools modernos)

---

## Resumen de instalación

### Instalado exitosamente

| Herramienta | Versión | Ruta |
|-------------|---------|------|
| Git | 2.53.0 | Sistema |
| Node.js | 22.14.0 | C:\Program Files\nodejs |
| Chocolatey | 2.7.1 | C:\ProgramData\chocolatey |
| Java JDK | 1.8.0_211 | C:\Program Files\Java\jdk1.8.0_211 |
| Android SDK | - | C:\Android\android-sdk |
| Android platform-tools | - | C:\Android\android-sdk\platform-tools |

### Instalado exitosamente

| Herramienta | Versión | Ruta |
|-------------|---------|------|
| Git | 2.53.0 | Sistema |
| Node.js | 22.14.0 | C:\Program Files\nodejs |
| pnpm | Latest | npm global |
| Chocolatey | 2.7.1 | C:\ProgramData\chocolatey |
| Flutter SDK | 3.38.9 | C:\tools\flutter |
| Java JDK | 1.8.0_211 | C:\Program Files\Java\jdk1.8.0_211 |
| Android SDK | - | C:\Android\android-sdk |
| Android platform-tools | - | C:\Android\android-sdk\platform-tools |
| VS Code extensions | **Pendiente** | Flutter + Dart, Awesome Flutter Snippets |

## 9. Herramientas excluidas para la beta personal

| Herramienta | Motivo de exclusión |
|---|---|
| Docker | PC de bajos recursos, no se necesita para app local con SQLite |
| Android Studio | Pesado, innecesario. Flutter compila APKs con CLI tools + VS Code |
| PostgreSQL | La beta usa SQLite local. Se evalúa en fase de escalado |
| Supabase / Firebase | Sin backend en beta personal |
| PostHog | Para fase posterior con analítica |
| Playwright | Para fase posterior si hay interfaz web |

## 10. Nota de trabajo

El stack final para la beta personal es: Flutter + SQLite local + Whisper local por defecto + APIs opcionales configurables, todo desde VS Code.
