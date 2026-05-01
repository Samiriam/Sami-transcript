# Politica de Privacidad — Sami Transcribe

**Ultima actualizacion:** 1 de mayo de 2026

## 1. Informacion que recopilamos

Sami Transcribe es una aplicacion de uso personal que prioriza la privacidad. Recopilamos la minima informacion necesaria:

### Datos generados por el usuario
- **Archivos de audio:** Grabados o importados por el usuario. Se almacenan exclusivamente en el dispositivo.
- **Transcripciones:** Texto generado a partir del audio. Se almacena exclusivamente en el dispositivo.
- **Configuracion:** Preferencias de motor de transcripcion, claves API y ajustes de tema. Se almacenan localmente usando SharedPreferences.

### Datos NO recopilados
- No recopilamos datos personales identificables.
- No accedemos a contactos, ubicacion, calendario ni otros datos del sistema.
- No enviamos audio ni transcripciones a servidores externos, salvo que el usuario configure explicitamente un motor de transcripcion remoto (OpenAI, AssemblyAI u otro).

## 2. Permisos que solicita la aplicacion

| Permiso | Uso |
|---|---|
| `RECORD_AUDIO` | Grabar audio desde el microfono del dispositivo |
| `INTERNET` | Descargar modelo Whisper local y, opcionalmente, conectar a APIs de transcripcion configuradas por el usuario |

## 3. Almacenamiento local

Todos los datos se almacenan en el almacenamiento interno de la aplicacion:
- Audio: directorio de documentos de la app
- Transcripciones: base de datos SQLite local
- Modelo Whisper: directorio de soporte de la app

El usuario puede eliminar todos los datos desinstalando la aplicacion.

## 4. Servicios de terceros (opcionales)

Si el usuario configura un motor de transcripcion remoto:

| Servicio | Datos enviados | Politica de privacidad |
|---|---|---|
| OpenAI / OpenAI-compatible | Archivo de audio para transcripcion | https://openai.com/privacy |
| AssemblyAI | Archivo de audio para transcripcion | https://www.assemblyai.com/privacy |

El envio de datos a estos servicios es exclusivamente bajo la configuracion activa del usuario. La aplicacion no envia datos sin autorizacion.

## 5. Seguridad

- Las claves API se almacenan localmente en SharedPreferences (no en texto plano visible para otras apps).
- La comunicacion con APIs remotas utiliza HTTPS.
- No existe backend propio de Sami Transcribe.

## 6. Derechos del usuario

- Acceder, modificar o eliminar cualquier dato almacenado en la app.
- Cambiar o desactivar el motor de transcripcion remoto en cualquier momento desde Ajustes.
- Eliminar todos los datos desinstalando la aplicacion.

## 7. Cambios a esta politica

Cualquier cambio sera reflejado en esta pagina con la fecha de actualizacion correspondiente.

## 8. Contacto

Para preguntas sobre esta politica de privacidad, contactar a: samiriam.dev@gmail.com
